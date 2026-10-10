// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../../domain/animated_army_theme.dart';
import '../../domain/cinematic_replay.dart';
import '../../domain/piece_pack.dart';
import 'board_appearance.dart';

const cinematicBoardMoveStart = .20;
const cinematicBoardMoveEnd = .56;

/// The film's permanent board view. Motion is derived solely from the recorded
/// scene and film progress; there are no timers, taps, engine calls or edits.
class NeonCinematicBoard extends StatelessWidget {
  const NeonCinematicBoard({
    required this.position,
    required this.scene,
    required this.progress,
    required this.reducedMotion,
    this.theme = AnimatedArmyTheme.neon,
    this.classicPieces = false,
    this.classicStyle = ClassicPieceStyle.magneticTeaching,
    this.intro = false,
    this.finale = false,
    this.threatSquares = const {},
    super.key,
  });

  /// An authoritative initial/final snapshot when no move scene is active.
  final Position position;
  final CinematicReplayScene? scene;
  final double progress;
  final bool reducedMotion;
  final bool intro;
  final bool finale;
  final Set<Square> threatSquares;
  final AnimatedArmyTheme theme;
  final bool classicPieces;
  final ClassicPieceStyle classicStyle;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final active = !intro && !finale ? scene : null;
      final p = progress.clamp(0.0, 1.0);
      final snapshot = active == null
          ? position
          : p >= cinematicBoardMoveEnd
          ? active.after
          : active.before;
      final movement =
          ((p - cinematicBoardMoveStart) /
                  (cinematicBoardMoveEnd - cinematicBoardMoveStart))
              .clamp(0.0, 1.0);
      final moving =
          active != null &&
          !reducedMotion &&
          p > cinematicBoardMoveStart &&
          p < cinematicBoardMoveEnd;
      final zoom = active == null || reducedMotion ? 1.0 : _cameraZoom(p);
      final extent = math.max(1.0, math.min(box.maxWidth, box.maxHeight));
      final border = math.max(6.0, math.min(14.0, extent * .055));
      final boardExtent = math.max(1.0, extent - border * 2);
      final overviewExtent = math.max(34.0, math.min(104.0, extent * .26));
      final overviewBounds = _overviewBounds(
        active,
        extent: extent,
        border: border,
        overviewExtent: overviewExtent,
      );
      final focus = active == null
          ? const Offset(.5, .5)
          : Offset.lerp(
              _squareCenter(active.source),
              _squareCenter(active.target),
              _movementEase(movement),
            )!;
      final halfWindow = .5 / zoom;
      final cameraCenter = Offset(
        focus.dx.clamp(halfWindow, 1 - halfWindow),
        focus.dy.clamp(halfWindow, 1 - halfWindow),
      );
      final transform = Matrix4.diagonal3Values(zoom, zoom, 1)
        ..setTranslationRaw(
          boardExtent * (.5 - cameraCenter.dx * zoom),
          boardExtent * (.5 - cameraCenter.dy * zoom),
          0,
        );
      final accent = Color(
        active?.side == Side.black
            ? theme.blackColorArgb
            : theme.whiteColorArgb,
      );
      return Semantics(
        key: const ValueKey('neon-cinematic-board'),
        label: active == null
            ? 'Recorded ${intro
                  ? 'initial'
                  : finale
                  ? 'final'
                  : 'game'} chess position'
            : 'Recorded move ${active.san}, ${active.source.name} to ${active.target.name}',
        child: Center(
          child: SizedBox.square(
            dimension: extent,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(theme.baseColorArgb),
                border: Border.all(color: accent.withValues(alpha: .38)),
                borderRadius: BorderRadius.circular(5),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: .08),
                    blurRadius: 22,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _BoardCoordinates(
                      border: border,
                      zoomed: zoom > 1.001,
                      child: ClipRect(
                        key: const ValueKey('cinematic-board-viewport'),
                        child: Transform(
                          key: const ValueKey('cinematic-board-camera'),
                          transform: transform,
                          child: _BoardSurface(
                            key: const ValueKey('cinematic-board-main-world'),
                            theme: theme,
                            classicPieces: classicPieces,
                            classicStyle: classicStyle,
                            snapshot: snapshot,
                            scene: active,
                            movement: movement,
                            moving: moving,
                            threatSquares: threatSquares,
                            squareNames: zoom > 1.001,
                            miniature: false,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // The overview remains visible for every zoomed frame,
                  // including camera movement before/after the actual move.
                  if (zoom > 1.001)
                    Positioned(
                      left: overviewBounds.left,
                      top: overviewBounds.top,
                      width: overviewBounds.width,
                      height: overviewBounds.height,
                      child: Semantics(
                        label:
                            'Full-board overview while camera follows the move',
                        child: DecoratedBox(
                          key: const ValueKey('cinematic-board-context'),
                          decoration: BoxDecoration(
                            color: Color(theme.baseColorArgb),
                            border: Border.all(
                              color: accent.withValues(alpha: .9),
                              width: 1.3,
                            ),
                            boxShadow: const [
                              BoxShadow(color: Colors.black87, blurRadius: 8),
                            ],
                          ),
                          child: _BoardCoordinates(
                            border: 7,
                            zoomed: false,
                            miniature: true,
                            child: _BoardSurface(
                              theme: theme,
                              classicPieces: classicPieces,
                              classicStyle: classicStyle,
                              snapshot: snapshot,
                              scene: active,
                              movement: movement,
                              moving: moving,
                              threatSquares: threatSquares,
                              squareNames: false,
                              miniature: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

double _cameraZoom(double p) {
  final arrival = Curves.easeInOutCubic.transform(
    ((p - .04) / .16).clamp(0.0, 1.0),
  );
  final departure = Curves.easeInOutCubic.transform(
    ((p - .66) / .26).clamp(0.0, 1.0),
  );
  return 1 + .35 * arrival * (1 - departure);
}

Offset _squareCenter(Square square) =>
    Offset((square.file.value + .5) / 8, (7 - square.rank.value + .5) / 8);

double _movementEase(double progress) =>
    progress * progress * (3 - 2 * progress);

Rect _overviewBounds(
  CinematicReplayScene? scene, {
  required double extent,
  required double border,
  required double overviewExtent,
}) {
  final far = extent - overviewExtent - 3;
  final corners = [
    Rect.fromLTWH(far, 3, overviewExtent, overviewExtent),
    Rect.fromLTWH(3, 3, overviewExtent, overviewExtent),
    Rect.fromLTWH(3, far, overviewExtent, overviewExtent),
    Rect.fromLTWH(far, far, overviewExtent, overviewExtent),
  ];
  if (scene == null) return corners.first;
  final source = _squareCenter(scene.source);
  final target = _squareCenter(scene.target);
  final boardExtent = math.max(1.0, extent - border * 2);
  final endpoints = [source, target];
  if (scene.captureSquare != null) {
    endpoints.add(_squareCenter(scene.captureSquare!));
  }
  if (scene.isCastling) {
    endpoints.add(_squareCenter(scene.resolution.move.to));
    endpoints.add(
      _squareCenter(
        Square.fromCoords(
          scene.target.file == File.g ? File.f : File.d,
          scene.source.rank,
        ),
      ),
    );
  }
  if (scene.isCheck) {
    final king = scene.after.board.kingOf(scene.after.turn);
    if (king != null) endpoints.add(_squareCenter(king));
  }
  final protected = <Rect>[];
  // Assess the whole chapter rather than the current frame. The selected
  // corner stays fixed while the camera tracks, including its clamped motion
  // at board edges. Endpoints and the travelling piece remain unobscured.
  for (final p in const [.08, .16, .20, .29, .38, .47, .56, .66, .79, .9]) {
    final zoom = _cameraZoom(p);
    final progress =
        ((p - cinematicBoardMoveStart) /
                (cinematicBoardMoveEnd - cinematicBoardMoveStart))
            .clamp(0.0, 1.0);
    final mover = Offset.lerp(source, target, _movementEase(progress))!;
    final half = .5 / zoom;
    final center = Offset(
      mover.dx.clamp(half, 1 - half),
      mover.dy.clamp(half, 1 - half),
    );
    for (final point in [...endpoints, mover]) {
      final projected = Offset(
        border + boardExtent * (.5 + (point.dx - center.dx) * zoom),
        border + boardExtent * (.5 + (point.dy - center.dy) * zoom),
      );
      protected.add(
        Rect.fromCenter(
          center: projected,
          width: boardExtent * zoom / 8 + 12,
          height: boardExtent * zoom / 8 + 12,
        ),
      );
    }
  }
  var chosen = corners.first;
  var best = double.negativeInfinity;
  for (final corner in corners) {
    var clearance = double.infinity;
    for (final piece in protected) {
      clearance = math.min(clearance, _rectClearance(corner, piece));
    }
    if (clearance > best) {
      best = clearance;
      chosen = corner;
    }
  }
  return chosen;
}

double _rectClearance(Rect a, Rect b) {
  if (a.overlaps(b)) {
    final intersection = a.intersect(b);
    return -intersection.width * intersection.height;
  }
  final x = math.max(0.0, math.max(a.left - b.right, b.left - a.right));
  final y = math.max(0.0, math.max(a.top - b.bottom, b.top - a.bottom));
  return math.sqrt(x * x + y * y);
}

class _BoardCoordinates extends StatelessWidget {
  const _BoardCoordinates({
    required this.border,
    required this.zoomed,
    required this.child,
    this.miniature = false,
  });
  final double border;
  final bool zoomed;
  final bool miniature;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final extent = math.max(1.0, box.maxWidth - border * 2);
      final text = TextStyle(
        fontSize: miniature
            ? 5
            : border < 9
            ? 6
            : 8,
        height: 1,
        color: const Color(0xFFB5CFD9),
        fontWeight: FontWeight.w700,
      );
      return Stack(
        children: [
          Positioned(
            left: border,
            top: border,
            width: extent,
            height: extent,
            child: child,
          ),
          // Outer labels describe the full board. Once zoomed, each visible cell
          // carries its own true coordinate and the overview retains these axes.
          if (!zoomed) ...[
            for (var file = 0; file < 8; file++)
              Positioned(
                left: border + file * extent / 8,
                bottom: 0,
                width: extent / 8,
                height: border,
                child: Center(child: Text(File.values[file].name, style: text)),
              ),
            for (var rank = 0; rank < 8; rank++)
              Positioned(
                left: 0,
                top: border + rank * extent / 8,
                width: border,
                height: extent / 8,
                child: Center(
                  child: Text(Rank.values[7 - rank].name, style: text),
                ),
              ),
          ],
        ],
      );
    },
  );
}

class _BoardSurface extends StatelessWidget {
  const _BoardSurface({
    required this.theme,
    required this.classicPieces,
    required this.classicStyle,
    required this.snapshot,
    required this.scene,
    required this.movement,
    required this.moving,
    required this.threatSquares,
    required this.squareNames,
    required this.miniature,
    super.key,
  });
  final AnimatedArmyTheme theme;
  final bool classicPieces;
  final ClassicPieceStyle classicStyle;
  final Position snapshot;
  final CinematicReplayScene? scene;
  final double movement;
  final bool moving;
  final Set<Square> threatSquares;
  final bool squareNames;
  final bool miniature;

  Color get _white => Color(theme.whiteColorArgb);
  Color get _black => Color(theme.blackColorArgb);
  PiecePack get _pack =>
      piecePacks.singleWhere((pack) => pack.id == theme.packId);
  BoardAppearance get _look {
    final look = BoardAppearance.forPack(_pack);
    return classicPieces ? look.withStandardPieces(classicStyle) : look;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final extent = box.maxWidth;
      final pack = _pack;
      final look = _look;
      final cell = extent / 8;
      final s = scene;
      final rookFrom = s?.isCastling == true ? s!.resolution.move.to : null;
      final rookTo = s?.isCastling == true
          ? Square.fromCoords(
              s!.target.file == File.g ? File.f : File.d,
              s.source.rank,
            )
          : null;
      final prefix = miniature ? 'context' : 'main';
      final accent = s?.side == Side.black ? _black : _white;
      return Stack(
        children: [
          for (var index = 0; index < 64; index++)
            Builder(
              builder: (context) {
                final square = Square(index);
                final piece = snapshot.board.pieceAt(square);
                final center = _squareCenter(square) * extent;
                final source = s?.source == square;
                final target = s?.target == square;
                final captured =
                    s?.captureSquare == square && snapshot == s?.before;
                final hidden = moving && (source || square == rookFrom);
                final threatened = threatSquares.contains(square);
                final checkedKing =
                    snapshot.isCheck &&
                    snapshot.board.kingOf(snapshot.turn) == square;
                final light = (square.file.value + square.rank.value).isOdd;
                return Positioned(
                  left: center.dx - cell / 2,
                  top: center.dy - cell / 2,
                  width: cell,
                  height: cell,
                  child: Semantics(
                    key: ValueKey('cinematic-board-$prefix-${square.name}'),
                    label:
                        '${square.name} ${piece == null ? 'empty' : '${piece.color.name} ${piece.role.name}'}'
                        '${threatened ? ', threatened' : ''}${checkedKing ? ', checked king' : ''}',
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: checkedKing
                            ? const Color(0xFF8A2740)
                            : Color.lerp(
                                light ? look.lightSquare : look.darkSquare,
                                captured ? _black : accent,
                                source || target || captured ? .26 : 0,
                              ),
                        border: source || target || threatened
                            ? Border.all(
                                color: threatened ? _black : accent,
                                width: miniature
                                    ? .7
                                    : target
                                    ? 2.4
                                    : 1.3,
                              )
                            : null,
                      ),
                      child: Stack(
                        children: [
                          if (piece != null && !hidden)
                            Positioned.fill(
                              child: CharacterPiece(
                                piece: piece,
                                pack: pack,
                                standard: classicPieces,
                                classicStyle: classicStyle,
                                showRole: !miniature && cell >= 24,
                              ),
                            ),
                          if (squareNames)
                            Positioned(
                              left: 2,
                              top: 1,
                              child: Text(
                                square.name,
                                style: TextStyle(
                                  fontSize: miniature
                                      ? 4
                                      : math.max(4, math.min(8, cell * .2)),
                                  height: 1,
                                  color: light
                                      ? const Color(0xFF08101B)
                                      : Colors.white70,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          if (threatened)
                            Positioned(
                              top: 1,
                              right: 1,
                              child: Icon(
                                Icons.warning_amber_rounded,
                                key: ValueKey(
                                  'cinematic-board-$prefix-threat-${square.name}',
                                ),
                                size: miniature ? 5 : math.min(12, cell * .3),
                                color: _black,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          if (s != null)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _RoutePainter(
                    from: _squareCenter(s.source),
                    to: _squareCenter(s.target),
                    accent: accent,
                    miniature: miniature,
                  ),
                ),
              ),
            ),
          if (moving && s != null) ...[
            _travellingPiece(
              s.resolution.attacker,
              s.source,
              s.target,
              cell,
              extent,
              'cinematic-board-$prefix-moving-piece',
              movement,
            ),
            if (rookFrom != null && rookTo != null)
              _travellingPiece(
                Piece(color: s.side, role: Role.rook),
                rookFrom,
                rookTo,
                cell,
                extent,
                'cinematic-board-$prefix-moving-rook',
                movement,
              ),
          ],
        ],
      );
    },
  );

  Widget _travellingPiece(
    Piece piece,
    Square from,
    Square to,
    double cell,
    double extent,
    String key,
    double progress,
  ) {
    final t = _movementEase(progress);
    final center =
        Offset.lerp(_squareCenter(from), _squareCenter(to), t)! * extent;
    return Positioned(
      left: center.dx - cell / 2,
      top: center.dy - cell / 2,
      width: cell,
      height: cell,
      child: Semantics(
        label:
            'Moving ${piece.color.name} ${piece.role.name} from ${from.name} to ${to.name}',
        child: DecoratedBox(
          key: ValueKey(key),
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: (piece.color == Side.white ? _white : _black).withValues(
                  alpha: .4,
                ),
                blurRadius: miniature ? 2 : 10,
              ),
            ],
          ),
          child: CharacterPiece(
            piece: piece,
            pack: _pack,
            standard: classicPieces,
            classicStyle: classicStyle,
            showRole: !miniature && cell >= 24,
          ),
        ),
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  const _RoutePainter({
    required this.from,
    required this.to,
    required this.accent,
    required this.miniature,
  });
  final Offset from;
  final Offset to;
  final Color accent;
  final bool miniature;

  @override
  void paint(Canvas canvas, Size size) {
    final a = from * size.width;
    final b = to * size.width;
    final vector = b - a;
    final length = vector.distance;
    if (length <= 0) return;
    final direction = vector / length;
    final paint = Paint()
      ..color = accent.withValues(alpha: miniature ? .75 : .45)
      ..strokeWidth = miniature ? .8 : 1.5
      ..strokeCap = StrokeCap.round;
    for (var start = 0.0; start < length; start += miniature ? 4 : 11) {
      canvas.drawLine(
        a + direction * start,
        a + direction * math.min(length, start + (miniature ? 2 : 5)),
        paint,
      );
    }
    final normal = Offset(-direction.dy, direction.dx);
    final arrowSize = miniature ? 2.5 : math.min(7.0, size.width / 32);
    canvas.drawPath(
      Path()
        ..moveTo(b.dx, b.dy)
        ..lineTo(
          (b - direction * arrowSize + normal * arrowSize * .5).dx,
          (b - direction * arrowSize + normal * arrowSize * .5).dy,
        )
        ..lineTo(
          (b - direction * arrowSize - normal * arrowSize * .5).dx,
          (b - direction * arrowSize - normal * arrowSize * .5).dy,
        )
        ..close(),
      paint..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_RoutePainter oldDelegate) =>
      oldDelegate.from != from ||
      oldDelegate.to != to ||
      oldDelegate.accent != accent ||
      oldDelegate.miniature != miniature;
}
