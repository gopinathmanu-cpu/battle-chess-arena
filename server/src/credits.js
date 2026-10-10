// SPDX-License-Identifier: GPL-3.0-or-later
import { MatchError } from './match.js';

export const creditPolicy = Object.freeze({
  version: 1,
  starterCredits: 300,
  dailyLoginCredits: 3,
  dailyAllowanceCap: 300,
  completionRewardCredits: 1,
  dailyCompletionRewardCap: 5,
  lowBalanceRecoveryThreshold: 2,
  lowBalanceRecoveryTarget: 5,
  lowBalanceRecoveryCooldownHours: 24,
  costs: Object.freeze({
    liveHumanRound: 0,
    dailyHumanRound: 0,
    computerRound: 0,
    onlineMoveSuggestion: 1,
  }),
});

const utcDay = (now) => new Date(now).toISOString().slice(0, 10);

const nextUtcDay = (now) => {
  const date = new Date(now);
  return Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate() + 1);
};

const safeCreditInteger = (value) => Number.isSafeInteger(value) && value >= 0;
const betaLedgerLimit = 100;

const totalCredits = (account) => account.bonusBalance + account.purchasedBalance;

function validateAccount(account) {
  if (
    account?.version !== 1 ||
    !safeCreditInteger(account.bonusBalance) ||
    !safeCreditInteger(account.purchasedBalance) ||
    !safeCreditInteger(account.lifetimeEarned) ||
    !safeCreditInteger(account.lifetimePurchased) ||
    !safeCreditInteger(account.lifetimeSpent) ||
    !safeCreditInteger(account.completionRewardsToday) ||
    !(account.lastRecoveryAt === null ||
      account.lastRecoveryAt === undefined ||
      safeCreditInteger(account.lastRecoveryAt)) ||
    typeof account.lastDailyLoginDay !== 'string' ||
    typeof account.completionRewardDay !== 'string' ||
    !Array.isArray(account.ledger)
  ) throw new Error('Invalid durable credit account');
  const ids = new Set();
  for (const transaction of account.ledger) {
    if (
      !transaction ||
      typeof transaction.transactionId !== 'string' ||
      transaction.transactionId.length === 0 ||
      ids.has(transaction.transactionId) ||
      !Number.isSafeInteger(transaction.delta) ||
      !Number.isSafeInteger(transaction.bonusDelta) ||
      !Number.isSafeInteger(transaction.purchasedDelta) ||
      transaction.delta !== transaction.bonusDelta + transaction.purchasedDelta ||
      typeof transaction.type !== 'string' ||
      typeof transaction.reason !== 'string' ||
      !Number.isSafeInteger(transaction.createdAt)
    ) throw new Error('Invalid durable credit ledger');
    ids.add(transaction.transactionId);
  }
}

/**
 * Lazily migrates a v1 profile. Missing data is legacy, while malformed data
 * fails closed so a corrupt balance can never silently mint replacement funds.
 */
export function ensureCreditAccount(profile, now = Date.now()) {
  if (!profile.creditAccount) {
    const day = utcDay(now);
    profile.creditAccount = {
      version: 1,
      bonusBalance: creditPolicy.starterCredits,
      purchasedBalance: 0,
      lifetimeEarned: creditPolicy.starterCredits,
      lifetimePurchased: 0,
      lifetimeSpent: 0,
      lastDailyLoginDay: day,
      completionRewardDay: day,
      completionRewardsToday: 0,
      lastRecoveryAt: null,
      ledger: [{
        transactionId: 'starter:v1',
        delta: creditPolicy.starterCredits,
        bonusDelta: creditPolicy.starterCredits,
        purchasedDelta: 0,
        type: 'starter',
        reason: 'starter_credits',
        createdAt: now,
      }],
    };
    return { account: profile.creditAccount, created: true };
  }
  validateAccount(profile.creditAccount);
  if (profile.creditAccount.ledger.length > betaLedgerLimit)
    profile.creditAccount.ledger.splice(0, profile.creditAccount.ledger.length - betaLedgerLimit);
  return { account: profile.creditAccount, created: false };
}

function existingTransaction(account, transactionId) {
  return account.ledger.find((item) => item.transactionId === transactionId);
}

function appendTransaction(account, transaction) {
  const previous = existingTransaction(account, transaction.transactionId);
  if (previous) {
    const same = ['delta', 'bonusDelta', 'purchasedDelta', 'type', 'reason', 'gameId', 'round']
      .every((key) => previous[key] === transaction[key]);
    if (!same) throw new Error('Credit transaction ID was reused');
    return { transaction: previous, duplicate: true };
  }
  account.ledger.push(transaction);
  if (account.ledger.length > betaLedgerLimit)
    account.ledger.splice(0, account.ledger.length - betaLedgerLimit);
  return { transaction, duplicate: false };
}

function grantBonus(profile, { transactionId, amount, type, reason, now, gameId, round }) {
  const { account } = ensureCreditAccount(profile, now);
  const previous = existingTransaction(account, transactionId);
  if (previous) return appendTransaction(account, {
    transactionId, delta: amount, bonusDelta: amount, purchasedDelta: 0,
    type, reason, createdAt: previous.createdAt, ...(gameId ? { gameId } : {}),
    ...(round === undefined ? {} : { round }),
  });
  account.bonusBalance += amount;
  account.lifetimeEarned += amount;
  return appendTransaction(account, {
    transactionId, delta: amount, bonusDelta: amount, purchasedDelta: 0,
    type, reason, createdAt: now, ...(gameId ? { gameId } : {}),
    ...(round === undefined ? {} : { round }),
  });
}

/** Trusted-server hook for a future verified store-receipt adapter. */
export function grantPurchasedCredits(profile, { transactionId, amount, now = Date.now() }) {
  if (!Number.isSafeInteger(amount) || amount <= 0)
    throw new TypeError('Purchased credit amount must be a positive integer');
  const { account } = ensureCreditAccount(profile, now);
  const previous = existingTransaction(account, transactionId);
  if (previous) return appendTransaction(account, {
    transactionId, delta: amount, bonusDelta: 0, purchasedDelta: amount,
    type: 'purchase', reason: 'verified_purchase', createdAt: previous.createdAt,
  });
  account.purchasedBalance += amount;
  account.lifetimePurchased += amount;
  return appendTransaction(account, {
    transactionId, delta: amount, bonusDelta: 0, purchasedDelta: amount,
    type: 'purchase', reason: 'verified_purchase', createdAt: now,
  });
}

export function grantDailyLogin(profile, now = Date.now()) {
  const ensured = ensureCreditAccount(profile, now);
  const { account } = ensured;
  const day = utcDay(now);
  // A newly migrated/new profile receives exactly the advertised 300 credits.
  // Missed days never stack; only the first registration on a later UTC day pays.
  if (ensured.created || account.lastDailyLoginDay === day)
    return { changed: false, transaction: null };
  account.lastDailyLoginDay = day;
  const amount = Math.min(
    creditPolicy.dailyLoginCredits,
    Math.max(0, creditPolicy.dailyAllowanceCap - account.bonusBalance),
  );
  if (amount === 0) return { changed: false, transaction: null };
  const result = grantBonus(profile, {
    transactionId: `daily-login:${day}`,
    amount,
    type: 'daily_login',
    reason: 'daily_login',
    now,
  });
  return { changed: !result.duplicate, transaction: result.transaction };
}

export function grantLowBalanceRecovery(profile, now = Date.now()) {
  const { account } = ensureCreditAccount(profile, now);
  if (totalCredits(account) >= creditPolicy.lowBalanceRecoveryThreshold)
    return { changed: false, transaction: null };
  const cooldownMs = creditPolicy.lowBalanceRecoveryCooldownHours * 60 * 60 * 1000;
  if (Number.isSafeInteger(account.lastRecoveryAt) && now - account.lastRecoveryAt < cooldownMs)
    return { changed: false, transaction: null };
  const amount = creditPolicy.lowBalanceRecoveryTarget - totalCredits(account);
  if (amount <= 0) return { changed: false, transaction: null };
  account.lastRecoveryAt = now;
  const result = grantBonus(profile, {
    transactionId: `low-balance-recovery:${profile.id}:${now}`,
    amount,
    type: 'recovery_grant',
    reason: 'low_balance_recovery',
    now,
  });
  return { changed: !result.duplicate, transaction: result.transaction };
}

export function grantCompletionReward(profile, { gameId, round, now = Date.now() }) {
  const { account } = ensureCreditAccount(profile, now);
  const day = utcDay(now);
  if (account.completionRewardDay !== day) {
    account.completionRewardDay = day;
    account.completionRewardsToday = 0;
  }
  const transactionId = `completion:${gameId}:${round}:${profile.id}`;
  const previous = existingTransaction(account, transactionId);
  if (previous) return { changed: false, transaction: previous };
  if (account.completionRewardsToday >= creditPolicy.dailyCompletionRewardCap)
    return { changed: false, transaction: null };
  const amount = Math.min(
    creditPolicy.completionRewardCredits,
    creditPolicy.dailyCompletionRewardCap - account.completionRewardsToday,
  );
  const result = grantBonus(profile, {
    transactionId,
    amount,
    type: 'completion_reward',
    reason: 'meaningful_round_completed',
    now,
    gameId,
    round,
  });
  if (!result.duplicate) account.completionRewardsToday += amount;
  return { changed: !result.duplicate, transaction: result.transaction };
}

export function roundCost(game) {
  const hasComputer = Object.values(game.players).some((player) => player?.computer === true);
  if (hasComputer) return creditPolicy.costs.computerRound;
  return game.clockMode === 'daily'
    ? creditPolicy.costs.dailyHumanRound
    : creditPolicy.costs.liveHumanRound;
}

export function humanPlayers(players) {
  return [...new Map(players
    .filter((player) => player && player.computer !== true)
    .map((player) => [player.id, player])).values()];
}

// Games are free, including for accounts with no suggestion credits.
export function requireRoundCredits(players, cost, now = Date.now()) {
  return humanPlayers(players);
}

export function canAffordRound(profile, cost, now = Date.now()) {
  return true;
}

export function requireOnlineMoveSuggestionCredit(profile, now = Date.now()) {
  const { account } = ensureCreditAccount(profile, now);
  if (totalCredits(account) < creditPolicy.costs.onlineMoveSuggestion) {
    throw new MatchError(
      'INSUFFICIENT_CREDITS',
      'You need 1 credit for an online move suggestion.',
    );
  }
}

// Kept as a compatibility hook for existing match-creation call sites.
// Never append a round fee, including when replaying an older command.
export function chargeRound(players, options) {
  return [];
}

export function chargeOnlineMoveSuggestion(
  profile,
  { gameId, round, commandId, now = Date.now() },
) {
  const cost = creditPolicy.costs.onlineMoveSuggestion;
  const { account } = ensureCreditAccount(profile, now);
  const transactionId = `suggestion:${gameId}:${round}:${profile.id}:${commandId}`;
  const previous = existingTransaction(account, transactionId);
  if (previous) {
    if (
      previous.delta !== -cost ||
      previous.type !== 'feature_fee' ||
      previous.reason !== 'online_move_suggestion' ||
      previous.gameId !== gameId ||
      previous.round !== round
    ) throw new Error('Credit transaction ID was reused');
    return { profile, transaction: previous, duplicate: true };
  }
  requireOnlineMoveSuggestionCredit(profile, now);
  const bonusSpent = Math.min(account.bonusBalance, cost);
  const purchasedSpent = cost - bonusSpent;
  account.bonusBalance -= bonusSpent;
  account.purchasedBalance -= purchasedSpent;
  account.lifetimeSpent += cost;
  const result = appendTransaction(account, {
    transactionId,
    delta: -cost,
    bonusDelta: -bonusSpent,
    purchasedDelta: -purchasedSpent,
    type: 'feature_fee',
    reason: 'online_move_suggestion',
    createdAt: now,
    gameId,
    round,
    commandId,
  });
  return { profile, transaction: result.transaction, duplicate: false };
}

export function publicCreditAccount(profile, now = Date.now()) {
  const { account } = ensureCreditAccount(profile, now);
  const day = utcDay(now);
  const completionRewardsToday = account.completionRewardDay === day
    ? account.completionRewardsToday
    : 0;
  return {
    credits: totalCredits(account),
    bonusCredits: account.bonusBalance,
    purchasedCredits: account.purchasedBalance,
    lifetimeEarned: account.lifetimeEarned,
    lifetimePurchased: account.lifetimePurchased,
    lifetimeSpent: account.lifetimeSpent,
    completionRewardsToday,
    completionRewardCreditsRemaining: Math.max(
      0,
      creditPolicy.dailyCompletionRewardCap - completionRewardsToday,
    ),
    nextDailyLoginAt: nextUtcDay(now),
    recentTransactions: account.ledger.slice(-20).reverse().map((item) => ({ ...item })),
  };
}
