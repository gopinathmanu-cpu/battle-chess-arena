// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'animated_move_timing.dart';
import 'chess_set_swipe.dart';

import '../../domain/piece_pack.dart';
import 'board_appearance.dart';
import '../studio/custom_board_surface.dart';

class MatchHeader extends StatelessWidget {
  const MatchHeader({
    super.key,
    required this.status,
    required this.whiteTime,
    required this.blackTime,
    required this.turn,
    required this.accent,
    this.timed = true,
  });
  final String status;
  final Duration whiteTime;
  final Duration blackTime;
  final Side turn;
  final Color accent;
  final bool timed;

  String _format(Duration value) => value.inHours > 0
      ? '${value.inHours}h ${(value.inMinutes % 60).toString().padLeft(2, '0')}m'
      : '${value.inMinutes.toString().padLeft(2, '0')}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final whiteClock = _Clock(
        label: 'WHITE',
        time: timed ? _format(whiteTime) : '--:--',
        active: turn == Side.white,
      );
      final blackClock = _Clock(
        label: 'BLACK',
        time: timed ? _format(blackTime) : '--:--',
        active: turn == Side.black,
      );
      final statusText = Text(
        status,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(color: accent, fontWeight: FontWeight.w800),
      );
      if (MediaQuery.textScalerOf(context).scale(14) > 21 ||
          constraints.maxWidth < 280) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: whiteClock,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: blackClock,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            statusText,
          ],
        );
      }
      return Row(
        children: [
          whiteClock,
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: statusText,
            ),
          ),
          blackClock,
        ],
      );
    },
  );
}

class _Clock extends StatelessWidget {
  const _Clock({required this.label, required this.time, required this.active});
  final String label;
  final String time;
  final bool active;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: active ? Colors.white : Colors.white10,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: active ? Colors.black54 : Colors.white54,
          ),
        ),
        Text(
          time,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: active ? Colors.black : Colors.white,
          ),
        ),
      ],
    ),
  );
}

class ChessBoard extends StatefulWidget {
  const ChessBoard({
    required this.position,
    required this.selected,
    required this.legalTargets,
    required this.accent,
    required this.onSquareTap,
    this.orientation = Side.white,
    this.appearance,
    this.hiddenPieceSquare,
    this.suggestedFrom,
    this.suggestedTo,
    this.previewFrom,
    this.previewTo,
    this.blinkingSquare,
    this.previewLit = true,
    this.lastMoveFrom,
    this.lastMoveTo,
    this.threatFrom,
    this.threatTarget,
    this.threatLanding,
    this.threatLit = true,
    this.showPieceRoles = true,
    this.showCoordinates = false,
    this.onSetSwipe,
    this.swipeHint,
    this.animateMoves = false,
    this.animatedMove,
    this.moveAnimationDuration = animatedMoveDuration,
    this.reducedMotion = false,
    super.key,
  });
  final Position position;
  final Square? selected;
  final Set<Square> legalTargets;
  final Color accent;
  final ValueChanged<Square> onSquareTap;
  final Side orientation;
  final BoardAppearance? appearance;
  final Square? hiddenPieceSquare;
  final Square? suggestedFrom;
  final Square? suggestedTo;
  final Square? previewFrom;
  final Square? previewTo;
  final Square? blinkingSquare;
  final bool previewLit;
  final Square? lastMoveFrom;
  final Square? lastMoveTo;
  final Square? threatFrom;
  final Square? threatTarget;
  final Square? threatLanding;
  final bool threatLit;
  final bool showPieceRoles;
  final bool showCoordinates;
  final ValueChanged<int>? onSetSwipe;
  final String? swipeHint;

  /// Moves the rendered piece without delaying the authoritative [position].
  /// Callers enable this only for a board paired with the Animated arena.
  final bool animateMoves;

  /// The accepted move that produced [position]. Requests, reconnect snapshots
  /// and undo/reset operations leave this null; they never invent movement.
  final NormalMove? animatedMove;
  final Duration moveAnimationDuration;
  final bool reducedMotion;

  /// The reserved margin outside the playable grid when coordinates are shown.
  /// Overlays can use the same inset to keep their square positions aligned.
  static double coordinateInset(double boardExtent) => boardExtent <= 0
      ? 0
      : math.min(boardExtent * .14, (boardExtent * .055).clamp(10.0, 22.0));

  @override
  State<ChessBoard> createState() => _ChessBoardState();
}

class _ChessBoardState extends State<ChessBoard>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _swipeHintDismissed = false;

  void _dismissSwipeHint() {
    if (!_swipeHintDismissed) setState(() => _swipeHintDismissed = true);
  }

  late final AnimationController _motion;
  final _pieceScaleKeys = <Square, GlobalKey>{};
  _BoardMovePresentation? _movement;
  bool _reduced = false;
  bool _background = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _motion = AnimationController(
      vsync: this,
      duration: widget.moveAnimationDuration,
      value: 1,
    )..addStatusListener(_motionStatus);
  }

  void _motionStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _movement != null && mounted) {
      setState(() => _movement = null);
    }
  }

  void _snapMovement() {
    _movement = null;
    _motion
      ..stop()
      ..value = 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced =
        widget.reducedMotion ||
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    if (_reduced) _snapMovement();
  }

  @override
  void didUpdateWidget(ChessBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.swipeHint == null && widget.swipeHint != null) {
      _swipeHintDismissed = false;
    }
    _reduced =
        widget.reducedMotion ||
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    _motion.duration = widget.moveAnimationDuration;
    if (_reduced || !widget.animateMoves) {
      _snapMovement();
      return;
    }
    if (oldWidget.position.fen == widget.position.fen) return;
    _snapMovement();
    final move = widget.animatedMove;
    if (move == null || widget.moveAnimationDuration <= Duration.zero) return;
    final movement = _BoardMovePresentation.accepted(
      before: oldWidget.position,
      after: widget.position,
      move: move,
      startScale: _renderedPieceScale(move.from),
    );
    if (movement == null ||
        movement.flights.every(
          (flight) => flight.target == widget.hiddenPieceSquare,
        )) {
      return;
    }
    _movement = movement;
    _motion.value = 0;
    if (!_background) _motion.forward();
  }

  double _renderedPieceScale(Square source) {
    final rendered = _pieceScaleKeys[source]?.currentContext
        ?.findRenderObject();
    return rendered is RenderTransform && rendered.child != null
        ? rendered.child!.getTransformTo(rendered).getMaxScaleOnAxis()
        : 1;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _background = state != AppLifecycleState.resumed;
    if (_background) {
      _motion.stop();
    } else if (_movement != null && !_reduced) {
      _motion.forward();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChessSetSwipe(
    onChange: widget.onSetSwipe == null
        ? null
        : (direction) {
            _dismissSwipeHint();
            widget.onSetSwipe!(direction);
          },
    child: widget.showCoordinates
        ? LayoutBuilder(
            builder: (context, box) {
              final extent = math.min(box.maxWidth, box.maxHeight);
              final inset = ChessBoard.coordinateInset(extent);
              final files = widget.orientation == Side.white
                  ? 'ABCDEFGH'
                  : 'HGFEDCBA';
              final ranks = widget.orientation == Side.white
                  ? '87654321'
                  : '12345678';

              Widget label(String reference, String side) => _BoardReference(
                reference: reference,
                side: side,
                fontSize: (inset * .68).clamp(7.0, 13.0),
              );

              return Center(
                child: SizedBox.square(
                  key: const ValueKey('board-coordinate-frame'),
                  dimension: extent,
                  child: ColoredBox(
                    color: const Color(0xFF101C29),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Padding(
                            padding: EdgeInsets.all(inset),
                            child: _buildGrid(context),
                          ),
                        ),
                        for (final side in ['top', 'bottom'])
                          Positioned(
                            left: inset,
                            right: inset,
                            top: side == 'top' ? 0 : null,
                            bottom: side == 'bottom' ? 0 : null,
                            height: inset,
                            child: IgnorePointer(
                              child: Row(
                                children: [
                                  for (final file in files.split(''))
                                    Expanded(child: label(file, side)),
                                ],
                              ),
                            ),
                          ),
                        for (final side in ['left', 'right'])
                          Positioned(
                            top: inset,
                            bottom: inset,
                            left: side == 'left' ? 0 : null,
                            right: side == 'right' ? 0 : null,
                            width: inset,
                            child: IgnorePointer(
                              child: Column(
                                children: [
                                  for (final rank in ranks.split(''))
                                    Expanded(child: label(rank, side)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          )
        : _buildGrid(context),
  );

  Widget _buildGrid(BuildContext context) => Stack(
    children: [
      _buildSquares(context),
      if (_movement != null)
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: Padding(
                padding: widget.showCoordinates
                    ? EdgeInsets.zero
                    : EdgeInsets.only(
                        top: MediaQuery.paddingOf(context).top,
                        bottom: MediaQuery.paddingOf(context).bottom,
                      ),
                child: AnimatedBuilder(
                  animation: _motion,
                  builder: (context, _) => _buildMovement(context),
                ),
              ),
            ),
          ),
        ),
      if (!_swipeHintDismissed &&
          widget.swipeHint != null &&
          widget.onSetSwipe != null)
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  key: const ValueKey('board-swipe-hint'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xEE243C50),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF9BCBDD)),
                  ),
                  child: Text(
                    widget.swipeHint!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );

  Widget _buildMovement(BuildContext context) {
    final movement = _movement;
    if (movement == null) return const SizedBox.shrink();
    final look = widget.appearance ?? BoardAppearance.forPack(piecePacks.first);
    final progress = _motion.value;
    final travel = Curves.easeInOutCubic.transform(
      ((progress - .08) / (animatedMoveImpactFraction - .08)).clamp(0.0, 1.0),
    );
    final loss = Curves.easeOutCubic.transform(
      ((progress - animatedMoveImpactFraction) /
              (.80 - animatedMoveImpactFraction))
          .clamp(0.0, 1.0),
    );

    Widget piece(Piece value) => CharacterPiece(
      piece: value,
      pack: look.army(value.color),
      standard: look.standardPieces,
      classicStyle: look.classicStyle,
      customSet: look.customSet,
      showRole: widget.showPieceRoles,
    );

    return LayoutBuilder(
      builder: (context, box) {
        final cell = box.maxWidth / 8;
        Offset offset(Square square) => widget.orientation == Side.white
            ? Offset(square.file.value * cell, (7 - square.rank.value) * cell)
            : Offset((7 - square.file.value) * cell, square.rank.value * cell);
        final captured = movement.captured;
        final captureSquare = movement.captureSquare;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            if (captured != null && captureSquare != null && loss < 1)
              Positioned(
                left: offset(captureSquare).dx,
                top: offset(captureSquare).dy,
                width: cell,
                height: cell,
                child: Opacity(
                  key: ValueKey('board-captured-${captureSquare.name}'),
                  opacity: 1 - loss,
                  child: Transform.rotate(
                    angle: (captured.color == Side.white ? -.12 : .12) * loss,
                    child: piece(captured),
                  ),
                ),
              ),
            for (final flight in movement.flights)
              if (flight.target != widget.hiddenPieceSquare)
                Builder(
                  builder: (context) {
                    final point = Offset.lerp(
                      offset(flight.source),
                      offset(flight.target),
                      travel,
                    )!;
                    final hop = flight.original.role == Role.knight
                        ? -math.sin(travel * math.pi) * cell * .24
                        : 0.0;
                    return Positioned(
                      left: point.dx,
                      top: point.dy,
                      width: cell,
                      height: cell,
                      child: SizedBox.square(
                        key: ValueKey(
                          'board-moving-${flight.source.name}-${flight.target.name}',
                        ),
                        dimension: cell,
                        child: Transform.translate(
                          offset: Offset(0, hop),
                          child: Transform.scale(
                            key: ValueKey(
                              'board-flight-scale-${flight.source.name}',
                            ),
                            scale: 1 + (flight.startScale - 1) * (1 - travel),
                            child: piece(
                              progress < animatedMoveImpactFraction
                                  ? flight.original
                                  : flight.arrived,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
          ],
        );
      },
    );
  }

  Widget _buildSquares(BuildContext context) => GridView.builder(
    key: const ValueKey('board-playable-squares'),
    padding: widget.showCoordinates ? EdgeInsets.zero : null,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 8,
    ),
    itemCount: 64,
    itemBuilder: (context, index) {
      final look =
          widget.appearance ?? BoardAppearance.forPack(piecePacks.first);
      final row = index ~/ 8;
      final col = index % 8;
      final square = widget.orientation == Side.white
          ? Square(col + (7 - row) * 8)
          : Square(7 - col + row * 8);
      final piece = widget.position.board.pieceAt(square);
      final isSelected = widget.selected == square;
      final isTarget = widget.legalTargets.contains(square);
      final isSuggestedFrom = widget.suggestedFrom == square;
      final isSuggestedTo = widget.suggestedTo == square;
      final isLastMoveFrom = widget.lastMoveFrom == square;
      final isLastMoveTo = widget.lastMoveTo == square;
      final isThreatFrom = widget.threatFrom == square;
      final isThreatTarget = widget.threatTarget == square;
      final isThreatLanding = widget.threatLanding == square;
      final isCheckedKing =
          widget.position.isCheck &&
          widget.position.board.kingOf(widget.position.turn) == square;
      final light = (row + col).isEven;
      return Semantics(
        label:
            '${square.name} ${piece == null ? 'empty' : '${piece.color.name} ${piece.role.name}'}${isThreatFrom
                ? ', opponent attacker'
                : isThreatTarget
                ? ', threatened piece'
                : isThreatLanding
                ? ', en passant landing square'
                : ''}',
        selected: isSelected,
        button: true,
        child: GestureDetector(
          key: ValueKey('square-${square.name}'),
          onTap: () => widget.onSquareTap(square),
          onDoubleTap: !_swipeHintDismissed && widget.swipeHint != null
              ? _dismissSwipeHint
              : null,
          child: ColoredBox(
            color: isCheckedKing
                ? const Color(0xFFB71C1C).withValues(alpha: .72)
                : isSelected
                ? widget.accent.withValues(alpha: .74)
                : isSuggestedFrom
                ? const Color(0xFFFFC107).withValues(alpha: .62)
                : (isLastMoveFrom || isLastMoveTo) &&
                      !(square == widget.blinkingSquare && !widget.previewLit)
                ? const Color(0xFF29B6F6).withValues(alpha: .34)
                : light
                ? look.lightSquare
                : look.darkSquare,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (look.customSet != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: CustomBoardSurfacePainter(
                          look.customSet!.surface,
                        ),
                      ),
                    ),
                  ),
                if ((square == widget.previewFrom ||
                        square == widget.previewTo) &&
                    (square != widget.blinkingSquare || widget.previewLit))
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFC107).withValues(alpha: .38),
                          border: Border.all(
                            color: const Color(0xFFFFC107),
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (piece != null &&
                    square != widget.hiddenPieceSquare &&
                    !(_movement?.flights.any(
                          (flight) => flight.target == square,
                        ) ??
                        false))
                  AnimatedScale(
                    key: _pieceScaleKeys.putIfAbsent(square, GlobalKey.new),
                    duration: _reduced
                        ? Duration.zero
                        : widget.animateMoves
                        ? animatedSelectionDuration
                        : const Duration(milliseconds: 140),
                    scale: isSelected && look.customSet == null ? 1.12 : 1,
                    child: CharacterPiece(
                      piece: piece,
                      pack: look.army(piece.color),
                      standard: look.standardPieces,
                      classicStyle: look.classicStyle,
                      customSet: look.customSet,
                      showRole: widget.showPieceRoles,
                    ),
                  ),
                if (isTarget)
                  Container(
                    width: piece == null ? 15 : 42,
                    height: piece == null ? 15 : 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: piece == null
                          ? widget.accent.withValues(alpha: .72)
                          : Colors.transparent,
                      border: piece == null
                          ? null
                          : Border.all(color: widget.accent, width: 4),
                    ),
                  ),
                if (isSuggestedTo)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFC107).withValues(alpha: .27),
                          border: Border.all(
                            color: const Color(0xFFFFD740),
                            width: 4,
                          ),
                        ),
                        child: const Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(
                              Icons.flag_rounded,
                              key: ValueKey('best-move-target-icon'),
                              size: 16,
                              color: Color(0xFF4A3200),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (isSuggestedFrom)
                  const Positioned(
                    left: 2,
                    top: 2,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0xFFFFD740),
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(
                            Icons.lightbulb_rounded,
                            key: ValueKey('best-move-origin-icon'),
                            size: 14,
                            color: Color(0xFF4A3200),
                          ),
                        ),
                      ),
                    ),
                  ),
                if ((isLastMoveFrom || isLastMoveTo) && !isSuggestedTo)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        key: ValueKey('last-move-${square.name}'),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.lightBlueAccent.withValues(alpha: .9),
                            width: isLastMoveTo ? 4 : 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (isThreatFrom || isThreatTarget || isThreatLanding)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        duration: _reduced
                            ? Duration.zero
                            : const Duration(milliseconds: 160),
                        opacity: widget.threatLit ? 1 : .22,
                        child: DecoratedBox(
                          key: ValueKey('threat-${square.name}'),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(
                              alpha: isThreatLanding ? .10 : .30,
                            ),
                            border: Border.all(
                              color: Colors.redAccent,
                              width: isThreatTarget ? 4 : 3,
                            ),
                          ),
                          child: Align(
                            alignment: Alignment.topRight,
                            child: Icon(
                              isThreatFrom
                                  ? Icons.gps_fixed
                                  : isThreatTarget
                                  ? Icons.warning_amber_rounded
                                  : Icons.subdirectory_arrow_right,
                              size: 15,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (isCheckedKing)
                  Positioned.fill(
                    child: _CheckedKingAlert(
                      reducedMotion: _reduced,
                      square: square,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _BoardPieceFlight {
  const _BoardPieceFlight({
    required this.source,
    required this.target,
    required this.original,
    required this.arrived,
    this.startScale = 1,
  });

  final Square source, target;
  final Piece original, arrived;
  final double startScale;
}

/// A verified single ply, used only to paint pieces over the current grid.
class _BoardMovePresentation {
  const _BoardMovePresentation({
    required this.flights,
    this.captured,
    this.captureSquare,
  });

  final List<_BoardPieceFlight> flights;
  final Piece? captured;
  final Square? captureSquare;

  static _BoardMovePresentation? accepted({
    required Position before,
    required Position after,
    required NormalMove move,
    required double startScale,
  }) {
    if (!before.isLegal(move) || before.play(move).fen != after.fen) {
      return null;
    }
    final original = before.board.pieceAt(move.from);
    if (original == null) return null;
    final castle =
        original.role == Role.king &&
        before.board.pieceAt(move.to)?.color == original.color;
    final target = castle ? after.board.kingOf(original.color) : move.to;
    if (target == null) return null;
    final arrived = after.board.pieceAt(target);
    if (arrived == null) return null;
    final flights = <_BoardPieceFlight>[
      _BoardPieceFlight(
        source: move.from,
        target: target,
        original: original,
        arrived: arrived,
        startScale: startScale,
      ),
    ];
    if (castle) {
      final rookTarget = Square.fromCoords(
        move.to.file > move.from.file ? File.f : File.d,
        move.from.rank,
      );
      final rook = before.board.pieceAt(move.to);
      final arrivedRook = after.board.pieceAt(rookTarget);
      if (rook == null || arrivedRook == null) return null;
      flights.add(
        _BoardPieceFlight(
          source: move.to,
          target: rookTarget,
          original: rook,
          arrived: arrivedRook,
        ),
      );
      return _BoardMovePresentation(flights: flights);
    }
    var captureSquare = target;
    var captured = before.board.pieceAt(target);
    if (captured == null &&
        original.role == Role.pawn &&
        before.epSquare == target) {
      captureSquare = Square.fromCoords(target.file, move.from.rank);
      captured = before.board.pieceAt(captureSquare);
    }
    return _BoardMovePresentation(
      flights: flights,
      captured: captured,
      captureSquare: captured == null ? null : captureSquare,
    );
  }
}

class _BoardReference extends StatelessWidget {
  const _BoardReference({
    required this.reference,
    required this.side,
    required this.fontSize,
  });

  final String reference, side;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Center(
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        reference,
        key: ValueKey(
          'board-${side == 'top' || side == 'bottom' ? 'file' : 'rank'}-$side-$reference',
        ),
        maxLines: 1,
        textScaler: MediaQuery.textScalerOf(
          context,
        ).clamp(minScaleFactor: .9, maxScaleFactor: 1.3),
        style: TextStyle(
          color: const Color(0xFFF1FCFF),
          fontSize: fontSize,
          height: 1,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

class _CheckedKingAlert extends StatefulWidget {
  const _CheckedKingAlert({required this.reducedMotion, required this.square});

  final bool reducedMotion;
  final Square square;

  @override
  State<_CheckedKingAlert> createState() => _CheckedKingAlertState();
}

class _CheckedKingAlertState extends State<_CheckedKingAlert>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    if (!widget.reducedMotion) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _CheckedKingAlert oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reducedMotion == oldWidget.reducedMotion) return;
    if (widget.reducedMotion) {
      _controller
        ..stop()
        ..value = 1;
    } else {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse = widget.reducedMotion ? 1.0 : _controller.value;
        return DecoratedBox(
          key: ValueKey('checked-king-${widget.square.name}'),
          decoration: BoxDecoration(
            color: const Color(
              0xFFFF1744,
            ).withValues(alpha: .10 + (.20 * pulse)),
            border: Border.all(
              color: Color.lerp(
                const Color(0xFFFF5252),
                Colors.white,
                pulse * .45,
              )!,
              width: 3 + (2 * pulse),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFFFF1744,
                ).withValues(alpha: .35 + (.35 * pulse)),
                blurRadius: 5 + (8 * pulse),
                spreadRadius: pulse * 2,
              ),
            ],
          ),
          child: const Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: EdgeInsets.all(2),
              child: Icon(
                Icons.warning_amber_rounded,
                key: ValueKey('checked-king-warning-icon'),
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// Keeps chess-set swipes and board inspection gestures unambiguous.
///
/// At 100%, [ChessSetSwipe] owns one-finger horizontal drags. A two-finger
/// pinch enlarges the board; while enlarged, one-finger drags pan and the
/// builder receives `true` so callers can disable set swipes.
class ZoomableChessBoard extends StatefulWidget {
  const ZoomableChessBoard({required this.builder, super.key});

  final Widget Function(BuildContext context, bool zoomed) builder;

  @override
  State<ZoomableChessBoard> createState() => _ZoomableChessBoardState();
}

class _ZoomableChessBoardState extends State<ZoomableChessBoard> {
  static const _maxScale = 3.0;
  final _transformation = TransformationController();
  final _pointers = <int>{};
  double _scale = 1;
  bool _pinching = false;

  bool get _zoomed => _scale > 1.001;

  void _syncScale() {
    final next = _transformation.value.getMaxScaleOnAxis().clamp(
      1.0,
      _maxScale,
    );
    if ((next - _scale).abs() > .01) setState(() => _scale = next);
  }

  void _finishInteraction() {
    _syncScale();
    if (_transformation.value.getMaxScaleOnAxis() <= 1.05) {
      _transformation.value = Matrix4.identity();
      if (_scale != 1) setState(() => _scale = 1);
    }
  }

  void _pointerDown(PointerDownEvent event) {
    _pointers.add(event.pointer);
    if (_pointers.length >= 2 && !_pinching) {
      setState(() => _pinching = true);
    }
  }

  void _pointerEnded(PointerEvent event) {
    _pointers.remove(event.pointer);
    if (_pointers.length < 2 && _pinching) {
      setState(() => _pinching = false);
    }
  }

  @override
  void dispose() {
    _transformation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _pointerDown,
    onPointerUp: _pointerEnded,
    onPointerCancel: _pointerEnded,
    child: InteractiveViewer(
      key: const ValueKey('chessboard-pan-zoom-viewer'),
      transformationController: _transformation,
      minScale: 1,
      maxScale: _maxScale,
      panEnabled: _zoomed,
      scaleEnabled: true,
      clipBehavior: Clip.hardEdge,
      onInteractionUpdate: (_) => _syncScale(),
      onInteractionEnd: (_) => _finishInteraction(),
      child: widget.builder(context, _zoomed || _pinching),
    ),
  );
}

class MoveStrip extends StatelessWidget {
  const MoveStrip({super.key, required this.moves, required this.accent});
  final List<String> moves;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (moves.isEmpty) {
      return const Text(
        'Select a piece to see its legal moves.',
        textAlign: TextAlign.center,
      );
    }
    final rows = <TableRow>[
      TableRow(
        decoration: BoxDecoration(color: accent.withValues(alpha: .18)),
        children: const [
          _MoveCell('Move', header: true),
          _MoveCell('White', header: true),
          _MoveCell('Black', header: true),
        ],
      ),
      for (var index = 0; index < moves.length; index += 2)
        TableRow(
          decoration: BoxDecoration(
            color: (index ~/ 2).isEven
                ? Colors.white.withValues(alpha: .035)
                : Colors.transparent,
          ),
          children: [
            _MoveCell('${index ~/ 2 + 1}.'),
            _MoveCell(moves[index]),
            _MoveCell(index + 1 < moves.length ? moves[index + 1] : '—'),
          ],
        ),
    ];
    return Container(
      key: const ValueKey('move-history-table'),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: .28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(72),
          1: FlexColumnWidth(),
          2: FlexColumnWidth(),
        },
        border: TableBorder(
          horizontalInside: BorderSide(
            color: Colors.white.withValues(alpha: .1),
          ),
          verticalInside: BorderSide(
            color: Colors.white.withValues(alpha: .08),
          ),
        ),
        children: rows,
      ),
    );
  }
}

class _MoveCell extends StatelessWidget {
  const _MoveCell(this.text, {this.header = false});
  final String text;
  final bool header;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    child: Text(
      text,
      style: TextStyle(
        fontWeight: header ? FontWeight.w900 : FontWeight.w700,
        color: header ? Colors.white : Colors.white.withValues(alpha: .88),
      ),
    ),
  );
}

class TurnIndicator extends StatelessWidget {
  const TurnIndicator({
    required this.isPlayerTurn,
    required this.playerLabel,
    required this.opponentLabel,
    super.key,
  });

  final bool isPlayerTurn;
  final String playerLabel;
  final String opponentLabel;

  Color get color =>
      isPlayerTurn ? const Color(0xFF25C978) : const Color(0xFF5C7CFA);

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    key: const ValueKey('turn-indicator'),
    duration: const Duration(milliseconds: 240),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .22),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color, width: 2),
      boxShadow: [
        BoxShadow(color: color.withValues(alpha: .24), blurRadius: 14),
      ],
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          isPlayerTurn ? Icons.play_circle_fill : Icons.hourglass_top,
          color: color,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            isPlayerTurn ? playerLabel : opponentLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: .4,
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
  );
}

class TopBarRestoreButton extends StatelessWidget {
  const TopBarRestoreButton({
    required this.accent,
    required this.onPressed,
    super.key,
  });
  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black.withValues(alpha: .66),
    shape: CircleBorder(side: BorderSide(color: accent.withValues(alpha: .7))),
    child: IconButton(
      tooltip: 'Show top bar',
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
      icon: const Icon(Icons.keyboard_arrow_down),
    ),
  );
}

String pieceSymbol(Piece piece) {
  const white = <Role, String>{
    Role.king: '♔',
    Role.queen: '♕',
    Role.rook: '♖',
    Role.bishop: '♗',
    Role.knight: '♘',
    Role.pawn: '♙',
  };
  const black = <Role, String>{
    Role.king: '♚',
    Role.queen: '♛',
    Role.rook: '♜',
    Role.bishop: '♝',
    Role.knight: '♞',
    Role.pawn: '♟',
  };
  return (piece.color == Side.white ? white : black)[piece.role]!;
}
