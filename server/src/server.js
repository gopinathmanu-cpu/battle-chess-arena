// SPDX-License-Identifier: GPL-3.0-or-later
import { WebSocketServer, WebSocket } from "ws";
import { createServer } from "node:http";
import { randomUUID } from "node:crypto";
import { performance } from "node:perf_hooks";
import { Match, MatchError } from "./match.js";
import { isAction, validateMessage } from "./protocol.js";

export function createMatchServer({
  port = 8080,
  host = "0.0.0.0",
  tickMs = 1000,
  now = () => performance.now(),
} = {}) {
  const games = new Map();
  const peers = new Map();
  const matchmaking = new Map();
  const profiles = new Map();
  const awardedResults = new Set();
  const invites = new Map();
  const httpServer = createServer((request, response) => {
    if (request.method === "GET" && request.url === "/health") {
      response.writeHead(200, { "content-type": "application/json" });
      response.end(JSON.stringify({ status: "ok", protocolVersion: 2 }));
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
  httpServer.listen(port, host);
  const send = (socket, type, payload = {}) => {
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
  const publicInvite = (invite, viewerId) => {
    const sender = invite.sender;
    const recipient = invite.recipient;
    const side = viewerId === sender.id ? "w" : "b";
    return {
      inviteId: invite.id,
      sender: { name: sender.name, avatarId: sender.avatarId },
      recipient: { name: recipient.name, avatarId: recipient.avatarId },
      scheduledAt: invite.scheduledAt,
      createdAt: invite.createdAt,
      status: invite.status,
      awaitingResponseFromName: invite.awaiting?.name ?? null,
      timed: invite.timed,
      baseMs: invite.baseMs,
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
  const createInviteGame = (invite) => {
    if (invite.game || invite.status !== "accepted") return;
    const match = new Match({
      whitePlayer: invite.sender,
      timed: invite.timed,
      baseMs: invite.baseMs,
    });
    const blackToken = match.joinBlack(now(), invite.recipient);
    games.set(match.id, match);
    invite.game = {
      match,
      tokens: { w: match.whiteToken, b: blackToken },
    };
    publishInvite(invite);
  };
  const activateDueInvites = () => {
    const wallTime = Date.now();
    for (const invite of invites.values()) {
      if (
        invite.status === "accepted" &&
        !invite.game &&
        (invite.scheduledAt === null || invite.scheduledAt <= wallTime)
      ) {
        createInviteGame(invite);
      }
    }
  };
  const broadcast = (gameId, state) => {
    for (const [socket, peer] of peers) {
      if (peer.gameId === gameId) send(socket, "game_state", { state });
    }
  };
  const awardCompletedRound = (game) => {
    if (game.status !== "complete") return;
    const key = `${game.id}:${game.round}`;
    if (awardedResults.has(key)) return;
    awardedResults.add(key);
    const white = game.players.w;
    const black = game.players.b;
    if (!white || !black) return;
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
  };
  const tick = () => {
    activateDueInvites();
    for (const game of games.values()) {
      if (game.status === "active") {
        game.settleClock(now());
        awardCompletedRound(game);
        broadcast(game.id, game.snapshot(now()));
      }
    }
  };
  const timer = setInterval(tick, tickMs);
  timer.unref();
  server.on("close", () => clearInterval(timer));

  server.on("connection", (socket) => {
    const peer = { setupReceipts: new Map() };
    peers.set(socket, peer);
    socket.on("error", () => {}); // A transport failure must not crash other rooms.
    send(socket, "connected", { protocolVersion: 2 });
    socket.on("message", (raw, binary) => {
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
        if (message.type === "ping") {
          send(socket, "pong");
          return;
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
          const profile = tokenProfile ?? existing ?? {
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
          });
          return;
        }
        if (!peer.player) {
          throw new MatchError(
            "PROFILE_REQUIRED",
            "Choose an Avatar Name and icon before playing online",
          );
        }
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
          });
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
        if (message.type === "delete_history") {
          peer.player.pointHistory = peer.player.pointHistory.filter(
            (record) => record.recordId !== message.recordId,
          );
          send(socket, "history_deleted", {
            commandId: message.commandId,
            recordId: message.recordId,
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
            createdAt: Date.now(),
            status: "pending",
            awaiting: opponent,
            timed: message.timed ?? true,
            baseMs: message.baseMs ?? 600_000,
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
          invite.hiddenFor.add(peer.player.id);
          send(socket, "invite_deleted", {
            commandId: message.commandId,
            inviteId: invite.id,
          });
          return;
        }
        if (message.type === "respond_invite") {
          const invite = invites.get(message.inviteId);
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
          invite.scheduledAt = message.scheduledAt;
          invite.timed = message.timed ?? invite.timed;
          invite.baseMs = message.baseMs ?? invite.baseMs;
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
          message.type === "quick_match"
        ) {
          const fingerprint = JSON.stringify(message);
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
          if (peer.gameId)
            throw new MatchError(
              "ALREADY_SEATED",
              "Reconnect to a new lobby connection before joining another room",
            );
          if (message.type === "create_game") {
            if (games.size >= 1000)
              throw new MatchError(
                "ROOM_LIMIT",
                "Development server room limit reached",
              );
            game = new Match({
              baseMs: message.baseMs,
              incrementMs: message.incrementMs,
              whitePlayer: peer.player,
            });
            games.set(game.id, game);
            peer.gameId = game.id;
            peer.token = game.whiteToken;
          } else if (message.type === "join_game") {
            game = games.get(message.gameId);
            if (!game)
              throw new MatchError("GAME_NOT_FOUND", "Game does not exist");
            if (game.hasPlayer(peer.player.id))
              throw new MatchError(
                "SELF_MATCH",
                "You cannot join your own game",
              );
            if (
              [...games.values()].some(
                (match) =>
                  match.status !== "complete" &&
                  match.isPair(game.players.w.id, peer.player.id),
              )
            ) {
              throw new MatchError(
                "OPPONENT_GAME_EXISTS",
                "You already have an open game with this opponent",
              );
            }
            peer.token = game.joinBlack(now(), peer.player);
            peer.gameId = game.id;
          } else {
            const baseMs = message.baseMs ?? 600_000;
            const incrementMs = message.incrementMs ?? 0;
            const queueKey = `${baseMs}:${incrementMs}:${peer.player.level}`;
            const eligible = [...games.values()].filter(
              (match) =>
                match.status === "waiting" &&
                match.baseMs === baseMs &&
                match.incrementMs === incrementMs &&
                !match.hasPlayer(peer.player.id) &&
                ![...games.values()].some(
                  (other) =>
                    other.status !== "complete" &&
                    other.isPair(match.players.w.id, peer.player.id),
                ),
            );
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
              for (const [key, gameId] of matchmaking) {
                if (gameId === game.id) matchmaking.delete(key);
              }
              game.matchmakingLevel = null;
              game.matchmakingStartedAt = null;
              peer.token = game.joinBlack(now(), peer.player);
              peer.gameId = game.id;
            } else {
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
              });
              games.set(game.id, game);
              game.matchmakingLevel = peer.player.level;
              game.matchmakingStartedAt = matchTime;
              matchmaking.set(queueKey, game.id);
              peer.gameId = game.id;
              peer.token = game.whiteToken;
              peer.queueKey = queueKey;
            }
          }
          const type =
            message.type === "create_game"
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
          };
          peer.setupReceipts.set(message.commandId, {
            fingerprint,
            type,
            payload,
          });
          send(socket, type, payload);
          broadcast(game.id, state);
          return;
        }
        if (message.type === "cancel_matchmaking") {
          game = games.get(message.gameId);
          if (!game)
            throw new MatchError("GAME_NOT_FOUND", "Game does not exist");
          if (peer.gameId !== game.id || game.sideForToken(peer.token) !== "w")
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
          });
          return;
        }
        if (peer.gameId !== game.id)
          throw new MatchError(
            "UNAUTHORIZED_SEAT",
            "Join or resume the game first",
          );
        game.requireSeat(peer.token);
        if (message.type === "sync") {
          send(socket, "game_state", {
            state: game.snapshot(now()),
            synced: true,
          });
        } else if (isAction(message.type)) {
          const receipt = game.command(peer.token, message, now());
          awardCompletedRound(game);
          broadcast(game.id, game.snapshot(now()));
          send(socket, "command_result", receipt);
        }
      } catch (error) {
        const known = error instanceof MatchError;
        send(socket, "error", {
          ...(message?.commandId ? { commandId: message.commandId } : {}),
          code: known ? error.code : "SERVER_ERROR",
          message: known
            ? error.message
            : "The server could not process the request",
        });
        // A rejected request can still have settled a timeout.
        const seatedGame = games.get(peer.gameId);
        if (seatedGame) broadcast(seatedGame.id, seatedGame.snapshot(now()));
      }
    });
    socket.on("close", () => {
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
    });
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
    async close() {
      clearInterval(timer);
      for (const socket of server.clients) socket.terminate();
      await new Promise((resolve, reject) =>
        server.close((error) => (error ? reject(error) : resolve())),
      );
      await new Promise((resolve, reject) =>
        httpServer.close((error) => (error ? reject(error) : resolve())),
      );
    },
  };
}
