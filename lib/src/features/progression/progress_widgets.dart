// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../domain/player_progress.dart';
import '../../services/player_identity_controller.dart';
import '../../services/player_progress_controller.dart';
import '../credits/gold_credit_coin.dart';

class ProgressBadgeSummary extends StatelessWidget {
  const ProgressBadgeSummary({this.showTitle = true, super.key});

  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final controller = PlayerProgressScope.maybeOf(context);
    if (controller == null) {
      return Text(
        showTitle ? 'BATTLE CHESS ARENA' : 'Your next great match awaits',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: .4,
        ),
      );
    }
    final progress = controller.progress;
    return InkWell(
      key: const ValueKey('player-badge-summary'),
      borderRadius: BorderRadius.circular(8),
      onTap: () => showPlayerProgress(context, progress),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showTitle)
              const Text(
                'BATTLE CHESS ARENA',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .8,
                ),
              ),
            Text(
              '${progress.badge.icon} ${progress.badge.name}  ·  ${progress.overallPoints} pts',
              key: const ValueKey('badge-subtitle'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: showTitle ? 10 : 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showPlayerProgress(
  BuildContext context,
  PlayerProgress progress,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${progress.badge.icon}  ${progress.badge.name}',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            '${progress.overallPoints} overall points',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: progress.badgeProgress),
          const SizedBox(height: 8),
          Text(
            progress.nextBadge == null
                ? 'Highest badge achieved'
                : '${progress.nextBadge!.minimumPoints - progress.overallPoints} points to ${progress.nextBadge!.name}',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _ProgressStat(
                  icon: Icons.auto_awesome,
                  value: '${progress.experience}',
                  label: 'Experience',
                ),
              ),
              Expanded(
                child: _ProgressStat(
                  icon: Icons.emoji_events,
                  value: '${progress.trophies}',
                  label: 'Trophies',
                ),
              ),
              Expanded(
                child: _ProgressStat(
                  icon: Icons.sports_esports,
                  value: '${progress.completedGames}',
                  label: 'Games',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Badge path', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final badge in arenaBadges)
            ListTile(
              dense: true,
              leading: Text(badge.icon, style: const TextStyle(fontSize: 24)),
              title: Text(badge.name),
              subtitle: Text('${badge.minimumPoints} overall points'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const GoldCreditCoin(size: 18),
                  const SizedBox(width: 5),
                  Text(
                    '+${badge.creditReward}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              enabled: progress.overallPoints >= badge.minimumPoints,
            ),
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'The displayed credits are awarded once when each badge is unlocked.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          const Text(
            'Overall points = experience + 100 points per trophy. '
            'Every completed game earns 10 XP plus one XP per move, capped at 110 XP. Trophies are awarded for wins only.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
  ),
);

class _ProgressStat extends StatelessWidget {
  const _ProgressStat({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
      Text(label, style: const TextStyle(fontSize: 11)),
    ],
  );
}

class ProgressAwardBanner extends StatelessWidget {
  const ProgressAwardBanner({required this.award, super.key});
  final ProgressAward award;

  @override
  Widget build(BuildContext context) {
    if (award.alreadyAwarded) return const SizedBox.shrink();
    final nickname = PlayerIdentityScope.maybeOf(context)?.nickname;
    return Container(
      key: const ValueKey('progress-award-banner'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD166).withValues(alpha: .12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFFD166).withValues(alpha: .55),
        ),
      ),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 18,
            runSpacing: 6,
            children: [
              Text(
                '+${award.experience} XP',
                style: const TextStyle(
                  color: Color(0xFFFFD166),
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (award.trophies > 0)
                const Text(
                  '🏆 +1 Trophy',
                  style: TextStyle(
                    color: Color(0xFFFFD166),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              if (award.badgeCredits > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const GoldCreditCoin(size: 20),
                    const SizedBox(width: 5),
                    Text(
                      '+${award.badgeCredits} Badge reward',
                      style: const TextStyle(
                        color: Color(0xFFFFD166),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (award.unlockedBadge case final badge?) ...[
            const SizedBox(height: 6),
            Text(
              '${nickname == null ? '' : '$nickname, '}${badge.icon} ${badge.name} unlocked!',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (award.badgeCredits > 0)
              const Text(
                'Reward credits added to your balance!',
                style: TextStyle(
                  color: Color(0xFFFFD166),
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
