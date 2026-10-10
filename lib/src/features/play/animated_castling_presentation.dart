// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../../domain/animated_army_theme.dart';
import '../../domain/neon_live_action.dart';
import 'animated_move_timing.dart';
import 'neon_illustrated_stage.dart';

/// King and rook share the arena's accepted-move clock. This widget owns no
/// timer, audio, or game state; restored and reduced-motion scenes stay still.
class AnimatedCastlingPresentation extends StatelessWidget {
  const AnimatedCastlingPresentation({
    required this.action,
    required this.theme,
    required this.progress,
    required this.figureBodyHeight,
    required this.actorCenter,
    this.startKingCenter,
    this.reducedMotion = false,
    super.key,
  });

  final NeonLiveAction action;
  final AnimatedArmyTheme theme;
  final double progress;
  final double figureBodyHeight;

  /// Viewer-relative king center as a fraction of the full arena width.
  final double actorCenter;
  final double? startKingCenter;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final castle = action.castling;
    if (castle == null || action.isSelection) return const SizedBox.shrink();
    final color = Color(
      action.actor.color == Side.white
          ? theme.whiteColorArgb
          : theme.blackColorArgb,
    );
    return Semantics(
      key: const ValueKey('animated-live-castling'),
      label:
          '${action.actor.color.name} ${castle.kingside ? 'kingside' : 'queenside'} castling. '
          'King ${action.source.name} to ${action.target!.name}; '
          'rook ${castle.source.name} to ${castle.target.name}.',
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, box) {
            final size = Size(box.maxWidth, box.maxHeight);
            if (size.isEmpty) return const SizedBox.shrink();
            final labelHeight = math.min(21.0, size.height * .2);
            final spriteHeight = math.max(0.0, size.height - labelHeight);
            final slotWidth = size.width * .26;
            final bodyHeight = math.min(
              figureBodyHeight,
              animatedFigureBodyHeight(
                theme: theme,
                space: Size(slotWidth, spriteHeight),
                pieces: [action.actor, castle.rook],
              ),
            );
            final p = reducedMotion ? 1.0 : progress.clamp(0.0, 1.0);
            final travel = Curves.easeInOutCubic.transform(
              (p / animatedMoveImpactFraction).clamp(0.0, 1.0),
            );
            final direction = action.actorOnLeft ? 1.0 : -1.0;
            final inset = slotWidth / size.width * .5;
            double center(double value) =>
                value.clamp(inset, 1 - inset).toDouble();
            final kingStart = center(startKingCenter ?? actorCenter);
            final kingEnd = center(
              actorCenter + direction * (castle.kingside ? .085 : -.065),
            );
            final rookStart = center(
              actorCenter + direction * (castle.kingside ? .235 : -.12),
            );
            final rookEnd = center(
              actorCenter + direction * (castle.kingside ? -.09 : .15),
            );
            final kingX = kingStart + (kingEnd - kingStart) * travel;
            final rookX = rookStart + (rookEnd - rookStart) * travel;
            Widget figure(
              Piece piece,
              double x, {
              required bool king,
            }) => Positioned(
              key: ValueKey(
                king
                    ? 'animated-castling-king-motion'
                    : 'animated-castling-rook-motion',
              ),
              left: x * size.width - slotWidth * .5,
              top: 0,
              width: slotWidth,
              height: spriteHeight,
              child: NeonFigureSprite(
                key: king
                    ? ValueKey(
                        'neon-live-${action.actorOnLeft ? 'left' : 'right'}-figure',
                      )
                    : const ValueKey('neon-live-castling-rook'),
                piece: piece,
                theme: theme,
                faceRight: action.actorOnLeft,
                bodyHeight: bodyHeight,
              ),
            );
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    key: const ValueKey('animated-castling-protection'),
                    painter: AnimatedCastlingPainter(
                      theme: theme,
                      king: Offset(kingX * size.width, spriteHeight * .6),
                      rook: Offset(rookX * size.width, spriteHeight * .6),
                      color: color,
                      progress: p,
                      reducedMotion: reducedMotion,
                    ),
                  ),
                ),
                // The rook passes behind the king, then guards its new flank.
                figure(castle.rook, rookX, king: false),
                figure(action.actor, kingX, king: true),
                for (final (square, x, king) in [
                  (castle.target, rookX, false),
                  (action.target!, kingX, true),
                ])
                  Positioned(
                    left: x * size.width - slotWidth * .5,
                    top: spriteHeight,
                    width: slotWidth,
                    height: labelHeight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${king ? 'KING' : 'ROOK'} · ${square.name.toUpperCase()}',
                        key: ValueKey(
                          king
                              ? 'animated-castling-king-label'
                              : 'animated-castling-rook-label',
                        ),
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          shadows: const [
                            Shadow(color: Color(0xFF070B19), blurRadius: 6),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A protective bridge between the two allied units, rather than a strike.
class AnimatedCastlingPainter extends CustomPainter {
  const AnimatedCastlingPainter({
    required this.theme,
    required this.king,
    required this.rook,
    required this.color,
    required this.progress,
    required this.reducedMotion,
  });

  final AnimatedArmyTheme theme;
  final Offset king;
  final Offset rook;
  final Color color;
  final double progress;
  final bool reducedMotion;

  @override
  void paint(Canvas canvas, Size size) {
    final pulse = reducedMotion ? .4 : math.sin(math.pi * progress);
    if (pulse <= 0) return;
    final radius = math.min(size.height * .31, size.width * .14);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, radius * .045)
      ..color = color.withValues(alpha: pulse * .8);
    final ground = king.dy + radius * .5;
    canvas.drawLine(Offset(king.dx, ground), Offset(rook.dx, ground), line);
    switch (theme) {
      case AnimatedArmyTheme.neon:
        final circuit = Path()
          ..moveTo(rook.dx, ground)
          ..lineTo(rook.dx, king.dy - radius * .6)
          ..lineTo(king.dx, king.dy - radius * .6)
          ..lineTo(king.dx, ground);
        canvas.drawPath(circuit, line);
        for (final point in [king, rook]) {
          canvas.drawRect(
            Rect.fromCenter(
              center: point,
              width: radius * .22,
              height: radius * .22,
            ),
            line,
          );
        }
      case AnimatedArmyTheme.manga:
        for (final sign in [-1.0, 1.0]) {
          canvas.drawArc(
            Rect.fromCircle(center: king, radius: radius),
            -math.pi / 2 + sign * .25,
            sign * math.pi * .85,
            false,
            line,
          );
        }
        final comet = Path()
          ..moveTo(rook.dx, ground)
          ..quadraticBezierTo(
            (rook.dx + king.dx) / 2,
            king.dy - radius,
            king.dx,
            ground,
          );
        canvas.drawPath(comet, line);
      case AnimatedArmyTheme.epic:
        canvas.drawCircle(king, radius, line);
        for (var petal = 0; petal < 7; petal++) {
          final angle = math.pi + petal * math.pi / 6;
          final tip = king + Offset(math.cos(angle), math.sin(angle)) * radius;
          canvas.drawOval(
            Rect.fromCenter(
              center: tip,
              width: radius * .28,
              height: radius * .5,
            ),
            line,
          );
        }
      case AnimatedArmyTheme.olympian:
        final shield = Path()
          ..moveTo(king.dx - radius * .7, king.dy - radius * .7)
          ..lineTo(king.dx + radius * .7, king.dy - radius * .7)
          ..lineTo(king.dx + radius * .55, king.dy + radius * .2)
          ..quadraticBezierTo(
            king.dx,
            king.dy + radius,
            king.dx - radius * .55,
            king.dy + radius * .2,
          )
          ..close();
        canvas.drawPath(shield, line);
        final bolt = Path()
          ..moveTo(rook.dx, king.dy - radius)
          ..lineTo(rook.dx - radius * .15, king.dy - radius * .35)
          ..lineTo(rook.dx + radius * .15, king.dy - radius * .35)
          ..lineTo(rook.dx, ground);
        canvas.drawPath(bolt, line);
    }
  }

  @override
  bool shouldRepaint(AnimatedCastlingPainter oldDelegate) =>
      oldDelegate.theme != theme ||
      oldDelegate.king != king ||
      oldDelegate.rook != rook ||
      oldDelegate.color != color ||
      oldDelegate.progress != progress ||
      oldDelegate.reducedMotion != reducedMotion;
}
