// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import '../../domain/piece_pack.dart';
import '../../services/theme_music.dart';

class BoardAppearance {
  const BoardAppearance({
    required this.white,
    required this.black,
    required this.board,
  });
  factory BoardAppearance.forPack(PiecePack pack) =>
      BoardAppearance(white: pack, black: pack, board: pack);
  final PiecePack white;
  final PiecePack black;
  final PiecePack board;
  PiecePack army(Side side) => side == Side.white ? white : black;
}

extension PieceWorld on PiecePack {
  Color get lightSquare => switch (id) {
    PiecePackId.anime => const Color(0xFFE8D6D0),
    PiecePackId.indianEpic => const Color(0xFFF0D6A0),
    PiecePackId.greek => const Color(0xFFE0EBEE),
    PiecePackId.futuristic => const Color(0xFF526E85),
    PiecePackId.classic => const Color(0xFFE9DBBD),
  };
  Color get darkSquare => switch (id) {
    PiecePackId.anime => const Color(0xFF61415E),
    PiecePackId.indianEpic => const Color(0xFF856039),
    PiecePackId.greek => const Color(0xFF476585),
    PiecePackId.futuristic => const Color(0xFF15253E),
    PiecePackId.classic => const Color(0xFF68513F),
  };
  Color get backdrop => Color.lerp(darkSquare, Colors.black, .78)!;
  String armyName(Side side) {
    const names = [
      ['Dawn Guard', 'Dusk Raiders'],
      ['Solar Guardians', 'Moon Sentinels'],
      ['Olympian Court', 'Underworld Legion'],
      ['Aurora Command', 'Void Command'],
      ['Ivory Court', 'Obsidian Court'],
    ];
    return names[id.index][side == Side.white ? 0 : 1];
  }
}

/// One atlas shared by every board cell; Flutter caches the decoded image.
class CharacterPiece extends StatelessWidget {
  const CharacterPiece({
    required this.piece,
    required this.pack,
    this.showRole = true,
    super.key,
  });
  static const atlas = 'assets/characters/themed-piece-atlas-transparent.png';
  static const roles = [
    Role.king,
    Role.queen,
    Role.bishop,
    Role.knight,
    Role.rook,
    Role.pawn,
  ];
  final Piece piece;
  final PiecePack pack;
  final bool showRole;
  int get atlasRow => pack.id.index * 2 + (piece.color == Side.white ? 0 : 1);
  int get atlasColumn => roles.indexOf(piece.role);
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest.shortestSide;
      // Art-directed atlas rows are not uniform; keep explicit source bounds.
      const columns = [0.0, 180.0, 348.0, 504.0, 666.0, 818.0, 971.0];
      const rows = [
        0.0,
        198.0,
        389.0,
        578.0,
        765.0,
        944.0,
        1120.0,
        1278.0,
        1427.0,
        1541.0,
        1619.0,
      ];
      final left = columns[atlasColumn];
      final top = rows[atlasRow];
      final width = columns[atlasColumn + 1] - left;
      final height = rows[atlasRow + 1] - top;
      return SizedBox.square(
        dimension: size,
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: ExcludeSemantics(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: width,
                      height: height,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: OverflowBox(
                          alignment: Alignment(
                            -1 + 2 * left / (971 - width),
                            -1 + 2 * top / (1619 - height),
                          ),
                          minWidth: 971,
                          maxWidth: 971,
                          minHeight: 1619,
                          maxHeight: 1619,
                          child: Image.asset(
                            atlas,
                            fit: BoxFit.fill,
                            filterQuality: FilterQuality.medium,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (showRole)
              Positioned(
                right: 1,
                bottom: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: piece.color == Side.white
                        ? const Color(0xFFF8F0DD)
                        : const Color(0xFF161525),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: pack.accent.withValues(alpha: .7),
                      width: .6,
                    ),
                  ),
                  child: Text(
                    switch (piece.role) {
                      Role.king => 'K',
                      Role.queen => 'Q',
                      Role.rook => 'R',
                      Role.bishop => 'B',
                      Role.knight => 'N',
                      Role.pawn => 'P',
                    },
                    style: TextStyle(
                      fontSize: 8,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      color: piece.color == Side.white
                          ? Colors.black87
                          : Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

Future<BoardAppearance?> chooseBoardAppearance(
  BuildContext context,
  BoardAppearance current,
) {
  var white = current.white;
  var black = current.black;
  var board = current.board;
  return showDialog<BoardAppearance>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, refresh) {
        Widget field(
          String label,
          PiecePack value,
          ValueChanged<PiecePack> changed,
        ) => DropdownButtonFormField<PiecePack>(
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: piecePacks
              .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
              .toList(),
          onChanged: (p) {
            if (p != null) refresh(() => changed(p));
          },
        );
        return AlertDialog(
          title: const Text('Armies & board'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                field('White army', white, (p) => white = p),
                const SizedBox(height: 12),
                field('Black army', black, (p) => black = p),
                const SizedBox(height: 12),
                field('Board world', board, (p) => board = p),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    SizedBox.square(
                      dimension: 76,
                      child: CharacterPiece(
                        piece: const Piece(color: Side.white, role: Role.king),
                        pack: white,
                      ),
                    ),
                    SizedBox.square(
                      dimension: 76,
                      child: CharacterPiece(
                        piece: const Piece(color: Side.black, role: Role.king),
                        pack: black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Appearance changes only. Chess roles and turns stay the same.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                BoardAppearance(white: white, black: black, board: board),
              ),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    ),
  );
}

class WorldBackdrop extends StatelessWidget {
  const WorldBackdrop({required this.pack, required this.child, super.key});
  final PiecePack pack;
  final Widget child;
  @override
  Widget build(BuildContext context) => ThemeSoundtrack(
    theme: pack.id,
    child: Stack(
      children: [
        Positioned.fill(
          child: ExcludeSemantics(
            child: ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: 256,
                  height: 204.8,
                  child: ClipRect(
                    child: OverflowBox(
                      minWidth: 1536,
                      maxWidth: 1536,
                      minHeight: 1024,
                      maxHeight: 1024,
                      alignment: Alignment(1, -1 + pack.id.index * .5),
                      child: Image.asset(
                        'assets/concepts/piece-families.png',
                        fit: BoxFit.fill,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  pack.backdrop.withValues(alpha: .48),
                  pack.backdrop.withValues(alpha: .78),
                ],
              ),
            ),
          ),
        ),
        SafeArea(child: child),
      ],
    ),
  );
}
