// SPDX-License-Identifier: GPL-3.0-or-later
import test from "node:test";
import assert from "node:assert/strict";
import { once } from "node:events";
import WebSocket from "ws";
import { createMatchServer } from "../src/server.js";
import { computerOpponents } from "../src/computer-opponents.js";

let playerCounter = 0;

test('available humans are paged ten at a time without self, offline users or secrets', async (t) => {
  const app = createMatchServer({
    port: 0,
    host: '127.0.0.1',
    tickMs: 60000,
    // This functional test intentionally creates 24 clients from localhost.
    // Production keeps the stricter anti-abuse defaults.
    securityLimits: {
      maxConnectionsPerIp: 30,
      connectionAttemptsPerMinute: 40,
      newProfilesPerHourPerIp: 30,
    },
  });
  t.after(() => app.close());
  await once(app.server, 'listening');
  const url = `ws://127.0.0.1:${app.server.address().port}`;
  const viewer = await client(url);
  const humans = [];
  for (let i = 0; i < 23; i++) humans.push(await client(url));
  const offline = humans.pop();
  offline.socket.close();
  await once(offline.socket, 'close');
  let after;
  const names = [];
  for (const [index, count] of [10, 10, 2].entries()) {
    viewer.send({type: 'list_available_players', requestId: `page-${index}`, ...(after ? {after} : {})});
    const page = await viewer.next(frame => frame.type === 'available_players');
    assert.equal(page.requestId, `page-${index}`);
    assert.equal(page.players.length, count);
    for (const player of page.players) {
      assert.deepEqual(Object.keys(player).sort(), ['avatarId', 'level', 'name', 'online']);
      assert.equal(player.online, true);
      names.push(player.name);
    }
    after = page.nextCursor;
  }
  assert.equal(after, null);
  assert.equal(new Set(names).size, 22);
  assert.ok(!names.includes(viewer.profile.name));
  assert.ok(!names.includes(offline.profile.name));
  viewer.send({type: 'list_available_players', requestId: 'invalid', after: 12});
  assert.equal((await viewer.next(frame => frame.type === 'error')).code, 'INVALID_MESSAGE');
});

test('WhatsApp HTTPS invite is preview-safe, revocable, and owner-only', async (t) => {
  const app = createMatchServer({ port: 0, host: '127.0.0.1', tickMs: 60000 });
  t.after(() => app.close());
  await once(app.server, 'listening');
  const origin = `http://127.0.0.1:${app.server.address().port}`;
  const owner = await client(origin.replace('http:', 'ws:'));
  const friend = await client(origin.replace('http:', 'ws:'));
  const request = { type: 'create_shared_invite', commandId: 'share-1', baseMs: 300000 };
  owner.send(request);
  const created = await owner.next((frame) => frame.type === 'shared_invite_created');
  const id = created.invite.inviteId;
  assert.equal(JSON.stringify(created).includes('seatToken'), false);
  owner.send(request);
  assert.equal((await owner.next((frame) => frame.type === 'shared_invite_created')).invite.inviteId, id);
  const preview = await fetch(`${origin}/invite/${id}`);
  assert.equal(preview.status, 200);
  assert.equal(preview.headers.get('cache-control'), 'no-store, max-age=0');
  const html = await preview.text();
  assert.ok(html.includes(owner.profile.name));
  assert.ok(html.includes('search for the Avatar name'));
  assert.ok(html.includes(`battlechessarena://invite?invite=${id}`));
  const association = await fetch(`${origin}/.well-known/assetlinks.json`);
  assert.equal(association.headers.get('content-type'), 'application/json');
  assert.equal((await association.json())[0].target.package_name, 'com.manugopinath.battlechessarena');
  owner.send({ type: 'list_games' });
  assert.equal((await owner.next((frame) => frame.type === 'active_games')).games.length, 0);
  friend.send({ type: 'delete_shared_invite', commandId: 'not-owner', inviteId: id });
  assert.equal((await friend.next((frame) => frame.type === 'error')).code, 'INVITE_UNAVAILABLE');
  owner.send({ type: 'delete_shared_invite', commandId: 'delete-link', inviteId: id });
  assert.equal((await owner.next((frame) => frame.type === 'shared_invite_updated')).invite.status, 'deleted');
  const deleted = await fetch(`${origin}/invite/${id}`);
  assert.equal(deleted.status, 410);
  const deletedHtml = await deleted.text();
  assert.ok(deletedHtml.includes('This invitation has been deleted'));
  assert.equal(deletedHtml.includes('battlechessarena://'), false);
  friend.send({ type: 'open_shared_invite', commandId: 'late-open', inviteId: id });
  const denied = await friend.next((frame) => frame.type === 'error' && frame.commandId === 'late-open');
  assert.equal(denied.code, 'INVITE_DELETED');
  assert.ok(denied.message.includes('deleted'));
  owner.send({ type: 'list_shared_invites' });
  assert.equal((await owner.next((frame) => frame.type === 'shared_invites')).invites.length, 0);
  const unknown = await fetch(`${origin}/invite/old-server-invite`);
  assert.equal(unknown.status, 404);
  assert.ok((await unknown.text()).includes('no longer available'));
});

test('shared invite claims once, keeps toss seats, and revocation preserves the started game', async (t) => {
  const app = createMatchServer({ port: 0, host: '127.0.0.1', tickMs: 60000, toss: () => 'b' });
  t.after(() => app.close());
  await once(app.server, 'listening');
  const url = `ws://127.0.0.1:${app.server.address().port}`;
  const owner = await client(url);
  const friend = await client(url);
  const stranger = await client(url);
  owner.send({ type: 'create_shared_invite', commandId: 'new-link', tossForColors: true });
  const id = (await owner.next((frame) => frame.type === 'shared_invite_created')).invite.inviteId;
  friend.send({ type: 'open_shared_invite', commandId: 'open-link', inviteId: id });
  const joined = await friend.next((frame) => frame.type === 'seat_joined');
  assert.equal(joined.seat, 'w');
  assert.equal(joined.state.players.b.name, owner.profile.name);
  assert.equal(joined.state.tossForColors, true);
  const ownerUpdate = await owner.next((frame) => frame.type === 'shared_invite_updated');
  assert.equal(ownerUpdate.invite.status, 'accepted');
  assert.equal(ownerUpdate.invite.gameId, joined.gameId);
  const ownerActivity = await owner.next(frame => frame.type === 'game_activity');
  assert.equal(ownerActivity.game.seat, 'b');
  assert.equal(ownerActivity.game.gameId, joined.gameId);
  friend.send({ type: 'open_shared_invite', commandId: 'retry-open', inviteId: id });
  const retried = await friend.next((frame) => frame.type === 'seat_joined');
  assert.equal(retried.gameId, joined.gameId);
  assert.equal(retried.seatToken, joined.seatToken);
  stranger.send({ type: 'open_shared_invite', commandId: 'third-player', inviteId: id });
  assert.equal((await stranger.next((frame) => frame.type === 'error')).code, 'INVITE_USED');
  owner.send({ type: 'delete_shared_invite', commandId: 'revoke-used', inviteId: id });
  await owner.next((frame) => frame.type === 'shared_invite_updated' && frame.invite.status === 'deleted');
  owner.send({ type: 'list_games' });
  const active = await owner.next((frame) => frame.type === 'active_games');
  assert.equal(active.games[0].gameId, joined.gameId);
  assert.equal(active.games[0].seat, 'b');
  friend.send({ type: 'move', commandId: 'play-after-revoke', gameId: joined.gameId, round: 1, ply: 0, move: { from: 'e2', to: 'e4' } });
  assert.equal((await friend.next((frame) => frame.type === 'command_result')).accepted, true);
});

test('deleting an unanswered named invitation prevents later acceptance', async (t) => {
  const app = createMatchServer({ port: 0, host: '127.0.0.1', tickMs: 60000 });
  t.after(() => app.close());
  await once(app.server, 'listening');
  const url = `ws://127.0.0.1:${app.server.address().port}`;
  const owner = await client(url);
  const friend = await client(url);
  owner.send({ type: 'send_invite', commandId: 'named', opponentName: friend.profile.name });
  const id = (await friend.next((frame) => frame.type === 'invite_updated')).invite.inviteId;
  owner.send({ type: 'delete_invite', commandId: 'cancel-named', inviteId: id });
  assert.equal((await friend.next((frame) => frame.type === 'invite_updated')).invite.status, 'deleted');
  friend.send({ type: 'respond_invite', commandId: 'accept-deleted', inviteId: id, accept: true });
  const denied = await friend.next((frame) => frame.type === 'error');
  assert.equal(denied.code, 'INVITE_DELETED');
});

test('shared link expires exactly after 24 hours, including browser and app opens', async (t) => {
  let wallTime = Date.now();
  const app = createMatchServer({ port: 0, host: '127.0.0.1', tickMs: 60000, inviteNow: () => wallTime });
  t.after(() => app.close());
  await once(app.server, 'listening');
  const origin = `http://127.0.0.1:${app.server.address().port}`;
  const owner = await client(origin.replace('http:', 'ws:'));
  const friend = await client(origin.replace('http:', 'ws:'));
  const request = { type: 'create_shared_invite', commandId: 'expiring' };
  owner.send(request);
  const created = (await owner.next((frame) => frame.type === 'shared_invite_created')).invite;
  assert.equal(created.expiresAt - created.createdAt, 24 * 60 * 60 * 1000);
  wallTime = created.expiresAt - 1;
  assert.equal((await fetch(`${origin}/invite/${created.inviteId}`)).status, 200);
  wallTime++;
  const expired = await fetch(`${origin}/invite/${created.inviteId}`);
  assert.equal(expired.status, 410);
  assert.ok((await expired.text()).includes('This invitation has expired'));
  friend.send({ type: 'open_shared_invite', commandId: 'too-late', inviteId: created.inviteId });
  assert.equal((await friend.next((frame) => frame.type === 'error')).code, 'INVITE_EXPIRED');
  owner.send(request);
  const replay = (await owner.next((frame) => frame.type === 'shared_invite_created')).invite;
  assert.equal(replay.status, 'expired');
  assert.equal(replay.expiresAt, created.expiresAt);
  owner.send({ type: 'list_games' });
  assert.equal((await owner.next((frame) => frame.type === 'active_games')).games.length, 0);
});

test('named invitations expire while scheduled invitations retain their later deadline', async (t) => {
  let wallTime = Date.now();
  const app = createMatchServer({ port: 0, host: '127.0.0.1', tickMs: 60000, inviteNow: () => wallTime });
  t.after(() => app.close());
  await once(app.server, 'listening');
  const url = `ws://127.0.0.1:${app.server.address().port}`;
  const owner = await client(url);
  const friend = await client(url);
  owner.send({ type: 'send_invite', commandId: 'expires-named', opponentName: friend.profile.name });
  const invite = (await friend.next((frame) => frame.type === 'invite_updated')).invite;
  wallTime = invite.expiresAt;
  friend.send({ type: 'respond_invite', commandId: 'expired-response', inviteId: invite.inviteId, accept: true });
  assert.equal((await friend.next((frame) => frame.type === 'error')).code, 'INVITE_EXPIRED');
  const scheduledAt = wallTime + 3 * 24 * 60 * 60 * 1000;
  owner.send({ type: 'send_invite', commandId: 'scheduled-expiry', opponentName: friend.profile.name, scheduledAt });
  const scheduled = (await friend.next((frame) => frame.type === 'invite_updated' && frame.invite.status === 'pending')).invite;
  assert.equal(scheduled.expiresAt, scheduledAt + 15 * 60 * 1000);
});

test('colour toss gives creator Black, survives retries, and joins White', async (t) => {
  let tosses = 0;
  const app = createMatchServer({ port: 0, host: '127.0.0.1', tickMs: 60000, toss: () => { tosses++; return 'b'; } });
  t.after(() => app.close());
  await once(app.server, 'listening');
  const url = `ws://127.0.0.1:${app.server.address().port}`;
  const host = await client(url);
  const guest = await client(url);
  const connected = await host.next((frame) => frame.type === 'connected');
  assert.ok(connected.capabilities.includes('color_toss'));
  const request = { type: 'create_game', commandId: 'toss-create', tossForColors: true };
  host.send(request);
  const created = await host.next((frame) => frame.type === 'game_created');
  assert.equal(created.seat, 'b');
  assert.equal(created.state.players.b.name, host.profile.name);
  assert.equal(created.state.players.w, null);
  assert.equal(created.state.tossForColors, true);
  host.send(request);
  const repeated = await host.next((frame) => frame.type === 'game_created');
  assert.equal(repeated.seatToken, created.seatToken);
  assert.equal(tosses, 1);
  guest.send({ type: 'join_game', commandId: 'join-toss', gameId: created.gameId });
  const joined = await guest.next((frame) => frame.type === 'seat_joined');
  assert.equal(joined.seat, 'w');
  assert.equal(joined.state.players.w.name, guest.profile.name);
  guest.send({ type: 'move', commandId: 'white-opens', gameId: joined.gameId, round: 1, ply: 0, move: { from: 'e2', to: 'e4' } });
  assert.equal((await guest.next((frame) => frame.type === 'command_result' && frame.commandId === 'white-opens')).accepted, true);
  host.send({ type: 'resume_game', gameId: created.gameId, seatToken: created.seatToken });
  const resumed = await host.next((frame) => frame.type === 'seat_resumed');
  assert.equal(resumed.seat, 'b');
  assert.equal(tosses, 1);
});

test('invitation toss assigns recipient White and only reveals their own token', async (t) => {
  const app = createMatchServer({ port: 0, host: '127.0.0.1', tickMs: 60000, toss: () => 'b' });
  t.after(() => app.close());
  await once(app.server, 'listening');
  const url = `ws://127.0.0.1:${app.server.address().port}`;
  const sender = await client(url);
  const recipient = await client(url);
  sender.send({ type: 'send_invite', commandId: 'invite-toss', opponentName: recipient.profile.name, tossForColors: true, timed: false });
  const pending = await recipient.next((frame) => frame.type === 'invite_updated');
  assert.equal(pending.invite.tossForColors, true);
  recipient.send({ type: 'respond_invite', commandId: 'accept-toss', inviteId: pending.invite.inviteId, accept: true });
  const accepted = await recipient.next((frame) => frame.type === 'invite_updated' && frame.invite.game);
  const sent = await sender.next((frame) => frame.type === 'invite_updated' && frame.invite.game);
  assert.equal(accepted.invite.game.seat, 'w');
  assert.equal(sent.invite.game.seat, 'b');
  assert.notEqual(accepted.invite.game.seatToken, sent.invite.game.seatToken);
  assert.equal(accepted.invite.game.state.players.w.name, recipient.profile.name);
});

test('online computer opens as White when the human tosses Black', async (t) => {
  const app = createMatchServer({ port: 0, host: '127.0.0.1', tickMs: 60000, computerThinkMs: 5, toss: () => 'b', random: () => 0 });
  t.after(() => app.close());
  await once(app.server, 'listening');
  const human = await client(`ws://127.0.0.1:${app.server.address().port}`);
  human.send({ type: 'start_computer_game', commandId: 'bot-toss', opponentId: computerOpponents[0].id, tossForColors: true });
  const started = await human.next((frame) => frame.type === 'computer_match_found');
  assert.equal(started.seat, 'b');
  assert.equal(started.state.players.w.botLevel, 1);
  const moved = await human.next((frame) => frame.type === 'game_state' && frame.state.san.length === 1);
  assert.equal(moved.state.turn, 'b');
});

test('default computer replies allow a full animation gap without changing opponent strength', async (t) => {
  const app = createMatchServer({ port: 0, host: '127.0.0.1', tickMs: 60000, random: () => 0 });
  t.after(() => app.close());
  await once(app.server, 'listening');
  const human = await client(`ws://127.0.0.1:${app.server.address().port}`);
  human.send({ type: 'start_computer_game', commandId: 'delayed-bot', opponentId: 'priya-nair' });
  const started = await human.next((frame) => frame.type === 'computer_match_found');
  assert.equal(started.state.players.b.botLevel, 8);
  const requestedAt = performance.now();
  human.send({ type: 'move', gameId: started.gameId, round: 1, commandId: 'delayed-e4',
    ply: 0, move: { from: 'e2', to: 'e4' } });
  await human.next((frame) => frame.type === 'command_result' && frame.commandId === 'delayed-e4');
  await new Promise((resolve) => setTimeout(resolve, 1100));
  assert.equal(app.games.get(started.gameId).chess.history().length, 1,
    'The computer must not interrupt the move animation with an immediate reply');
  const moved = await human.next((frame) => frame.type === 'game_state' && frame.state.san.length === 2);
  // Allow only timer scheduling precision; the configured wait is 2000ms.
  assert.ok(performance.now() - requestedAt >= 1990);
  assert.equal(moved.state.turn, 'w');
  assert.equal(moved.state.players.b.botLevel, 8);
});

test('finishing a round cancels its pending computer reply', async (t) => {
  const app = createMatchServer({ port: 0, host: '127.0.0.1', tickMs: 60000,
    computerThinkMs: 100, toss: () => 'b', random: () => 0 });
  t.after(() => app.close());
  await once(app.server, 'listening');
  const human = await client(`ws://127.0.0.1:${app.server.address().port}`);
  human.send({ type: 'start_computer_game', commandId: 'finish-before-reply',
    opponentId: computerOpponents[0].id, tossForColors: true });
  const started = await human.next((frame) => frame.type === 'computer_match_found');
  human.send({ type: 'resign', gameId: started.gameId, round: 1, commandId: 'cancel-reply' });
  await human.next((frame) => frame.type === 'command_result' && frame.commandId === 'cancel-reply');
  const game = app.games.get(started.gameId);
  const sequence = game.sequence;
  await new Promise((resolve) => setTimeout(resolve, 180));
  assert.equal(game.status, 'complete');
  assert.equal(game.chess.history().length, 0);
  assert.equal(game.sequence, sequence);
});

test('rematching replaces an old pending computer reply with a fresh full delay', async (t) => {
  const app = createMatchServer({ port: 0, host: '127.0.0.1', tickMs: 60000,
    computerThinkMs: 500, toss: () => 'b', random: () => 0 });
  t.after(() => app.close());
  await once(app.server, 'listening');
  const human = await client(`ws://127.0.0.1:${app.server.address().port}`);
  human.send({ type: 'start_computer_game', commandId: 'rematch-before-reply',
    opponentId: computerOpponents[0].id, tossForColors: true });
  const started = await human.next((frame) => frame.type === 'computer_match_found');
  await new Promise((resolve) => setTimeout(resolve, 250));
  human.send({ type: 'resign', gameId: started.gameId, round: 1, commandId: 'round-one-resign' });
  await human.next((frame) => frame.type === 'command_result' && frame.commandId === 'round-one-resign');
  const restartedAt = performance.now();
  human.send({ type: 'rematch', gameId: started.gameId, round: 1, commandId: 'fresh-bot-round' });
  await human.next((frame) => frame.type === 'command_result' && frame.commandId === 'fresh-bot-round');
  await new Promise((resolve) => setTimeout(resolve, 300));
  const game = app.games.get(started.gameId);
  assert.equal(game.round, 2);
  assert.equal(game.chess.history().length, 0,
    'A timer from round one must not play early in round two');
  const moved = await human.next((frame) => frame.type === 'game_state' &&
    frame.state.round === 2 && frame.state.san.length === 1);
  assert.ok(performance.now() - restartedAt >= 490);
  assert.equal(moved.state.turn, 'b');
});

test('Black waiting player can cancel a toss queue and a new toss queue pairs correctly', async (t) => {
  const app = createMatchServer({ port: 0, host: '127.0.0.1', tickMs: 60000, toss: () => 'b' });
  t.after(() => app.close());
  await once(app.server, 'listening');
  const url = `ws://127.0.0.1:${app.server.address().port}`;
  const first = await client(url);
  const second = await client(url);
  first.send({ type: 'quick_match', commandId: 'queue-toss', tossForColors: true });
  const queued = await first.next((frame) => frame.type === 'matchmaking_waiting');
  assert.equal(queued.seat, 'b');
  first.send({ type: 'cancel_matchmaking', commandId: 'cancel-black', gameId: queued.gameId });
  const cancelled = await first.next((frame) => frame.type === 'matchmaking_cancelled');
  assert.equal(cancelled.commandId, 'cancel-black');
  first.send({ type: 'quick_match', commandId: 'queue-again', tossForColors: true });
  const waiting = await first.next((frame) => frame.type === 'matchmaking_waiting');
  second.send({ type: 'quick_match', commandId: 'join-queue', tossForColors: true });
  const paired = await second.next((frame) => frame.type === 'match_found');
  assert.equal(paired.seat, 'w');
  assert.equal(paired.gameId, waiting.gameId);
  assert.equal(paired.state.players.b.name, first.profile.name);
});

async function client(url, savedProfile = null) {
  const socket = new WebSocket(url);
  const inbox = [];
  const waiters = [];
  socket.on("message", (raw) => {
    const frame = JSON.parse(raw);
    const index = waiters.findIndex((waiter) => waiter.predicate(frame));
    if (index < 0) inbox.push(frame);
    else waiters.splice(index, 1)[0].resolve(frame);
  });
  await once(socket, "open");
  const api = {
    socket,
    profile: null,
    send: (message) => socket.send(JSON.stringify(message)),
    next(predicate) {
      const index = inbox.findIndex(predicate);
      if (index >= 0) return Promise.resolve(inbox.splice(index, 1)[0]);
      return new Promise((resolve, reject) => {
        const timer = setTimeout(
          () => reject(new Error("Timed out waiting for protocol response")),
          3000,
        );
        waiters.push({
          predicate,
          resolve: (frame) => {
            clearTimeout(timer);
            resolve(frame);
          },
        });
      });
    },
  };
  const profile = savedProfile ?? {
    name: `Player ${++playerCounter}`,
    avatarId: "knight",
  };
  api.send({
    type: "register_player",
    commandId: `profile-${playerCounter}-${Date.now()}`,
    name: profile.name,
    avatarId: profile.avatarId,
    level: profile.level ?? "intermediate",
    ...(profile.playerToken ? { playerToken: profile.playerToken } : {}),
  });
  const registered = await api.next(
    (frame) => frame.type === "player_registered",
  );
  api.profile = {
    name: registered.name,
    avatarId: registered.avatarId,
    level: registered.level,
    playerToken: registered.playerToken,
  };
  api.registered = registered;
  return api;
}

test("health check and lobby heartbeat work without a game", async (t) => {
  const app = createMatchServer({ port: 0, host: "127.0.0.1", tickMs: 60_000 });
  t.after(() => app.close());
  await once(app.server, "listening");
  const address = `127.0.0.1:${app.server.address().port}`;

  const response = await fetch(`http://${address}/health`);
  assert.equal(response.status, 200);
  const health = await response.json();
  assert.equal(health.status, "ok");
  assert.equal(health.protocolVersion, 4);
  assert.equal(health.serverVersion, "0.9.0-beta.8");
  assert.equal(health.durableStorage, false);
  assert.equal(Number.isInteger(health.startedAt), true);

  const lobby = await client(`ws://${address}`);
  lobby.send({ type: "ping" });
  assert.equal(
    (await lobby.next((frame) => frame.type === "pong")).type,
    "pong",
  );
});

test("connection and message floods are closed before game work", async (t) => {
  const app = createMatchServer({
    port: 0,
    host: "127.0.0.1",
    tickMs: 60_000,
    securityLimits: {
      maxConnections: 1,
      maxConnectionsPerIp: 1,
      connectionAttemptsPerMinute: 5,
      messagesPerTenSeconds: 2,
    },
  });
  t.after(() => app.close());
  await once(app.server, "listening");
  const url = `ws://127.0.0.1:${app.server.address().port}`;

  const accepted = new WebSocket(url);
  const connected = once(accepted, "message");
  await once(accepted, "open");
  await connected;

  const rejected = new WebSocket(url);
  await once(rejected, "open");
  const [connectionCode] = await once(rejected, "close");
  assert.equal(connectionCode, 1013);

  accepted.send(JSON.stringify({ type: "ping" }));
  accepted.send(JSON.stringify({ type: "ping" }));
  accepted.send(JSON.stringify({ type: "ping" }));
  const [messageCode] = await once(accepted, "close");
  assert.equal(messageCode, 1008);
});

test("two sockets play, reconnect, sync, reject replays, draw and rematch", async (t) => {
  const app = createMatchServer({ port: 0, host: "127.0.0.1", tickMs: 60_000 });
  t.after(() => app.close());
  await once(app.server, "listening");
  const url = `ws://127.0.0.1:${app.server.address().port}`;
  const white = await client(url);
  const black = await client(url);
  white.send({ type: "create_game", commandId: "create", baseMs: 60_000 });
  const created = await white.next((f) => f.type === "game_created");
  const gameId = created.gameId;
  black.send({ type: "join_game", gameId, commandId: "join" });
  const joined = await black.next((f) => f.type === "seat_joined");
  assert.equal(joined.seat, "b");
  const move = {
    type: "move",
    gameId,
    round: 1,
    commandId: "move1",
    ply: 0,
    move: { from: "e2", to: "e4" },
  };
  white.send(move);
  const state1 = await black.next(
    (f) => f.type === "game_state" && f.state.san.length === 1,
  );
  assert.deepEqual(state1.state.san, ["e4"]);
  assert.equal(JSON.stringify(state1).includes(created.seatToken), false);
  white.send(move);
  assert.equal(
    (await white.next((f) => f.type === "command_result" && f.duplicate))
      .accepted,
    true,
  );
  black.send({
    ...move,
    commandId: "move2",
    ply: 1,
    move: { from: "d7", to: "d5" },
  });
  await white.next((f) => f.type === "game_state" && f.state.san.length === 2);
  white.send({
    ...move,
    commandId: "move3",
    ply: 2,
    move: { from: "e4", to: "d5" },
  });
  await black.next(
    (f) => f.type === "game_state" && f.state.san.at(-1) === "exd5",
  );
  white.socket.terminate();
  const resumed = await client(url, white.profile);
  resumed.send({ type: "resume_game", gameId, seatToken: created.seatToken });
  const seat = await resumed.next((f) => f.type === "seat_resumed");
  assert.equal(seat.state.san.length, 3);
  resumed.send({ type: "sync", gameId });
  const sync = await resumed.next((f) => f.synced);
  assert.ok(sync.state.sequence > seat.state.sequence);
  resumed.send(move); // A lost acknowledgement can be retried after reconnect.
  assert.equal(
    (await resumed.next((f) => f.type === "command_result")).duplicate,
    true,
  );
  resumed.send({ type: "offer_draw", gameId, commandId: "draw", round: 1 });
  await black.next((f) => f.state?.drawOffer?.offerId === "draw");
  black.send({
    type: "respond_draw",
    gameId,
    commandId: "accept",
    round: 1,
    offerId: "draw",
    accept: true,
  });
  const ended = await resumed.next((f) => f.state?.status === "complete");
  assert.deepEqual(ended.state.result, { reason: "agreement", winner: null });
  for (const [c, commandId] of [
    [resumed, "rematchw"],
    [black, "rematchb"],
  ]) {
    c.send({ type: "rematch", gameId, round: 1, commandId });
  }
  const rematch = await resumed.next((f) => f.state?.round === 2);
  assert.equal(rematch.state.san.length, 0);
  assert.equal(rematch.state.status, "active");
  assert.ok(rematch.state.sequence > ended.state.sequence);
  const outsider = await client(url);
  outsider.send({ type: "sync", gameId });
  assert.equal(
    (await outsider.next((f) => f.type === "error")).code,
    "UNAUTHORIZED_SEAT",
  );
  outsider.send({ type: "resume_game", gameId, seatToken: null });
  assert.equal(
    (await outsider.next((f) => f.type === "error")).code,
    "INVALID_MESSAGE",
  );
  outsider.socket.send("not json");
  assert.equal(
    (await outsider.next((f) => f.type === "error")).code,
    "INVALID_MESSAGE",
  );
  outsider.socket.send("x".repeat(17 * 1024));
  assert.equal((await once(outsider.socket, "close"))[0], 1009);
});

test("server tick broadcasts timeout without a player command", async (t) => {
  let now = 1000;
  const app = createMatchServer({
    port: 0,
    host: "127.0.0.1",
    now: () => now,
    tickMs: 60_000,
  });
  t.after(() => app.close());
  await once(app.server, "listening");
  const url = `ws://127.0.0.1:${app.server.address().port}`;
  const white = await client(url);
  const black = await client(url);
  white.send({ type: "create_game", commandId: "create", baseMs: 10_000 });
  const { gameId } = await white.next((f) => f.type === "game_created");
  black.send({ type: "join_game", commandId: "join", gameId });
  await black.next((f) => f.type === "seat_joined");
  now = 11_001;
  app.tick();
  const [a, b] = await Promise.all(
    [white, black].map((c) => c.next((f) => f.state?.status === "complete")),
  );
  assert.deepEqual(a.state, b.state);
  assert.deepEqual(a.state.result, { reason: "timeout", winner: "b" });
});

test("quick match pairs equal time controls and supports cancellation", async (t) => {
  const app = createMatchServer({ port: 0, host: "127.0.0.1", tickMs: 60_000 });
  t.after(() => app.close());
  await once(app.server, "listening");
  const url = `ws://127.0.0.1:${app.server.address().port}`;
  const first = await client(url);
  const second = await client(url);

  first.send({
    type: "quick_match",
    commandId: "quick-one",
    baseMs: 180_000,
    incrementMs: 0,
  });
  const waiting = await first.next((f) => f.type === "matchmaking_waiting");
  assert.equal(waiting.seat, "w");
  assert.equal(waiting.state.status, "waiting");

  second.send({
    type: "quick_match",
    commandId: "quick-two",
    baseMs: 180_000,
    incrementMs: 0,
  });
  const found = await second.next((f) => f.type === "match_found");
  assert.equal(found.gameId, waiting.gameId);
  assert.equal(found.seat, "b");
  assert.equal(found.state.status, "active");
  const active = await first.next(
    (f) => f.type === "game_state" && f.state.status === "active",
  );
  assert.equal(active.state.gameId, waiting.gameId);

  const third = await client(url);
  third.send({
    type: "quick_match",
    commandId: "quick-three",
    baseMs: 300_000,
    incrementMs: 0,
  });
  const other = await third.next((f) => f.type === "matchmaking_waiting");
  assert.notEqual(other.gameId, waiting.gameId);
  third.send({
    type: "cancel_matchmaking",
    commandId: "cancel-three",
    gameId: other.gameId,
  });
  const cancelled = await third.next((f) => f.type === "matchmaking_cancelled");
  assert.equal(cancelled.gameId, other.gameId);
  assert.equal(app.games.has(other.gameId), false);

  const abandoned = await client(url);
  abandoned.send({
    type: "quick_match",
    commandId: "quick-abandoned",
    baseMs: 600_000,
    incrementMs: 0,
  });
  const reserved = await abandoned.next(
    (f) => f.type === "matchmaking_waiting",
  );
  abandoned.socket.close();
  await once(abandoned.socket, "close");
  for (
    let attempt = 0;
    attempt < 20 && app.games.has(reserved.gameId);
    attempt++
  ) {
    await new Promise((resolve) => setTimeout(resolve, 5));
  }
  assert.equal(app.games.has(reserved.gameId), false);
});

test("twenty built-in opponents create authoritative online computer games", async (t) => {
  assert.equal(computerOpponents.length, 20);
  assert.equal(new Set(computerOpponents.map((opponent) => opponent.id)).size, 20);
  assert.deepEqual(
    new Set(computerOpponents.map((opponent) => opponent.level)),
    new Set(["beginner", "intermediate", "advanced"]),
  );
  const app = createMatchServer({
    port: 0,
    host: "127.0.0.1",
    tickMs: 60_000,
    computerThinkMs: 0,
    random: () => 0,
  });
  t.after(() => app.close());
  await once(app.server, "listening");
  const human = await client(`ws://127.0.0.1:${app.server.address().port}`);
  human.send({
    type: "start_computer_game",
    commandId: "computer-game",
    opponentId: "priya-nair",
    baseMs: 180_000,
    incrementMs: 0,
  });
  const created = await human.next((frame) => frame.type === "computer_match_found");
  assert.equal(created.seat, "w");
  assert.equal(created.state.players.b.name, "Priya Nair");
  assert.equal(created.state.players.b.computer, true);
  assert.equal(created.state.players.b.botLevel, 8);
  human.send({
    type: "move",
    gameId: created.gameId,
    round: 1,
    commandId: "human-e4",
    ply: 0,
    move: { from: "e2", to: "e4" },
  });
  const replied = await human.next(
    (frame) => frame.type === "game_state" && frame.state.san.length === 2,
  );
  assert.equal(replied.state.turn, "w");
});

test("quick match prefers equal player levels then widens after waiting", async (t) => {
  let clock = 0;
  const app = createMatchServer({
    port: 0,
    host: "127.0.0.1",
    tickMs: 60_000,
    now: () => clock,
  });
  t.after(() => app.close());
  await once(app.server, "listening");
  const url = `ws://127.0.0.1:${app.server.address().port}`;
  const beginner = await client(url, {
    name: "Level Beginner One",
    avatarId: "knight",
    level: "beginner",
  });
  const advanced = await client(url, {
    name: "Level Advanced One",
    avatarId: "mage",
    level: "advanced",
  });
  const beginnerTwo = await client(url, {
    name: "Level Beginner Two",
    avatarId: "sun",
    level: "beginner",
  });
  beginner.send({
    type: "quick_match",
    commandId: "level-beginner-one",
    baseMs: 300_000,
    incrementMs: 0,
  });
  const beginnerWaiting = await beginner.next(
    (frame) => frame.type === "matchmaking_waiting",
  );
  advanced.send({
    type: "quick_match",
    commandId: "level-advanced-one",
    baseMs: 300_000,
    incrementMs: 0,
  });
  const advancedWaiting = await advanced.next(
    (frame) => frame.type === "matchmaking_waiting",
  );
  assert.notEqual(beginnerWaiting.gameId, advancedWaiting.gameId);
  beginnerTwo.send({
    type: "quick_match",
    commandId: "level-beginner-two",
    baseMs: 300_000,
    incrementMs: 0,
  });
  const sameLevel = await beginnerTwo.next(
    (frame) => frame.type === "match_found",
  );
  assert.equal(sameLevel.gameId, beginnerWaiting.gameId);

  const waitingIntermediate = await client(url, {
    name: "Level Intermediate",
    avatarId: "robot",
    level: "intermediate",
  });
  waitingIntermediate.send({
    type: "quick_match",
    commandId: "level-intermediate",
    baseMs: 600_000,
    incrementMs: 0,
  });
  const aged = await waitingIntermediate.next(
    (frame) => frame.type === "matchmaking_waiting",
  );
  clock = 15_001;
  const wideningBeginner = await client(url, {
    name: "Widen Beginner",
    avatarId: "dragon",
    level: "beginner",
  });
  wideningBeginner.send({
    type: "quick_match",
    commandId: "level-widened",
    baseMs: 600_000,
    incrementMs: 0,
  });
  const widened = await wideningBeginner.next(
    (frame) => frame.type === "match_found",
  );
  assert.equal(widened.gameId, aged.gameId);
});

test("unique profiles, one open game per opponent, multiple opponents and leaderboard", async (t) => {
  const app = createMatchServer({ port: 0, host: "127.0.0.1", tickMs: 60_000 });
  t.after(() => app.close());
  await once(app.server, "listening");
  const url = `ws://127.0.0.1:${app.server.address().port}`;
  const alice = await client(url, { name: "Arena Alice", avatarId: "mage" });
  const bob = await client(url, { name: "Arena Bob", avatarId: "robot" });

  alice.send({ type: "find_player", query: "Arena Bob" });
  const found = await alice.next((frame) => frame.type === "player_found");
  assert.deepEqual(found.player, {
    name: "Arena Bob",
    avatarId: "robot",
    level: "intermediate",
    online: true,
  });
  bob.send({
    type: "update_player",
    commandId: "update-avatar",
    name: "Arena Bob",
    avatarId: "sun",
  });
  const updated = await bob.next((frame) => frame.type === "player_updated");
  assert.equal(updated.avatarId, "sun");

  const imposter = new WebSocket(url);
  await once(imposter, "open");
  const duplicateName = new Promise((resolve) => {
    imposter.on("message", (raw) => {
      const frame = JSON.parse(raw);
      if (frame.code === "AVATAR_NAME_TAKEN") resolve(frame);
    });
  });
  imposter.send(
    JSON.stringify({
      type: "register_player",
      commandId: "duplicate-name",
      name: "arena alice",
      avatarId: "crown",
    }),
  );
  assert.equal((await duplicateName).code, "AVATAR_NAME_TAKEN");
  imposter.close();

  alice.send({ type: "create_game", commandId: "first", baseMs: 60_000 });
  const first = await alice.next((frame) => frame.type === "game_created");
  bob.send({
    type: "join_game",
    commandId: "join-first",
    gameId: first.gameId,
  });
  await bob.next((frame) => frame.type === "seat_joined");
  bob.send({ type: "list_games" });
  const activeGames = await bob.next((frame) => frame.type === "active_games");
  assert.equal(activeGames.games.length, 1);
  assert.equal(activeGames.games[0].state.players.w.name, "Arena Alice");

  const aliceSecondConnection = await client(url, alice.profile);
  aliceSecondConnection.send({
    type: "create_game",
    commandId: "second",
    baseMs: 60_000,
  });
  const second = await aliceSecondConnection.next(
    (frame) => frame.type === "game_created",
  );
  const bobSecondConnection = await client(url, bob.profile);
  bobSecondConnection.send({
    type: "join_game",
    commandId: "duplicate-opponent",
    gameId: second.gameId,
  });
  assert.equal(
    (
      await bobSecondConnection.next(
        (frame) => frame.code === "OPPONENT_GAME_EXISTS",
      )
    ).code,
    "OPPONENT_GAME_EXISTS",
  );

  const charlie = await client(url, {
    name: "Arena Charlie",
    avatarId: "dragon",
  });
  charlie.send({
    type: "join_game",
    commandId: "join-second",
    gameId: second.gameId,
  });
  await charlie.next((frame) => frame.type === "seat_joined");

  alice.send({
    type: "resign",
    gameId: first.gameId,
    round: 1,
    commandId: "resign",
  });
  await bob.next((frame) => frame.state?.status === "complete");
  bob.send({ type: "leaderboard" });
  const leaders = await bob.next((frame) => frame.type === "leaderboard");
  assert.equal(leaders.leaders[0].name, "Arena Bob");
  assert.equal(leaders.leaders[0].points, 3);
  assert.equal(leaders.leaders[0].wins, 1);
  assert.equal(
    leaders.leaders.find((entry) => entry.name === "Arena Alice").losses,
    1,
  );
  bob.send({ type: "points_history" });
  const points = await bob.next((frame) => frame.type === "points_history");
  assert.equal(points.matches.length, 1);
  assert.equal(points.matches[0].opponentName, "Arena Alice");
  assert.equal(points.matches[0].result, "win");
  assert.equal(points.matches[0].points, 3);
  bob.send({
    type: "update_player",
    commandId: "rename-avatar",
    name: "Arena Bobby",
    avatarId: "sun",
  });
  await bob.next(
    (frame) => frame.type === "player_updated" && frame.name === "Arena Bobby",
  );
  const reconnected = await client(url, {
    ...bob.profile,
    name: "Arena Bob",
  });
  assert.equal(reconnected.profile.name, "Arena Bobby");
});

test("favourite presence and immediate or scheduled invitations", async (t) => {
  const app = createMatchServer({ port: 0, host: "127.0.0.1", tickMs: 60_000 });
  t.after(() => app.close());
  await once(app.server, "listening");
  const url = `ws://127.0.0.1:${app.server.address().port}`;
  const alice = await client(url, { name: "Invite Alice", avatarId: "sun" });
  const bob = await client(url, { name: "Invite Bob", avatarId: "moon" });
  const charlie = await client(url, {
    name: "Invite Charlie",
    avatarId: "ranger",
  });

  alice.send({ type: "presence", names: ["Invite Bob", "Missing Hero"] });
  const presence = await alice.next((frame) => frame.type === "presence");
  assert.deepEqual(presence.statuses, [
    { name: "Invite Bob", online: true },
    { name: "Missing Hero", online: false },
  ]);

  alice.send({
    type: "send_invite",
    commandId: "invite-now",
    opponentName: "Invite Bob",
  });
  const received = await bob.next((frame) => frame.type === "invite_updated");
  assert.equal(received.invite.status, "pending");
  bob.send({
    type: "respond_invite",
    commandId: "accept-now",
    inviteId: received.invite.inviteId,
    accept: true,
  });
  const bobGame = await bob.next(
    (frame) => frame.type === "invite_updated" && frame.invite.game,
  );
  const aliceGame = await alice.next(
    (frame) => frame.type === "invite_updated" && frame.invite.game,
  );
  assert.equal(bobGame.invite.game.seat, "b");
  assert.equal(aliceGame.invite.game.seat, "w");
  assert.equal(bobGame.invite.game.gameId, aliceGame.invite.game.gameId);
  assert.notEqual(
    bobGame.invite.game.seatToken,
    aliceGame.invite.game.seatToken,
  );
  bob.send({
    type: "delete_invite",
    commandId: "delete-invite",
    inviteId: received.invite.inviteId,
  });
  await bob.next((frame) => frame.type === "invite_deleted");
  bob.send({ type: "list_invites" });
  const bobInvites = await bob.next((frame) => frame.type === "invites");
  assert.equal(
    bobInvites.invites.some(
      (invite) => invite.inviteId === received.invite.inviteId,
    ),
    false,
  );
  alice.send({ type: "list_invites" });
  const aliceInvites = await alice.next((frame) => frame.type === "invites");
  assert.equal(
    aliceInvites.invites.some(
      (invite) => invite.inviteId === received.invite.inviteId,
    ),
    true,
  );

  const future = Date.now() + 180_000;
  alice.send({
    type: "send_invite",
    commandId: "invite-active-opponent-later",
    opponentName: "Invite Bob",
    scheduledAt: future,
    timed: false,
    baseMs: 600_000,
  });
  const futureInvite = await bob.next(
    (frame) =>
      frame.type === "invite_updated" && frame.invite.scheduledAt === future,
  );
  assert.equal(futureInvite.invite.awaitingResponseFromName, "Invite Bob");
  assert.equal(futureInvite.invite.timed, false);
  const counter = future + 60_000;
  bob.send({
    type: "propose_invite_time",
    commandId: "counter-time",
    inviteId: futureInvite.invite.inviteId,
    scheduledAt: counter,
    timed: true,
    baseMs: 180_000,
  });
  const countered = await alice.next(
    (frame) =>
      frame.type === "invite_updated" && frame.invite.scheduledAt === counter,
  );
  assert.equal(countered.invite.awaitingResponseFromName, "Invite Alice");
  assert.equal(countered.invite.timed, true);
  assert.equal(countered.invite.baseMs, 180_000);
  alice.send({
    type: "respond_invite",
    commandId: "accept-counter",
    inviteId: futureInvite.invite.inviteId,
    accept: true,
  });
  const counterAccepted = await bob.next(
    (frame) =>
      frame.type === "invite_updated" &&
      frame.invite.inviteId === futureInvite.invite.inviteId &&
      frame.invite.status === "accepted",
  );
  assert.equal(counterAccepted.invite.game, undefined);

  const due = Date.now() + 200;
  alice.send({
    type: "send_invite",
    commandId: "invite-later",
    opponentName: "Invite Charlie",
    scheduledAt: due,
  });
  const scheduled = await charlie.next(
    (frame) =>
      frame.type === "invite_updated" && frame.invite.scheduledAt === due,
  );
  charlie.send({
    type: "respond_invite",
    commandId: "accept-later",
    inviteId: scheduled.invite.inviteId,
    accept: true,
  });
  const accepted = await charlie.next(
    (frame) =>
      frame.type === "invite_updated" &&
      frame.invite.inviteId === scheduled.invite.inviteId &&
      frame.invite.status === "accepted",
  );
  assert.equal(accepted.invite.game, undefined);
  await new Promise((resolve) => setTimeout(resolve, 210));
  app.tick();
  const scheduledGame = await charlie.next(
    (frame) =>
      frame.type === "invite_updated" &&
      frame.invite.inviteId === scheduled.invite.inviteId &&
      frame.invite.game,
  );
  assert.equal(scheduledGame.invite.game.seat, "b");
});

test('games and rematches are free while suggestions and completion rewards retain their rules', async (t) => {
  const creditTime = Date.UTC(2026, 8, 26, 12);
  const app = createMatchServer({ port: 0, host: '127.0.0.1', tickMs: 60_000,
    creditNow: () => creditTime, computerThinkMs: 60_000 });
  t.after(() => app.close());
  await once(app.server, 'listening');
  const url = `ws://127.0.0.1:${app.server.address().port}`;
  const alice = await client(url, { name: 'Credit Alice', avatarId: 'crown' });
  const bob = await client(url, { name: 'Credit Bobby', avatarId: 'knight' });
  const connected = await alice.next((frame) => frame.type === 'connected');
  assert.ok(connected.capabilities.includes('credits'));
  assert.equal(alice.registered.credits, 300);
  assert.equal(alice.registered.account.credits, 300);
  assert.equal(alice.registered.creditPolicy.costs.liveHumanRound, 0);
  assert.equal((await alice.next((frame) => frame.type === 'credit_balance')).account.credits, 300);

  const create = { type: 'create_game', commandId: 'credit-room', baseMs: 600_000 };
  alice.send(create);
  const waiting = await alice.next((frame) => frame.type === 'game_created');
  assert.equal(waiting.credits, 300);
  assert.equal(app.profiles.get('credit alice').creditAccount.bonusBalance, 300);
  alice.send(create);
  assert.equal((await alice.next((frame) => frame.type === 'game_created')).gameId, waiting.gameId);
  assert.equal(app.profiles.get('credit alice').creditAccount.bonusBalance, 300);

  bob.send({ type: 'join_game', commandId: 'credit-join', gameId: waiting.gameId });
  const joined = await bob.next((frame) => frame.type === 'seat_joined');
  assert.equal(joined.credits, 300);
  assert.equal(joined.account.credits, 300);
  assert.ok(joined.account.recentTransactions.every(transaction => transaction.type !== 'round_fee'));
  assert.equal(app.profiles.get('credit alice').creditAccount.bonusBalance, 300);
  assert.equal(app.profiles.get('credit bobby').creditAccount.bonusBalance, 300);


  bob.send({ type: 'resume_game', gameId: joined.gameId, seatToken: joined.seatToken });
  assert.equal((await bob.next((frame) => frame.type === 'seat_resumed')).credits, 300);
  assert.equal(app.profiles.get('credit bobby').creditAccount.bonusBalance, 300);

  const suggestion = { type: 'use_lifeline', commandId: 'paid-suggestion',
    gameId: joined.gameId, round: 1 };
  alice.send(suggestion);
  const suggested = await alice.next((frame) =>
    frame.type === 'error' && frame.commandId === 'paid-suggestion');
  assert.equal(suggested.code, 'ASSIST_NOT_AVAILABLE');
  assert.equal(app.profiles.get('credit alice').creditAccount.bonusBalance, 300);
  assert.equal(app.games.get(joined.gameId).lifelineRequests.w, 0);
  bob.send({ ...suggestion, commandId: 'wrong-turn-suggestion' });
  const wrongTurnSuggestion = await bob.next((frame) =>
    frame.type === 'command_result' && frame.commandId === 'wrong-turn-suggestion');
  assert.equal(wrongTurnSuggestion.accepted, false);
  assert.equal(wrongTurnSuggestion.code, 'NOT_YOUR_TURN');
  assert.equal(wrongTurnSuggestion.credits, 300);
  assert.equal(app.games.get(joined.gameId).lifelineRequests.b, 0);

  alice.send({ type: 'resign', commandId: 'empty-resign', gameId: joined.gameId, round: 1 });
  await alice.next((frame) => frame.type === 'command_result' && frame.commandId === 'empty-resign');
  assert.equal(app.profiles.get('credit alice').creditAccount.bonusBalance, 300);
  assert.equal(app.profiles.get('credit bobby').creditAccount.bonusBalance, 300);

  alice.send({ type: 'rematch', commandId: 'rematch-a', gameId: joined.gameId, round: 1 });
  await alice.next((frame) => frame.type === 'command_result' && frame.commandId === 'rematch-a');
  assert.equal(app.profiles.get('credit alice').creditAccount.bonusBalance, 300);
  bob.send({ type: 'rematch', commandId: 'rematch-b', gameId: joined.gameId, round: 1 });
  await bob.next((frame) => frame.type === 'command_result' && frame.commandId === 'rematch-b');
  assert.equal(app.profiles.get('credit alice').creditAccount.bonusBalance, 300);
  assert.equal(app.profiles.get('credit bobby').creditAccount.bonusBalance, 300);

  alice.send({ type: 'move', commandId: 'credit-e4', gameId: joined.gameId, round: 2,
    ply: 0, move: { from: 'e2', to: 'e4' } });
  await alice.next((frame) => frame.type === 'command_result' && frame.commandId === 'credit-e4');
  bob.send({ type: 'move', commandId: 'credit-e5', gameId: joined.gameId, round: 2,
    ply: 1, move: { from: 'e7', to: 'e5' } });
  await bob.next((frame) => frame.type === 'command_result' && frame.commandId === 'credit-e5');
  alice.send({ type: 'resign', commandId: 'played-resign', gameId: joined.gameId, round: 2 });
  await alice.next((frame) => frame.type === 'command_result' && frame.commandId === 'played-resign');
  assert.equal(app.profiles.get('credit alice').creditAccount.bonusBalance, 301);
  assert.equal(app.profiles.get('credit bobby').creditAccount.bonusBalance, 301);

  const botConnection = await client(url, alice.profile);
  botConnection.send({ type: 'start_computer_game', commandId: 'paid-bot',
    opponentId: computerOpponents[0].id });
  const bot = await botConnection.next((frame) => frame.type === 'computer_match_found');
  assert.equal(bot.credits, 301);
  assert.equal(app.profiles.get('credit alice').creditAccount.bonusBalance, 301);
  app.profiles.get('credit alice').creditAccount.bonusBalance = 0;
  botConnection.send({ type: 'use_lifeline', commandId: 'unfunded-suggestion',
    gameId: bot.gameId, round: 1 });
  const unfunded = await botConnection.next((frame) =>
    frame.type === 'error' && frame.commandId === 'unfunded-suggestion');
  assert.equal(unfunded.code, 'INSUFFICIENT_CREDITS');
  assert.equal(unfunded.message, 'You need 1 credit for an online move suggestion.');
  assert.equal(unfunded.credits, 0);
  assert.equal(app.games.get(bot.gameId).lifelineRequests.w, 0);
});

test('zero credits allow room creation, joins and quick matching', async (t) => {
  const app = createMatchServer({port: 0, host: '127.0.0.1', tickMs: 60_000});
  t.after(() => app.close());
  await once(app.server, 'listening');
  const url = `ws://127.0.0.1:${app.server.address().port}`;
  const host = await client(url, {name: 'Poor Host', avatarId: 'crown'});
  const guest = await client(url, {name: 'Funded Guest', avatarId: 'knight'});
  app.profiles.get('poor host').creditAccount.bonusBalance = 0;
  host.send({type: 'create_game', commandId: 'free-room'});
  const room = await host.next(frame => frame.type === 'game_created');
  guest.send({type: 'join_game', commandId: 'free-join', gameId: room.gameId});
  await guest.next(frame => frame.type === 'seat_joined');
  assert.equal(app.profiles.get('poor host').creditAccount.bonusBalance, 0);
  assert.equal(app.profiles.get('funded guest').creditAccount.bonusBalance, 300);
  const first = await client(url, {name: 'Poor Queue', avatarId: 'mage'});
  const second = await client(url, {name: 'Fresh Queue', avatarId: 'robot'});
  app.profiles.get('poor queue').creditAccount.bonusBalance = 0;
  first.send({type: 'quick_match', commandId: 'free-queue'});
  const waiting = await first.next(frame => frame.type === 'matchmaking_waiting');
  second.send({type: 'quick_match', commandId: 'free-match'});
  const matched = await second.next(frame => frame.type === 'match_found');
  assert.equal(matched.gameId, waiting.gameId);
  assert.equal(app.profiles.get('poor queue').creditAccount.bonusBalance, 0);
});

test('scheduled games activate without a credit balance requirement', async (t) => {
  let creditTime = Date.UTC(2026, 8, 26, 12);
  const app = createMatchServer({ port: 0, host: '127.0.0.1', tickMs: 60_000,
    creditNow: () => creditTime });
  t.after(() => app.close());
  await once(app.server, 'listening');
  const url = `ws://127.0.0.1:${app.server.address().port}`;
  const alice = await client(url, { name: 'Schedule Alice', avatarId: 'crown' });
  const bob = await client(url, { name: 'Schedule Bobby', avatarId: 'knight' });
  app.profiles.get('schedule bobby').creditAccount.bonusBalance = 1;
  const due = Date.now() + 300;
  alice.send({ type: 'send_invite', commandId: 'credit-schedule',
    opponentName: bob.profile.name, scheduledAt: due });
  const pending = (await bob.next((frame) => frame.type === 'invite_updated' &&
    frame.invite.status === 'pending')).invite;
  bob.send({ type: 'respond_invite', commandId: 'accept-credit-schedule',
    inviteId: pending.inviteId, accept: true });
  await bob.next((frame) => frame.type === 'invite_updated' && frame.invite.status === 'accepted');
  // Existing invitations blocked by the previous credit policy also recover.
  app.invites.get(pending.inviteId).status = 'credit_required';
  await new Promise((resolve) => setTimeout(resolve, 320));
  app.tick();
  const activated = await alice.next(frame => frame.type === 'invite_updated' && frame.invite.game);
  assert.equal(activated.invite.status, 'accepted');
  assert.equal(app.games.size, 1);
  assert.equal(app.profiles.get('schedule alice').creditAccount.bonusBalance, 300);
  assert.equal(app.profiles.get('schedule bobby').creditAccount.bonusBalance, 1);
});

test('account activity reaches other-screen sessions without taking their seat or leaking to strangers', async (t) => {
  const app = createMatchServer({ port: 0, host: '127.0.0.1', tickMs: 60000 });
  t.after(() => app.close());
  await once(app.server, 'listening');
  const url = `ws://127.0.0.1:${app.server.address().port}`;
  const alice = await client(url);
  const bob = await client(url);
  const watcher = await client(url, alice.profile);
  const stranger = await client(url);
  const strayFrames = [];
  stranger.socket.on('message', raw => strayFrames.push(JSON.parse(raw)));
  alice.send({ type: 'send_invite', commandId: 'activity-invite', opponentName: bob.profile.name, timed: false });
  const pending = await bob.next(f => f.type === 'invite_updated');
  bob.send({ type: 'respond_invite', commandId: 'activity-accept', inviteId: pending.invite.inviteId, accept: true });
  const activity = await watcher.next(f => f.type === 'game_activity');
  assert.equal(activity.kind, 'opponent_joined');
  assert.equal(activity.game.seat, 'w');
  assert.equal(activity.game.state.status, 'active');
  alice.send({ type: 'resume_game', gameId: activity.game.gameId, seatToken: activity.game.seatToken });
  await alice.next(f => f.type === 'seat_resumed');
  alice.send({ type: 'move', commandId: 'activity-e4', gameId: activity.game.gameId, round: 1, ply: 0, move: { from: 'e2', to: 'e4' } });
  const move = await watcher.next(f => f.type === 'game_activity' && f.game.state.san.length === 1);
  assert.equal(move.kind, 'move');
  assert.deepEqual(move.game.state.san, ['e4']);
  assert.equal(strayFrames.some(f => f.type === 'game_activity'), false);
});

test('push targets inactive opted-in devices and opponent moves, with duplicate/foreground suppression', async (t) => {
  const notifications = [];
  const app = createMatchServer({ port: 0, host: '127.0.0.1', tickMs: 60000,
    pushSender: { send: async message => notifications.push(message) } });
  t.after(() => app.close());
  await once(app.server, 'listening');
  const url = `ws://127.0.0.1:${app.server.address().port}`;
  const alice = await client(url);
  const bob = await client(url);
  const device = { type: 'set_push_device', deviceId: 'alice-phone', token: 'alice_push_token_1234567890', enabled: true, active: false };
  alice.send(device);
  await alice.next(f => f.type === 'push_device_saved');
  alice.send({ type: 'send_invite', commandId: 'push-invite', opponentName: bob.profile.name, timed: false });
  const pending = await bob.next(f => f.type === 'invite_updated');
  bob.send({ type: 'respond_invite', commandId: 'push-accept', inviteId: pending.invite.inviteId, accept: true });
  const activity = await alice.next(f => f.type === 'game_activity');
  assert.equal(notifications.length, 1);
  assert.ok(notifications[0].body.includes('joined'));
  const gameId = activity.game.gameId;
  alice.send({ type: 'resume_game', gameId, seatToken: activity.game.seatToken });
  await alice.next(f => f.type === 'seat_resumed');
  const bobGame = await bob.next(f => f.type === 'game_activity');
  bob.send({ type: 'resume_game', gameId, seatToken: bobGame.game.seatToken });
  await bob.next(f => f.type === 'seat_resumed');
  alice.send({ type: 'move', commandId: 'push-e4', gameId, round: 1, ply: 0, move: { from: 'e2', to: 'e4' } });
  await bob.next(f => f.type === 'game_state' && f.state.san.length === 1);
  assert.equal(notifications.length, 1); // Never charge/notify the mover for their own move.
  const reply = { type: 'move', commandId: 'push-e5', gameId, round: 1, ply: 1, move: { from: 'e7', to: 'e5' } };
  bob.send(reply);
  await alice.next(f => f.type === 'game_activity' && f.game.state.san.length === 2);
  assert.equal(notifications.length, 2);
  assert.ok(notifications[1].body.includes('played e5'));
  bob.send(reply);
  await bob.next(f => f.type === 'command_result' && f.commandId === 'push-e5');
  assert.equal(notifications.length, 2);
  alice.send({ ...device, active: true });
  await alice.next(f => f.type === 'push_device_saved');
  alice.send({ type: 'move', commandId: 'push-nf3', gameId, round: 1, ply: 2, move: { from: 'g1', to: 'f3' } });
  await bob.next(f => f.type === 'game_state' && f.state.san.length === 3);
  bob.send({ type: 'move', commandId: 'push-nc6', gameId, round: 1, ply: 3, move: { from: 'b8', to: 'c6' } });
  await alice.next(f => f.type === 'game_activity' && f.game.state.san.length === 4);
  assert.equal(notifications.length, 2);
  alice.send({ ...device, enabled: false, active: false });
  await alice.next(f => f.type === 'push_device_saved');
  assert.equal(app.profiles.get(alice.profile.name.toLowerCase()).pushDevices['alice-phone'].enabled, false);
});

test('a game alert link resumes an owned active or completed seat through account authentication', async (t) => {
  const app = createMatchServer({ port: 0, host: '127.0.0.1', tickMs: 60000 });
  t.after(() => app.close());
  await once(app.server, 'listening');
  const url = `ws://127.0.0.1:${app.server.address().port}`;
  const owner = await client(url);
  const friend = await client(url);
  owner.send({ type: 'create_game', commandId: 'alert-room', baseMs: 600000 });
  const room = await owner.next(f => f.type === 'game_created');
  friend.send({ type: 'join_game', gameId: room.gameId, commandId: 'alert-friend' });
  await friend.next(f => f.type === 'seat_joined');
  const returning = await client(url, owner.profile);
  returning.send({ type: 'join_game', gameId: room.gameId, commandId: 'alert-open' });
  const resumed = await returning.next(f => f.type === 'seat_resumed');
  assert.equal(resumed.seat, 'w');
  assert.equal(resumed.seatToken, room.seatToken);
  assert.equal(resumed.state.status, 'active');
  friend.send({ type: 'resign', gameId: room.gameId, round: 1, commandId: 'alert-end' });
  await returning.next(f => f.type === 'game_state' && f.state.status === 'complete');
  const afterClose = await client(url, owner.profile);
  afterClose.send({ type: 'join_game', gameId: room.gameId, commandId: 'alert-open-complete' });
  assert.equal((await afterClose.next(f => f.type === 'seat_resumed')).state.status, 'complete');
});

test('a synchronous push failure cannot stop game acceptance or legal moves', async (t) => {
  const app = createMatchServer({ port: 0, host: '127.0.0.1', tickMs: 60000,
    pushSender: { send() { throw new Error('Notification service unavailable'); } } });
  t.after(() => app.close());
  await once(app.server, 'listening');
  const url = `ws://127.0.0.1:${app.server.address().port}`;
  const alice = await client(url);
  const bob = await client(url);
  alice.send({ type: 'set_push_device', deviceId: 'failed-push-phone', token: 'failed_push_token_1234567890', enabled: true, active: false });
  await alice.next(f => f.type === 'push_device_saved');
  alice.send({ type: 'send_invite', commandId: 'failed-push-invite', opponentName: bob.profile.name, timed: false });
  const invite = await bob.next(f => f.type === 'invite_updated');
  bob.send({ type: 'respond_invite', commandId: 'failed-push-accept', inviteId: invite.invite.inviteId, accept: true });
  const activity = await alice.next(f => f.type === 'game_activity');
  assert.equal(activity.game.state.status, 'active');
  alice.send({ type: 'join_game', gameId: activity.game.gameId, commandId: 'failed-push-open' });
  await alice.next(f => f.type === 'seat_resumed');
  alice.send({ type: 'move', gameId: activity.game.gameId, commandId: 'failed-push-move', round: 1, ply: 0, move: { from: 'e2', to: 'e4' } });
  assert.deepEqual((await alice.next(f => f.type === 'game_state' && f.state.san.length === 1)).state.san, ['e4']);
});
