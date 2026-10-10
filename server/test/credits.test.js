// SPDX-License-Identifier: GPL-3.0-or-later
import test from 'node:test';
import assert from 'node:assert/strict';
import {
  chargeOnlineMoveSuggestion,
  chargeRound,
  creditPolicy,
  ensureCreditAccount,
  grantCompletionReward,
  grantDailyLogin,
  grantLowBalanceRecovery,
  grantPurchasedCredits,
  publicCreditAccount,
} from '../src/credits.js';

const day = 24 * 60 * 60 * 1000;
const epoch = Date.UTC(2026, 8, 26, 12);
const player = (id) => ({ id, name: `Player ${id}` });

test('legacy and new profiles start at exactly 300 with no first-day login grant', () => {
  const profile = player('starter');
  const login = grantDailyLogin(profile, epoch);
  assert.equal(login.changed, false);
  assert.deepEqual(publicCreditAccount(profile, epoch), {
    credits: 300,
    bonusCredits: 300,
    purchasedCredits: 0,
    lifetimeEarned: 300,
    lifetimePurchased: 0,
    lifetimeSpent: 0,
    completionRewardsToday: 0,
    completionRewardCreditsRemaining: 5,
    nextDailyLoginAt: Date.UTC(2026, 8, 27),
    recentTransactions: [profile.creditAccount.ledger[0]],
  });
  assert.equal(grantDailyLogin(profile, epoch + 1000).changed, false);
});

test('daily allowance refills at most three bonus credits to 300 and never stacks', () => {
  const partial = player('partial');
  ensureCreditAccount(partial, epoch);
  for (let i = 0; i < 5; i++) chargeOnlineMoveSuggestion(partial, {gameId: 'g1', round: 1, commandId: `hint-${i}`, now: epoch});
  const refill = grantDailyLogin(partial, epoch + day);
  assert.equal(refill.transaction.delta, 3);
  assert.equal(publicCreditAccount(partial, epoch + day).bonusCredits, 298);
  assert.equal(grantDailyLogin(partial, epoch + day + 1000).changed, false);
  assert.equal(publicCreditAccount(partial, epoch + day).bonusCredits, 298);

  const nearlyFull = player('nearly-full');
  ensureCreditAccount(nearlyFull, epoch);
  for (let i = 0; i < 2; i++) chargeOnlineMoveSuggestion(nearlyFull, {gameId: 'g2', round: 1, commandId: `hint-${i}`, now: epoch});
  grantPurchasedCredits(nearlyFull, { transactionId: 'store:one', amount: 100, now: epoch });
  assert.equal(grantDailyLogin(nearlyFull, epoch + day).transaction.delta, 2);
  assert.equal(publicCreditAccount(nearlyFull, epoch + day).credits, 400);
  assert.equal(publicCreditAccount(nearlyFull, epoch + day).bonusCredits, 300);

  const full = player('full');
  ensureCreditAccount(full, epoch);
  const ledgerLength = full.creditAccount.ledger.length;
  assert.equal(grantDailyLogin(full, epoch + day).changed, false);
  assert.equal(full.creditAccount.ledger.length, ledgerLength);
  assert.equal(full.creditAccount.lastDailyLoginDay, '2026-09-27');
  assert.equal(grantDailyLogin(full, epoch + 2 * day).changed, false);
});

test('low-balance recovery restores play access once per rolling day', () => {
  const profile = player('recovery');
  const account = ensureCreditAccount(profile, epoch).account;
  account.bonusBalance = 1;

  const recovery = grantLowBalanceRecovery(profile, epoch);
  assert.equal(recovery.changed, true);
  assert.equal(recovery.transaction.delta, 4);
  assert.equal(recovery.transaction.reason, 'low_balance_recovery');
  assert.equal(publicCreditAccount(profile, epoch).credits, 5);

  account.bonusBalance = 0;
  assert.equal(grantLowBalanceRecovery(profile, epoch + day - 1).changed, false);
  assert.equal(publicCreditAccount(profile, epoch).credits, 0);
  assert.equal(grantLowBalanceRecovery(profile, epoch + day).changed, true);
  assert.equal(publicCreditAccount(profile, epoch + day).credits, 5);
});

test('all rounds are free and append no spending transactions even at zero balance', () => {
  const profile = player('free-player');
  ensureCreditAccount(profile, epoch).account.bonusBalance = 0;
  const before = publicCreditAccount(profile, epoch);
  for (const cost of [0, 2, 3, 4]) {
    assert.deepEqual(chargeRound([profile], {gameId: 'free', round: cost + 1, cost, now: epoch}), []);
    assert.deepEqual(publicCreditAccount(profile, epoch), before);
  }
  assert.equal(creditPolicy.costs.liveHumanRound, 0);
  assert.equal(creditPolicy.costs.dailyHumanRound, 0);
  assert.equal(creditPolicy.costs.computerRound, 0);
  assert.equal(creditPolicy.costs.onlineMoveSuggestion, 1);
});

test('meaningful completion grants are idempotent and capped at five per UTC day', () => {
  const profile = player('finisher');
  ensureCreditAccount(profile, epoch);
  for (let index = 0; index < 8; index++) {
    grantCompletionReward(profile, { gameId: `game-${index}`, round: 1, now: epoch });
  }
  assert.equal(publicCreditAccount(profile, epoch).credits, 305);
  assert.equal(publicCreditAccount(profile, epoch).completionRewardsToday, 5);
  assert.equal(
    grantCompletionReward(profile, { gameId: 'game-0', round: 1, now: epoch }).changed,
    false,
  );
  grantCompletionReward(profile, { gameId: 'tomorrow', round: 1, now: epoch + day });
  assert.equal(publicCreditAccount(profile, epoch + day).credits, 306);
  assert.equal(publicCreditAccount(profile, epoch + day).completionRewardsToday, 1);
});

test('online move suggestion charge is exact-once and uses the one-credit policy', () => {
  const profile = player('hint');
  ensureCreditAccount(profile, epoch);
  const charged = chargeOnlineMoveSuggestion(profile, {
    gameId: 'hint-game', round: 1, commandId: 'hint-command', now: epoch,
  });
  assert.equal(charged.transaction.delta, -1);
  assert.equal(charged.transaction.type, 'feature_fee');
  assert.equal(publicCreditAccount(profile, epoch).credits, 299);
  const replay = chargeOnlineMoveSuggestion(profile, {
    gameId: 'hint-game', round: 1, commandId: 'hint-command', now: epoch,
  });
  assert.equal(replay.duplicate, true);
  assert.equal(publicCreditAccount(profile, epoch).credits, 299);
  assert.equal(creditPolicy.costs.onlineMoveSuggestion, 1);
});

test('beta ledger keeps the newest 100 entries while preserving lifetime counters', () => {
  const profile = player('ledger');
  ensureCreditAccount(profile, epoch);
  for (let index = 0; index < 105; index++) {
    grantPurchasedCredits(profile, {
      transactionId: `store:${index}`,
      amount: 1,
      now: epoch + index,
    });
  }
  assert.equal(profile.creditAccount.ledger.length, 100);
  assert.equal(publicCreditAccount(profile, epoch).lifetimePurchased, 105);
  assert.equal(publicCreditAccount(profile, epoch).purchasedCredits, 105);
  assert.equal(publicCreditAccount(profile, epoch).recentTransactions.length, 20);
  assert.equal(creditPolicy.dailyAllowanceCap, 300);
});
