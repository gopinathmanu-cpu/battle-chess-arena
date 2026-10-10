// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../domain/online_credits.dart';
import '../../domain/player_progress.dart';
import '../../services/arena_credit_controller.dart';
import 'gold_credit_coin.dart';

Future<void> showCreditRulesSheet(BuildContext context) {
  final wallet = ArenaCreditScope.maybeOf(context);
  final policy = wallet?.policy ?? defaultOnlineCreditPolicy;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 600),
    builder: (context) => FractionallySizedBox(
      heightFactor: .9,
      child: ListView(
        key: const ValueKey('credit-rules-sheet'),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [
          Row(
            children: [
              const GoldCreditCoin(size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'How Credits Work',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      wallet == null
                          ? '${policy.starterCredits} welcome credits for every new player'
                          : '${wallet.credits} available · ${policy.starterCredits} welcome credits at signup',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _RuleHeading('PLAY FREELY'),
          const _RuleTile(
            icon: Icons.check_circle_outline,
            title: 'Core chess stays free',
            body:
                'All games, rematches, tournament and Conquest retries, auto-play, threat scans, themes, boards and avatars are free. Only Suggest Move uses credits.',
          ),
          const _RuleTile(
            icon: Icons.visibility_outlined,
            title: 'Prices appear before an action',
            body:
                'The gold coin and exact amount are shown beside every action that uses credits. A failed or unavailable action is not charged.',
          ),
          const SizedBox(height: 14),
          const _RuleHeading('USES CREDITS'),
          _PriceTile(
            'Move suggestion',
            policy.onlineMoveSuggestionCost,
            note:
                'Available in computer/practice play only; never in a real-player online game.',
          ),
          const SizedBox(height: 14),
          const _RuleHeading('EARN CREDITS'),
          _RuleTile(
            icon: Icons.card_giftcard,
            title: 'Welcome balance',
            body: '+${policy.starterCredits} when your wallet is created.',
          ),
          _RuleTile(
            icon: Icons.today_outlined,
            title: 'Daily Top-up',
            body:
                'Up to +${policy.dailyLoginCredits} bonus credits each day, topping up the welcome balance to ${policy.dailyAllowanceCap}. Missed days do not stack.',
          ),
          _RuleTile(
            icon: Icons.flag_outlined,
            title: 'Complete meaningful online games',
            body:
                '+${policy.completionRewardCredits} after a qualifying completion, up to ${policy.dailyCompletionRewardCap} rewards each day. Winning is not required.',
          ),
          _RuleTile(
            icon: Icons.health_and_safety_outlined,
            title: 'Low-balance safety grant',
            body:
                'If your online balance drops below ${policy.lowBalanceRecoveryThreshold}, reconnect after the ${policy.lowBalanceRecoveryCooldownHours}-hour cooldown and the server restores it to ${policy.lowBalanceRecoveryTarget}.',
          ),
          const SizedBox(height: 6),
          for (final badge in arenaBadges)
            _RuleTile(
              icon: Icons.military_tech_outlined,
              title: '${badge.icon} ${badge.name}',
              body:
                  '${badge.minimumPoints} overall points · +${badge.creditReward} one-time badge credits',
              coinReward: badge.creditReward,
            ),
          const SizedBox(height: 14),
          const _RuleHeading('FAIRNESS & PURCHASES'),
          const _RuleTile(
            icon: Icons.balance_outlined,
            title: 'No credit wagering or stronger pieces',
            body:
                'Credits never change chess rules, clocks, matchmaking strength, piece power, tournament points or Conquest difficulty.',
          ),
          const _RuleTile(
            icon: Icons.lock_outline,
            title: 'Credit packs are not sold in this beta',
            body:
                'Planned pack sizes are 100, 300, 750 and 1,500 credits. Purchases will remain disabled until Google Play or App Store verification, refunds and account recovery are ready.',
          ),
          const Text(
            'Bonus and future purchased credits do not expire. Bonus credits are used first. Credits cannot be transferred, wagered or redeemed for cash.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

class _RuleHeading extends StatelessWidget {
  const _RuleHeading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w900,
        letterSpacing: 1,
      ),
    ),
  );
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({
    required this.icon,
    required this.title,
    required this.body,
    this.coinReward,
  });
  final IconData icon;
  final String title;
  final String body;
  final int? coinReward;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
    subtitle: Text(body),
    trailing: coinReward == null
        ? null
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const GoldCreditCoin(size: 16),
              const SizedBox(width: 4),
              Text('+$coinReward'),
            ],
          ),
  );
}

class _PriceTile extends StatelessWidget {
  const _PriceTile(this.title, this.cost, {this.note});
  final String title;
  final int cost;
  final String? note;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const GoldCreditCoin(size: 22),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
    subtitle: note == null ? null : Text(note!),
    trailing: Text(
      '$cost',
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
    ),
  );
}
