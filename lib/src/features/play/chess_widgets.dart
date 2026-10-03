// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
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
  Widget build(BuildContext context) => Row(
    children: [
      _Clock(
        label: 'WHITE',
        time: timed ? _format(whiteTime) : '--:--',
        active: turn == Side.white,
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            status,
            textAlign: TextAlign.center,
            style: TextStyle(color: accent, fontWeight: FontWeight.w800),
          ),
        ),
      ),
      _Clock(
        label: 'BLACK',
        time: timed ? _format(blackTime) : '--:--',
        active: turn == Side.black,
      ),
    ],
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

class ChessBoard extends StatelessWidget {
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
    this.lastMoveFrom,
    this.lastMoveTo,
    this.threatFrom,
    this.threatTarget,
    this.threatLanding,
    this.threatLit = true,
    this.showPieceRoles = true,
    this.onSetSwipe,
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
  final Square? lastMoveFrom;
  final Square? lastMoveTo;
  final Square? threatFrom;
  final Square? threatTarget;
  final Square? threatLanding;
  final bool threatLit;
  final bool showPieceRoles;
  final ValueChanged<int>? onSetSwipe;

  @override
  Widget build(BuildContext context) => ChessSetSwipe(
    onChange: onSetSwipe,
    child: GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
      ),
      itemCount: 64,
      itemBuilder: (context, index) {
        final look = appearance ?? BoardAppearance.forPack(piecePacks.first);
        final row = index ~/ 8;
        final col = index % 8;
        final square = orientation == Side.white
            ? Square(col + (7 - row) * 8)
            : Square(7 - col + row * 8);
        final piece = position.board.pieceAt(square);
        final isSelected = selected == square;
        final isTarget = legalTargets.contains(square);
        final isSuggestedFrom = suggestedFrom == square;
        final isSuggestedTo = suggestedTo == square;
        final isLastMoveFrom = lastMoveFrom == square;
        final isLastMoveTo = lastMoveTo == square;
        final isThreatFrom = threatFrom == square;
        final isThreatTarget = threatTarget == square;
        final isThreatLanding = threatLanding == square;
        final isCheckedKing =
            position.isCheck && position.board.kingOf(position.turn) == square;
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
            onTap: () => onSquareTap(square),
            child: ColoredBox(
              color: isCheckedKing
                  ? const Color(0xFFB71C1C).withValues(alpha: .72)
                  : isSelected
                  ? accent.withValues(alpha: .74)
                  : isSuggestedFrom
                  ? const Color(0xFFFFC107).withValues(alpha: .62)
                  : isLastMoveFrom || isLastMoveTo
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
                  if (piece != null && square != hiddenPieceSquare)
                    AnimatedScale(
                      duration: const Duration(milliseconds: 140),
                      scale: isSelected && look.customSet == null ? 1.12 : 1,
                      child: CharacterPiece(
                        piece: piece,
                        pack: look.army(piece.color),
                        standard: look.standardPieces,
                        classicStyle: look.classicStyle,
                        customSet: look.customSet,
                        showRole: showPieceRoles,
                      ),
                    ),
                  if (isTarget)
                    Container(
                      width: piece == null ? 15 : 42,
                      height: piece == null ? 15 : 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: piece == null
                            ? accent.withValues(alpha: .72)
                            : Colors.transparent,
                        border: piece == null
                            ? null
                            : Border.all(color: accent, width: 4),
                      ),
                    ),
                  if (isSuggestedTo)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFFFC107,
                            ).withValues(alpha: .27),
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
                              color: Colors.lightBlueAccent.withValues(
                                alpha: .9,
                              ),
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
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 160),
                          opacity: threatLit ? 1 : .22,
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
                        reducedMotion: MediaQuery.disableAnimationsOf(context),
                        square: square,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
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
