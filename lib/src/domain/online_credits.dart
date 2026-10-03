// SPDX-License-Identifier: GPL-3.0-or-later

/// Server-owned prices and rewards for Arena Credits.
///
/// Offline chess never uses this policy. The server includes the policy with
/// the player's account so the client can explain a charge before asking the
/// server to create a match.
class OnlineCreditPolicy {
  const OnlineCreditPolicy({
    required this.version,
    required this.starterCredits,
    required this.dailyLoginCredits,
    required this.dailyAllowanceCap,
    required this.completionRewardCredits,
    required this.dailyCompletionRewardCap,
    required this.lowBalanceRecoveryThreshold,
    required this.lowBalanceRecoveryTarget,
    required this.lowBalanceRecoveryCooldownHours,
    required this.liveHumanRoundCost,
    required this.dailyHumanRoundCost,
    required this.computerRoundCost,
    required this.onlineMoveSuggestionCost,
  });

  factory OnlineCreditPolicy.fromJson(Map<String, dynamic> json) {
    final costs = (json['costs'] as Map).cast<String, dynamic>();
    final policy = OnlineCreditPolicy(
      version: _wholeNumber(json['version'], 'version'),
      starterCredits: _wholeNumber(json['starterCredits'], 'starterCredits'),
      dailyLoginCredits: _wholeNumber(
        json['dailyLoginCredits'],
        'dailyLoginCredits',
      ),
      dailyAllowanceCap: _wholeNumber(
        json['dailyAllowanceCap'] ?? json['starterCredits'],
        'dailyAllowanceCap',
      ),
      completionRewardCredits: _wholeNumber(
        json['completionRewardCredits'],
        'completionRewardCredits',
      ),
      dailyCompletionRewardCap: _wholeNumber(
        json['dailyCompletionRewardCap'],
        'dailyCompletionRewardCap',
      ),
      lowBalanceRecoveryThreshold: _wholeNumber(
        json['lowBalanceRecoveryThreshold'] ?? 2,
        'lowBalanceRecoveryThreshold',
      ),
      lowBalanceRecoveryTarget: _wholeNumber(
        json['lowBalanceRecoveryTarget'] ?? 5,
        'lowBalanceRecoveryTarget',
      ),
      lowBalanceRecoveryCooldownHours: _wholeNumber(
        json['lowBalanceRecoveryCooldownHours'] ?? 24,
        'lowBalanceRecoveryCooldownHours',
      ),
      liveHumanRoundCost: _wholeNumber(
        costs['liveHumanRound'],
        'costs.liveHumanRound',
      ),
      dailyHumanRoundCost: _wholeNumber(
        costs['dailyHumanRound'],
        'costs.dailyHumanRound',
      ),
      computerRoundCost: _wholeNumber(
        costs['computerRound'],
        'costs.computerRound',
      ),
      onlineMoveSuggestionCost: _wholeNumber(
        costs['onlineMoveSuggestion'] ?? 1,
        'costs.onlineMoveSuggestion',
      ),
    );
    if (policy.version < 1 ||
        policy.starterCredits < 0 ||
        policy.dailyLoginCredits < 0 ||
        policy.dailyAllowanceCap < 0 ||
        policy.completionRewardCredits < 0 ||
        policy.dailyCompletionRewardCap < 0 ||
        policy.lowBalanceRecoveryThreshold < 0 ||
        policy.lowBalanceRecoveryTarget < policy.lowBalanceRecoveryThreshold ||
        policy.lowBalanceRecoveryCooldownHours <= 0 ||
        policy.liveHumanRoundCost < 0 ||
        policy.dailyHumanRoundCost < 0 ||
        policy.computerRoundCost < 0 ||
        policy.onlineMoveSuggestionCost < 0) {
      throw const FormatException('Invalid credit policy');
    }
    return policy;
  }

  final int version;
  final int starterCredits;
  final int dailyLoginCredits;
  final int dailyAllowanceCap;
  final int completionRewardCredits;
  final int dailyCompletionRewardCap;
  final int lowBalanceRecoveryThreshold;
  final int lowBalanceRecoveryTarget;
  final int lowBalanceRecoveryCooldownHours;
  final int liveHumanRoundCost;
  final int dailyHumanRoundCost;
  final int computerRoundCost;
  final int onlineMoveSuggestionCost;

  int humanRoundCost({required bool daily}) =>
      daily ? dailyHumanRoundCost : liveHumanRoundCost;
}

/// The launch economy, used for explanatory UI until the server account is
/// received. The server remains authoritative for every balance mutation.
const defaultOnlineCreditPolicy = OnlineCreditPolicy(
  version: 1,
  starterCredits: 300,
  dailyLoginCredits: 3,
  dailyAllowanceCap: 300,
  completionRewardCredits: 1,
  dailyCompletionRewardCap: 5,
  lowBalanceRecoveryThreshold: 2,
  lowBalanceRecoveryTarget: 5,
  lowBalanceRecoveryCooldownHours: 24,
  liveHumanRoundCost: 2,
  dailyHumanRoundCost: 3,
  computerRoundCost: 4,
  onlineMoveSuggestionCost: 1,
);

class OnlineCreditTransaction {
  const OnlineCreditTransaction({
    required this.transactionId,
    required this.delta,
    required this.type,
    required this.reason,
    required this.createdAt,
    this.gameId,
    this.round,
  });

  factory OnlineCreditTransaction.fromJson(Map<String, dynamic> json) {
    final transaction = OnlineCreditTransaction(
      transactionId: json['transactionId'] as String,
      delta: _wholeNumber(json['delta'], 'delta'),
      type: json['type'] as String,
      reason: json['reason'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        _wholeNumber(json['createdAt'], 'createdAt'),
        isUtc: true,
      ),
      gameId: json['gameId'] as String?,
      round: json['round'] == null
          ? null
          : _wholeNumber(json['round'], 'round'),
    );
    if (transaction.transactionId.isEmpty ||
        transaction.type.isEmpty ||
        transaction.reason.isEmpty ||
        transaction.createdAt.millisecondsSinceEpoch < 0 ||
        (transaction.round != null && transaction.round! < 1)) {
      throw const FormatException('Invalid credit transaction');
    }
    return transaction;
  }

  final String transactionId;
  final int delta;
  final String type;
  final String reason;
  final DateTime createdAt;
  final String? gameId;
  final int? round;
}

class OnlineCreditAccount {
  const OnlineCreditAccount({
    required this.credits,
    required this.bonusCredits,
    required this.purchasedCredits,
    this.lifetimeEarned = 0,
    this.lifetimeSpent = 0,
    this.completionRewardsToday = 0,
    this.nextDailyLoginAt,
    this.recentTransactions = const [],
  });

  factory OnlineCreditAccount.balanceOnly(
    int credits, {
    int? bonusCredits,
    int? purchasedCredits,
  }) => OnlineCreditAccount.fromJson({
    'credits': credits,
    if (bonusCredits != null) 'bonusCredits': bonusCredits,
    if (purchasedCredits != null) 'purchasedCredits': purchasedCredits,
  });

  factory OnlineCreditAccount.fromJson(Map<String, dynamic> json) {
    final nextDailyLogin = json['nextDailyLoginAt'];
    final credits = _wholeNumber(json['credits'], 'credits');
    final purchasedCredits = _wholeNumber(
      json['purchasedCredits'] ?? 0,
      'purchasedCredits',
    );
    final bonusCredits = _wholeNumber(
      json['bonusCredits'] ?? credits - purchasedCredits,
      'bonusCredits',
    );
    final account = OnlineCreditAccount(
      credits: credits,
      bonusCredits: bonusCredits,
      purchasedCredits: purchasedCredits,
      lifetimeEarned: _wholeNumber(
        json['lifetimeEarned'] ?? 0,
        'lifetimeEarned',
      ),
      lifetimeSpent: _wholeNumber(json['lifetimeSpent'] ?? 0, 'lifetimeSpent'),
      completionRewardsToday: _wholeNumber(
        json['completionRewardsToday'] ?? 0,
        'completionRewardsToday',
      ),
      nextDailyLoginAt: nextDailyLogin == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              _wholeNumber(nextDailyLogin, 'nextDailyLoginAt'),
              isUtc: true,
            ),
      recentTransactions: List<OnlineCreditTransaction>.unmodifiable(
        (json['recentTransactions'] as List? ?? const []).map(
          (item) => OnlineCreditTransaction.fromJson(
            (item as Map).cast<String, dynamic>(),
          ),
        ),
      ),
    );
    if (account.credits < 0 ||
        account.bonusCredits < 0 ||
        account.purchasedCredits < 0 ||
        account.bonusCredits + account.purchasedCredits != account.credits ||
        account.lifetimeEarned < 0 ||
        account.lifetimeSpent < 0 ||
        account.completionRewardsToday < 0) {
      throw const FormatException('Invalid credit account');
    }
    return account;
  }

  final int credits;
  final int bonusCredits;
  final int purchasedCredits;
  final int lifetimeEarned;
  final int lifetimeSpent;
  final int completionRewardsToday;
  final DateTime? nextDailyLoginAt;
  final List<OnlineCreditTransaction> recentTransactions;

  OnlineCreditAccount withBalance(
    int value, {
    int? bonusCredits,
    int? purchasedCredits,
  }) {
    if (value < 0) throw const FormatException('Invalid credit balance');
    final nextPurchased =
        purchasedCredits ??
        (this.purchasedCredits > value ? value : this.purchasedCredits);
    final nextBonus = bonusCredits ?? value - nextPurchased;
    if (nextBonus < 0 ||
        nextPurchased < 0 ||
        nextBonus + nextPurchased != value) {
      throw const FormatException('Invalid credit balance breakdown');
    }
    return OnlineCreditAccount(
      credits: value,
      bonusCredits: nextBonus,
      purchasedCredits: nextPurchased,
      lifetimeEarned: lifetimeEarned,
      lifetimeSpent: lifetimeSpent,
      completionRewardsToday: completionRewardsToday,
      nextDailyLoginAt: nextDailyLoginAt,
      recentTransactions: recentTransactions,
    );
  }
}

int _wholeNumber(Object? value, String field) {
  if (value is! num || !value.isFinite || value != value.roundToDouble()) {
    throw FormatException('Invalid $field');
  }
  return value.toInt();
}
