// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/online_credits.dart';
import '../domain/player_progress.dart';
import 'online_game_history.dart';

/// One authoritative balance transition for presentation in the app header.
class ArenaCreditChange {
  const ArenaCreditChange({
    required this.sequence,
    required this.from,
    required this.to,
    required this.delta,
    this.reason,
    this.transactionId,
  });

  final int sequence;
  final int from;
  final int to;
  final int delta;
  final String? reason;
  final String? transactionId;

  bool get isAddition => delta > 0;
}

/// App-lifetime wallet presentation and local-feature settlement controller.
///
/// Online suggestion charges are accepted only from the server. Successful
/// on-device paid features are settled locally and persisted immediately.
class ArenaCreditController extends ChangeNotifier {
  ArenaCreditController({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static const _localBalanceKey = 'arena_credit_local_balance_v1';
  static const badgeRewardClaimsKey = 'arena_credit_badge_rewards_v1';
  static const testingCreditsEnabled = bool.fromEnvironment('BCA_TEST_CREDITS');
  static const september2026TopUpCode = 'BETATESTSEP26';
  static const october2026TopUpCode = 'BETATESTOCT26';
  static const testingTopUpBalanceLimit = 1000;
  final DateTime Function() _now;
  OnlineCreditAccount? _account;
  OnlineCreditPolicy _policy = defaultOnlineCreditPolicy;
  String? _playerToken;
  DateTime? _lastSyncedAt;
  bool _live = false;
  bool _disposed = false;
  bool _notificationScheduled = false;
  int _mutationRevision = 0;
  int _changeSequence = 0;
  ArenaCreditChange? _lastChange;
  Set<String> _seenTransactionIds = <String>{};
  List<String> _orderedSeenTransactionIds = <String>[];
  Future<void> _saveQueue = Future<void>.value();
  Future<void> _badgeRewardQueue = Future<void>.value();

  OnlineCreditAccount? get account => _account;
  OnlineCreditPolicy get policy => _policy;

  /// The balance shown before an online profile is created is the guaranteed
  /// welcome grant. Once a profile exists, only server-authoritative or cached
  /// values replace it.
  int get credits => _account?.credits ?? _policy.starterCredits;
  bool get isLive => _live;
  bool get hasCachedBalance => _account != null && !_live;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  ArenaCreditChange? get lastChange => _lastChange;

  /// Charges an on-device feature after it has completed successfully.
  ///
  /// Online suggestion charges remain server-authoritative. This path is reserved
  /// for local features, such as a successfully generated computer-game hint,
  /// where there is no match server command to settle the charge.
  bool trySpendLocal({required int cost, required String reason}) {
    if (_disposed || cost <= 0 || reason.isEmpty || credits < cost) {
      return cost == 0;
    }
    final previous = _account ?? OnlineCreditAccount.balanceOnly(credits);
    final bonusSpent = previous.bonusCredits < cost
        ? previous.bonusCredits
        : cost;
    final purchasedSpent = cost - bonusSpent;
    if (previous.purchasedCredits < purchasedSpent) return false;
    final transactionId =
        'local:$reason:${_now().toUtc().microsecondsSinceEpoch}:${_changeSequence + 1}';
    final transaction = OnlineCreditTransaction(
      transactionId: transactionId,
      delta: -cost,
      type: 'feature_fee',
      reason: reason,
      createdAt: _now().toUtc(),
    );
    _account = OnlineCreditAccount(
      credits: previous.credits - cost,
      bonusCredits: previous.bonusCredits - bonusSpent,
      purchasedCredits: previous.purchasedCredits - purchasedSpent,
      lifetimeEarned: previous.lifetimeEarned,
      lifetimeSpent: previous.lifetimeSpent + cost,
      completionRewardsToday: previous.completionRewardsToday,
      nextDailyLoginAt: previous.nextDailyLoginAt,
      recentTransactions: [transaction, ...previous.recentTransactions],
    );
    _lastChange = ArenaCreditChange(
      sequence: ++_changeSequence,
      from: previous.credits,
      to: previous.credits - cost,
      delta: -cost,
      reason: reason,
      transactionId: transactionId,
    );
    _rememberTransactions(_account!);
    _queueSave();
    _notifySafely();
    return true;
  }

  /// Adds a disposable balance only in explicitly flagged mobile test builds.
  bool grantTestingCredits([int amount = 100]) {
    if (!testingCreditsEnabled ||
        _disposed ||
        amount <= 0 ||
        credits >= testingTopUpBalanceLimit) {
      return false;
    }
    final previous = _account ?? OnlineCreditAccount.balanceOnly(credits);
    final available = testingTopUpBalanceLimit - previous.credits;
    final granted = amount > available ? available : amount;
    final transactionId =
        'test:credit_grant:${_now().toUtc().microsecondsSinceEpoch}:${_changeSequence + 1}';
    final transaction = OnlineCreditTransaction(
      transactionId: transactionId,
      delta: granted,
      type: 'test_grant',
      reason: 'testing_credits',
      createdAt: _now().toUtc(),
    );
    _account = OnlineCreditAccount(
      credits: previous.credits + granted,
      bonusCredits: previous.bonusCredits + granted,
      purchasedCredits: previous.purchasedCredits,
      lifetimeEarned: previous.lifetimeEarned + granted,
      lifetimeSpent: previous.lifetimeSpent,
      completionRewardsToday: previous.completionRewardsToday,
      nextDailyLoginAt: previous.nextDailyLoginAt,
      recentTransactions: [transaction, ...previous.recentTransactions],
    );
    _lastChange = ArenaCreditChange(
      sequence: ++_changeSequence,
      from: previous.credits,
      to: previous.credits + granted,
      delta: granted,
      reason: transaction.reason,
      transactionId: transactionId,
    );
    _rememberTransactions(_account!);
    _queueSave();
    _notifySafely();
    return true;
  }

  bool redeemTestingTopUpCode(String code) {
    final normalized = code.trim().toUpperCase();
    final localNow = _now().toLocal();
    final expected = switch ((localNow.year, localNow.month)) {
      (2026, 9) => september2026TopUpCode,
      (2026, 10) => october2026TopUpCode,
      _ => null,
    };
    if (!testingCreditsEnabled || expected == null || normalized != expected) {
      return false;
    }
    return grantTestingCredits();
  }

  /// Grants each earned badge reward once, even if a result is reopened.
  Future<int> grantBadgeUpgradeCredits(ArenaBadge badge) async {
    if (_disposed || badge.creditReward <= 0) return 0;
    var granted = 0;
    _badgeRewardQueue = _badgeRewardQueue.then((_) async {
      final preferences = await SharedPreferences.getInstance();
      final claimed = preferences.getStringList(badgeRewardClaimsKey) ?? [];
      final transactionId = 'badge_upgrade:${badge.name}';
      if (claimed.contains(badge.name) ||
          _seenTransactionIds.contains(transactionId) ||
          _disposed) {
        return;
      }

      final previous = _account ?? OnlineCreditAccount.balanceOnly(credits);
      final transaction = OnlineCreditTransaction(
        transactionId: transactionId,
        delta: badge.creditReward,
        type: 'badge_reward',
        reason: '${badge.name} badge reward',
        createdAt: _now().toUtc(),
      );
      _account = OnlineCreditAccount(
        credits: previous.credits + badge.creditReward,
        bonusCredits: previous.bonusCredits + badge.creditReward,
        purchasedCredits: previous.purchasedCredits,
        lifetimeEarned: previous.lifetimeEarned + badge.creditReward,
        lifetimeSpent: previous.lifetimeSpent,
        completionRewardsToday: previous.completionRewardsToday,
        nextDailyLoginAt: previous.nextDailyLoginAt,
        recentTransactions: [transaction, ...previous.recentTransactions],
      );
      _lastChange = ArenaCreditChange(
        sequence: ++_changeSequence,
        from: previous.credits,
        to: previous.credits + badge.creditReward,
        delta: badge.creditReward,
        reason: transaction.reason,
        transactionId: transactionId,
      );
      granted = badge.creditReward;
      _rememberTransactions(_account!);
      await preferences.setStringList(badgeRewardClaimsKey, [
        ...claimed,
        badge.name,
      ]);
      _queueSave();
      _notifySafely();
    });
    await _badgeRewardQueue;
    return granted;
  }

  /// Restores a cached balance only when it belongs to the saved profile token.
  Future<void> restore() async {
    final revision = _mutationRevision;
    final preferences = await SharedPreferences.getInstance();
    final localBalance = preferences.getInt(_localBalanceKey);
    if (!_disposed && revision == _mutationRevision && localBalance != null) {
      _account = OnlineCreditAccount.balanceOnly(localBalance);
      _notifySafely();
    }
    final profile = await OnlineGameHistory.loadProfile();
    if (_disposed || revision != _mutationRevision) return;
    await restoreForToken(profile?.playerToken, expectedRevision: revision);
  }

  @visibleForTesting
  Future<void> restoreForToken(
    String? playerToken, {
    int? expectedRevision,
  }) async {
    if (playerToken == null || playerToken.isEmpty) return;
    final revision = expectedRevision ?? _mutationRevision;
    final cached = await OnlineGameHistory.loadCreditBalance(playerToken);
    if (_disposed || revision != _mutationRevision || cached == null) return;
    _playerToken = cached.playerToken;
    _account = OnlineCreditAccount.balanceOnly(
      cached.credits,
      bonusCredits: cached.bonusCredits,
      purchasedCredits: cached.purchasedCredits,
    );
    _lastSyncedAt = cached.syncedAt;
    _orderedSeenTransactionIds = cached.seenTransactionIds.toList();
    _seenTransactionIds = cached.seenTransactionIds.toSet();
    _live = false;
    _notifySafely();
  }

  /// Accepts a complete account that the server has already acknowledged.
  ///
  /// Repeating the same account or transaction IDs is presentation-idempotent:
  /// it neither changes the balance nor replays an animation.
  void acceptServerAccount({
    required String profileToken,
    required OnlineCreditAccount account,
    required OnlineCreditPolicy policy,
  }) {
    if (_disposed || profileToken.isEmpty) return;
    _mutationRevision++;
    final samePlayer = _playerToken == null || _playerToken == profileToken;
    final previous = samePlayer ? _account : null;
    if (!samePlayer) {
      _seenTransactionIds = <String>{};
      _orderedSeenTransactionIds = <String>[];
      _lastChange = null;
    }
    final unseen = account.recentTransactions
        .where(
          (transaction) =>
              !_seenTransactionIds.contains(transaction.transactionId),
        )
        .toList(growable: false);
    final from = previous?.credits;
    final delta = from == null ? 0 : account.credits - from;

    _playerToken = profileToken;
    _account = account;
    _policy = policy;
    _lastSyncedAt = _now().toUtc();
    _live = true;
    _rememberTransactions(account);

    if (delta != 0) {
      OnlineCreditTransaction? matchingTransaction;
      for (final transaction in unseen) {
        if (transaction.delta == delta) {
          matchingTransaction = transaction;
          break;
        }
      }
      matchingTransaction ??= unseen.firstOrNull;
      _lastChange = ArenaCreditChange(
        sequence: ++_changeSequence,
        from: from!,
        to: account.credits,
        delta: delta,
        reason: matchingTransaction?.reason,
        transactionId: matchingTransaction?.transactionId,
      );
    }
    _queueSave();
    _notifySafely();
  }

  /// Keeps the last authoritative balance visible while marking it as cached.
  void markDisconnected({String? profileToken}) {
    if (_disposed ||
        !_live ||
        (profileToken != null &&
            _playerToken != null &&
            profileToken != _playerToken)) {
      return;
    }
    _live = false;
    _notifySafely();
  }

  void _notifySafely() {
    if (_disposed) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_notificationScheduled) return;
      _notificationScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _notificationScheduled = false;
        if (!_disposed) notifyListeners();
      });
      return;
    }
    notifyListeners();
  }

  void _rememberTransactions(OnlineCreditAccount account) {
    final ordered = <String>[
      for (final transaction in account.recentTransactions)
        transaction.transactionId,
      ..._orderedSeenTransactionIds,
    ];
    final unique = <String>[];
    final seen = <String>{};
    for (final id in ordered) {
      if (id.isNotEmpty && seen.add(id)) unique.add(id);
      if (unique.length == 64) break;
    }
    _orderedSeenTransactionIds = unique;
    _seenTransactionIds = unique.toSet();
  }

  void _queueSave() {
    final account = _account;
    final token = _playerToken;
    final syncedAt = _lastSyncedAt;
    if (account == null) return;
    if (token == null || syncedAt == null) {
      final balance = account.credits;
      _saveQueue = _saveQueue.then((_) async {
        try {
          final preferences = await SharedPreferences.getInstance();
          await preferences.setInt(_localBalanceKey, balance);
        } catch (_) {
          // A cache failure must never interfere with the local feature.
        }
      });
      return;
    }
    final snapshot = CachedArenaCreditBalance(
      playerToken: token,
      credits: account.credits,
      bonusCredits: account.bonusCredits,
      purchasedCredits: account.purchasedCredits,
      syncedAt: syncedAt,
      seenTransactionIds: _orderedSeenTransactionIds,
    );
    _saveQueue = _saveQueue.then((_) async {
      try {
        await OnlineGameHistory.saveCreditBalance(snapshot);
      } catch (_) {
        // A cache failure must never interfere with the server-owned wallet.
      }
    });
  }

  @visibleForTesting
  Future<void> flushPendingSave() async {
    await _badgeRewardQueue;
    await _saveQueue;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class ArenaCreditScope extends InheritedNotifier<ArenaCreditController> {
  const ArenaCreditScope({
    required ArenaCreditController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static ArenaCreditController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<ArenaCreditScope>();
    assert(scope != null, 'ArenaCreditScope is missing above this context');
    return scope!.notifier!;
  }

  static ArenaCreditController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ArenaCreditScope>()?.notifier;
}
