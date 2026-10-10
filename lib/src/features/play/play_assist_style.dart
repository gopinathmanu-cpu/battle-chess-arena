// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

const moveSuggestionIconColor = Color(0xFFFFC928);
const threatIconColor = Color(0xFFFF5252);
const _iconSurface = Color(0xFF2F3E63);
const _assistInk = Color(0xFF223149);
const _disabledInk = Color(0xFF4A5871);

class MoveSuggestionIcon extends StatelessWidget {
  const MoveSuggestionIcon({this.size, super.key});

  final double? size;

  @override
  Widget build(BuildContext context) {
    final iconSize = size ?? IconTheme.of(context).size ?? 24;
    return Container(
      width: iconSize + 10,
      height: iconSize + 10,
      decoration: BoxDecoration(
        color: _iconSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: moveSuggestionIconColor, width: 1.4),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.lightbulb_rounded,
            key: const ValueKey('move-suggestion-icon'),
            size: iconSize,
            color: moveSuggestionIconColor,
          ),
          CustomPaint(
            key: const ValueKey('move-suggestion-rays'),
            size: Size.square(iconSize + 4),
            painter: const _LightRayPainter(),
          ),
        ],
      ),
    );
  }
}

class _LightRayPainter extends CustomPainter {
  const _LightRayPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height * .43);
    final inner = size.shortestSide * .38;
    final outer = size.shortestSide * .49;
    final paint = Paint()
      ..color = moveSuggestionIconColor
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    for (final angle in [-2.72, -2.20, -1.57, -.94, -.42]) {
      canvas.drawLine(
        centre + Offset.fromDirection(angle, inner),
        centre + Offset.fromDirection(angle, outer),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_LightRayPainter oldDelegate) => false;
}

class ThreatActionIcon extends StatelessWidget {
  const ThreatActionIcon({this.size, super.key});

  final double? size;

  @override
  Widget build(BuildContext context) {
    final iconSize = size ?? IconTheme.of(context).size ?? 24;
    return Container(
      width: iconSize + 10,
      height: iconSize + 10,
      decoration: BoxDecoration(
        color: _iconSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: threatIconColor, width: 1.4),
      ),
      child: Icon(
        Icons.radar_rounded,
        key: const ValueKey('threat-action-icon'),
        size: iconSize,
        color: threatIconColor,
      ),
    );
  }
}

// Keep both assist labels at the same readable size. Let long labels wrap
// instead of shrinking one button's text independently of the other.
final playAssistButtonStyle = ButtonStyle(
  backgroundColor: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.disabled)) return const Color(0xFFCCD3DF);
    if (states.contains(WidgetState.pressed)) return const Color(0xFFC6D6EC);
    if (states.contains(WidgetState.hovered) ||
        states.contains(WidgetState.focused)) {
      return const Color(0xFFD3DFF0);
    }
    return const Color(0xFFE2EAF4);
  }),
  foregroundColor: WidgetStateProperty.resolveWith(
    (states) =>
        states.contains(WidgetState.disabled) ? _disabledInk : _assistInk,
  ),
  iconColor: WidgetStateProperty.resolveWith(
    (states) =>
        states.contains(WidgetState.disabled) ? _disabledInk : _assistInk,
  ),
  overlayColor: const WidgetStatePropertyAll(Color(0x10223149)),
  surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
  side: WidgetStateProperty.resolveWith(
    (states) => BorderSide(
      color: states.contains(WidgetState.disabled)
          ? const Color(0xFFAAB8CC)
          : const Color(0xFF8DA1BD),
    ),
  ),
  backgroundBuilder: _assistProgressTheme,
  textStyle: const WidgetStatePropertyAll(
    TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
  ),
  padding: const WidgetStatePropertyAll(
    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
  ),
  minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
  iconSize: const WidgetStatePropertyAll(18),
);

Widget _assistProgressTheme(
  BuildContext context,
  Set<WidgetState> states,
  Widget? child,
) => ProgressIndicatorTheme(
  data: ProgressIndicatorTheme.of(context).copyWith(
    color: states.contains(WidgetState.disabled) ? _disabledInk : _assistInk,
  ),
  child: child ?? const SizedBox.shrink(),
);
