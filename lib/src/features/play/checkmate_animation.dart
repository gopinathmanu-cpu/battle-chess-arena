// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../../domain/animated_army_theme.dart';
import 'board_appearance.dart';
import 'neon_illustrated_stage.dart';
import 'neon_live_arena.dart';

const checkmateAnimationDuration = Duration(milliseconds: 2600);
const _reducedMotionDuration = Duration(milliseconds: 650);

/// Completes only after the mate presentation has finished. The caller retains
/// responsibility for checking that its game is still current before a result.
Future<void> showCheckmateAnimation({
  required BuildContext context,
  required Side winner,
  BoardAppearance? appearance,
}) async {
  if (!context.mounted) return;
  final navigator = Navigator.of(context, rootNavigator: true);
  late final RawDialogRoute<void> route;
  route = RawDialogRoute<void>(
    barrierDismissible: false,
    barrierLabel: 'Checkmate animation',
    barrierColor: Colors.black87,
    transitionDuration: Duration.zero,
    pageBuilder: (context, animation, secondaryAnimation) => PopScope(
      canPop: false,
      child: CheckmateAnimation(
        winner: winner,
        appearance: appearance,
        onComplete: () {
          // Remove this precise route, even if another route now covers it.
          if (route.isActive) navigator.removeRoute(route);
        },
      ),
    ),
  );
  await navigator.push<void>(route);
}

/// Reuses the active animated world even when the board displays Classic pieces.
class MatchResultBackdrop extends StatelessWidget {
  const MatchResultBackdrop({required this.appearance, super.key});

  final BoardAppearance appearance;

  @override
  Widget build(BuildContext context) {
    final theme = animatedArmyThemeForAppearance(appearance);
    if (theme == null) {
      return WorldBackdrop(
        pack: appearance.board,
        customSet: appearance.customSet,
        playSoundtrack: false,
        child: const SizedBox.expand(),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          theme.worldAsset,
          key: ValueKey(
            theme == AnimatedArmyTheme.neon
                ? 'result-neon-city'
                : 'result-${theme.name}-world',
          ),
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, _, _) =>
              ColoredBox(color: Color(theme.baseColorArgb)),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(theme.baseColorArgb).withValues(alpha: .27),
                Color(theme.baseColorArgb).withValues(alpha: .73),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class CheckmateAnimation extends StatefulWidget {
  const CheckmateAnimation({
    required this.winner,
    required this.onComplete,
    this.appearance,
    super.key,
  });

  final Side winner;
  final BoardAppearance? appearance;
  final VoidCallback onComplete;

  @override
  State<CheckmateAnimation> createState() => _CheckmateAnimationState();
}

class _CheckmateAnimationState extends State<CheckmateAnimation>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  bool _started = false;
  bool _completed = false;
  bool _reducedMotion = false;
  bool get _active =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller =
        AnimationController(vsync: this, duration: checkmateAnimationDuration)
          ..addStatusListener((status) {
            if (status != AnimationStatus.completed || _completed) return;
            _completed = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) widget.onComplete();
            });
          });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    _controller.duration = _reducedMotion
        ? _reducedMotionDuration
        : checkmateAnimationDuration;
    if (!_started) {
      _started = true;
      if (_active) _controller.forward();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_completed) return;
    if (state == AppLifecycleState.resumed) {
      _controller.forward();
    } else {
      _controller.stop(canceled: false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loser = widget.winner.opposite;
    final appearance = widget.appearance;
    final theme = appearance == null
        ? null
        : animatedArmyThemeForAppearance(appearance);
    final accent = widget.winner == Side.white
        ? Color(theme?.whiteColorArgb ?? 0xFF83F8EF)
        : Color(theme?.blackColorArgb ?? 0xFFFF6ACB);
    return Material(
      key: const ValueKey('checkmate-animation'),
      color: Color(theme?.baseColorArgb ?? 0xFF070B19),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (appearance != null) MatchResultBackdrop(appearance: appearance),
          ColoredBox(
            color: Color(
              theme?.baseColorArgb ?? 0xFF070B19,
            ).withValues(alpha: .4),
          ),
          SafeArea(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final p = _reducedMotion ? .72 : _controller.value;
                final reveal = Curves.easeOutCubic.transform(
                  (p / .23).clamp(0.0, 1.0),
                );
                final closing = _reducedMotion
                    ? 1.0
                    : (1 - (p - .9) / .1).clamp(0.0, 1.0);
                final defeat = Curves.easeInOut.transform(
                  ((p - .2) / .45).clamp(0.0, 1.0),
                );
                return Opacity(
                  opacity: reveal * closing,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 650),
                        child: Column(
                          children: [
                            Expanded(
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Positioned.fill(
                                    child: CustomPaint(
                                      key: const ValueKey('checkmate-seal'),
                                      painter: _MateSealPainter(
                                        progress: p,
                                        accent: accent,
                                      ),
                                    ),
                                  ),
                                  LayoutBuilder(
                                    builder: (context, size) => SizedBox.square(
                                      dimension: math.min(
                                        370,
                                        size.biggest.shortestSide * .7,
                                      ),
                                      child: Transform.translate(
                                        key: const ValueKey(
                                          'checkmate-king-drift',
                                        ),
                                        offset: Offset(0, defeat * 16),
                                        child: Transform.rotate(
                                          key: const ValueKey(
                                            'checkmate-king-motion',
                                          ),
                                          angle: _reducedMotion
                                              ? 0
                                              : (loser == Side.black
                                                        ? .1
                                                        : -.1) *
                                                    defeat,
                                          child: Opacity(
                                            opacity: 1 - defeat * .38,
                                            child: Semantics(
                                              label:
                                                  '${loser.name} king is checkmated',
                                              child: appearance == null
                                                  ? Center(
                                                      child: FittedBox(
                                                        child: Text(
                                                          loser == Side.white
                                                              ? '♔'
                                                              : '♚',
                                                          style: TextStyle(
                                                            color: accent,
                                                            fontSize: 260,
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                  : theme != null
                                                  ? NeonFigureSprite(
                                                      piece: Piece(
                                                        color: loser,
                                                        role: Role.king,
                                                      ),
                                                      theme: theme,
                                                    )
                                                  : CharacterPiece(
                                                      piece: Piece(
                                                        color: loser,
                                                        role: Role.king,
                                                      ),
                                                      pack: appearance.army(
                                                        loser,
                                                      ),
                                                      customSet:
                                                          appearance.customSet,
                                                      showRole: false,
                                                    ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Semantics(
                              liveRegion: true,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'CHECKMATE',
                                  key: const ValueKey(
                                    'checkmate-animation-title',
                                  ),
                                  style: TextStyle(
                                    color: accent,
                                    fontSize: 48,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 6,
                                    shadows: [
                                      Shadow(color: accent, blurRadius: 24),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '${widget.winner == Side.white ? 'White' : 'Black'} wins',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 25,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${loser == Side.white ? 'White' : 'Black'} king has no legal escape.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MateSealPainter extends CustomPainter {
  const _MateSealPainter({required this.progress, required this.accent});

  final double progress;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final extent = size.shortestSide * .43;
    final reveal = (progress / .35).clamp(0.0, 1.0);
    final paint = Paint()
      ..color = accent.withValues(alpha: .4 * reveal)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var ring = 0; ring < 3; ring++) {
      canvas.drawCircle(
        center,
        extent * (.72 + ring * .12) * (.86 + reveal * .14),
        paint,
      );
    }
    for (var ray = 0; ray < 12; ray++) {
      final angle = ray * math.pi / 6;
      final vector = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + vector * extent * .97,
        center + vector * extent * (1.05 + reveal * .08),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_MateSealPainter oldDelegate) =>
      progress != oldDelegate.progress || accent != oldDelegate.accent;
}
