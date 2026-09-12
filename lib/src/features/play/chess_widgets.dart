// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import '../../domain/piece_pack.dart';
import 'board_appearance.dart';

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

  String _format(Duration value) =>
      '${value.inMinutes.toString().padLeft(2, '0')}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';

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

  @override
  Widget build(BuildContext context) => GridView.builder(
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
      final light = (row + col).isEven;
      return Semantics(
        label:
            '${square.name} ${piece == null ? 'empty' : '${piece.color.name} ${piece.role.name}'}',
        selected: isSelected,
        button: true,
        child: GestureDetector(
          key: ValueKey('square-${square.name}'),
          onTap: () => onSquareTap(square),
          child: ColoredBox(
            color: isSelected
                ? accent.withValues(alpha: .74)
                : isSuggestedFrom
                ? Colors.amber.withValues(alpha: .72)
                : light
                ? look.board.lightSquare
                : look.board.darkSquare,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (piece != null && square != hiddenPieceSquare)
                  AnimatedScale(
                    duration: const Duration(milliseconds: 140),
                    scale: isSelected ? 1.12 : 1,
                    child: CharacterPiece(
                      piece: piece,
                      pack: look.army(piece.color),
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
                          color: Colors.amber.withValues(alpha: .22),
                          border: Border.all(
                            color: Colors.amberAccent,
                            width: 4,
                          ),
                        ),
                      ),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        List.generate(
          moves.length,
          (i) => i.isEven ? '${i ~/ 2 + 1}. ${moves[i]}' : moves[i],
        ).join('  '),
        style: TextStyle(color: accent, fontWeight: FontWeight.w700),
      ),
    );
  }
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
