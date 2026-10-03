// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:ui' as ui;

import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Themed pieces share one large visual height. Wide mounts are compressed
/// horizontally when needed, while pawns keep the same height with a deliberately
/// lean silhouette for role distinction and maximum small-screen visibility.
abstract final class ThemedPieceMetrics {
  static double scaleFor(Role role) => 1;

  static const baseline = .97;
  static const maximumHeight = .94;
  static const maximumWidth = .96;
  static const pawnMaximumWidth = .38;
  static const pawnMaximumHeight = maximumHeight;

  static double pawnWidthForArmy(List<Rect> armySources) {
    const roles = [Role.king, Role.queen, Role.bishop, Role.knight, Role.rook];
    var limit = pawnMaximumWidth;
    for (var index = 0; index < roles.length; index++) {
      final width =
          destination(
            const Size.square(1),
            armySources[index].size,
            roles[index],
          ).width *
          // Pawns stay visibly lean even beside a slender court character.
          .76;
      if (width < limit) limit = width;
    }
    return limit;
  }

  static double pawnHeightForArmy(List<Rect> armySources) {
    return pawnMaximumHeight;
  }

  static Rect destination(
    Size canvasSize,
    Size artworkSize,
    Role role, {
    double pawnWidthLimit = pawnMaximumWidth,
    double pawnHeightLimit = pawnMaximumHeight,
  }) {
    if (canvasSize.isEmpty || artworkSize.isEmpty) return Rect.zero;
    final extent = canvasSize.shortestSide;
    final height = extent * maximumHeight;
    final naturalWidth = height * artworkSize.aspectRatio;
    final widthLimit =
        extent *
        (role == Role.pawn
            ? pawnWidthLimit.clamp(0, pawnMaximumWidth)
            : maximumWidth);
    final width = naturalWidth.clamp(0.0, widthLimit).toDouble();
    return Rect.fromLTWH(
      (canvasSize.width - width) / 2,
      (canvasSize.height - extent) / 2 + extent * baseline - height,
      width,
      height,
    );
  }
}

/// Resolves through Flutter's image cache, then paints one isolated crop only.
/// Alpha bounds are measured once per atlas off the UI isolate, so both old
/// and newly added packs get the same real silhouette heights and baseline.
class ThemedPieceSprite extends StatefulWidget {
  const ThemedPieceSprite({
    required this.asset,
    required this.row,
    required this.column,
    required this.rows,
    required this.role,
    this.flipX = false,
    this.brightenDarkArmy = false,
    super.key,
  }) : assert(rows > 0),
       assert(row >= 0 && row < rows),
       assert(column >= 0 && column < 6);

  final String asset;
  final int row;
  final int column;
  final int rows;
  final Role role;
  final bool flipX;
  final bool brightenDarkArmy;

  @override
  State<ThemedPieceSprite> createState() => _ThemedPieceSpriteState();
}

final _alphaBoundsCache = <String, Future<List<Rect>>>{};

/// Public for asset-quality checks; the caller retains ownership of [image].
Future<List<Rect>> measureThemedSpriteBounds(ui.Image image, int rows) async {
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (bytes == null) throw StateError('Cannot inspect themed-piece alpha.');
  return compute(_measureBounds, (
    image.width,
    image.height,
    rows,
    bytes.buffer.asUint8List(),
  ));
}

List<Rect> _measureBounds((int, int, int, Uint8List) input) {
  final (width, height, rows, bytes) = input;
  final bounds = <Rect>[];
  for (var row = 0; row < rows; row++) {
    for (var column = 0; column < 6; column++) {
      final left = (column * width / 6).round();
      final right = ((column + 1) * width / 6).round();
      final top = (row * height / rows).round();
      final bottom = ((row + 1) * height / rows).round();
      var minX = right;
      var maxX = left - 1;
      var minY = bottom;
      var maxY = top - 1;
      for (var y = top; y < bottom; y++) {
        for (var x = left; x < right; x++) {
          if (bytes[(y * width + x) * 4 + 3] <= 12) continue;
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
      bounds.add(
        maxX < minX
            ? Rect.fromLTRB(
                left.toDouble(),
                top.toDouble(),
                right.toDouble(),
                bottom.toDouble(),
              )
            : Rect.fromLTRB(
                minX.toDouble(),
                minY.toDouble(),
                (maxX + 1).toDouble(),
                (maxY + 1).toDouble(),
              ),
      );
    }
  }
  return bounds;
}

Future<List<Rect>> _cachedBounds(String asset, ui.Image image, int rows) {
  final key = '$asset:${image.width}:${image.height}:$rows';
  return _alphaBoundsCache.putIfAbsent(key, () async {
    final retained = image.clone();
    try {
      return await measureThemedSpriteBounds(retained, rows);
    } finally {
      retained.dispose();
    }
  });
}

class _ThemedPieceSpriteState extends State<ThemedPieceSprite> {
  ImageStream? _stream;
  ImageInfo? _image;
  List<Rect>? _sources;
  bool _failed = false;

  late final _listener = ImageStreamListener(
    (image, _) {
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() {
        _image?.dispose();
        _image = image;
        _sources = null;
        _failed = false;
      });
      _measure(image);
    },
    onError: (Object error, StackTrace? stack) {
      if (mounted) setState(() => _failed = true);
    },
  );

  Future<void> _measure(ImageInfo image) async {
    try {
      final bounds = await _cachedBounds(
        widget.asset,
        image.image,
        widget.rows,
      );
      if (mounted && identical(_image, image)) {
        setState(() => _sources = bounds);
      }
    } catch (_) {
      // A device unable to read texture pixels can still render an isolated
      // cell with the same role scale; it must never show neighbouring cells.
      if (mounted && identical(_image, image)) setState(() {});
    }
  }

  void _resolve() {
    final stream = AssetImage(
      widget.asset,
    ).resolve(createLocalImageConfiguration(context));
    if (_stream?.key == stream.key) return;
    _stream?.removeListener(_listener);
    _image?.dispose();
    _image = null;
    _sources = null;
    _failed = false;
    _stream = stream..addListener(_listener);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(ThemedPieceSprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset != widget.asset) _resolve();
    if (oldWidget.rows != widget.rows && _image != null) _measure(_image!);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image?.image;
    if (image == null) {
      return _failed
          ? const Icon(Icons.image_not_supported_outlined, size: 18)
          : const SizedBox.expand();
    }
    final source =
        _sources?[widget.row * 6 + widget.column] ??
        Rect.fromLTWH(
          widget.column * image.width / 6,
          widget.row * image.height / widget.rows,
          image.width / 6,
          image.height / widget.rows,
        );
    return CustomPaint(
      painter: ThemedPieceSpritePainter(
        image: image,
        source: source,
        role: widget.role,
        flipX: widget.flipX,
        brightenDarkArmy: widget.brightenDarkArmy,
        pawnWidthLimit: _sources == null
            ? ThemedPieceMetrics.pawnMaximumWidth
            : ThemedPieceMetrics.pawnWidthForArmy(
                _sources!.sublist(widget.row * 6, widget.row * 6 + 6),
              ),
        pawnHeightLimit: _sources == null
            ? ThemedPieceMetrics.pawnMaximumHeight
            : ThemedPieceMetrics.pawnHeightForArmy(
                _sources!.sublist(widget.row * 6, widget.row * 6 + 6),
              ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class ThemedPieceSpritePainter extends CustomPainter {
  const ThemedPieceSpritePainter({
    required this.image,
    required this.source,
    required this.role,
    this.flipX = false,
    this.brightenDarkArmy = false,
    this.pawnWidthLimit = ThemedPieceMetrics.pawnMaximumWidth,
    this.pawnHeightLimit = ThemedPieceMetrics.pawnMaximumHeight,
  });
  final ui.Image image;
  final Rect source;
  final Role role;
  final bool flipX;
  final bool brightenDarkArmy;
  final double pawnWidthLimit;
  final double pawnHeightLimit;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final target = ThemedPieceMetrics.destination(
      size,
      source.size,
      role,
      pawnWidthLimit: pawnWidthLimit,
      pawnHeightLimit: pawnHeightLimit,
    );
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (flipX) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    final outline = Paint()
      ..filterQuality = FilterQuality.medium
      ..colorFilter = ColorFilter.mode(
        brightenDarkArmy
            ? const Color(0xFFE8C66A).withValues(alpha: .82)
            : const Color(0xFF101722).withValues(alpha: .72),
        BlendMode.srcIn,
      );
    final outlineStep = size.shortestSide * .018;
    for (final offset in <Offset>[
      Offset(-outlineStep, 0),
      Offset(outlineStep, 0),
      Offset(0, -outlineStep),
      Offset(0, outlineStep),
    ]) {
      canvas.drawImageRect(image, source, target.shift(offset), outline);
    }
    final paint = Paint()
      ..filterQuality = FilterQuality.high
      // A small midtone lift keeps faces readable at phone-board size. Dark
      // armies receive stronger colour separation while the tiny offset keeps
      // black clothing recognisably black rather than turning it grey.
      ..colorFilter = ColorFilter.matrix(
        brightenDarkArmy
            ? const <double>[
                1.27,
                -0.07,
                -0.07,
                0,
                3,
                -0.05,
                1.23,
                -0.05,
                0,
                3,
                -0.05,
                -0.05,
                1.25,
                0,
                3,
                0,
                0,
                0,
                1,
                0,
              ]
            : const <double>[
                1.12,
                -0.02,
                -0.02,
                0,
                5,
                -0.02,
                1.12,
                -0.02,
                0,
                5,
                -0.02,
                -0.02,
                1.12,
                0,
                5,
                0,
                0,
                0,
                1,
                0,
              ],
      );
    canvas.drawImageRect(image, source, target, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(ThemedPieceSpritePainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.source != source ||
      oldDelegate.role != role ||
      oldDelegate.flipX != flipX ||
      oldDelegate.brightenDarkArmy != brightenDarkArmy ||
      oldDelegate.pawnWidthLimit != pawnWidthLimit ||
      oldDelegate.pawnHeightLimit != pawnHeightLimit;
}
