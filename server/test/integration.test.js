// SPDX-License-Identifier: GPL-3.0-or-later
import test from "node:test";
import assert from "node:assert/strict";
import { once } from "node:events";
import WebSocket from "ws";
import { createMatchServer } from "../src/server.js";

let playerCounter = 0;

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
  return api;
}

test("health check and lobby heartbeat work without a game", async (t) => {
  const app = createMatchServer({ port: 0, host: "127.0.0.1", tickMs: 60_000 });
  t.after(() => app.close());
  await once(app.server, "listening");
  const address = `127.0.0.1:${app.server.address().port}`;

  const response = await fetch(`http://${address}/health`);
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { status: "ok", protocolVersion: 3 });

  const lobby = await client(`ws://${address}`);
  lobby.send({ type: "ping" });
  assert.equal(
    (await lobby.next((frame) => frame.type === "pong")).type,
    "pong",
  );
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
