// SPDX-License-Identifier: GPL-3.0-or-later
import { WebSocketServer, WebSocket } from "ws";
import { createServer } from "node:http";
import { randomUUID, randomInt } from "node:crypto";
import { checkpoint, restoreCheckpoint } from './durable-state.js';
import { Match, MatchError } from "./match.js";
import { isAction, validateMessage } from "./protocol.js";
import { SharedInvites, serveInvitePage, inviteExpiresAt, expiredInviteMessage, deletedInviteMessage } from './shared-invites.js';
import {
  chooseComputerMove,
  computerOpponents,
  computerProfile,
} from "./computer-opponents.js";
import {
  canAffordRound,
  chargeOnlineMoveSuggestion,
  chargeRound,
  creditPolicy,
  ensureCreditAccount,
  grantCompletionReward,
  grantDailyLogin,
  grantLowBalanceRecovery,
  publicCreditAccount,
  requireOnlineMoveSuggestionCredit,
  requireRoundCredits,
  roundCost,
} from './credits.js';

export function createMatchServer({
  port = 8080,
  host = "0.0.0.0",
  tickMs = 1000,
  now = Date.now,
  random = Math.random,
  toss = () => randomInt(2) === 0 ? 'w' : 'b',
  computerThinkMs = 2000,
  inviteNow = Date.now,
  creditNow = Date.now,
  stateStore = null,
  initialState = null,
  securityLimits = {},
  pushSender = null,
} = {}) {
  const limits = Object.freeze({
    maxConnections: securityLimits.maxConnections ?? 100,
    maxConnectionsPerIp: securityLimits.maxConnectionsPerIp ?? 10,
    connectionAttemptsPerMinute:
      securityLimits.connectionAttemptsPerMinute ?? 30,
    messagesPerTenSeconds: securityLimits.messagesPerTenSeconds ?? 40,
    newProfilesPerHourPerIp:
      securityLimits.newProfilesPerHourPerIp ?? 10,
    maxProfiles: securityLimits.maxProfiles ?? 1000,
    invalidMessagesPerConnection:
      securityLimits.invalidMessagesPerConnection ?? 5,
  });
  const capabilities = ['available_players', 'color_toss', 'shared_invites', 'custom_avatars', 'invite_clocks', 'credits', 'game_activity',
    ...(pushSender ? ['game_push'] : []),
    ...(stateStore ? ['daily_games'] : [])];
  const startedAt = Date.now();
  const games = new Map();
  const peers = new Map();
  const matchmaking = new Map();
  const profiles = new Map();
  const awardedResults = new Set();
  const invites = new Map();
  const sharedInvites = new SharedInvites({ now: inviteNow });
  const computerTimers = new Map();
  const pushEvents = new Map();
  const connectionsByIp = new Map();
  const connectionAttempts = new Map();
  const profileCreations = new Map();
  const durable = { games, profiles, invites, sharedInvites, awardedResults };
  restoreCheckpoint(initialState, durable, { creditNow });
  const activityPositions = new Map([...games.values()].map(game =>
    [game.id, { round: game.round, ply: game.chess.history().length, status: game.status }]));
  let persistenceFailed = false;
  let closing = false;
  let outbox = null;
  let work = Promise.resolve();
  let lastCheckpoint = initialState ? JSON.stringify(initialState) : null;
  const serialize = (action) => {
    if (!stateStore) return action();
    work = work.then(async () => {
      if (persistenceFailed) return;
      outbox = [];
      try {
        action();
        const saved = checkpoint(durable);
        const encoded = JSON.stringify(saved);
        if (encoded !== lastCheckpoint) {
          await stateStore.save(saved);
          lastCheckpoint = encoded;
        }
        const pending = outbox;
        outbox = null;
        for (const deliver of pending) deliver();
      } catch {
        // No success acknowledgement may escape for a non-durable move.
        // Stop serving this authority; restart must load the last committed state.
        persistenceFailed = true;
        outbox = null;
        console.error('Durable state unavailable; refusing further game requests');
        for (const socket of server.clients) socket.close(1011, 'Game storage unavailable; reconnect later');
      }
    });
    return work;
  };
  const httpServer = createServer((request, response) => {
    if (persistenceFailed) { response.writeHead(503); response.end('Game storage unavailable'); return; }
    if (serveInvitePage(request, response, sharedInvites)) return;
    if (request.method === "GET" && request.url === "/health") {
      response.writeHead(200, { "content-type": "application/json" });
      response.end(
        JSON.stringify({
          status: "ok",
          protocolVersion: 4,
          capabilities,
          durableStorage: stateStore !== null,
          serverVersion: "0.9.0-beta.8",
          startedAt,
        }),
      );
      return;
    }
    response.writeHead(404, { "content-type": "application/json" });
    response.end(JSON.stringify({ error: "not_found" }));
  });
  const server = new WebSocketServer({
    server: httpServer,
    maxPayload: 16 * 1024,
    perMessageDeflate: false,
  });

  const remoteIp = (request) => {
    const forwarded = request.headers['x-forwarded-for'];
    const candidate = Array.isArray(forwarded)
      ? forwarded[0]
      : forwarded?.split(',')[0];
    return candidate?.trim().slice(0, 64) ||
      request.socket.remoteAddress?.slice(0, 64) || 'unknown';
  };
  const allowInWindow = (buckets, key, maximum, windowMs, instant) => {
    if (buckets.size >= 5000) {
      for (const [bucketKey, candidate] of buckets) {
        if (instant - candidate.startedAt >= windowMs) buckets.delete(bucketKey);
      }
    }
    const previous = buckets.get(key);
    const bucket = !previous || instant - previous.startedAt >= windowMs
      ? { startedAt: instant, count: 0 }
      : previous;
    bucket.count += 1;
    buckets.set(key, bucket);
    return bucket.count <= maximum;
  };
  httpServer.listen(port, host);
  const send = (socket, type, payload = {}) => {
    if (outbox) {
      const frame = JSON.stringify({ type, ...payload });
      outbox.push(() => { if (socket.readyState === WebSocket.OPEN) socket.send(frame); });
      return;
    }
    if (socket.readyState === WebSocket.OPEN)
      socket.send(JSON.stringify({ type, ...payload }));
  };
  const sendToPlayer = (playerId, type, payloadForPeer) => {
    for (const [socket, peer] of peers) {
      if (peer.player?.id === playerId) {
        send(socket, type, payloadForPeer(peer));
      }
    }
  };
  const creditFields = (profile) => {
    const account = publicCreditAccount(profile, creditNow());
    return {
      // Keep every balance transition and its ledger reason in one envelope.
      // This prevents clients from observing a number-only change before the
      // authoritative transaction ID arrives on a later frame.
      account,
      credits: account.credits,
      bonusCredits: account.bonusCredits,
      purchasedCredits: account.purchasedCredits,
      creditPolicy,
    };
  };
  const sendCreditBalance = (profile) => sendToPlayer(
    profile.id,
    'credit_balance',
    () => ({ account: publicCreditAccount(profile, creditNow()), creditPolicy }),
  );
  const publishCreditChanges = (changes) => {
    for (const { profile, duplicate } of changes) {
      if (!duplicate) sendCreditBalance(profile);
    }
  };
  const publicInvite = (invite, viewerId) => {
    const sender = invite.sender;
    const recipient = invite.recipient;
    const side = invite.game
      ? (invite.game.match.players.w?.id === viewerId ? 'w' : 'b')
      : null;
    return {
      inviteId: invite.id,
      sender: { name: sender.name, avatarId: sender.avatarId },
      recipient: { name: recipient.name, avatarId: recipient.avatarId },
      scheduledAt: invite.scheduledAt,
      createdAt: invite.createdAt,
      expiresAt: invite.expiresAt,
      status: invite.status,
      awaitingResponseFromName: invite.awaiting?.name ?? null,
      timed: invite.timed,
      baseMs: invite.baseMs,
      incrementMs: invite.incrementMs ?? 0,
      clockMode: invite.clockMode ?? 'live',
      tossForColors: invite.tossForColors,
      ...(invite.game
        ? {
            game: {
              gameId: invite.game.match.id,
              seat: side,
              seatToken: invite.game.tokens[side],
              state: invite.game.match.snapshot(now()),
            },
          }
        : {}),
    };
  };
  const publishInvite = (invite) => {
    for (const player of [invite.sender, invite.recipient]) {
      if (invite.hiddenFor?.has(player.id)) continue;
      sendToPlayer(player.id, "invite_updated", () => ({
        invite: publicInvite(invite, player.id),
      }));
    }
  };
  const createInviteGame = (invite, { creditRequiredOnFailure = false } = {}) => {
    if (invite.game || !['accepted', 'credit_required'].includes(invite.status)) return false;
    const cost = invite.clockMode === 'daily'
      ? creditPolicy.costs.dailyHumanRound
      : creditPolicy.costs.liveHumanRound;
    try {
      requireRoundCredits([invite.sender, invite.recipient], cost, creditNow());
    } catch (error) {
      if (!creditRequiredOnFailure || error.code !== 'INSUFFICIENT_CREDITS') throw error;
      if (invite.status !== 'credit_required') {
        invite.status = 'credit_required';
        publishInvite(invite);
      }
      return false;
    }
    const match = new Match({
      whitePlayer: invite.sender,
      creatorSide: invite.tossForColors ? toss() : 'w',
      tossForColors: invite.tossForColors,
      timed: invite.timed,
      baseMs: invite.baseMs,
      incrementMs: invite.incrementMs ?? 0,
      clockMode: invite.clockMode ?? 'live',
    });
    match.joinBlack(now(), invite.recipient);
    const changes = chargeRound(Object.values(match.players), {
      gameId: match.id,
      round: match.round,
      cost,
      reason: invite.clockMode === 'daily' ? 'daily_human_round' : 'live_human_round',
      now: creditNow(),
    });
    games.set(match.id, match);
    invite.status = 'accepted';
    invite.game = {
      match,
      tokens: { ...match.tokens },
    };
    publishCreditChanges(changes);
    publishInvite(invite);
    publishGameActivity(match, match.snapshot(now()), 'opponent_joined');
    return true;
  };
  const activateDueInvites = () => {
    const wallTime = Date.now();
    for (const invite of invites.values()) {
      if (
        ["accepted", "credit_required"].includes(invite.status) &&
        !invite.game &&
        (invite.scheduledAt === null || invite.scheduledAt <= wallTime)
      ) {
        createInviteGame(invite, { creditRequiredOnFailure: true });
      }
    }
  };
  const reactivateCreditInvitesFor = (playerId) => {
    const wallTime = Date.now();
    for (const invite of invites.values()) {
      if (
        invite.status === 'credit_required' &&
        !invite.game &&
        [invite.sender.id, invite.recipient.id].includes(playerId) &&
        (invite.scheduledAt === null || invite.scheduledAt <= wallTime)
      ) createInviteGame(invite, { creditRequiredOnFailure: true });
    }
  };
  const expireInvitations = () => {
    for (const invite of invites.values()) {
      if (!invite.game && ['pending', 'accepted', 'credit_required'].includes(invite.status) && inviteNow() >= invite.expiresAt) {
        invite.status = 'expired';
        invite.awaiting = null;
        publishInvite(invite);
      }
    }
    for (const invite of sharedInvites.expire()) {
      sendToPlayer(invite.owner.id, 'shared_invite_updated', () => ({ invite: sharedInvites.public(invite) }));
    }
  };
  const pushGameEvent = (game, state, kind) => {
    if (!pushSender || !['move', 'opponent_joined'].includes(kind)) return;
    for (const side of ['w', 'b']) {
      const player = game.players[side];
      if (!player || player.computer) continue;
      const opponent = game.players[side === 'w' ? 'b' : 'w'];
      if (!opponent) continue;
      const lastMover = state.san.length % 2 === 1 ? 'w' : 'b';
      if (kind !== 'opponent_joined' && (state.san.length === 0 || lastMover === side)) continue;
      const eventKey = `${game.round}:${state.san.length}:${kind}`;
      const body = kind === 'opponent_joined'
        ? `${opponent.name} joined. Your game is ready.`
        : `${opponent.name} played ${state.san.at(-1)}.${state.status === 'complete' ? ' Game complete.' : ' It’s your turn.'}`;
      for (const [deviceId, device] of Object.entries(player.pushDevices ?? {})) {
        if (!device.enabled) continue;
        // Match/account socket activity is ephemeral, so closed apps cannot leave
        // a stale persisted "active" flag that suppresses future notifications.
        if ([...peers.values()].some(peer => peer.player?.id === player.id &&
            peer.pushDeviceId === deviceId && peer.pushActive)) continue;
        const key = `${game.id}:${deviceId}`;
        if (pushEvents.get(key) === eventKey) continue;
        pushEvents.set(key, eventKey);
        const deliver = () => Promise.resolve().then(() => pushSender.send({ token: device.token,
          gameId: game.id, title: 'Battle Chess Arena', body })).catch(() => {
          if (pushEvents.get(key) === eventKey) pushEvents.delete(key);
        });
        if (outbox) outbox.push(deliver); else void deliver();
      }
    }
  };
  const publishGameActivity = (game, state, kind = 'updated') => {
    const previous = activityPositions.get(game.id);
    if (kind === 'updated') {
      if ((previous?.status === 'waiting' || !previous) && state.status === 'active' && state.san.length === 0) {
        kind = 'opponent_joined';
      } else if (state.san.length > (previous?.ply ?? 0) &&
          (!previous || previous.round === state.round)) kind = 'move';
    }
    activityPositions.set(game.id, { round: state.round, ply: state.san.length, status: state.status });
    pushGameEvent(game, state, kind);
    for (const side of ['w', 'b']) {
      const player = game.players[side];
      if (!player || player.computer) continue;
      sendToPlayer(player.id, 'game_activity', () => ({
        kind,
        game: { gameId: game.id, seat: side, seatToken: game.tokens[side], state },
      }));
    }
  };
  const broadcast = (gameId, state) => {
    for (const [socket, peer] of peers) {
      if (peer.gameId === gameId) send(socket, "game_state", { state });
    }
    const game = games.get(gameId);
    if (game) publishGameActivity(game, state);
  };
  const scheduleComputerMove = (game) => {
    const eligible = !closing && game.status === "active" &&
      game.players[game.chess.turn()]?.computer === true;
    const fen = game.chess.fen();
    const pending = computerTimers.get(game.id);
    if (pending && (!eligible || pending.round !== game.round || pending.fen !== fen)) {
      clearTimeout(pending.timer);
      computerTimers.delete(game.id);
    }
    if (!eligible || computerTimers.has(game.id)) return;
    // A rematch must receive its own full delay, even when the previous round's
    // reply is waiting behind a durable save or has not fired yet.
    const reply = { round: game.round, fen, timer: null };
    reply.timer = setTimeout(() => serialize(() => {
      if (computerTimers.get(game.id) !== reply) return;
      computerTimers.delete(game.id);
      const side = game.chess.turn();
      if (closing || games.get(game.id) !== game ||
          game.status !== "active" || game.players[side]?.computer !== true ||
          game.round !== reply.round || game.chess.fen() !== reply.fen) return;
      const move = chooseComputerMove(game.chess, game.players[side], random);
      if (!move) return;
      game.play(game.tokens[side], {
        from: move.from,
        to: move.to,
        promotion: move.promotion ?? "q",
      }, now());
      awardCompletedRound(game);
      broadcast(game.id, game.snapshot(now()));
    }), computerThinkMs);
    reply.timer.unref?.();
    computerTimers.set(game.id, reply);
  };
  const awardCompletedRound = (game) => {
    if (game.status !== "complete") return;
    const key = `${game.id}:${game.round}`;
    if (awardedResults.has(key)) return;
    const white = game.players.w;
    const black = game.players.b;
    if (!white || !black) return;
    const creditTime = creditNow();
    for (const player of [white, black]) {
      if (player.computer !== true) ensureCreditAccount(player, creditTime);
    }
    awardedResults.add(key);
    let whitePoints = 1;
    let blackPoints = 1;
    let whiteResult = "draw";
    let blackResult = "draw";
    if (game.result?.winner === "w") {
      whitePoints = 3;
      blackPoints = 0;
      whiteResult = "win";
      blackResult = "loss";
      white.points += 3;
      white.wins += 1;
      black.losses += 1;
    } else if (game.result?.winner === "b") {
      whitePoints = 0;
      blackPoints = 3;
      whiteResult = "loss";
      blackResult = "win";
      black.points += 3;
      black.wins += 1;
      white.losses += 1;
    } else {
      white.points += 1;
      black.points += 1;
      white.draws += 1;
      black.draws += 1;
    }
    const completedAt = Date.now();
    white.pointHistory.push({
      recordId: randomUUID(),
      gameId: game.id,
      opponentName: black.name,
      opponentAvatarId: black.avatarId,
      result: whiteResult,
      points: whitePoints,
      completedAt,
    });
    black.pointHistory.push({
      recordId: randomUUID(),
      gameId: game.id,
      opponentName: white.name,
      opponentAvatarId: white.avatarId,
      result: blackResult,
      points: blackPoints,
      completedAt,
    });
    if (game.chess.history().length >= 2) {
      for (const player of [white, black]) {
        if (player.computer === true) continue;
        const reward = grantCompletionReward(player, {
          gameId: game.id,
          round: game.round,
          now: creditTime,
        });
        if (reward.changed) {
          sendCreditBalance(player);
          reactivateCreditInvitesFor(player.id);
        }
      }
    }
  };

  const tick = () => serialize(() => {
    if (closing) return;
    expireInvitations();
    activateDueInvites();
    for (const game of games.values()) {
      if (game.status === "active") {
        // Client clocks interpolate locally. Daily rooms need a durable write
        // only for an action or expiry, not 86,400 writes per idle day.
        if (game.clockMode === 'daily' && game.activeSince !== null &&
            now() < game.activeSince + game.remaining[game.chess.turn()]) continue;
        game.settleClock(now());
        awardCompletedRound(game);
        broadcast(game.id, game.snapshot(now()));
        scheduleComputerMove(game);
      }
    }
  });
  const timer = setInterval(tick, tickMs);
  timer.unref();
  server.on("close", () => clearInterval(timer));

  server.on("connection", (socket, request) => {
    if (persistenceFailed || closing) { socket.close(1011, 'Game service unavailable'); return; }
    const ip = remoteIp(request);
    const connectedFromIp = connectionsByIp.get(ip) ?? 0;
    const accepted =
      peers.size < limits.maxConnections &&
      connectedFromIp < limits.maxConnectionsPerIp &&
      allowInWindow(
        connectionAttempts,
        ip,
        limits.connectionAttemptsPerMinute,
        60_000,
        Date.now(),
      );
    if (!accepted) {
      socket.close(1013, 'Connection limit reached. Try again later.');
      return;
    }
    connectionsByIp.set(ip, connectedFromIp + 1);
    const peer = {
      setupReceipts: new Map(),
      ip,
      messageWindowStartedAt: Date.now(),
      messageCount: 0,
      invalidMessages: 0,
    };
    peers.set(socket, peer);
    socket.on("error", () => {}); // A transport failure must not crash other rooms.
    send(socket, "connected", { protocolVersion: 4, capabilities });
    socket.on("message", (raw, binary) => {
      const instant = Date.now();
      if (instant - peer.messageWindowStartedAt >= 10_000) {
        peer.messageWindowStartedAt = instant;
        peer.messageCount = 0;
      }
      peer.messageCount += 1;
      if (peer.messageCount > limits.messagesPerTenSeconds) {
        socket.close(1008, 'Message rate limit exceeded.');
        return;
      }
      // Heartbeats are intentionally answered before durable serialization so
      // idle connections cannot force repeated Firestore checkpoint work.
      if (!binary) {
        try {
          const heartbeat = JSON.parse(raw.toString());
          if (heartbeat?.type === 'ping') {
            validateMessage(heartbeat);
            send(socket, 'pong');
            return;
          }
        } catch {
          // The normal protocol error path below counts malformed frames.
        }
      }
      serialize(() => {
        if (closing) return;
        let message;
        let game;
        try {
        const seatedGame = games.get(peer.gameId);
        seatedGame?.settleClock(now());
        if (seatedGame) awardCompletedRound(seatedGame);
        if (binary)
          throw new MatchError("INVALID_MESSAGE", "Use JSON text frames");
        let parsed;
        try {
          parsed = JSON.parse(raw.toString());
        } catch {
          throw new MatchError(
            "INVALID_MESSAGE",
            "Expected a JSON protocol message",
          );
        }
        message = validateMessage(parsed);
        if (message.clockMode === 'daily' && !stateStore) {
          throw new MatchError('DAILY_UNAVAILABLE', 'Daily games are unavailable until durable game storage is enabled. Choose Rapid or Classical.');
        }
        if (message.type === "register_player") {
          const normalizedName = message.name
            .trim()
            .replace(/\s+/g, " ")
            .toLocaleLowerCase("en-US");
          const existing = profiles.get(normalizedName);
          const tokenProfile = message.playerToken
            ? [...profiles.values()].find(
                (profile) => profile.token === message.playerToken,
              )
            : null;
          if (!tokenProfile && !existing) {
            if (profiles.size >= limits.maxProfiles) {
              throw new MatchError(
                'PROFILE_LIMIT',
                'New online profiles are temporarily unavailable.',
              );
            }
            if (!allowInWindow(
              profileCreations,
              peer.ip,
              limits.newProfilesPerHourPerIp,
              3_600_000,
              Date.now(),
            )) {
              throw new MatchError(
                'PROFILE_RATE_LIMIT',
                'Too many profiles were created from this network. Try again later.',
              );
            }
          }
          if (
            existing &&
            existing !== tokenProfile &&
            (!message.playerToken || message.playerToken !== existing.token)
          ) {
            throw new MatchError(
              "AVATAR_NAME_TAKEN",
              "That Avatar ID is already in use",
            );
          }
          const profile = tokenProfile ??
            existing ?? {
              id: randomUUID(),
              token: message.playerToken ?? randomUUID(),
              name: message.name.trim().replace(/\s+/g, " "),
              avatarId: message.avatarId,
              level: message.level ?? "intermediate",
              points: 0,
              wins: 0,
              draws: 0,
              losses: 0,
              pointHistory: [],
              sockets: new Set(),
            };
          const loginCredits = grantDailyLogin(profile, creditNow());
          const recoveryCredits = grantLowBalanceRecovery(profile, creditNow());
          profile.sockets ??= new Set();
          profile.pointHistory ??= [];
          profile.avatarId = message.avatarId;
          profile.level = message.level ?? profile.level ?? "intermediate";
          profile.sockets.add(socket);
          const canonicalKey = profile.name
            .trim()
            .replace(/\s+/g, " ")
            .toLocaleLowerCase("en-US");
          profiles.set(canonicalKey, profile);
          peer.player = profile;
          send(socket, "player_registered", {
            commandId: message.commandId,
            name: profile.name,
            avatarId: profile.avatarId,
            level: profile.level,
            playerToken: profile.token,
            points: profile.points,
            wins: profile.wins,
            draws: profile.draws,
            losses: profile.losses,
            ...creditFields(profile),
          });
          sendCreditBalance(profile);
          if (loginCredits.changed || recoveryCredits.changed)
            reactivateCreditInvitesFor(profile.id);
          return;
        }
        if (!peer.player) {
          throw new MatchError(
            "PROFILE_REQUIRED",
            "Choose an Avatar Name and icon before playing online",
          );
        }
        expireInvitations();
        if (message.type === "update_player") {
          const nextKey = message.name
            .trim()
            .replace(/\s+/g, " ")
            .toLocaleLowerCase("en-US");
          const owner = profiles.get(nextKey);
          if (owner && owner.id !== peer.player.id)
            throw new MatchError(
              "AVATAR_NAME_TAKEN",
              "That Avatar ID is already in use",
            );
          const oldKey = peer.player.name
            .trim()
            .replace(/\s+/g, " ")
            .toLocaleLowerCase("en-US");
          profiles.delete(oldKey);
          peer.player.name = message.name.trim().replace(/\s+/g, " ");
          peer.player.avatarId = message.avatarId;
          peer.player.level = message.level ?? peer.player.level;
          profiles.set(nextKey, peer.player);
          send(socket, "player_updated", {
            commandId: message.commandId,
            name: peer.player.name,
            avatarId: peer.player.avatarId,
            level: peer.player.level,
            playerToken: peer.player.token,
            ...creditFields(peer.player),
          });
          return;
        }
        if (message.type === 'create_shared_invite') {
          const invite = sharedInvites.create(peer.player, message);
          send(socket, 'shared_invite_created', { commandId: message.commandId, invite: sharedInvites.public(invite) });
          return;
        }
        if (message.type === 'list_shared_invites') {
          send(socket, 'shared_invites', { invites: sharedInvites.list(peer.player.id) });
          return;
        }
        if (message.type === 'delete_shared_invite') {
          const invite = sharedInvites.remove(message.inviteId, peer.player.id);
          sendToPlayer(peer.player.id, 'shared_invite_updated', () => ({ invite: sharedInvites.public(invite) }));
          send(socket, 'command_result', { commandId: message.commandId, accepted: true });
          return;
        }
        if (message.type === 'open_shared_invite') {
          const invite = sharedInvites.requireAvailable(message.inviteId);
          if (peer.gameId && peer.gameId !== invite.match?.id)
            throw new MatchError('ALREADY_SEATED', 'Return to the lobby before opening another invitation.');
          if (!invite.match) {
            if (invite.owner.id === peer.player.id)
              throw new MatchError('SELF_INVITE', 'This is your invitation. Share it with a friend to play.');
            if (games.size >= 1000) throw new MatchError('ROOM_LIMIT', 'Game limit reached. Please try again later.');
            if ([...games.values()].some((game) => game.status !== 'complete' && game.isPair(invite.owner.id, peer.player.id)))
              throw new MatchError('OPPONENT_GAME_EXISTS', 'You already have an open game with this friend. Open it from Active games.');
            const cost = invite.clockMode === 'daily'
              ? creditPolicy.costs.dailyHumanRound
              : creditPolicy.costs.liveHumanRound;
            requireRoundCredits([invite.owner, peer.player], cost, creditNow());
            const match = new Match({ whitePlayer: invite.owner, baseMs: invite.baseMs,
              incrementMs: invite.incrementMs, clockMode: invite.clockMode,
              tossForColors: invite.tossForColors, creatorSide: invite.tossForColors ? toss() : 'w' });
            match.joinBlack(now(), peer.player);
            const changes = chargeRound(Object.values(match.players), {
              gameId: match.id,
              round: match.round,
              cost,
              reason: invite.clockMode === 'daily' ? 'daily_human_round' : 'live_human_round',
              now: creditNow(),
            });
            games.set(match.id, match);
            invite.match = match;
            invite.status = 'accepted';
            publishCreditChanges(changes);
            sendToPlayer(invite.owner.id, 'shared_invite_updated', () => ({ invite: sharedInvites.public(invite) }));
            publishGameActivity(match, match.snapshot(now()), 'opponent_joined');
          }
          const match = invite.match;
          if (!match.hasPlayer(peer.player.id))
            throw new MatchError('INVITE_USED', 'This invitation has already been used. Ask your friend for a new invite.');
          const side = match.players.w.id === peer.player.id ? 'w' : 'b';
          peer.gameId = match.id;
          peer.token = match.tokens[side];
          send(socket, 'seat_joined', { commandId: message.commandId, gameId: match.id,
            seat: side, seatToken: peer.token, state: match.snapshot(now()),
            ...creditFields(peer.player) });
          return;
        }
        if (message.type === "leaderboard") {
          const leaders = [...profiles.values()]
            .sort(
              (a, b) =>
                b.points - a.points ||
                b.wins - a.wins ||
                a.name.localeCompare(b.name),
            )
            .slice(0, 50)
            .map(({ name, avatarId, level, points, wins, draws, losses }) => ({
              name,
              avatarId,
              level,
              points,
              wins,
              draws,
              losses,
            }));
          send(socket, "leaderboard", { leaders });
          return;
        }
        if (message.type === "points_history") {
          send(socket, "points_history", {
            matches: [...peer.player.pointHistory].reverse(),
          });
          return;
        }
        if (message.type === 'list_available_players') {
          const occupied = new Set();
          for (const game of games.values()) {
            if (game.status === 'active') {
              for (const player of Object.values(game.players)) {
                if (player) occupied.add(player.id);
              }
            }
          }
          const candidates = [...profiles.values()].filter(player =>
            player.id !== peer.player.id && !player.computer &&
            [...player.sockets].some(s => s.readyState === WebSocket.OPEN) &&
            !occupied.has(player.id) && (!message.after || player.id > message.after)
          ).sort((a, b) => a.id < b.id ? -1 : a.id > b.id ? 1 : 0);
          const page = candidates.slice(0, 10);
          send(socket, 'available_players', {
            requestId: message.requestId,
            players: page.map(player => ({name: player.name, avatarId: player.avatarId,
              level: player.level, online: true})),
            nextCursor: candidates.length > 10 ? page.at(-1).id : null,
          });
          return;
        }
        if (message.type === "find_player") {
          const found = profiles.get(
            message.query
              .trim()
              .replace(/\s+/g, " ")
              .toLocaleLowerCase("en-US"),
          );
          send(socket, "player_found", {
            player:
              found && found.id !== peer.player.id
                ? {
                    name: found.name,
                    avatarId: found.avatarId,
                    level: found.level,
                    online: found.sockets.size > 0,
                  }
                : null,
          });
          return;
        }
        if (message.type === "list_games") {
          for (const candidate of games.values()) {
            if (candidate.hasPlayer(peer.player.id)) {
              candidate.settleClock(now());
              awardCompletedRound(candidate);
            }
          }
          const activeGames = [...games.values()]
            .filter(
              (candidate) =>
                candidate.status !== "complete" &&
                candidate.hasPlayer(peer.player.id),
            )
            .map((candidate) => {
              const side =
                candidate.players.w?.id === peer.player.id ? "w" : "b";
              return {
                gameId: candidate.id,
                seat: side,
                seatToken: candidate.tokens[side],
                state: candidate.snapshot(now()),
              };
            });
          send(socket, "active_games", { games: activeGames });
          return;
        }
        if (message.type === "presence") {
          const statuses = message.names.map((name) => {
            const profile = profiles.get(
              name.trim().replace(/\s+/g, " ").toLocaleLowerCase("en-US"),
            );
            return {
              name,
              online: (profile?.sockets?.size ?? 0) > 0,
            };
          });
          send(socket, "presence", { statuses });
          return;
        }
        if (message.type === 'set_push_device') {
          // One installation belongs to the account currently signed in on it.
          for (const profile of profiles.values()) {
            if (profile.id === peer.player.id) continue;
            for (const [id, device] of Object.entries(profile.pushDevices ?? {})) {
              if (device.token === message.token) delete profile.pushDevices[id];
            }
          }
          const devices = peer.player.pushDevices ??= {};
          // A refreshed token identifies one installation; bound retained devices.
          for (const [id, device] of Object.entries(devices)) {
            if (id !== message.deviceId && device.token === message.token) delete devices[id];
          }
          if (!devices[message.deviceId] && Object.keys(devices).length >= 10) {
            delete devices[Object.keys(devices)[0]];
          }
          devices[message.deviceId] = { token: message.token, enabled: message.enabled };
          peer.pushDeviceId = message.deviceId;
          peer.pushActive = message.active;
          send(socket, 'push_device_saved', { enabled: message.enabled });
          return;
        }
        if (message.type === "send_invite") {
          const opponent = profiles.get(
            message.opponentName
              .trim()
              .replace(/\s+/g, " ")
              .toLocaleLowerCase("en-US"),
          );
          if (!opponent)
            throw new MatchError(
              "PLAYER_NOT_FOUND",
              "No player has registered that Avatar Name",
            );
          if (opponent.id === peer.player.id)
            throw new MatchError("SELF_INVITE", "You cannot invite yourself");
          const scheduledAt = message.scheduledAt ?? null;
          if (
            scheduledAt === null &&
            [...games.values()].some(
              (game) =>
                game.status !== "complete" &&
                game.isPair(peer.player.id, opponent.id),
            )
          )
            throw new MatchError(
              "OPPONENT_GAME_EXISTS",
              "Schedule a future game while your current game is open",
            );
          if (
            [...invites.values()].some(
              (invite) =>
                invite.status === "pending" &&
                ((invite.sender.id === peer.player.id &&
                  invite.recipient.id === opponent.id) ||
                  (invite.sender.id === opponent.id &&
                    invite.recipient.id === peer.player.id)),
            )
          )
            throw new MatchError(
              "INVITE_EXISTS",
              "A pending invitation already exists with this opponent",
            );
          if (scheduledAt !== null && scheduledAt < Date.now() - 60_000)
            throw new MatchError(
              "INVALID_SCHEDULE",
              "Scheduled time must be in the future",
            );
          const invite = {
            id: randomUUID(),
            sender: peer.player,
            recipient: opponent,
            scheduledAt,
            createdAt: inviteNow(),
            expiresAt: inviteExpiresAt(inviteNow(), scheduledAt),
            status: "pending",
            awaiting: opponent,
            timed: message.timed ?? true,
            baseMs: message.baseMs ?? 600_000,
            incrementMs: message.incrementMs ?? 0,
            clockMode: message.clockMode ?? 'live',
            tossForColors: message.tossForColors ?? false,
            game: null,
            hiddenFor: new Set(),
          };
          invites.set(invite.id, invite);
          publishInvite(invite);
          send(socket, "command_result", {
            commandId: message.commandId,
            accepted: true,
          });
          return;
        }
        if (message.type === "list_invites") {
          const visible = [...invites.values()]
            .filter(
              (invite) =>
                invite.sender.id === peer.player.id ||
                invite.recipient.id === peer.player.id,
            )
            .filter((invite) => !invite.hiddenFor?.has(peer.player.id))
            .sort((a, b) => b.createdAt - a.createdAt)
            .map((invite) => publicInvite(invite, peer.player.id));
          send(socket, "invites", { invites: visible });
          return;
        }
        if (message.type === "delete_invite") {
          const invite = invites.get(message.inviteId);
          if (
            !invite ||
            (invite.sender.id !== peer.player.id &&
              invite.recipient.id !== peer.player.id)
          )
            throw new MatchError(
              "INVITE_NOT_FOUND",
              "Invitation is unavailable",
            );
          invite.hiddenFor ??= new Set();
          if (!invite.game && ['pending', 'accepted', 'credit_required'].includes(invite.status)) {
            invite.status = 'deleted';
            invite.awaiting = null;
            publishInvite(invite);
          }
          invite.hiddenFor.add(peer.player.id);
          send(socket, "invite_deleted", {
            commandId: message.commandId,
            inviteId: invite.id,
          });
          return;
        }
        if (message.type === "respond_invite") {
          const invite = invites.get(message.inviteId);
          if (invite && [invite.sender.id, invite.recipient.id].includes(peer.player.id)) {
            if (invite.status === 'expired') throw new MatchError('INVITE_EXPIRED', expiredInviteMessage);
            if (invite.status === 'deleted') throw new MatchError('INVITE_DELETED', deletedInviteMessage);
          }
          if (!invite || invite.awaiting?.id !== peer.player.id)
            throw new MatchError(
              "INVITE_NOT_FOUND",
              "Invitation is unavailable",
            );
          if (invite.status !== "pending")
            throw new MatchError(
              "INVITE_ALREADY_ANSWERED",
              "Invitation already has a response",
            );
          if (
            message.accept &&
            (invite.scheduledAt === null || invite.scheduledAt <= Date.now())
          ) {
            const cost = invite.clockMode === 'daily'
              ? creditPolicy.costs.dailyHumanRound
              : creditPolicy.costs.liveHumanRound;
            requireRoundCredits([invite.sender, invite.recipient], cost, creditNow());
          }
          invite.status = message.accept ? "accepted" : "declined";
          invite.awaiting = null;
          if (
            invite.status === "accepted" &&
            (invite.scheduledAt === null || invite.scheduledAt <= Date.now())
          ) {
            createInviteGame(invite);
          } else {
            publishInvite(invite);
          }
          send(socket, "command_result", {
            commandId: message.commandId,
            accepted: true,
            ...creditFields(peer.player),
          });
          return;
        }
        if (message.type === "propose_invite_time") {
          const invite = invites.get(message.inviteId);
          if (!invite || invite.awaiting?.id !== peer.player.id)
            throw new MatchError(
              "INVITE_NOT_FOUND",
              "Invitation is unavailable or awaiting the other player",
            );
          if (invite.status !== "pending")
            throw new MatchError(
              "INVITE_ALREADY_ANSWERED",
              "Invitation already has a response",
            );
          if (message.scheduledAt < Date.now() + 60_000)
            throw new MatchError(
              "INVALID_SCHEDULE",
              "Proposed time must be at least one minute in the future",
            );
          // Validate the merged proposal before changing any invitation fields.
          new Match({ timed: message.timed ?? invite.timed,
            baseMs: message.baseMs ?? invite.baseMs,
            incrementMs: message.incrementMs ?? invite.incrementMs ?? 0,
            clockMode: message.clockMode ?? invite.clockMode ?? 'live' });
          invite.scheduledAt = message.scheduledAt;
          invite.expiresAt = inviteExpiresAt(inviteNow(), message.scheduledAt);
          invite.timed = message.timed ?? invite.timed;
          invite.baseMs = message.baseMs ?? invite.baseMs;
          invite.incrementMs = message.incrementMs ?? invite.incrementMs ?? 0;
          invite.clockMode = message.clockMode ?? invite.clockMode ?? 'live';
          invite.awaiting =
            peer.player.id === invite.sender.id
              ? invite.recipient
              : invite.sender;
          publishInvite(invite);
          send(socket, "command_result", {
            commandId: message.commandId,
            accepted: true,
          });
          return;
        }
        if (
          message.type === "create_game" ||
          message.type === "join_game" ||
          message.type === "quick_match" ||
          message.type === "start_computer_game"
        ) {
          const fingerprint = JSON.stringify(message);
          let setupCreditChanges = [];
          const previous = peer.setupReceipts.get(message.commandId);
          if (previous) {
            if (previous.fingerprint !== fingerprint)
              throw new MatchError(
                "COMMAND_ID_REUSED",
                "Command ID was already used",
              );
            send(socket, previous.type, previous.payload);
            const current = games.get(peer.gameId);
            if (current)
              send(socket, "game_state", { state: current.snapshot(now()) });
            return;
          }
          const requestedComputer =
            message.type === "start_computer_game"
              ? computerOpponents.find((item) => item.id === message.opponentId)
              : null;
          if (message.type === "start_computer_game" && !requestedComputer)
            throw new MatchError(
              "COMPUTER_NOT_FOUND",
              "Computer opponent is unavailable",
            );
          if (message.type === 'start_computer_game')
            requireRoundCredits([peer.player], creditPolicy.costs.computerRound, creditNow());
          if (message.type === "start_computer_game" && peer.gameId) {
            const queued = games.get(peer.gameId);
            if (
              queued?.status !== "waiting" ||
              queued.creatorPlayer?.id !== peer.player.id
            )
              throw new MatchError(
                "ALREADY_SEATED",
                "Finish the current game before starting another",
              );
            if (peer.queueKey && matchmaking.get(peer.queueKey) === queued.id)
              matchmaking.delete(peer.queueKey);
            games.delete(queued.id);
            peer.gameId = null;
            peer.token = null;
            peer.queueKey = null;
          }
          if (peer.gameId)
            throw new MatchError(
              "ALREADY_SEATED",
              "Reconnect to a new lobby connection before joining another room",
            );
          if (message.type === "start_computer_game") {
            if (games.size >= 1000)
              throw new MatchError(
                "ROOM_LIMIT",
                "Development server room limit reached",
              );
            game = new Match({
              baseMs: message.baseMs,
              incrementMs: message.incrementMs,
              whitePlayer: peer.player,
              creatorSide: message.tossForColors ? toss() : 'w',
              tossForColors: message.tossForColors ?? false,
            });
            game.joinBlack(now(), computerProfile(requestedComputer));
            setupCreditChanges = chargeRound(Object.values(game.players), {
              gameId: game.id,
              round: game.round,
              cost: creditPolicy.costs.computerRound,
              reason: 'server_computer_round',
              now: creditNow(),
            });
            games.set(game.id, game);
            peer.gameId = game.id;
            peer.token = game.creatorToken;
          } else if (message.type === "create_game") {
            if (games.size >= 1000)
              throw new MatchError(
                "ROOM_LIMIT",
                  "Development server room limit reached",
                );
            requireRoundCredits(
              [peer.player],
              creditPolicy.costs.liveHumanRound,
              creditNow(),
            );
            game = new Match({
              baseMs: message.baseMs,
              incrementMs: message.incrementMs,
              whitePlayer: peer.player,
              creatorSide: message.tossForColors ? toss() : 'w',
              tossForColors: message.tossForColors ?? false,
            });
            games.set(game.id, game);
            peer.gameId = game.id;
            peer.token = game.creatorToken;
          } else if (message.type === "join_game") {
            game = games.get(message.gameId);
            if (!game)
              throw new MatchError("GAME_NOT_FOUND", "Game does not exist");
            if (game.hasPlayer(peer.player.id)) {
              // Notification links reopen the authenticated owner's existing seat.
              const side = game.players.w?.id === peer.player.id ? 'w' : 'b';
              peer.gameId = game.id;
              peer.token = game.tokens[side];
              const payload = { commandId: message.commandId, gameId: game.id,
                seat: side, seatToken: peer.token, state: game.snapshot(now()),
                ...creditFields(peer.player) };
              peer.setupReceipts.set(message.commandId, { fingerprint, type: 'seat_resumed', payload });
              send(socket, 'seat_resumed', payload);
              return;
            }
            if (
              [...games.values()].some(
                (match) =>
                  match.status !== "complete" &&
                  match.isPair(game.creatorPlayer.id, peer.player.id),
              )
            ) {
              throw new MatchError(
                "OPPONENT_GAME_EXISTS",
                "You already have an open game with this opponent",
              );
            }
            requireRoundCredits(
              [...Object.values(game.players), peer.player],
              creditPolicy.costs.liveHumanRound,
              creditNow(),
            );
            peer.token = game.joinBlack(now(), peer.player);
            setupCreditChanges = chargeRound(Object.values(game.players), {
              gameId: game.id,
              round: game.round,
              cost: creditPolicy.costs.liveHumanRound,
              reason: 'live_human_round',
              now: creditNow(),
            });
            peer.gameId = game.id;
          } else {
            const baseMs = message.baseMs ?? 600_000;
            const incrementMs = message.incrementMs ?? 0;
            const queueKey = `${baseMs}:${incrementMs}:${peer.player.level}:${message.tossForColors === true}`;
            const eligible = [...games.values()].filter(
              (match) =>
                match.status === "waiting" &&
                match.baseMs === baseMs &&
                match.incrementMs === incrementMs &&
                match.tossForColors === (message.tossForColors ?? false) &&
                !match.hasPlayer(peer.player.id) &&
                ![...games.values()].some(
                  (other) =>
                    other.status !== "complete" &&
                    other.isPair(match.creatorPlayer.id, peer.player.id),
                  ),
            );
            for (let index = eligible.length - 1; index >= 0; index--) {
              const candidate = eligible[index];
              if (canAffordRound(candidate.creatorPlayer, creditPolicy.costs.liveHumanRound, creditNow()))
                continue;
              eligible.splice(index, 1);
              if (candidate.matchmakingStartedAt == null) continue;
              for (const [key, gameId] of matchmaking) {
                if (gameId === candidate.id) matchmaking.delete(key);
              }
              games.delete(candidate.id);
              for (const [waitingSocket, waitingPeer] of peers) {
                if (waitingPeer.gameId !== candidate.id) continue;
                waitingPeer.gameId = null;
                waitingPeer.token = null;
                waitingPeer.queueKey = null;
                send(waitingSocket, 'matchmaking_cancelled', {
                  commandId: null,
                  gameId: candidate.id,
                  reason: 'insufficient_credits',
                  ...creditFields(waitingPeer.player),
                });
              }
            }
            const matchTime = now();
            const waiting =
              eligible.find(
                (match) => match.matchmakingLevel === peer.player.level,
              ) ??
              eligible.find(
                (match) =>
                  matchTime - (match.matchmakingStartedAt ?? matchTime) >=
                  15_000,
              );
            if (waiting) {
              game = waiting;
              requireRoundCredits(
                [...Object.values(game.players), peer.player],
                creditPolicy.costs.liveHumanRound,
                creditNow(),
              );
              for (const [key, gameId] of matchmaking) {
                if (gameId === game.id) matchmaking.delete(key);
              }
              game.matchmakingLevel = null;
              game.matchmakingStartedAt = null;
              peer.token = game.joinBlack(now(), peer.player);
              setupCreditChanges = chargeRound(Object.values(game.players), {
                gameId: game.id,
                round: game.round,
                cost: creditPolicy.costs.liveHumanRound,
                reason: 'live_human_round',
                now: creditNow(),
              });
              peer.gameId = game.id;
            } else {
              requireRoundCredits(
                [peer.player],
                creditPolicy.costs.liveHumanRound,
                creditNow(),
              );
              matchmaking.delete(queueKey);
              if (games.size >= 1000)
                throw new MatchError(
                  "ROOM_LIMIT",
                  "Development server room limit reached",
                );
              game = new Match({
                baseMs,
                incrementMs,
                whitePlayer: peer.player,
                creatorSide: message.tossForColors ? toss() : 'w',
                tossForColors: message.tossForColors ?? false,
              });
              games.set(game.id, game);
              game.matchmakingLevel = peer.player.level;
              game.matchmakingStartedAt = matchTime;
              matchmaking.set(queueKey, game.id);
              peer.gameId = game.id;
              peer.token = game.creatorToken;
              peer.queueKey = queueKey;
            }
          }
          const type =
            message.type === "start_computer_game"
              ? "computer_match_found"
              : message.type === "create_game"
              ? "game_created"
              : message.type === "join_game"
                ? "seat_joined"
                : game.status === "waiting"
                  ? "matchmaking_waiting"
                  : "match_found";
          const state = game.snapshot(now());
          const payload = {
            commandId: message.commandId,
            gameId: game.id,
            seat: game.sideForToken(peer.token),
            seatToken: peer.token,
            state,
            ...creditFields(peer.player),
          };
          peer.setupReceipts.set(message.commandId, {
            fingerprint,
            type,
            payload,
          });
          send(socket, type, payload);
          broadcast(game.id, state);
          publishCreditChanges(setupCreditChanges);
          scheduleComputerMove(game);
          return;
        }
        if (message.type === "cancel_matchmaking") {
          game = games.get(message.gameId);
          if (!game)
            throw new MatchError("GAME_NOT_FOUND", "Game does not exist");
          if (peer.gameId !== game.id || game.sideForToken(peer.token) !== game.creatorSide)
            throw new MatchError(
              "UNAUTHORIZED_SEAT",
              "Only the waiting player can cancel matchmaking",
            );
          if (game.status !== "waiting")
            throw new MatchError(
              "MATCH_FOUND",
              "An opponent has already joined",
            );
          if (peer.queueKey && matchmaking.get(peer.queueKey) === game.id)
            matchmaking.delete(peer.queueKey);
          games.delete(game.id);
          peer.gameId = null;
          peer.token = null;
          peer.queueKey = null;
          send(socket, "matchmaking_cancelled", {
            commandId: message.commandId,
            gameId: game.id,
            ...creditFields(peer.player),
          });
          return;
        }
        game = games.get(message.gameId);
        if (!game)
          throw new MatchError("GAME_NOT_FOUND", "Game does not exist");
        game.settleClock(now());
        awardCompletedRound(game);
        if (message.type === "resume_game") {
          const side = game.requireSeat(message.seatToken);
          if (game.playerIdForSide(side) !== peer.player.id)
            throw new MatchError(
              "UNAUTHORIZED_PLAYER",
              "This game belongs to a different Avatar Name",
            );
          if (
            peer.gameId &&
            (peer.gameId !== game.id || peer.token !== message.seatToken)
          ) {
            throw new MatchError(
              "ALREADY_SEATED",
              "This connection already holds a different seat",
            );
          }
          peer.gameId = game.id;
          peer.token = message.seatToken;
          send(socket, "seat_resumed", {
            gameId: game.id,
            seat: side,
            state: game.snapshot(now()),
            ...creditFields(peer.player),
          });
          return;
        }
        if (peer.gameId !== game.id)
          throw new MatchError(
            "UNAUTHORIZED_SEAT",
            "Join or resume the game first",
          );
        const actingSide = game.requireSeat(peer.token);
        if (message.type === "sync") {
          send(socket, "game_state", {
            state: game.snapshot(now()),
            synced: true,
          });
        } else if (isAction(message.type)) {
          const computerSide = ['w', 'b'].find((side) => game.players[side]?.computer === true);
          const existingReceipt = game.commands.has(`${actingSide}:${message.commandId}`);
          const activatesHumanRematch =
            !computerSide &&
            message.type === 'rematch' &&
            game.status === 'complete' &&
            !game.rematchOffers.has(actingSide) &&
            game.rematchOffers.size === 1;
          const activatesComputerRematch =
            computerSide &&
            message.type === 'rematch' &&
            game.status === 'complete' &&
            !game.rematchOffers.has(actingSide);
          if (!existingReceipt && (activatesHumanRematch || activatesComputerRematch))
            requireRoundCredits(Object.values(game.players), roundCost(game), creditNow());
          const chargeableSuggestion =
            !existingReceipt &&
            message.type === 'use_lifeline' &&
            message.round === game.round &&
            game.status === 'active' &&
            actingSide === game.chess.turn();
          if (chargeableSuggestion && !computerSide)
            throw new MatchError(
              'ASSIST_NOT_AVAILABLE',
              'Move suggestions are available only against the server computer.',
            );
          if (chargeableSuggestion)
            requireOnlineMoveSuggestionCredit(peer.player, creditNow());
          const roundBefore = game.round;
          const receipt = game.command(peer.token, message, now());
          if (receipt.accepted && computerSide) {
            if (
              message.type === "offer_draw" &&
              game.drawOffer?.side !== computerSide
            ) {
              game.command(game.tokens[computerSide], {
                type: "respond_draw",
                commandId: `computer-draw-${game.round}-${game.sequence}`,
                round: game.round,
                offerId: game.drawOffer.offerId,
                accept: false,
              }, now());
            } else if (message.type === "rematch" && game.status === "complete") {
              game.command(game.tokens[computerSide], {
                type: "rematch",
                commandId: `computer-rematch-${game.round}-${game.sequence}`,
                round: game.round,
              }, now());
            }
          }
          let rematchCreditChanges = [];
          if (receipt.accepted && !receipt.duplicate && game.round > roundBefore) {
            const cost = roundCost(game);
            rematchCreditChanges = chargeRound(Object.values(game.players), {
              gameId: game.id,
              round: game.round,
              cost,
              reason: computerSide
                ? 'server_computer_round'
                : game.clockMode === 'daily'
                  ? 'daily_human_round'
                  : 'live_human_round',
              now: creditNow(),
            });
          }
          const suggestionCreditChanges = [];
          if (
            message.type === 'use_lifeline' &&
            receipt.accepted &&
            !receipt.duplicate
          ) {
            suggestionCreditChanges.push(chargeOnlineMoveSuggestion(peer.player, {
              gameId: game.id,
              round: game.round,
              commandId: message.commandId,
              now: creditNow(),
            }));
          }
          awardCompletedRound(game);
          broadcast(game.id, game.snapshot(now()));
          send(socket, "command_result", { ...receipt, ...creditFields(peer.player) });
          publishCreditChanges(rematchCreditChanges);
          publishCreditChanges(suggestionCreditChanges);
          scheduleComputerMove(game);
        }
      } catch (error) {
        const known = error instanceof MatchError;
        if (!known || error.code === 'INVALID_MESSAGE') {
          peer.invalidMessages += 1;
        }
        send(socket, "error", {
          ...(message?.commandId ? { commandId: message.commandId } : {}),
          code: known ? error.code : "SERVER_ERROR",
          message: known
            ? error.message
            : "The server could not process the request",
          ...(known && error.code === 'INSUFFICIENT_CREDITS' && peer.player
            ? creditFields(peer.player)
            : {}),
        });
        // A rejected request can still have settled a timeout.
        const seatedGame = games.get(peer.gameId);
        if (seatedGame) broadcast(seatedGame.id, seatedGame.snapshot(now()));
        if (peer.invalidMessages >= limits.invalidMessagesPerConnection) {
          socket.close(1008, 'Too many invalid messages.');
        }
      }
      });
    });
    socket.on("close", () => serialize(() => {
      peer.player?.sockets?.delete(socket);
      if (peer.queueKey) {
        const waiting = games.get(peer.gameId);
        if (waiting?.status === "waiting") {
          if (matchmaking.get(peer.queueKey) === peer.gameId)
            matchmaking.delete(peer.queueKey);
          games.delete(peer.gameId);
        }
      }
      peers.delete(socket);
      const remaining = (connectionsByIp.get(peer.ip) ?? 1) - 1;
      if (remaining > 0) connectionsByIp.set(peer.ip, remaining);
      else connectionsByIp.delete(peer.ip);
    }));
  });
  return {
    server,
    httpServer,
    games,
    matchmaking,
    profiles,
    awardedResults,
    invites,
    tick,
    sharedInvites,
    async close() {
      closing = true;
      clearInterval(timer);
      for (const computerReply of computerTimers.values())
        clearTimeout(computerReply.timer);
      await work;
      for (const socket of server.clients) socket.terminate();
      await new Promise((resolve, reject) =>
        server.close((error) => (error ? reject(error) : resolve())),
      );
      await work; // Flush disconnect/queue cleanup before the next authority loads.
      await new Promise((resolve, reject) =>
        httpServer.close((error) => (error ? reject(error) : resolve())),
      );
    },
  };
}
