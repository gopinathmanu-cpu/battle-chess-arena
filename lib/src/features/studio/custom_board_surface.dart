// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/custom_chess_set.dart';

/// Light, deterministic ornamentation over the user's chosen square colours.
class CustomBoardSurfacePainter extends CustomPainter {
  const CustomBoardSurfacePainter(this.surface);
  final CustomBoardSurface surface;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7;
    switch (surface) {
      case CustomBoardSurface.solid:
        return;
      case CustomBoardSurface.wood:
        stroke.color = Colors.black.withValues(alpha: .12);
        for (var row = 1; row < 9; row++) {
          final path = Path()..moveTo(0, size.height * row / 9);
          for (var x = 1; x <= 20; x++) {
            path.lineTo(
              size.width * x / 20,
              size.height * (row / 9 + math.sin(x * .35 + row) * .018),
            );
          }
          canvas.drawPath(path, stroke);
        }
      case CustomBoardSurface.marble:
        stroke.color = Colors.white.withValues(alpha: .19);
        for (var i = 0; i < 3; i++) {
          final y = size.height * i / 3;
          canvas.drawPath(
            Path()
              ..moveTo(0, y)
              ..cubicTo(
                size.width * .3,
                y + size.height * .25,
                size.width * .7,
                y - size.height * .14,
                size.width,
                y + size.height * .25,
              ),
            stroke,
          );
        }
      case CustomBoardSurface.neon:
        stroke.color = Colors.cyanAccent.withValues(alpha: .4);
        canvas.drawRect((Offset.zero & size).deflate(2), stroke);
    }
  }

  @override
  bool shouldRepaint(CustomBoardSurfacePainter oldDelegate) =>
      oldDelegate.surface != surface;
}
