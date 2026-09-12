import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/game_result_analysis.dart';

enum GameResultOutcome { victory, defeat, draw }

Future<bool> showCheckmateDialog({
  required BuildContext context,
  required bool userWon,
  required String title,
  required GameResultMessage message,
}) => showGameResultDialog(
  context: context,
  outcome: userWon ? GameResultOutcome.victory : GameResultOutcome.defeat,
  heading: 'CHECKMATE',
  title: title,
  message: message,
);

Future<bool> showGameResultDialog({
  required BuildContext context,
  required GameResultOutcome outcome,
  required String heading,
  required String title,
  required GameResultMessage message,
}) async =>
    await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Game result',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 650),
      pageBuilder: (context, animation, secondaryAnimation) => _ResultDialog(
        outcome: outcome,
        heading: heading,
        title: title,
        message: message,
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: curved, child: child),
        );
      },
    ) ??
    false;

class _ResultDialog extends StatefulWidget {
  const _ResultDialog({
    required this.outcome,
    required this.heading,
    required this.title,
    required this.message,
  });

  final GameResultOutcome outcome;
  final String heading;
  final String title;
  final GameResultMessage message;

  @override
  State<_ResultDialog> createState() => _ResultDialogState();
}

class _ResultDialogState extends State<_ResultDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final victory = widget.outcome == GameResultOutcome.victory;
    final primary = switch (widget.outcome) {
      GameResultOutcome.victory => const Color(0xFFFFD166),
      GameResultOutcome.defeat => const Color(0xFFE75A7C),
      GameResultOutcome.draw => const Color(0xFF77D5FF),
    };
    final secondary = switch (widget.outcome) {
      GameResultOutcome.victory => const Color(0xFF55E6A5),
      GameResultOutcome.defeat => const Color(0xFF8A6BFF),
      GameResultOutcome.draw => const Color(0xFFA98BFF),
    };
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse = (math.sin(_controller.value * math.pi * 2) + 1) / 2;
        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 1.15,
                      colors: [
                        primary.withValues(alpha: victory ? .22 : .09),
                        const Color(0xFF07050D).withValues(alpha: .94),
                      ],
                    ),
                  ),
                  child: CustomPaint(
                    key: const ValueKey('result-atmosphere'),
                    painter: _CelebrationAtmospherePainter(
                      progress: _controller.value,
                      color: primary,
                      celebratory: victory,
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: Container(
                  width: math.min(MediaQuery.sizeOf(context).width - 32, 470),
                  constraints: BoxConstraints(
                    maxHeight: math.max(
                      MediaQuery.sizeOf(context).height - 32,
                      220,
                    ),
                  ),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF201834), Color(0xFF090711)],
                    ),
                    border: Border.all(color: primary, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: .28 + pulse * .18),
                        blurRadius: 28 + pulse * 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: SingleChildScrollView(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _ResultBurstPainter(
                                  progress: _controller.value,
                                  color: primary,
                                  celebratory: victory,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Transform.scale(
                                  scale: 1 + pulse * .05,
                                  child: Container(
                                    width: 82,
                                    height: 82,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [primary, secondary],
                                      ),
                                    ),
                                    child: Icon(
                                      switch (widget.outcome) {
                                        GameResultOutcome.victory =>
                                          Icons.emoji_events,
                                        GameResultOutcome.defeat =>
                                          Icons.shield,
                                        GameResultOutcome.draw =>
                                          Icons.handshake,
                                      },
                                      size: 48,
                                      color: const Color(0xFF171020),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  widget.heading,
                                  key: const ValueKey('checkmate-heading'),
                                  style: TextStyle(
                                    color: primary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.title,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 27,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  widget.message.sentiment,
                                  key: const ValueKey('result-sentiment'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  widget.message.comment,
                                  key: const ValueKey('result-analysis'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Review Board'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        icon: const Icon(Icons.refresh),
                                        label: const Text('New Game'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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
        );
      },
    );
  }
}

class _CelebrationAtmospherePainter extends CustomPainter {
  const _CelebrationAtmospherePainter({
    required this.progress,
    required this.color,
    required this.celebratory,
  });

  final double progress;
  final Color color;
  final bool celebratory;

  @override
  void paint(Canvas canvas, Size size) {
    if (!celebratory) return;
    final paint = Paint();
    for (var index = 0; index < 44; index++) {
      final seed = (index * 37 % 101) / 101;
      final x = (index * 71 % 97) / 97 * size.width;
      final y = (seed + progress * (.35 + (index % 5) * .06)) % 1;
      final drift = math.sin(progress * math.pi * 2 + index) * 12;
      paint.color = (index.isEven ? color : const Color(0xFF55E6A5)).withValues(
        alpha: .38 + (index % 3) * .12,
      );
      canvas.save();
      canvas.translate(x + drift, y * size.height);
      canvas.rotate(progress * math.pi * 2 + index);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: 4 + (index % 3) * 2,
            height: 9 + (index % 4) * 2,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_CelebrationAtmospherePainter oldDelegate) =>
      progress != oldDelegate.progress ||
      color != oldDelegate.color ||
      celebratory != oldDelegate.celebratory;
}

class _ResultBurstPainter extends CustomPainter {
  const _ResultBurstPainter({
    required this.progress,
    required this.color,
    required this.celebratory,
  });

  final double progress;
  final Color color;
  final bool celebratory;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeCap = StrokeCap.round;
    final centre = Offset(size.width / 2, 66);
    final rays = celebratory ? 18 : 10;
    for (var i = 0; i < rays; i++) {
      final angle = i * math.pi * 2 / rays + progress * .2;
      final inner = 53 + math.sin(progress * math.pi) * 5;
      final outer = inner + (celebratory ? 22 : 12);
      paint
        ..color = color.withValues(alpha: celebratory ? .28 : .17)
        ..strokeWidth = celebratory ? 3 : 2;
      canvas.drawLine(
        centre + Offset(math.cos(angle), math.sin(angle)) * inner,
        centre + Offset(math.cos(angle), math.sin(angle)) * outer,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ResultBurstPainter oldDelegate) =>
      progress != oldDelegate.progress || color != oldDelegate.color;
}
