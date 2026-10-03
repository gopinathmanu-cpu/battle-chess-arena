// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/custom_avatar.dart';

/// A resolution-independent portrait assembled from editable vector layers.
/// Colours and parts are independent: selecting age or presentation never
/// changes a person's selected hair, skin tone, clothing or accessories.
class CustomAvatarPortrait extends StatelessWidget {
  const CustomAvatarPortrait({
    required this.design,
    this.size = 120,
    super.key,
  });

  final CustomAvatarDesign design;
  final double size;

  static const skinTones = <Color>[
    Color(0xFFFFE4D2),
    Color(0xFFF4C8A4),
    Color(0xFFE4AE87),
    Color(0xFFCC906B),
    Color(0xFFB97B53),
    Color(0xFF95603F),
    Color(0xFF70452F),
    Color(0xFF4E3025),
  ];
  static const hairColors = <Color>[
    Color(0xFF202027),
    Color(0xFF3A2927),
    Color(0xFF64442F),
    Color(0xFF8D5638),
    Color(0xFFAD4D36),
    Color(0xFFD7AF64),
    Color(0xFF9DA5B0),
    Color(0xFFE9E7DF),
    Color(0xFF365B86),
    Color(0xFF775181),
  ];
  static const outfitColors = <Color>[
    Color(0xFF334D70),
    Color(0xFF278B89),
    Color(0xFF944D65),
    Color(0xFF557957),
    Color(0xFFC9953A),
    Color(0xFF7D62A5),
    Color(0xFFD87C67),
    Color(0xFF65747F),
  ];
  static const backgroundColors = <Color>[
    Color(0xFF243950),
    Color(0xFF92C9BB),
    Color(0xFFD9A3B1),
    Color(0xFFB5ACDA),
    Color(0xFFE4BB76),
    Color(0xFF95BCD8),
    Color(0xFF66897A),
    Color(0xFFD4C1A3),
  ];

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Custom avatar portrait',
    child: SizedBox.square(
      dimension: size,
      child: ClipOval(child: CustomPaint(painter: CustomAvatarPainter(design))),
    ),
  );
}

/// The design space is 100 x 100, with a fixed bust baseline and a circular
/// boundary. No image decoding, remote asset or atlas crop is involved.
class CustomAvatarPainter extends CustomPainter {
  const CustomAvatarPainter(this.design);
  final CustomAvatarDesign design;

  Color get _skin => CustomAvatarPortrait.skinTones[design.skinTone];
  Color get _hair => CustomAvatarPortrait.hairColors[design.hairColor];
  Color get _cloth => CustomAvatarPortrait.outfitColors[design.outfitColor];
  Color get _background =>
      CustomAvatarPortrait.backgroundColors[design.background];
  bool get _feminine => design.presentation == 1;
  bool get _child => design.age == 0;
  double get _chin => switch (design.age) {
    0 => 68,
    1 => 72,
    3 => 75,
    _ => 74,
  };
  double get _eyeY => _child ? 46 : 47;
  double get _left => _child ? 27 : (design.age == 1 ? 30 : 29);
  double get _right => 100 - _left;

  Color _light(Color color, double amount) =>
      Color.lerp(color, Colors.white, amount)!;
  Color _dark(Color color, double amount) =>
      Color.lerp(color, Colors.black, amount)!;
  Paint _paint(Color color) => Paint()..color = color;
  Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Paint _gradient(
    Color color,
    Rect bounds, {
    double light = .12,
    double dark = .16,
  }) => Paint()
    ..shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_light(color, light), color, _dark(color, dark)],
      stops: const [0, .5, 1],
    ).createShader(bounds);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    final extent = size.shortestSide;
    canvas.translate((size.width - extent) / 2, (size.height - extent) / 2);
    canvas.scale(extent / 100);
    canvas.clipPath(Path()..addOval(const Rect.fromLTWH(0, 0, 100, 100)));
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 100, 100),
      _gradient(
        _background,
        const Rect.fromLTWH(0, 0, 100, 100),
        light: .11,
        dark: .1,
      ),
    );
    canvas.drawCircle(
      const Offset(22, 18),
      39,
      _paint(Colors.white.withValues(alpha: .065)),
    );
    canvas.drawCircle(
      const Offset(85, 87),
      37,
      _paint(Colors.white.withValues(alpha: .05)),
    );
    _backHair(canvas);
    canvas.save();
    if (_child) canvas.translate(0, -3);
    _neckAndOutfit(canvas);
    canvas.restore();
    _ears(canvas);
    final face = _facePath();
    canvas.drawPath(
      face,
      _gradient(
        _skin,
        Rect.fromLTRB(_left, 23, _right, _chin),
        light: .12,
        dark: .08,
      ),
    );
    canvas.save();
    canvas.clipPath(face);
    canvas.drawOval(
      Rect.fromLTWH(_left + 3, 38, 12, 25),
      _paint(Colors.white.withValues(alpha: .055)),
    );
    final cheek = Color.lerp(
      _skin,
      const Color(0xFFE07173),
      _child ? .24 : (design.age == 1 ? .16 : .11),
    )!;
    canvas.drawOval(
      const Rect.fromLTWH(31, 53, 10, 5),
      _paint(cheek.withValues(alpha: .45)),
    );
    canvas.drawOval(
      const Rect.fromLTWH(59, 53, 10, 5),
      _paint(cheek.withValues(alpha: .3)),
    );
    canvas.restore();
    _frontHair(canvas);
    _features(canvas);
    _facialHair(canvas);
    _glasses(canvas);
    canvas.restore();
  }

  Path _facePath() {
    final l = _left;
    final r = _right;
    final b = _chin;
    return switch (design.face) {
      1 =>
        Path()
          ..moveTo(50, 23)
          ..cubicTo(l - 1, 21, l - 5, 34, l - 1, 51)
          ..cubicTo(l, b - 5, 39, b, 50, b)
          ..cubicTo(61, b, r, b - 5, r + 1, 51)
          ..cubicTo(r + 5, 34, r + 1, 21, 50, 23)
          ..close(),
      2 =>
        Path()
          ..moveTo(50, 22)
          ..cubicTo(l + 1, 22, l - 1, 28, l, 47)
          ..lineTo(l + 3, b - 10)
          ..quadraticBezierTo(l + 4, b - 3, 43, b - 1)
          ..quadraticBezierTo(50, b + 1, 57, b - 1)
          ..quadraticBezierTo(r - 4, b - 3, r - 3, b - 10)
          ..lineTo(r, 47)
          ..cubicTo(r + 1, 28, r - 1, 22, 50, 22)
          ..close(),
      3 =>
        Path()
          ..moveTo(50, 24)
          ..cubicTo(l - 4, 19, l - 3, 32, l, 49)
          ..cubicTo(l + 2, 60, 42, b - 1, 50, b + 1)
          ..cubicTo(58, b - 1, r - 2, 60, r, 49)
          ..cubicTo(r + 3, 32, r + 4, 19, 50, 24)
          ..close(),
      _ =>
        Path()
          ..moveTo(50, 22)
          ..cubicTo(l + 1, 21, l - 3, 33, l + 1, 51)
          ..cubicTo(l + 2, b - 10, 39, b, 50, b)
          ..cubicTo(61, b, r - 2, b - 10, r - 1, 51)
          ..cubicTo(r + 3, 33, r - 1, 21, 50, 22)
          ..close(),
    };
  }

  void _neckAndOutfit(Canvas canvas) {
    final neck = Path()
      ..moveTo(42, 65)
      ..lineTo(58, 65)
      ..lineTo(58, 78)
      ..quadraticBezierTo(60, 82, 64, 83)
      ..quadraticBezierTo(50, 95, 36, 83)
      ..quadraticBezierTo(42, 80, 42, 77)
      ..close();
    canvas.drawPath(
      neck,
      _gradient(
        _skin,
        const Rect.fromLTWH(40, 65, 20, 23),
        light: .02,
        dark: .12,
      ),
    );
    canvas.drawPath(
      Path()
        ..moveTo(42, 68)
        ..quadraticBezierTo(50, 77, 58, 68)
        ..lineTo(58, 75)
        ..quadraticBezierTo(50, 80, 42, 75)
        ..close(),
      _paint(_dark(_skin, .2).withValues(alpha: .48)),
    );
    final body = Path()
      ..moveTo(11, 106)
      ..cubicTo(12, 88, 26, 80, 40, 78)
      ..quadraticBezierTo(50, 89, 60, 78)
      ..cubicTo(75, 80, 88, 88, 89, 106)
      ..close();
    canvas.drawPath(
      body,
      _gradient(
        _cloth,
        const Rect.fromLTWH(15, 77, 74, 26),
        light: .09,
        dark: .14,
      ),
    );
    canvas.drawPath(
      Path()
        ..moveTo(25, 92)
        ..quadraticBezierTo(23, 98, 23, 106),
      _stroke(_dark(_cloth, .2).withValues(alpha: .45), 1),
    );
    canvas.drawPath(
      Path()
        ..moveTo(75, 92)
        ..quadraticBezierTo(78, 98, 78, 106),
      _stroke(_dark(_cloth, .2).withValues(alpha: .45), 1),
    );
    switch (design.outfit) {
      case 0:
        canvas.drawPath(
          Path()
            ..moveTo(40, 79)
            ..quadraticBezierTo(50, 91, 60, 79),
          _stroke(_dark(_cloth, .25), 2.2),
        );
        canvas.drawPath(
          Path()
            ..moveTo(41, 80)
            ..quadraticBezierTo(50, 90, 59, 80),
          _stroke(_light(_cloth, .21), .6),
        );
      case 1:
        final hood = Path()
          ..moveTo(31, 83)
          ..quadraticBezierTo(32, 72, 41, 76)
          ..lineTo(50, 85)
          ..lineTo(59, 76)
          ..quadraticBezierTo(68, 72, 69, 83)
          ..lineTo(60, 89)
          ..lineTo(50, 86)
          ..lineTo(40, 89)
          ..close();
        canvas.drawPath(hood, _paint(_light(_cloth, .11)));
        canvas.drawPath(
          Path()
            ..moveTo(35, 81)
            ..lineTo(43, 84)
            ..lineTo(49, 86)
            ..moveTo(65, 81)
            ..lineTo(57, 84)
            ..lineTo(51, 86),
          _stroke(_dark(_cloth, .3), 1.4),
        );
        for (final x in [43.0, 57.0]) {
          canvas.drawLine(
            Offset(x, 86),
            Offset(x + (x < 50 ? -1 : 1), 96),
            _stroke(const Color(0xFFDDE1E2), .8),
          );
          canvas.drawCircle(
            Offset(x + (x < 50 ? -1 : 1), 96),
            .8,
            _paint(const Color(0xFFBBC7CC)),
          );
        }
        canvas.drawPath(
          Path()
            ..moveTo(36, 101)
            ..lineTo(40, 96)
            ..lineTo(60, 96)
            ..lineTo(64, 101),
          _stroke(_dark(_cloth, .2), .8),
        );
      case 2:
        canvas.drawPath(
          Path()
            ..moveTo(41, 77)
            ..lineTo(50, 85)
            ..lineTo(43, 89)
            ..lineTo(34, 82)
            ..close(),
          _paint(_light(_cloth, .26)),
        );
        canvas.drawPath(
          Path()
            ..moveTo(59, 77)
            ..lineTo(50, 85)
            ..lineTo(57, 89)
            ..lineTo(66, 82)
            ..close(),
          _paint(_light(_cloth, .18)),
        );
        canvas.drawLine(
          const Offset(50, 85),
          const Offset(50, 104),
          _stroke(_dark(_cloth, .18), .9),
        );
        for (final y in [90.0, 97.0]) {
          canvas.drawCircle(
            Offset(51.5, y),
            .7,
            _paint(const Color(0xFFE1E4E6)),
          );
        }
      case 3:
        canvas.drawPath(
          Path()
            ..moveTo(42, 80)
            ..quadraticBezierTo(50, 87, 58, 80)
            ..lineTo(60, 106)
            ..lineTo(40, 106)
            ..close(),
          _paint(const Color(0xFFE7E2DA)),
        );
        canvas.drawPath(
          Path()
            ..moveTo(38, 78)
            ..lineTo(48, 89)
            ..lineTo(42, 93)
            ..lineTo(46, 97)
            ..lineTo(39, 106)
            ..lineTo(31, 87)
            ..close(),
          _paint(_light(_cloth, .12)),
        );
        canvas.drawPath(
          Path()
            ..moveTo(62, 78)
            ..lineTo(52, 89)
            ..lineTo(58, 93)
            ..lineTo(54, 97)
            ..lineTo(61, 106)
            ..lineTo(69, 87)
            ..close(),
          _paint(_light(_cloth, .07)),
        );
        canvas.drawCircle(
          const Offset(58, 99),
          .9,
          _paint(const Color(0xFFD8C29A)),
        );
      case 4:
        canvas.drawPath(
          Path()
            ..moveTo(42, 78)
            ..quadraticBezierTo(50, 84, 58, 78)
            ..lineTo(58, 83)
            ..quadraticBezierTo(50, 88, 42, 83)
            ..close(),
          _paint(_light(_cloth, .2)),
        );
        canvas.drawLine(
          const Offset(50, 85),
          const Offset(50, 104),
          _stroke(_light(_cloth, .2), 1.5),
        );
        for (final y in [88.0, 94.0, 100.0]) {
          canvas.drawCircle(Offset(52, y), .8, _paint(const Color(0xFFE6C384)));
        }
        canvas.drawLine(
          const Offset(33, 89),
          const Offset(33, 97),
          _stroke(_light(_cloth, .18), .7),
        );
      case 5:
        canvas.drawPath(
          Path()
            ..moveTo(40, 78)
            ..lineTo(50, 91)
            ..lineTo(60, 78)
            ..lineTo(55, 79)
            ..lineTo(50, 86)
            ..lineTo(45, 79)
            ..close(),
          _paint(_skin),
        );
        canvas.drawPath(
          Path()
            ..moveTo(40, 79)
            ..lineTo(50, 92)
            ..lineTo(60, 79),
          _stroke(_light(_cloth, .22), .9),
        );
        canvas.drawPath(
          Path()
            ..moveTo(43, 78)
            ..quadraticBezierTo(50, 86, 57, 78),
          _stroke(const Color(0xFFE7C88B), .7),
        );
        canvas.drawCircle(
          const Offset(50, 83),
          1.1,
          _paint(const Color(0xFFE8C580)),
        );
    }
  }

  void _ears(Canvas canvas) {
    for (final left in [true, false]) {
      final x = left ? _left - 3 : _right - 4;
      canvas.drawOval(Rect.fromLTWH(x, 43, 7, 14), _paint(_dark(_skin, .05)));
      final inner = Path()
        ..moveTo(x + (left ? 4.5 : 2.5), 46)
        ..quadraticBezierTo(x + (left ? 1 : 6), 44, x + (left ? 2 : 5), 51)
        ..quadraticBezierTo(x + 3.5, 49, x + 3.5, 54);
      canvas.drawPath(
        inner,
        _stroke(_dark(_skin, .25).withValues(alpha: .6), .8),
      );
    }
  }

  Path _cap() => Path()
    ..moveTo(27, 49)
    ..cubicTo(20, 21, 35, 13, 51, 16)
    ..cubicTo(72, 13, 80, 32, 72, 51)
    ..lineTo(67, 45)
    ..lineTo(33, 45)
    ..close();

  void _backHair(Canvas canvas) {
    final paint = _gradient(
      _hair,
      const Rect.fromLTWH(18, 10, 65, 83),
      light: .12,
      dark: .22,
    );
    switch (design.hairStyle) {
      case 0:
        return;
      case 5:
        for (final (x, y, radius) in [
          (29.0, 28.0, 13.0),
          (40.0, 20.0, 14.0),
          (56.0, 19.0, 15.0),
          (69.0, 27.0, 13.0),
          (76.0, 40.0, 12.0),
          (71.0, 53.0, 11.0),
          (26.0, 52.0, 11.0),
          (22.0, 39.0, 12.0),
        ]) {
          canvas.drawCircle(Offset(x, y), radius, paint);
        }
        canvas.drawPath(_cap(), paint);
      case 6:
        canvas.drawPath(
          Path()
            ..moveTo(23, 76)
            ..lineTo(24, 37)
            ..cubicTo(22, 9, 79, 8, 77, 38)
            ..lineTo(78, 76)
            ..quadraticBezierTo(69, 80, 57, 74)
            ..lineTo(42, 74)
            ..quadraticBezierTo(32, 80, 23, 76)
            ..close(),
          paint,
        );
      case 7:
        canvas.drawPath(
          Path()
            ..moveTo(19, 89)
            ..quadraticBezierTo(25, 70, 24, 39)
            ..cubicTo(22, 9, 79, 8, 77, 39)
            ..quadraticBezierTo(76, 71, 82, 89)
            ..quadraticBezierTo(68, 95, 58, 85)
            ..lineTo(42, 85)
            ..quadraticBezierTo(30, 94, 19, 89)
            ..close(),
          paint,
        );
      case 8:
        canvas.drawPath(
          Path()
            ..moveTo(27, 28)
            ..cubicTo(26, 12, 71, 10, 76, 29)
            ..cubicTo(81, 39, 75, 46, 80, 54)
            ..cubicTo(91, 69, 75, 70, 80, 82)
            ..cubicTo(77, 93, 59, 88, 55, 80)
            ..lineTo(44, 80)
            ..cubicTo(26, 94, 16, 80, 22, 70)
            ..cubicTo(14, 58, 25, 50, 21, 41)
            ..quadraticBezierTo(20, 33, 27, 28)
            ..close(),
          paint,
        );
      case 9:
        canvas.drawPath(_cap(), paint);
        _braid(canvas, 25, paint);
        _braid(canvas, 75, paint);
      case 10:
        canvas.drawCircle(const Offset(51, 15), 11, paint);
        canvas.drawOval(
          const Rect.fromLTWH(40, 9, 21, 12),
          _stroke(_light(_hair, .2).withValues(alpha: .5), .8),
        );
        canvas.drawPath(_cap(), paint);
      case 11:
        canvas.drawPath(
          Path()
            ..moveTo(68, 29)
            ..cubicTo(90, 22, 78, 61, 88, 77)
            ..cubicTo(62, 74, 78, 45, 65, 42)
            ..close(),
          paint,
        );
        canvas.drawPath(
          Path()
            ..moveTo(75, 38)
            ..quadraticBezierTo(73, 62, 81, 72),
          _stroke(_light(_hair, .18), 1),
        );
        canvas.drawPath(_cap(), paint);
      default:
        canvas.drawPath(_cap(), paint);
    }
  }

  void _braid(Canvas canvas, double x, Paint paint) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 4, 36, 8, 45),
        const Radius.circular(4),
      ),
      paint,
    );
    for (var i = 0; i < 8; i++) {
      final y = 39.0 + i * 5;
      final left = Path()
        ..moveTo(x, y - 2)
        ..quadraticBezierTo(x - 7, y, x - 1, y + 5)
        ..quadraticBezierTo(x + 2, y + 2, x, y - 2)
        ..close();
      canvas.drawPath(left, _paint(_light(_hair, .08)));
      canvas.drawPath(
        Path()
          ..moveTo(x, y)
          ..quadraticBezierTo(x + 7, y + 1, x + 1, y + 6)
          ..quadraticBezierTo(x - 2, y + 3, x, y)
          ..close(),
        _paint(_dark(_hair, .08)),
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 3.6, 79, 7.2, 2.5),
        const Radius.circular(1),
      ),
      _paint(const Color(0xFFD8AD68)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(x - 3, 82)
        ..lineTo(x - 2, 87)
        ..lineTo(x + 3, 87)
        ..lineTo(x + 3, 82)
        ..close(),
      paint,
    );
  }

  void _frontHair(Canvas canvas) {
    final paint = _gradient(
      _hair,
      const Rect.fromLTWH(24, 12, 52, 52),
      light: .1,
      dark: .12,
    );
    final shine = _stroke(_light(_hair, .22).withValues(alpha: .6), .9);
    switch (design.hairStyle) {
      case 0:
        canvas.save();
        canvas.clipPath(_facePath());
        canvas.drawPath(
          Path()
            ..moveTo(26, 38)
            ..quadraticBezierTo(27, 15, 51, 18)
            ..quadraticBezierTo(73, 18, 74, 37)
            ..lineTo(68, 31)
            ..quadraticBezierTo(50, 25, 32, 32)
            ..close(),
          _paint(_hair.withValues(alpha: .23)),
        );
        for (var i = 0; i < 18; i++) {
          final x = 31.0 + i * 2.2;
          final y = 25.5 + math.pow((x - 50) / 15, 2) * 2;
          canvas.drawCircle(
            Offset(x, y),
            .36,
            _paint(_hair.withValues(alpha: .24)),
          );
        }
        canvas.restore();
      case 1:
        canvas.drawPath(
          Path()
            ..moveTo(28, 45)
            ..lineTo(26, 33)
            ..quadraticBezierTo(26, 16, 50, 18)
            ..quadraticBezierTo(75, 16, 73, 34)
            ..lineTo(70, 45)
            ..lineTo(67, 32)
            ..quadraticBezierTo(50, 29, 32, 33)
            ..lineTo(31, 44)
            ..close(),
          paint,
        );
        for (var i = 0; i < 12; i++) {
          final x = 30.0 + i * 3.5;
          canvas.drawLine(Offset(x, 25), Offset(x + 1.5, 29), shine);
        }
      case 2:
        canvas.drawPath(
          Path()
            ..moveTo(28, 45)
            ..cubicTo(19, 23, 38, 10, 60, 18)
            ..cubicTo(76, 18, 78, 30, 71, 45)
            ..lineTo(67, 33)
            ..quadraticBezierTo(60, 26, 55, 27)
            ..quadraticBezierTo(41, 38, 30, 35)
            ..lineTo(31, 45)
            ..close(),
          paint,
        );
        canvas.drawPath(
          Path()
            ..moveTo(57, 23)
            ..quadraticBezierTo(42, 34, 29, 31),
          shine,
        );
        canvas.drawPath(
          Path()
            ..moveTo(58, 22)
            ..quadraticBezierTo(70, 25, 71, 36),
          shine,
        );
      case 3:
        canvas.drawPath(
          Path()
            ..moveTo(27, 43)
            ..cubicTo(22, 30, 28, 20, 39, 18)
            ..cubicTo(45, 12, 59, 15, 61, 8)
            ..cubicTo(76, 15, 77, 29, 71, 43)
            ..lineTo(67, 32)
            ..quadraticBezierTo(47, 38, 32, 31)
            ..lineTo(31, 43)
            ..close(),
          paint,
        );
        canvas.drawPath(
          Path()
            ..moveTo(33, 27)
            ..cubicTo(45, 29, 65, 27, 65, 16),
          shine,
        );
        canvas.drawPath(
          Path()
            ..moveTo(36, 23)
            ..quadraticBezierTo(52, 24, 58, 17),
          shine,
        );
      case 4:
        canvas.drawPath(
          Path()
            ..moveTo(27, 43)
            ..lineTo(25, 29)
            ..quadraticBezierTo(48, 11, 74, 29)
            ..lineTo(72, 44)
            ..lineTo(68, 34)
            ..quadraticBezierTo(50, 31, 31, 35)
            ..lineTo(31, 44)
            ..close(),
          paint,
        );
        for (final (x, y, r) in [
          (29.0, 29.0, 5.0),
          (36.0, 24.0, 6.0),
          (45.0, 22.0, 6.2),
          (54.0, 23.0, 6.5),
          (63.0, 25.0, 6.0),
          (70.0, 31.0, 5.3),
          (39.0, 30.0, 4.2),
          (51.0, 29.0, 4.7),
          (61.0, 31.0, 4.0),
        ]) {
          canvas.drawCircle(Offset(x, y), r, paint);
          canvas.drawArc(
            Rect.fromCircle(center: Offset(x, y), radius: r * .7),
            -2.5,
            1.6,
            false,
            shine,
          );
        }
      case 5:
        canvas.drawPath(
          Path()
            ..moveTo(27, 44)
            ..quadraticBezierTo(23, 27, 34, 28)
            ..quadraticBezierTo(38, 21, 45, 26)
            ..quadraticBezierTo(50, 20, 56, 26)
            ..quadraticBezierTo(65, 21, 69, 30)
            ..quadraticBezierTo(77, 32, 72, 46)
            ..lineTo(69, 39)
            ..quadraticBezierTo(65, 29, 60, 31)
            ..quadraticBezierTo(50, 26, 39, 32)
            ..quadraticBezierTo(32, 29, 31, 43)
            ..close(),
          paint,
        );
        for (final (x, y) in [
          (25.0, 28.0),
          (37.0, 18.0),
          (54.0, 14.0),
          (68.0, 23.0),
          (78.0, 37.0),
        ]) {
          canvas.drawArc(
            Rect.fromCircle(center: Offset(x, y), radius: 5),
            -2,
            1.5,
            false,
            shine,
          );
        }
      case 6:
        canvas.drawPath(
          Path()
            ..moveTo(25, 73)
            ..lineTo(26, 32)
            ..cubicTo(27, 13, 68, 12, 74, 30)
            ..lineTo(75, 72)
            ..lineTo(67, 74)
            ..lineTo(68, 33)
            ..quadraticBezierTo(61, 29, 58, 25)
            ..quadraticBezierTo(44, 38, 32, 38)
            ..lineTo(33, 74)
            ..close(),
          paint,
        );
        canvas.drawPath(
          Path()
            ..moveTo(58, 21)
            ..quadraticBezierTo(43, 33, 29, 34)
            ..lineTo(29, 69),
          shine,
        );
        canvas.drawPath(
          Path()
            ..moveTo(68, 28)
            ..quadraticBezierTo(72, 43, 71, 69),
          shine,
        );
      case 7:
        _partedHair(canvas, paint, shine);
        canvas.drawPath(
          Path()
            ..moveTo(28, 38)
            ..quadraticBezierTo(23, 67, 27, 85),
          shine,
        );
        canvas.drawPath(
          Path()
            ..moveTo(72, 38)
            ..quadraticBezierTo(76, 65, 73, 86),
          shine,
        );
      case 8:
        _partedHair(canvas, paint, shine);
        canvas.drawPath(
          Path()
            ..moveTo(28, 32)
            ..cubicTo(20, 46, 34, 51, 26, 62)
            ..quadraticBezierTo(19, 72, 27, 80),
          _stroke(_light(_hair, .16), 2),
        );
        canvas.drawPath(
          Path()
            ..moveTo(72, 34)
            ..cubicTo(79, 45, 68, 49, 76, 61)
            ..quadraticBezierTo(82, 71, 75, 82),
          _stroke(_light(_hair, .17), 2),
        );
      case 9:
        canvas.drawPath(
          Path()
            ..moveTo(27, 42)
            ..cubicTo(20, 16, 77, 9, 73, 43)
            ..lineTo(68, 34)
            ..quadraticBezierTo(52, 34, 50, 27)
            ..quadraticBezierTo(45, 33, 32, 35)
            ..lineTo(31, 44)
            ..close(),
          paint,
        );
        for (var i = 0; i < 5; i++) {
          canvas.drawPath(
            Path()
              ..moveTo(48 - i * 2, 19 + i * .7)
              ..quadraticBezierTo(38.0 - i, 23, 29.0 + i, 33 + i * .6),
            shine,
          );
          canvas.drawPath(
            Path()
              ..moveTo(52 + i * 2, 19 + i * .7)
              ..quadraticBezierTo(64.0 + i, 23, 71.0 - i, 33 + i * .6),
            shine,
          );
        }
      case 10:
        _pulledHair(canvas, paint, shine);
        canvas.drawArc(
          const Rect.fromLTWH(42, 20, 17, 8),
          .1,
          2.9,
          false,
          _stroke(const Color(0xFFD3B078), 1.3),
        );
      case 11:
        _pulledHair(canvas, paint, shine);
        canvas.drawCircle(const Offset(73, 34), 2, _paint(_light(_cloth, .15)));
    }
  }

  void _partedHair(Canvas canvas, Paint paint, Paint shine) {
    canvas.drawPath(
      Path()
        ..moveTo(25, 52)
        ..lineTo(25, 34)
        ..cubicTo(27, 12, 73, 11, 75, 35)
        ..lineTo(75, 54)
        ..lineTo(69, 46)
        ..lineTo(68, 34)
        ..quadraticBezierTo(54, 33, 50, 24)
        ..quadraticBezierTo(46, 33, 32, 34)
        ..lineTo(31, 46)
        ..close(),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(48, 21)
        ..quadraticBezierTo(44, 28, 30, 30),
      shine,
    );
    canvas.drawPath(
      Path()
        ..moveTo(53, 21)
        ..quadraticBezierTo(60, 27, 71, 31),
      shine,
    );
  }

  void _pulledHair(Canvas canvas, Paint paint, Paint shine) {
    canvas.drawPath(
      Path()
        ..moveTo(27, 45)
        ..cubicTo(20, 15, 79, 11, 73, 45)
        ..lineTo(68, 36)
        ..quadraticBezierTo(57, 30, 50, 25)
        ..quadraticBezierTo(43, 31, 32, 36)
        ..lineTo(31, 45)
        ..close(),
      paint,
    );
    for (final shift in [0.0, 4.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(47, 20 + shift)
          ..quadraticBezierTo(35, 23 + shift, 29, 32 + shift),
        shine,
      );
      canvas.drawPath(
        Path()
          ..moveTo(54, 20 + shift)
          ..quadraticBezierTo(65, 23 + shift, 71, 32 + shift),
        shine,
      );
    }
  }

  void _features(Canvas canvas) {
    final brow = _hair.computeLuminance() > .55 ? _dark(_hair, .48) : _hair;
    final eyeHeight = _child ? 6.5 : (design.age == 1 ? 5.5 : 4.5);
    final eyeWidth = _child ? 10.2 : (design.age == 1 ? 8.8 : 8.3);
    for (final x in [40.0, 60.0]) {
      final l = x - eyeWidth / 2;
      final r = x + eyeWidth / 2;
      final y = _eyeY;
      final eye = Path()
        ..moveTo(l, y)
        ..quadraticBezierTo(x, y - eyeHeight, r, y)
        ..quadraticBezierTo(x, y + eyeHeight * .65, l, y)
        ..close();
      canvas.drawPath(eye, _paint(const Color(0xFFF4EEE8)));
      canvas.save();
      canvas.clipPath(eye);
      canvas.drawCircle(
        Offset(x, y - .2),
        _child ? 2.65 : 2.1,
        _paint(const Color(0xFF574033)),
      );
      canvas.drawCircle(
        Offset(x, y - .2),
        _child ? 1.55 : 1.25,
        _paint(const Color(0xFF20232A)),
      );
      canvas.drawCircle(
        Offset(x - .6, y - 1),
        .7,
        _paint(Colors.white.withValues(alpha: .9)),
      );
      canvas.restore();
      canvas.drawPath(
        Path()
          ..moveTo(l, y)
          ..quadraticBezierTo(x, y - eyeHeight, r, y),
        _stroke(_dark(_skin, .52), _feminine ? .9 : .7),
      );
      final eyebrow = Path()
        ..moveTo(l - .2, y - 5.3)
        ..quadraticBezierTo(x, y - (_feminine ? 7.7 : 6.9), r + .1, y - 5.7);
      canvas.drawPath(
        eyebrow,
        _stroke(
          brow.withValues(alpha: .87),
          _child ? 1.15 : (_feminine ? 1.3 : 1.9),
        ),
      );
      if (_feminine) {
        final outer = x < 50 ? l : r;
        final direction = x < 50 ? -1 : 1;
        canvas.drawLine(
          Offset(outer, y),
          Offset(outer + direction * 1.6, y - 1.4),
          _stroke(_dark(_skin, .58), .65),
        );
        canvas.drawLine(
          Offset(outer - direction, y - .8),
          Offset(outer + direction * .2, y - 2.2),
          _stroke(_dark(_skin, .58), .65),
        );
      }
    }
    final noseEnd = _child ? 53.0 : 57.0;
    canvas.drawPath(
      Path()
        ..moveTo(50.5, 48)
        ..quadraticBezierTo(50.4, 52, 48.4, noseEnd - 1.5)
        ..quadraticBezierTo(50.4, noseEnd + .9, 53, noseEnd - .7),
      _stroke(_dark(_skin, .32).withValues(alpha: .65), .75),
    );
    canvas.drawLine(
      const Offset(51, 50),
      Offset(51.7, noseEnd - 3),
      _stroke(_light(_skin, .35).withValues(alpha: .6), .65),
    );
    final mouthY = _child ? 58.0 : (design.age == 1 ? 62.0 : 63.0);
    final lip = Color.lerp(
      _skin,
      const Color(0xFF9D4254),
      _feminine ? .36 : .2,
    )!;
    canvas.drawPath(
      Path()
        ..moveTo(43.5, mouthY)
        ..quadraticBezierTo(47, mouthY - 1.2, 50, mouthY - .2)
        ..quadraticBezierTo(53, mouthY - 1.1, 56.5, mouthY)
        ..quadraticBezierTo(50, mouthY + 4.8, 43.5, mouthY)
        ..close(),
      _paint(lip),
    );
    canvas.drawPath(
      Path()
        ..moveTo(43.5, mouthY)
        ..quadraticBezierTo(50, mouthY + 2.6, 56.5, mouthY),
      _stroke(_dark(lip, .2).withValues(alpha: .75), .7),
    );
    canvas.drawPath(
      Path()
        ..moveTo(47, mouthY + 2.5)
        ..quadraticBezierTo(50, mouthY + 3.2, 53, mouthY + 2.5),
      _stroke(_light(lip, .35).withValues(alpha: .65), .6),
    );
    if (design.age == 3) {
      final wrinkle = _stroke(_dark(_skin, .28).withValues(alpha: .52), .65);
      for (final y in [36.0, 38.5]) {
        canvas.drawPath(
          Path()
            ..moveTo(42, y)
            ..quadraticBezierTo(50, y - 1, 58, y),
          wrinkle,
        );
      }
      canvas.drawPath(
        Path()
          ..moveTo(35, 51)
          ..quadraticBezierTo(40, 53.5, 44, 51.5)
          ..moveTo(56, 51.5)
          ..quadraticBezierTo(60, 53.5, 65, 51),
        wrinkle,
      );
      canvas.drawPath(
        Path()
          ..moveTo(43, 58)
          ..quadraticBezierTo(39, 62, 41, 66)
          ..moveTo(57, 58)
          ..quadraticBezierTo(61, 62, 59, 66),
        wrinkle,
      );
      for (final (x, direction) in [(34.0, -1.0), (66.0, 1.0)]) {
        canvas.drawLine(Offset(x, 47), Offset(x + 2 * direction, 46), wrinkle);
        canvas.drawLine(Offset(x, 49), Offset(x + 2 * direction, 50), wrinkle);
      }
    }
  }

  void _facialHair(Canvas canvas) {
    final paint = _gradient(
      _hair,
      const Rect.fromLTWH(31, 53, 38, 27),
      light: .06,
      dark: .13,
    );
    switch (design.beard) {
      case 1:
        canvas.save();
        canvas.clipPath(_facePath());
        for (var row = 0; row < 7; row++) {
          for (var col = 0; col < 15; col++) {
            final x = 32.5 + col * 2.5 + (row.isEven ? 0 : 1);
            final y = 56.5 + row * 2.7;
            if (x > 41 && x < 59 && y < 68) continue;
            canvas.drawCircle(
              Offset(x, y),
              .33,
              _paint(_hair.withValues(alpha: .4)),
            );
          }
        }
        canvas.restore();
      case 2:
        canvas.drawPath(
          Path()
            ..moveTo(45, 66)
            ..quadraticBezierTo(50, 69, 55, 66)
            ..lineTo(57, 72)
            ..quadraticBezierTo(50, 78, 43, 72)
            ..close(),
          paint,
        );
        canvas.drawPath(
          Path()
            ..moveTo(47, 65)
            ..lineTo(53, 65)
            ..quadraticBezierTo(50, 70, 47, 65),
          paint,
        );
      case 3:
        canvas.drawPath(
          Path()
            ..moveTo(31, 55)
            ..quadraticBezierTo(36, 66, 42, 67)
            ..quadraticBezierTo(50, 73, 58, 67)
            ..quadraticBezierTo(64, 66, 69, 55)
            ..quadraticBezierTo(68, 75, 50, 77)
            ..quadraticBezierTo(32, 75, 31, 55)
            ..close(),
          paint,
        );
      case 4:
        canvas.drawPath(
          Path()
            ..moveTo(31, 53)
            ..quadraticBezierTo(36, 62, 42, 64)
            ..quadraticBezierTo(50, 68, 58, 64)
            ..quadraticBezierTo(64, 62, 69, 53)
            ..lineTo(68, 70)
            ..quadraticBezierTo(64, 80, 50, 81)
            ..quadraticBezierTo(36, 80, 32, 70)
            ..close(),
          paint,
        );
      case 5:
        canvas.drawPath(
          Path()
            ..moveTo(31, 55)
            ..quadraticBezierTo(38, 66, 44, 65)
            ..quadraticBezierTo(50, 70, 56, 65)
            ..quadraticBezierTo(62, 66, 69, 55)
            ..lineTo(64, 73)
            ..lineTo(50, 84)
            ..lineTo(36, 73)
            ..close(),
          paint,
        );
    }
    if (design.beard >= 3) {
      canvas.drawPath(
        Path()
          ..moveTo(40, 69)
          ..quadraticBezierTo(43, 74, 47, 75)
          ..moveTo(54, 74)
          ..lineTo(59, 70),
        _stroke(_light(_hair, .15).withValues(alpha: .7), .6),
      );
    }
    final y = _child ? 55.5 : (design.age == 1 ? 59.5 : 60.5);
    switch (design.moustache) {
      case 1:
        canvas.drawPath(
          Path()
            ..moveTo(43, y)
            ..quadraticBezierTo(47, y - 1.5, 50, y - .7)
            ..quadraticBezierTo(53, y - 1.5, 57, y),
          _stroke(_hair, .85),
        );
      case 2:
        canvas.drawPath(
          Path()
            ..moveTo(50, y - 1.5)
            ..quadraticBezierTo(44, y - 3, 42, y + 1.7)
            ..quadraticBezierTo(47, y + 3, 50, y)
            ..quadraticBezierTo(53, y + 3, 58, y + 1.7)
            ..quadraticBezierTo(56, y - 3, 50, y - 1.5)
            ..close(),
          paint,
        );
      case 3:
        canvas.drawPath(
          Path()
            ..moveTo(50, y - 1)
            ..cubicTo(46, y - 3, 44, y + 3, 40, y)
            ..quadraticBezierTo(37, y - 3, 40, y - 4)
            ..quadraticBezierTo(39, y - 1, 43, y - 1)
            ..quadraticBezierTo(47, y - 4, 50, y - 1)
            ..quadraticBezierTo(53, y - 4, 57, y - 1)
            ..quadraticBezierTo(61, y - 1, 60, y - 4)
            ..quadraticBezierTo(63, y - 3, 60, y)
            ..cubicTo(56, y + 3, 54, y - 3, 50, y - 1)
            ..close(),
          paint,
        );
      case 4:
        canvas.drawPath(
          Path()
            ..moveTo(50, y - 2)
            ..quadraticBezierTo(41, y - 5, 40, y + 3)
            ..quadraticBezierTo(45, y + 4, 50, y + 1)
            ..quadraticBezierTo(55, y + 4, 60, y + 3)
            ..quadraticBezierTo(59, y - 5, 50, y - 2)
            ..close(),
          paint,
        );
    }
  }

  void _glasses(Canvas canvas) {
    if (design.eyewear == 0) return;
    final y = _eyeY;
    final frame = design.eyewear == 5
        ? const Color(0xFFC9AC75)
        : const Color(0xFF273343);
    final lens = design.eyewear == 4
        ? const Color(0xFF233244)
        : const Color(0xFF91B7C8).withValues(alpha: .13);
    for (final x in [40.0, 60.0]) {
      Path shape;
      if (design.eyewear == 1) {
        shape = Path()
          ..addOval(
            Rect.fromCenter(center: Offset(x, y), width: 14, height: 13),
          );
      } else if (design.eyewear == 3) {
        if (x < 50) {
          shape = Path()
            ..moveTo(31, y - 5)
            ..quadraticBezierTo(39, y - 3, 47, y - 4)
            ..lineTo(46, y + 4)
            ..quadraticBezierTo(39, y + 8, 33, y + 2)
            ..close();
        } else {
          shape = Path()
            ..moveTo(69, y - 5)
            ..quadraticBezierTo(61, y - 3, 53, y - 4)
            ..lineTo(54, y + 4)
            ..quadraticBezierTo(61, y + 8, 67, y + 2)
            ..close();
        }
      } else if (design.eyewear == 5) {
        shape = Path()
          ..moveTo(x - 7, y - 4)
          ..quadraticBezierTo(x, y - 7, x + 7, y - 3)
          ..lineTo(x + 6, y + 3)
          ..quadraticBezierTo(x, y + 9, x - 6, y + 3)
          ..close();
      } else {
        shape = Path()
          ..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(x, y), width: 15, height: 10),
              Radius.circular(design.eyewear == 4 ? 3 : 1.8),
            ),
          );
      }
      canvas.drawPath(shape, _paint(lens));
      canvas.drawPath(shape, _stroke(frame, design.eyewear == 5 ? 1 : 1.25));
      canvas.save();
      canvas.clipPath(shape);
      canvas.drawLine(
        Offset(x - 5, y + 2),
        Offset(x + 2, y - 5),
        _stroke(Colors.white.withValues(alpha: .22), 1.4),
      );
      canvas.restore();
    }
    canvas.drawPath(
      Path()
        ..moveTo(47, y - 1)
        ..quadraticBezierTo(50, y - 3, 53, y - 1),
      _stroke(frame, 1.1),
    );
    if (design.eyewear == 5) {
      canvas.drawLine(Offset(46, y - 4), Offset(54, y - 4), _stroke(frame, .8));
    }
    canvas.drawLine(Offset(32, y - 2), Offset(28, y - 3), _stroke(frame, 1));
    canvas.drawLine(Offset(68, y - 2), Offset(72, y - 3), _stroke(frame, 1));
  }

  @override
  bool shouldRepaint(CustomAvatarPainter oldDelegate) =>
      oldDelegate.design != design;
}
