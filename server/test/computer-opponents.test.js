import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import { Chess } from "chess.js";
import { computerOpponents, computerProfile, chooseComputerMove } from "../src/computer-opponents.js";

test("all twenty fixed levels match the app roster and proficiency", () => {
  const dart = readFileSync(new URL("../../lib/src/domain/online_player_profile.dart", import.meta.url), "utf8");
  assert.deepEqual(computerOpponents.map((bot) => bot.botLevel), Array.from({ length: 20 }, (_, i) => i + 1));
  for (const bot of computerOpponents) {
    assert.equal(bot.level, bot.botLevel <= 7 ? "beginner" : bot.botLevel <= 14 ? "intermediate" : "advanced");
    assert.ok(dart.includes(`id: '${bot.id}',\n    botLevel: ${bot.botLevel},`));
    assert.equal(computerProfile(bot).botLevel, bot.botLevel);
  }
});

test("server move strength comes from persona ID, independent of supplied tier", () => {
  const chess = new Chess("8/8/8/8/8/2k5/7p/K7 b - - 0 1");
  for (const bot of computerOpponents) {
    const before = chess.fen();
    const expected = chooseComputerMove(chess, computerProfile(bot), () => 0.9);
    assert.ok(chess.moves().includes(expected.san));
    for (const level of ["beginner", "intermediate", "advanced"]) {
      const actual = chooseComputerMove(chess, { ...computerProfile(bot), level, botLevel: 99 }, () => 0.9);
      assert.equal(actual.san, expected.san);
      assert.equal(chess.fen(), before);
    }
  }
});

test("higher fixed levels progressively reduce random mistakes", () => {
  const chess = new Chess("8/8/8/8/8/2k5/7p/K7 b - - 0 1");
  const randomBranches = [];
  for (const bot of computerOpponents) {
    let randomCount = 0;
    for (let sample = 0; sample < 24; sample++) {
      let calls = 0;
      chooseComputerMove(chess, bot, () => calls++ === 0 ? sample / 24 : 0);
      if (calls === 2) randomCount++;
    }
    randomBranches.push(randomCount);
  }
  for (let i = 1; i < randomBranches.length; i++) assert.ok(randomBranches[i] < randomBranches[i - 1]);
  assert.equal(randomBranches[19], 0);
});
