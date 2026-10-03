// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

/// A touch-first colour picker: choose saturation/brightness in the large
/// rectangle, then move through the full hue range in the strip below it.
class ColorRangePicker extends StatelessWidget {
  const ColorRangePicker({
    required this.value,
    required this.onChanged,
    this.height = 170,
    super.key,
  });

  final HSVColor value;
  final ValueChanged<HSVColor> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        label: 'Colour saturation and brightness',
        child: Builder(
          builder: (fieldContext) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => _setSaturationValue(
              details.localPosition,
              fieldContext.size?.width ?? 0,
            ),
            onPanStart: (details) => _setSaturationValue(
              details.localPosition,
              fieldContext.size?.width ?? 0,
            ),
            onPanUpdate: (details) => _setSaturationValue(
              details.localPosition,
              fieldContext.size?.width ?? 0,
            ),
            child: SizedBox(
              height: height,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CustomPaint(painter: _SaturationValuePainter(value)),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Semantics(
        label: 'Colour hue',
        child: Builder(
          builder: (hueContext) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) =>
                _setHue(details.localPosition.dx, hueContext.size?.width ?? 0),
            onPanStart: (details) =>
                _setHue(details.localPosition.dx, hueContext.size?.width ?? 0),
            onPanUpdate: (details) =>
                _setHue(details.localPosition.dx, hueContext.size?.width ?? 0),
            child: SizedBox(
              height: 30,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CustomPaint(painter: _HuePainter(value.hue)),
              ),
            ),
          ),
        ),
      ),
    ],
  );

  void _setSaturationValue(Offset point, double width) {
    if (width <= 0 || height <= 0) return;
    onChanged(
      value
          .withSaturation((point.dx / width).clamp(0, 1))
          .withValue((1 - point.dy / height).clamp(0, 1)),
    );
  }

  void _setHue(double x, double width) {
    if (width <= 0) return;
    onChanged(value.withHue((x / width).clamp(0, 1) * 360));
  }
}

class _SaturationValuePainter extends CustomPainter {
  const _SaturationValuePainter(this.value);
  final HSVColor value;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white,
            HSVColor.fromAHSV(1, value.hue, 1, 1).toColor(),
          ],
        ).createShader(bounds),
    );
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
        ).createShader(bounds),
    );
    final selected = Offset(
      value.saturation * size.width,
      (1 - value.value) * size.height,
    );
    canvas.drawCircle(selected, 8, Paint()..color = Colors.black54);
    canvas.drawCircle(
      selected,
      6,
      Paint()
        ..color = Colors.transparent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_SaturationValuePainter oldDelegate) =>
      oldDelegate.value != value;
}

class _HuePainter extends CustomPainter {
  const _HuePainter(this.hue);
  final double hue;

  static const colours = [
    Color(0xFFFF0000),
    Color(0xFFFFFF00),
    Color(0xFF00FF00),
    Color(0xFF00FFFF),
    Color(0xFF0000FF),
    Color(0xFFFF00FF),
    Color(0xFFFF0000),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(colors: colours).createShader(bounds),
    );
    final x = (hue / 360).clamp(0, 1) * size.width;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, size.height / 2),
          width: 7,
          height: size.height,
        ),
        const Radius.circular(4),
      ),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_HuePainter oldDelegate) => oldDelegate.hue != hue;
}
