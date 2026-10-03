// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/bot_tournament.dart';
import '../../domain/player_progress.dart';
import '../../domain/online_player_profile.dart';
import '../../services/theme_music.dart';
import '../../services/player_identity_controller.dart';
import '../progression/progress_widgets.dart';
import 'tournament_journey.dart';

/// Presentation only: replaying this ceremony never mutates saved rewards.
Future<bool> showChampionshipCelebration({
  required BuildContext context,
  required BotTournament cup,
  bool replay = false,
  AvatarVoice voice = AvatarVoice.male,
  bool checkmate = false,
  ProgressAward? progressAward,
}) async {
  if (replay) {
    MusicScope.of(context)?.playEffect(CinematicSound.victoryApplause);
  } else {
    MusicScope.of(context)?.announceVictory(voice: voice, checkmate: checkmate);
  }
  return await showGeneralDialog<bool>(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'Tournament championship',
        barrierColor: const Color(0xF5081020),
        transitionDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 400),
        pageBuilder: (_, __, ___) => ChampionshipCelebration(
          cup: cup,
          replay: replay,
          progressAward: progressAward,
        ),
        transitionBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ) ??
      false;
}

class ChampionshipCelebration extends StatefulWidget {
  const ChampionshipCelebration({
    required this.cup,
    this.replay = false,
    this.progressAward,
    super.key,
  });
  final BotTournament cup;
  final bool replay;
  final ProgressAward? progressAward;

  @override
  State<ChampionshipCelebration> createState() =>
      _ChampionshipCelebrationState();
}

class _ChampionshipCelebrationState extends State<ChampionshipCelebration>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );
  bool? _reducedMotion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (_reducedMotion == reduced) return;
    _reducedMotion = reduced;
    if (reduced) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cup = widget.cup;
    final nickname = PlayerIdentityScope.maybeOf(context)?.nickname;
    final color = tournamentColor(cup);
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (_, __) => CustomPaint(
                      painter: _CelebrationPainter(
                        _controller.value,
                        color,
                        _reducedMotion ?? false,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Container(
                    key: const ValueKey('championship-celebration'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 28,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xEF293852), Color(0xF511192C)],
                      ),
                      border: Border.all(
                        color: tournamentGold.withValues(alpha: .65),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: tournamentGold.withValues(alpha: .16),
                          blurRadius: 60,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: DefaultTextStyle.merge(
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'HALL OF CHAMPIONS',
                            style: TextStyle(
                              color: color,
                              letterSpacing: 2.5,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          AnimatedBuilder(
                            animation: _controller,
                            builder: (_, child) {
                              final entrance = Curves.easeOutBack.transform(
                                (_controller.value * 7).clamp(0.0, 1.0),
                              );
                              return Transform.scale(
                                scale: .65 + entrance * .35,
                                child: child,
                              );
                            },
                            child: const TournamentTrophy(
                              size: 156,
                              earned: true,
                            ),
                          ),
                          Text(
                            cup.isConquest
                                ? 'Conquest complete!'
                                : 'Tournament champion!',
                            style: const TextStyle(
                              fontSize: 32,
                              height: 1.1,
                              fontWeight: FontWeight.w900,
                              color: tournamentGold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            cup.title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (nickname != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Congratulations, $nickname!',
                              style: const TextStyle(
                                color: tournamentGold,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            '${cup.roundCount} rounds conquered. One trophy earned.\nYour journey belongs in the hall of champions.',
                            style: const TextStyle(
                              color: Colors.white70,
                              height: 1.5,
                            ),
                          ),
                          if (widget.progressAward case final award?) ...[
                            const SizedBox(height: 16),
                            ProgressAwardBanner(award: award),
                          ],
                          const SizedBox(height: 22),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: tournamentGold.withValues(alpha: .10),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  widget.replay
                                      ? 'CHAMPIONSHIP REWARDS'
                                      : '+${cup.pointsPerWin} points · Final victory',
                                  style: const TextStyle(
                                    color: tournamentGold,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${cup.pointsPerWin * cup.roundCount} cup points earned',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  widget.replay
                                      ? 'Already in your total · No additional points'
                                      : 'Added to your tournament total · Saved on this device',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              key: const ValueKey('championship-continue'),
                              style: FilledButton.styleFrom(
                                backgroundColor: tournamentGold,
                                foregroundColor: const Color(0xFF151E31),
                                padding: const EdgeInsets.all(16),
                              ),
                              onPressed: () => Navigator.pop(context, true),
                              icon: const Icon(Icons.emoji_events_rounded),
                              label: Text(
                                widget.replay
                                    ? 'Back to my trophy'
                                    : 'View my trophy',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Deterministic particles avoid layout churn and new random values per frame.
/// The show finishes after seven seconds; reduced motion uses a static starfield.
class _CelebrationPainter extends CustomPainter {
  const _CelebrationPainter(this.progress, this.color, this.reducedMotion);
  final double progress;
  final Color color;
  final bool reducedMotion;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final colors = [
      tournamentGold,
      color,
      Colors.white,
      const Color(0xFFFF8FAE),
    ];
    final random = math.Random(42);
    // Broad, soft spotlights frame the trophy without flashing.
    for (final x in [.12, .88]) {
      final center = Offset(size.width * x, size.height * .25);
      paint.shader =
          RadialGradient(
            colors: [color.withValues(alpha: .2), color.withValues(alpha: 0)],
          ).createShader(
            Rect.fromCircle(center: center, radius: size.longestSide * .6),
          );
      canvas.drawRect(Offset.zero & size, paint);
    }
    paint.shader = null;
    for (var i = 0; i < 95; i++) {
      final baseX = random.nextDouble();
      final baseY = random.nextDouble();
      final speed = .65 + random.nextDouble() * .8;
      final width = 3 + random.nextDouble() * 5;
      final angle = random.nextDouble() * math.pi;
      paint.color = colors[i % colors.length].withValues(
        alpha: .35 + random.nextDouble() * .5,
      );
      final x =
          baseX * size.width +
          (reducedMotion ? 0 : math.sin(progress * 9 + angle) * 24);
      final y =
          ((baseY + (reducedMotion ? 0 : progress * speed)) % 1) * size.height;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle + (reducedMotion ? 0 : progress * 8));
      if (reducedMotion || i % 3 == 0) {
        canvas.drawCircle(Offset.zero, width * .4, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: width,
              height: width * 1.8,
            ),
            const Radius.circular(1),
          ),
          paint,
        );
      }
      canvas.restore();
    }
    if (reducedMotion || progress >= 1) return;
    // Staggered expanding bursts, with a gentle fade instead of a strobe.
    for (var burst = 0; burst < 6; burst++) {
      final age = (progress * 7 - burst * .85 - .2) / 1.5;
      if (age < 0 || age > 1) continue;
      final center = Offset(
        size.width * (burst.isEven ? .15 : .85),
        size.height * (.12 + (burst % 3) * .24),
      );
      paint
        ..color = colors[burst % colors.length].withValues(
          alpha: (1 - age) * .8,
        )
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      for (var ray = 0; ray < 18; ray++) {
        final angle = ray / 18 * math.pi * 2;
        final direction = Offset(math.cos(angle), math.sin(angle));
        canvas.drawLine(
          center + direction * (age * 90),
          center + direction * (age * 115 + 4),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CelebrationPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.reducedMotion != reducedMotion;
}
