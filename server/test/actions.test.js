// SPDX-License-Identifier: GPL-3.0-or-later
import test from "node:test";
import assert from "node:assert/strict";
import { Match } from "../src/match.js";
import { validateMessage } from "../src/protocol.js";

function setup() {
  const game = new Match({ baseMs: 10_000 });
  const black = game.joinBlack(1000);
  let id = 0;
  const act = (token, type, extra = {}, now = 1100) =>
    game.command(
      token,
      { type, commandId: `cmd${++id}`, round: game.round, ...extra },
      now,
    );
  return { game, black, white: game.whiteToken, act };
}

test("illegal and wrong-seat moves do not change position", () => {
  const { game, black, white, act } = setup();
  assert.equal(
    act(black, "move", { ply: 0, move: { from: "e7", to: "e5" } }).code,
    "NOT_YOUR_TURN",
  );
  assert.equal(
    act(white, "move", { ply: 0, move: { from: "e2", to: "e5" } }).code,
    "ILLEGAL_MOVE",
  );
  assert.equal(game.chess.history().length, 0);
  assert.throws(() => act(null, "resign"), { code: "UNAUTHORIZED_SEAT" });
});

test("duplicate successful and rejected commands are idempotent", () => {
  const { game, white } = setup();
  const cmd = {
    type: "move",
    commandId: "one",
    round: 1,
    ply: 0,
    move: { from: "e2", to: "e4" },
  };
  assert.equal(game.command(white, cmd, 1100).accepted, true);
  assert.equal(game.command(white, cmd, 1200).duplicate, true);
  assert.equal(game.chess.history().length, 1);
  assert.throws(() => game.command(white, { ...cmd, type: "resign" }, 1200), {
    code: "COMMAND_ID_REUSED",
  });
  const invalid = { ...cmd, commandId: "two", ply: 1 };
  assert.equal(game.command(white, invalid, 1200).accepted, false);
  assert.equal(game.command(white, invalid, 1300).duplicate, true);
});

test("clock settles before wrong turn, resign, draw and rematch requests", () => {
  for (const type of [
    "move",
    "resign",
    "offer_draw",
    "respond_draw",
    "rematch",
  ]) {
    const { game, black, act } = setup();
    act(black, type, { ply: 0, move: { from: "e7", to: "e5" } }, 11_001);
    assert.deepEqual(game.result, { reason: "timeout", winner: "b" });
    assert.equal(game.chess.history().length, 0);
  }
});

test("resign finishes once and disallows subsequent actions", () => {
  const { game, white, black, act } = setup();
  assert.equal(act(white, "resign").accepted, true);
  assert.deepEqual(game.result, { reason: "resignation", winner: "b" });
  assert.equal(act(black, "offer_draw").code, "GAME_NOT_ACTIVE");
});

test("lifelines are limited per round and repeated positions are free", () => {
  const { game, white, black, act } = setup();
  assert.equal(act(white, "use_lifeline").accepted, true);
  assert.deepEqual(game.lifelines, { w: 2, b: 3 });
  assert.equal(game.lifelineRequests.w, 1);
  assert.equal(act(white, "use_lifeline").accepted, true);
  assert.deepEqual(game.lifelines, { w: 2, b: 3 });
  assert.equal(game.lifelineRequests.w, 2);
  assert.equal(act(black, "use_lifeline").code, "NOT_YOUR_TURN");
  act(white, "move", { ply: 0, move: { from: "e2", to: "e4" } });
  assert.equal(act(black, "use_lifeline").accepted, true);
  assert.deepEqual(game.snapshot().lifelines, { w: 2, b: 2 });
});

test("draw offers require the opponent and the current offer ID", () => {
  const { game, white, black, act } = setup();
  const offer = act(white, "offer_draw");
  assert.equal(
    act(white, "respond_draw", { offerId: offer.commandId, accept: true })
      .accepted,
    false,
  );
  assert.equal(
    act(black, "respond_draw", { offerId: "wrong", accept: true }).accepted,
    false,
  );
  assert.equal(
    act(black, "respond_draw", { offerId: offer.commandId, accept: true })
      .accepted,
    true,
  );
  assert.deepEqual(game.result, { reason: "agreement", winner: null });
});

test("draw decline and an opponent move clear the offer", () => {
  const { game, white, black, act } = setup();
  const offer = act(black, "offer_draw");
  act(white, "respond_draw", { offerId: offer.commandId, accept: false });
  assert.equal(game.drawOffer, null);
  act(black, "offer_draw");
  act(white, "move", { ply: 0, move: { from: "e2", to: "e4" } });
  assert.equal(game.drawOffer, null);
});

test("mutual rematch keeps seats, resets clocks and rejects old-round commands", () => {
  const { game, white, black, act } = setup();
  act(white, "resign");
  const before = game.snapshot(1200);
  act(white, "rematch", {}, 1300);
  assert.equal(game.status, "complete");
  act(black, "rematch", {}, 1400);
  const after = game.snapshot(1400);
  assert.equal(after.round, 2);
  assert.equal(after.status, "active");
  assert.deepEqual(after.clocks, { w: 10_000, b: 10_000 });
  assert.deepEqual(after.lifelines, { w: 3, b: 3 });
  assert.ok(after.sequence > before.sequence);
  assert.equal(game.sideForToken(white), "w");
  assert.equal(act(white, "resign", { round: 1 }, 1400).code, "STALE_ROUND");
});

test("checkmate and repetition produce canonical terminal results", () => {
  const { game, white, black, act } = setup();
  for (const [ply, uci] of ["f2f3", "e7e5", "g2g4", "d8h4"].entries()) {
    assert.equal(
      act(ply % 2 ? black : white, "move", {
        ply,
        move: { from: uci.slice(0, 2), to: uci.slice(2) },
      }).accepted,
      true,
    );
  }
  assert.deepEqual(game.result, { reason: "checkmate", winner: "b" });
  const other = setup();
  for (const [ply, uci] of [
    "g1f3",
    "g8f6",
    "f3g1",
    "f6g8",
    "g1f3",
    "g8f6",
    "f3g1",
    "f6g8",
  ].entries()) {
    other.act(ply % 2 ? other.black : other.white, "move", {
      ply,
      move: { from: uci.slice(0, 2), to: uci.slice(2) },
    });
  }
  assert.equal(other.game.result.reason, "repetition");
});

test("promotion choice is committed and malformed protocol fields are rejected", () => {
  const { game, white, act } = setup();
  game.chess.load("7k/P7/8/8/8/8/8/7K w - - 0 1");
  assert.equal(
    act(white, "move", {
      ply: 0,
      move: { from: "a7", to: "a8", promotion: "n" },
    }).accepted,
    true,
  );
  assert.equal(game.chess.get("a8").type, "n");
  for (const message of [
    null,
    [],
    { type: "__proto__" },
    { type: "sync", gameId: 5 },
    {
      type: "register_player",
      commandId: "x",
      name: "Level Hero",
      avatarId: "crown",
      level: "expert",
    },
    {
      type: "move",
      commandId: "x",
      gameId: "y",
      round: 1,
      ply: 0,
      move: { from: "e2", to: "e9" },
    },
    { type: "resign", commandId: "x", gameId: "y", round: 1, result: "white" },
    {
      type: "respond_draw",
      commandId: "x",
      gameId: "y",
      round: 1,
      offerId: "x",
      accept: "true",
    },
  ]) {
    assert.throws(() => validateMessage(message), { code: "INVALID_MESSAGE" });
  }
});
