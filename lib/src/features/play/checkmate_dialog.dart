import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/game_result_analysis.dart';

Future<bool> showCheckmateDialog({
  required BuildContext context,
  required bool userWon,
  required String title,
  required GameResultMessage message,
}) async {
  return await showGeneralDialog<bool>(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'Checkmate result',
        barrierColor: Colors.black87,
        transitionDuration: const Duration(milliseconds: 650),
        pageBuilder: (context, animation, secondaryAnimation) =>
            _CheckmateDialog(userWon: userWon, title: title, message: message),
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
}

class _CheckmateDialog extends StatefulWidget {
  const _CheckmateDialog({
    required this.userWon,
    required this.title,
    required this.message,
  });

  final bool userWon;
  final String title;
  final GameResultMessage message;

  @override
  State<_CheckmateDialog> createState() => _CheckmateDialogState();
}

class _CheckmateDialogState extends State<_CheckmateDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.userWon
        ? const Color(0xFFFFD166)
        : const Color(0xFFE75A7C);
    final secondary = widget.userWon
        ? const Color(0xFF55E6A5)
        : const Color(0xFF8A6BFF);
    return SafeArea(
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Container(
            width: math.min(MediaQuery.sizeOf(context).width - 32, 470),
            constraints: BoxConstraints(
              maxHeight: math.max(MediaQuery.sizeOf(context).height - 32, 220),
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
                  color: primary.withValues(
                    alpha: .28 + _controller.value * .2,
                  ),
                  blurRadius: 28 + _controller.value * 16,
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
                            celebratory: widget.userWon,
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
                            scale: 1 + _controller.value * .08,
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
                                widget.userWon
                                    ? Icons.emoji_events
                                    : Icons.smart_toy,
                                size: 48,
                                color: const Color(0xFF171020),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'CHECKMATE',
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
                                  onPressed: () => Navigator.pop(context, true),
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
    );
  }
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
