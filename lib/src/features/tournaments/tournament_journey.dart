// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/bot_tournament.dart';
import '../../domain/online_player_profile.dart';
import '../../domain/piece_pack.dart';
import '../../services/tournament_storage.dart';
import '../online/online_avatar_image.dart';

const tournamentGold = Color(0xFFFFD580);

Color tournamentColor(BotTournament cup) => switch (cup.level) {
  OnlinePlayerLevel.beginner => const Color(0xFF71E5C2),
  OnlinePlayerLevel.intermediate => const Color(0xFF95B7FF),
  OnlinePlayerLevel.advanced => const Color(0xFFE4A0FF),
};

class TournamentTrophy extends StatelessWidget {
  const TournamentTrophy({this.size = 72, this.earned = false, super.key});
  final double size;
  final bool earned;

  @override
  Widget build(BuildContext context) => Semantics(
    label: earned ? 'Championship trophy earned' : 'Championship trophy',
    child: CustomPaint(
      painter: _LaurelPainter(earned ? tournamentGold : Colors.white38),
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * .2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              tournamentGold.withValues(alpha: earned ? .32 : .12),
              tournamentGold.withValues(alpha: .01),
            ],
          ),
        ),
        child: Icon(
          Icons.emoji_events_rounded,
          color: tournamentGold,
          size: size * .52,
        ),
      ),
    ),
  );
}

class _LaurelPainter extends CustomPainter {
  const _LaurelPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width * .44;
    final paint = Paint()..color = color;
    for (final side in [-1, 1]) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * .016;
      canvas.drawArc(
        Rect.fromCenter(
          center: center,
          width: radius * 1.8,
          height: radius * 2,
        ),
        (side == -1 ? .7 : -.3) * math.pi,
        .6 * math.pi,
        false,
        paint,
      );
      paint.style = PaintingStyle.fill;
      for (var i = 0; i < 7; i++) {
        final angle = (.2 + i * .1) * math.pi;
        final point =
            center + Offset(side * math.sin(angle), math.cos(angle)) * radius;
        canvas.save();
        canvas.translate(point.dx, point.dy);
        canvas.rotate(side * -angle);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: size.width * .055,
            height: size.height * .12,
          ),
          paint,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_LaurelPainter oldDelegate) => color != oldDelegate.color;
}

class TournamentScoreBanner extends StatelessWidget {
  const TournamentScoreBanner({
    required this.score,
    this.conquests = false,
    super.key,
  });
  final TournamentPlayerScore? score;
  final bool conquests;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('tournament-player-score'),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(
        colors: [Color(0xFF273856), Color(0xFF151D32)],
      ),
      border: Border.all(color: tournamentGold.withValues(alpha: .35)),
    ),
    child: DefaultTextStyle.merge(
      style: const TextStyle(color: Colors.white),
      child: Row(
        children: [
          const TournamentTrophy(size: 64, earned: true),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conquests
                      ? 'YOUR CONQUEST JOURNEY'
                      : 'YOUR TOURNAMENT JOURNEY',
                  style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.5,
                    color: tournamentGold,
                  ),
                ),
                Text(
                  score == null
                      ? 'Points unavailable'
                      : '${score!.points} points',
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  score == null
                      ? 'Reopen a cup to retry loading progress.'
                      : '${score!.wins} round wins · ${score!.trophies} / ${conquests ? builtInConquests.length : builtInTournaments.length} trophies',
                ),
                const Text(
                  'Saved on this device',
                  style: TextStyle(fontSize: 12, color: Colors.white60),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// The nodes reveal actual opponents only as the bracket is unlocked.
class TournamentJourney extends StatelessWidget {
  const TournamentJourney({required this.cup, required this.run, super.key});
  final BotTournament cup;
  final TournamentRun run;

  @override
  Widget build(BuildContext context) {
    final color = tournamentColor(cup);
    final bracket = run.bracket(cup);
    if (cup.isConquest) {
      return _ConquestRoadmap(cup: cup, run: run);
    }
    return Container(
      key: const ValueKey('tournament-journey'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(const Color(0xFF172339), color, .18)!,
            const Color(0xFF101728),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: .4)),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        run.completed
                            ? 'THE CUP IS YOURS'
                            : 'ROAD TO THE TROPHY',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.3,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${run.wonRounds} of ${cup.roundCount} rounds conquered',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${run.pointsEarned(cup)} cup points · +${cup.pointsPerWin} per win',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                TournamentTrophy(size: 68, earned: run.completed),
              ],
            ),
            const SizedBox(height: 20),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: run.wonRounds / cup.roundCount),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 950),
              curve: Curves.easeOutCubic,
              builder: (context, progress, _) => CustomPaint(
                painter: _JourneyPathPainter(color, progress, cup.roundCount),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var round = 0; round < cup.roundCount; round++)
                      Expanded(child: _node(round, bracket, color)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _node(int round, List<List<TournamentPairing>> bracket, Color color) {
    final won = round < run.wonRounds;
    final current = !run.completed && round == run.wonRounds;
    final unlocked = won || current;
    final opponentId = unlocked
        ? bracket[round].singleWhere((pair) => pair.involvesHuman).opponentId
        : null;
    final bot = opponentId == null
        ? null
        : cup.opponents.singleWhere((bot) => bot.id == opponentId);
    final status = won
        ? 'Won · +${cup.pointsPerWin}'
        : current
        ? (run.lastResult != null ? 'Rematch ready' : 'Up next')
        : 'Locked';
    return Semantics(
      label:
          '${cup.roundName(round)}, ${bot?.name ?? 'opponent to be revealed'}, $status',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          children: [
            Container(
              key: ValueKey('journey-round-$round'),
              width: 64,
              height: 64,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF151E31),
                border: Border.all(
                  color: won
                      ? tournamentGold
                      : current
                      ? color
                      : Colors.white24,
                  width: current ? 3 : 2,
                ),
                boxShadow: current || won
                    ? [
                        BoxShadow(
                          color: (won ? tournamentGold : color).withValues(
                            alpha: .22,
                          ),
                          blurRadius: 18,
                        ),
                      ]
                    : [],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (bot != null)
                    OnlineAvatarImage(avatarId: bot.avatarId, size: 50)
                  else
                    const Icon(
                      Icons.lock_outline_rounded,
                      color: Colors.white38,
                    ),
                  if (won)
                    const Align(
                      alignment: Alignment.bottomRight,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0xFF151E31),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_circle,
                          size: 21,
                          color: tournamentGold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              cup.roundName(round),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              status,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: won
                    ? tournamentGold
                    : current
                    ? color
                    : Colors.white54,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConquestRoadmap extends StatelessWidget {
  const _ConquestRoadmap({required this.cup, required this.run});

  final BotTournament cup;
  final TournamentRun run;

  @override
  Widget build(BuildContext context) {
    final armies = cup.armies;
    final color = tournamentColor(cup);
    return Container(
      key: const ValueKey('conquest-roadmap'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF203A46), Color(0xFF111B2A)],
        ),
        border: Border.all(color: color.withValues(alpha: .55)),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.public, color: color, size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${cup.conquestSize?.label.toUpperCase() ?? 'CONQUEST'} ROADMAP',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.3,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${run.wonRounds} of ${cup.roundCount} realms conquered',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${run.pointsEarned(cup)} pts',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Every opponent on your route is shown below. Win each match to advance to the next realm.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 18),
            for (var index = 0; index < armies.length; index++) ...[
              _ConquestStop(
                index: index,
                army: armies[index],
                conquered: index < run.wonRounds,
                current: !run.completed && index == run.wonRounds,
                alignLeft: index.isEven,
              ),
              if (index != armies.length - 1)
                Center(
                  child: Container(
                    width: 3,
                    height: 22,
                    decoration: BoxDecoration(
                      color: index < run.wonRounds ? color : Colors.white24,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: run.wonRounds / cup.roundCount,
              color: color,
              backgroundColor: Colors.white12,
            ),
            const SizedBox(height: 8),
            Text(
              run.completed
                  ? 'World map secured · Conquest complete'
                  : 'Next: ${armies[run.wonRounds].name}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConquestStop extends StatelessWidget {
  const _ConquestStop({
    required this.index,
    required this.army,
    required this.conquered,
    required this.current,
    required this.alignLeft,
  });

  final int index;
  final PiecePack army;
  final bool conquered;
  final bool current;
  final bool alignLeft;

  @override
  Widget build(BuildContext context) {
    final status = conquered
        ? 'Conquered'
        : current
        ? 'Next opponent'
        : 'Upcoming';
    final node = Container(
      key: ValueKey('conquest-roadmap-stop-$index'),
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: current
            ? army.accent.withValues(alpha: .2)
            : Colors.white.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: current ? army.accent : Colors.white24,
          width: current ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: army.accent.withValues(alpha: .2),
            foregroundColor: conquered || current
                ? army.accent
                : Colors.white54,
            child: Icon(conquered ? Icons.check : army.icon),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${index + 1}. ${army.name}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  status,
                  style: TextStyle(
                    color: current ? army.accent : Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return Align(
      alignment: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
      child: node,
    );
  }
}

class _JourneyPathPainter extends CustomPainter {
  const _JourneyPathPainter(this.color, this.progress, this.nodes);
  final Color color;
  final double progress;
  final int nodes;

  @override
  void paint(Canvas canvas, Size size) {
    if (nodes < 2) return;
    final start = size.width / nodes / 2;
    final end = size.width - start;
    final paint = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = Colors.white12;
    canvas.drawLine(Offset(start, 32), Offset(end, 32), paint);
    paint.color = color;
    canvas.drawLine(
      Offset(start, 32),
      Offset(
        start +
            (end - start) * (progress * nodes / (nodes - 1)).clamp(0.0, 1.0),
        32,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_JourneyPathPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.nodes != nodes;
}
