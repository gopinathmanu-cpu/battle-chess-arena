import 'package:battle_chess_arena/src/domain/online_credits.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only move suggestions have a nonzero credit cost', () {
    expect(defaultOnlineCreditPolicy.starterCredits, 300);
    expect(defaultOnlineCreditPolicy.dailyLoginCredits, 3);
    expect(defaultOnlineCreditPolicy.dailyAllowanceCap, 300);
    expect(defaultOnlineCreditPolicy.liveHumanRoundCost, 0);
    expect(defaultOnlineCreditPolicy.dailyHumanRoundCost, 0);
    expect(defaultOnlineCreditPolicy.computerRoundCost, 0);
    expect(defaultOnlineCreditPolicy.onlineMoveSuggestionCost, 1);
    expect(defaultOnlineCreditPolicy.completionRewardCredits, 1);
    expect(defaultOnlineCreditPolicy.dailyCompletionRewardCap, 5);
  });

  test('credit policy and authoritative account parse server payloads', () {
    final policy = OnlineCreditPolicy.fromJson({
      'version': 1,
      'starterCredits': 300,
      'dailyLoginCredits': 3,
      'dailyAllowanceCap': 300,
      'completionRewardCredits': 1,
      'dailyCompletionRewardCap': 5,
      'costs': {
        'liveHumanRound': 2,
        'dailyHumanRound': 3,
        'computerRound': 4,
        'onlineMoveSuggestion': 1,
      },
    });
    final account = OnlineCreditAccount.fromJson({
      'credits': 298,
      'bonusCredits': 198,
      'purchasedCredits': 100,
      'lifetimeEarned': 301,
      'lifetimeSpent': 3,
      'completionRewardsToday': 1,
      'nextDailyLoginAt': 86400000,
      'recentTransactions': [
        {
          'transactionId': 'credit-1',
          'delta': -2,
          'type': 'spend',
          'reason': 'live_human_round',
          'createdAt': 1000,
          'gameId': 'game-1',
          'round': 1,
        },
      ],
    });

    expect(policy.humanRoundCost(daily: false), 2);
    expect(policy.humanRoundCost(daily: true), 3);
    expect(policy.onlineMoveSuggestionCost, 1);
    expect(account.credits, 298);
    expect(account.bonusCredits, 198);
    expect(account.purchasedCredits, 100);
    expect(account.nextDailyLoginAt, DateTime.utc(1970, 1, 2));
    expect(account.recentTransactions.single.delta, -2);
    expect(account.recentTransactions.single.gameId, 'game-1');
  });

  test('older policy payload defaults the daily refill ceiling to starter', () {
    final policy = OnlineCreditPolicy.fromJson({
      'version': 1,
      'starterCredits': 300,
      'dailyLoginCredits': 3,
      'completionRewardCredits': 1,
      'dailyCompletionRewardCap': 5,
      'costs': {'liveHumanRound': 2, 'dailyHumanRound': 3, 'computerRound': 4},
    });

    expect(policy.dailyAllowanceCap, 300);
    expect(policy.onlineMoveSuggestionCost, 1);
  });

  test('negative balances and fractional prices are rejected', () {
    expect(() => OnlineCreditAccount.balanceOnly(-1), throwsFormatException);
    expect(
      () => OnlineCreditPolicy.fromJson({
        'version': 1,
        'starterCredits': 300,
        'dailyLoginCredits': 3,
        'completionRewardCredits': 1,
        'dailyCompletionRewardCap': 5,
        'costs': {
          'liveHumanRound': 2.5,
          'dailyHumanRound': 3,
          'computerRound': 4,
        },
      }),
      throwsFormatException,
    );
  });
}
