import 'package:battle_chess_arena/src/domain/online_credits.dart';
import 'package:battle_chess_arena/src/domain/online_player_profile.dart';
import 'package:battle_chess_arena/src/services/arena_credit_controller.dart';
import 'package:battle_chess_arena/src/domain/player_progress.dart';
import 'package:battle_chess_arena/src/services/online_game_history.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('restores only the matching profile last-known balance', () async {
    await OnlineGameHistory.saveProfile(
      const OnlinePlayerProfile(
        name: 'Credit Knight',
        avatarId: 'avatar-01',
        playerToken: 'player-token-a',
      ),
    );
    await OnlineGameHistory.saveCreditBalance(
      CachedArenaCreditBalance(
        playerToken: 'player-token-a',
        credits: 287,
        bonusCredits: 280,
        purchasedCredits: 7,
        syncedAt: DateTime.utc(2026, 9, 26, 10),
        seenTransactionIds: const ['transaction-a'],
      ),
    );

    final restored = ArenaCreditController();
    await restored.restore();

    expect(restored.credits, 287);
    expect(restored.account?.bonusCredits, 280);
    expect(restored.account?.purchasedCredits, 7);
    expect(restored.isLive, isFalse);
    expect(restored.hasCachedBalance, isTrue);
    expect(restored.lastChange, isNull);

    final mismatch = ArenaCreditController();
    await mismatch.restoreForToken('different-player-token');
    expect(mismatch.account, isNull);
    expect(mismatch.credits, defaultOnlineCreditPolicy.starterCredits);

    restored.dispose();
    mismatch.dispose();
  });

  test('authoritative transitions are idempotent and survive disconnect', () {
    final now = DateTime.utc(2026, 9, 26, 11);
    final controller = ArenaCreditController(now: () => now);
    final initial = _account(300, [
      OnlineCreditTransaction(
        transactionId: 'starter',
        delta: 300,
        type: 'grant',
        reason: 'starter_credits',
        createdAt: _transactionTime,
      ),
    ]);
    controller.acceptServerAccount(
      profileToken: 'player-token',
      account: initial,
      policy: defaultOnlineCreditPolicy,
    );
    expect(controller.lastChange, isNull);
    expect(controller.isLive, isTrue);

    final charged = _account(298, [
      OnlineCreditTransaction(
        transactionId: 'round-charge',
        delta: -2,
        type: 'round_fee',
        reason: 'live_human_round',
        createdAt: _transactionTime,
      ),
      ...initial.recentTransactions,
    ]);
    controller.acceptServerAccount(
      profileToken: 'player-token',
      account: charged,
      policy: defaultOnlineCreditPolicy,
    );
    final chargeEvent = controller.lastChange!;
    expect(chargeEvent.delta, -2);
    expect(chargeEvent.from, 300);
    expect(chargeEvent.to, 298);
    expect(chargeEvent.transactionId, 'round-charge');

    controller.acceptServerAccount(
      profileToken: 'player-token',
      account: charged,
      policy: defaultOnlineCreditPolicy,
    );
    expect(controller.lastChange?.sequence, chargeEvent.sequence);

    final rewarded = _account(299, [
      OnlineCreditTransaction(
        transactionId: 'completion-reward',
        delta: 1,
        type: 'reward',
        reason: 'meaningful_round_completed',
        createdAt: _transactionTime,
      ),
      ...charged.recentTransactions,
    ]);
    controller.acceptServerAccount(
      profileToken: 'player-token',
      account: rewarded,
      policy: defaultOnlineCreditPolicy,
    );
    expect(controller.lastChange?.delta, 1);
    expect(controller.lastChange?.isAddition, isTrue);

    controller.markDisconnected(profileToken: 'another-player');
    expect(controller.isLive, isTrue);
    controller.markDisconnected(profileToken: 'player-token');
    expect(controller.isLive, isFalse);
    expect(controller.credits, 299);
    expect(controller.lastSyncedAt, now);

    controller.dispose();
  });

  test(
    'authoritative balance is cached with transaction deduplication',
    () async {
      final controller = ArenaCreditController(
        now: () => DateTime.utc(2026, 9, 26, 12),
      );
      controller.acceptServerAccount(
        profileToken: 'persistent-player',
        account: _account(296, [
          OnlineCreditTransaction(
            transactionId: 'computer-round',
            delta: -4,
            type: 'round_fee',
            reason: 'server_computer_round',
            createdAt: _transactionTime,
          ),
        ]),
        policy: defaultOnlineCreditPolicy,
      );
      await controller.flushPendingSave();

      final cached = await OnlineGameHistory.loadCreditBalance(
        'persistent-player',
      );
      expect(cached?.credits, 296);
      expect(cached?.seenTransactionIds, contains('computer-round'));

      final restored = ArenaCreditController();
      await restored.restoreForToken('persistent-player');
      restored.acceptServerAccount(
        profileToken: 'persistent-player',
        account: _account(296, [
          OnlineCreditTransaction(
            transactionId: 'computer-round',
            delta: -4,
            type: 'round_fee',
            reason: 'server_computer_round',
            createdAt: _transactionTime,
          ),
        ]),
        policy: defaultOnlineCreditPolicy,
      );
      expect(restored.lastChange, isNull);

      controller.dispose();
      restored.dispose();
    },
  );

  test('successful local feature spend deducts once and persists', () async {
    final controller = ArenaCreditController(
      now: () => DateTime.utc(2026, 9, 26, 13),
    );

    expect(
      controller.trySpendLocal(cost: 1, reason: 'move_suggestion'),
      isTrue,
    );
    expect(controller.credits, 299);
    expect(controller.lastChange?.delta, -1);
    expect(controller.lastChange?.reason, 'move_suggestion');
    await controller.flushPendingSave();

    final restored = ArenaCreditController();
    await restored.restore();
    expect(restored.credits, 299);

    expect(
      restored.trySpendLocal(cost: 300, reason: 'move_suggestion'),
      isFalse,
    );
    expect(restored.credits, 299);
    controller.dispose();
    restored.dispose();
  });

  test('each badge reward is granted and persisted exactly once', () async {
    final bronze = arenaBadges[1];
    final controller = ArenaCreditController(
      now: () => DateTime.utc(2026, 9, 26, 14),
    );

    expect(await controller.grantBadgeUpgradeCredits(bronze), 25);
    expect(controller.credits, 325);
    expect(controller.lastChange?.delta, 25);
    expect(controller.lastChange?.transactionId, 'badge_upgrade:Bronze Knight');
    expect(await controller.grantBadgeUpgradeCredits(bronze), 0);
    expect(controller.credits, 325);
    await controller.flushPendingSave();

    final restored = ArenaCreditController();
    await restored.restore();
    expect(restored.credits, 325);
    expect(await restored.grantBadgeUpgradeCredits(bronze), 0);
    expect(restored.credits, 325);
    controller.dispose();
    restored.dispose();
  });

  test('monthly mobile-test Top-up codes work only in their month', () {
    final september = ArenaCreditController(
      now: () => DateTime(2026, 9, 30, 23, 59),
    );
    expect(september.redeemTestingTopUpCode('wrong-code'), isFalse);
    expect(
      september.redeemTestingTopUpCode(
        ArenaCreditController.october2026TopUpCode,
      ),
      isFalse,
    );
    expect(
      september.redeemTestingTopUpCode(
        ArenaCreditController.september2026TopUpCode,
      ),
      isTrue,
    );
    expect(september.credits, 400);

    final october = ArenaCreditController(now: () => DateTime(2026, 10, 1));
    expect(
      october.redeemTestingTopUpCode(
        ArenaCreditController.september2026TopUpCode,
      ),
      isFalse,
    );
    expect(
      october.redeemTestingTopUpCode(
        ArenaCreditController.october2026TopUpCode,
      ),
      isTrue,
    );

    final expired = ArenaCreditController(now: () => DateTime(2026, 11, 1));
    expect(
      expired.redeemTestingTopUpCode(
        ArenaCreditController.october2026TopUpCode,
      ),
      isFalse,
    );
    september.dispose();
    october.dispose();
    expired.dispose();
  }, skip: !ArenaCreditController.testingCreditsEnabled);

  test('Beta Top-ups cannot raise the wallet above 1000 credits', () {
    final controller = ArenaCreditController(now: () => DateTime(2026, 9, 15));
    expect(controller.grantTestingCredits(650), isTrue);
    expect(controller.credits, 950);
    expect(
      controller.redeemTestingTopUpCode(
        ArenaCreditController.september2026TopUpCode,
      ),
      isTrue,
    );
    expect(controller.credits, 1000);
    expect(controller.lastChange?.delta, 50);
    expect(
      controller.redeemTestingTopUpCode(
        ArenaCreditController.september2026TopUpCode,
      ),
      isFalse,
    );
    expect(controller.credits, 1000);
    controller.dispose();
  }, skip: !ArenaCreditController.testingCreditsEnabled);
}

final _transactionTime = DateTime.utc(2026, 9, 26, 9);

OnlineCreditAccount _account(
  int credits,
  List<OnlineCreditTransaction> transactions,
) => OnlineCreditAccount(
  credits: credits,
  bonusCredits: credits,
  purchasedCredits: 0,
  recentTransactions: transactions,
);
