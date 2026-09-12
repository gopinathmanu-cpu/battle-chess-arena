// SPDX-License-Identifier: GPL-3.0-or-later
import test from "node:test";
import assert from "node:assert/strict";
import { once } from "node:events";
import WebSocket from "ws";
import { createMatchServer } from "../src/server.js";

async function client(url) {
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
  return {
    socket,
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
}

test("health check and lobby heartbeat work without a game", async (t) => {
  const app = createMatchServer({ port: 0, host: "127.0.0.1", tickMs: 60_000 });
  t.after(() => app.close());
  await once(app.server, "listening");
  const address = `127.0.0.1:${app.server.address().port}`;

  const response = await fetch(`http://${address}/health`);
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { status: "ok", protocolVersion: 2 });

  const lobby = await client(`ws://${address}`);
  lobby.send({ type: "ping" });
  assert.equal((await lobby.next((frame) => frame.type === "pong")).type, "pong");
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
  const resumed = await client(url);
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
  const cancelled = await third.next(
    (f) => f.type === "matchmaking_cancelled",
  );
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
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(app.games.has(reserved.gameId), false);
});
