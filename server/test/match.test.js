// SPDX-License-Identifier: GPL-3.0-or-later
import test from "node:test";
import assert from "node:assert/strict";
import { Match, MatchError } from "../src/match.js";

test("unclaimed seats reject missing and invalid tokens", () => {
  const game = new Match();
  for (const token of [null, undefined, "", "unknown", 0, {}, []]) {
    assert.equal(game.sideForToken(token), null);
  }
  assert.equal(game.sideForToken(game.whiteToken), "w");
  const black = game.joinBlack(1_000);
  assert.equal(game.sideForToken(black), "b");
  assert.equal(game.sideForToken(null), null);
  assert.throws(
    () => game.play(null, { from: "e2", to: "e4" }, 1_100),
    (error) =>
      error instanceof MatchError && error.code === "UNAUTHORIZED_SEAT",
  );
});

test("requires the correct seat and validates moves", () => {
  const game = new Match({ id: "test", baseMs: 60_000 });
  const black = game.joinBlack(1_000);
  assert.throws(
    () => game.play(black, { from: "e7", to: "e5" }, 1_100),
    (error) => error instanceof MatchError && error.code === "NOT_YOUR_TURN",
  );
  const state = game.play(game.whiteToken, { from: "e2", to: "e4" }, 1_100);
  assert.equal(state.turn, "b");
  assert.equal(state.san[0], "e4");
});

test("server clock remains authoritative and applies increment", () => {
  const game = new Match({ id: "clock", baseMs: 60_000, incrementMs: 2_000 });
  game.joinBlack(10_000);
  const state = game.play(game.whiteToken, { from: "e2", to: "e4" }, 13_000);
  assert.equal(state.clocks.w, 59_000);
  assert.equal(state.clocks.b, 60_000);
});

test("detects timeout before accepting a move", () => {
  const game = new Match({ id: "flag", baseMs: 10_000 });
  game.joinBlack(5_000);
  const state = game.play(game.whiteToken, { from: "e2", to: "e4" }, 15_001);
  assert.equal(state.status, "complete");
  assert.deepEqual(state.result, { reason: "timeout", winner: "b" });
  assert.equal(state.san.length, 0);
});
