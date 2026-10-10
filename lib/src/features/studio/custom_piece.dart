// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../../domain/custom_chess_set.dart';
import '../../domain/piece_pack.dart';
import '../play/themed_piece_sprite.dart';

/// A constrained jigsaw model built from complete themed-piece formations.
///
/// Mount, rider, costume, face, weapon and orientation remain one authored
/// silhouette. Studio users can swap the compatible formation tile for each
/// chess role, but cannot create floating riders or intersecting body parts.
abstract final class CustomPieceParts {
  static const atlas = 'assets/characters/kingdoms/chola-v3.png';
  static const categories = ['formation'];
  static const formationPacks = [
    PiecePackId.chola,
    PiecePackId.roman,
    PiecePackId.chinese,
    PiecePackId.asgard,
  ];
  static const availableFormationPacks = availablePiecePacks;

  static String categoryLabel(String category) => 'Complete formation';

  static List<String> labels(String category) => const [
    'Ivory court',
    'Crimson legion',
    'Jade dynasty',
    'Radiant realm',
  ];

  static List<String> supportedCategories(Role role) => categories;

  static PiecePack packForVariant(int variant) {
    final id = formationPacks[variant.clamp(0, formationPacks.length - 1)];
    return piecePacks.singleWhere((pack) => pack.id == id);
  }

  static PiecePack packForDesign(CustomPieceDesign design) =>
      design.formationPack == null
      ? packForVariant(design.costume)
      : piecePacks.singleWhere((pack) => pack.id == design.formationPack);

  static String formationName(Role role) => switch (role) {
    Role.king => 'King',
    Role.queen => 'Queen',
    Role.bishop => 'Elephant & bishop rider',
    Role.knight => 'Horse & knight rider',
    Role.rook => 'Chariot & rook rider',
    Role.pawn => 'Lean pawn guard',
  };
}

class CustomPiece extends StatelessWidget {
  const CustomPiece({
    required this.piece,
    required this.chessSet,
    this.showRole = true,
    super.key,
  });

  final Piece piece;
  final CustomChessSet chessSet;
  final bool showRole;

  @override
  Widget build(BuildContext context) {
    final design = chessSet.designFor(piece.color, piece.role);
    return _FormationSprite(
      piece: piece,
      variant: design.costume,
      packOverride: CustomPieceParts.packForDesign(design),
      showRole: showRole,
      accent: Color(
        piece.color == Side.white ? chessSet.whiteAccent : chessSet.blackAccent,
      ),
    );
  }
}

class CustomPartThumbnail extends StatelessWidget {
  const CustomPartThumbnail({
    required this.category,
    required this.variant,
    required this.role,
    this.side = Side.white,
    this.pack,
    super.key,
  });

  final String category;
  final int variant;
  final Role role;
  final Side side;
  final PiecePack? pack;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label:
        '${pack?.name ?? CustomPieceParts.labels(category)[variant.clamp(0, 3)]}, ${pack == null ? CustomPieceParts.formationName(role) : role.name}',
    child: _FormationSprite(
      piece: Piece(color: side, role: role),
      variant: variant,
      showRole: false,
      accent: (pack ?? CustomPieceParts.packForVariant(variant)).accent,
      packOverride: pack,
    ),
  );
}

class _FormationSprite extends StatelessWidget {
  const _FormationSprite({
    required this.piece,
    required this.variant,
    required this.showRole,
    required this.accent,
    this.packOverride,
  });

  final Piece piece;
  final int variant;
  final bool showRole;
  final Color accent;
  final PiecePack? packOverride;

  static const roles = [
    Role.king,
    Role.queen,
    Role.bishop,
    Role.knight,
    Role.rook,
    Role.pawn,
  ];

  @override
  Widget build(BuildContext context) {
    final pack = packOverride ?? CustomPieceParts.packForVariant(variant);
    final kingdom = pack.id.index >= 4;
    final asset = kingdom
        ? 'assets/characters/kingdoms/${pack.id.name}-v3.png'
        : 'assets/characters/themed-piece-atlas-fantasy-vivid-v5.png';
    final rows = kingdom ? 2 : 8;
    final row =
        (kingdom ? 0 : pack.id.index * 2) + (piece.color == Side.white ? 0 : 1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest.shortestSide;
        return SizedBox.square(
          dimension: size,
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(.5),
                  child: ExcludeSemantics(
                    child: ThemedPieceSprite(
                      asset: asset,
                      row: row,
                      column: roles.indexOf(piece.role),
                      rows: rows,
                      role: piece.role,
                      // Every source faces right. Mirror the complete formation,
                      // including its rider and weapon, for Black.
                      flipX: piece.color == Side.black,
                      brightenDarkArmy: piece.color == Side.black,
                    ),
                  ),
                ),
              ),
              if (showRole)
                Positioned(
                  right: 1,
                  bottom: 1,
                  child: _RoleBadge(
                    role: piece.role,
                    white: piece.color == Side.white,
                    accent: accent,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({
    required this.role,
    required this.white,
    required this.accent,
  });

  final Role role;
  final bool white;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
    decoration: BoxDecoration(
      color: white ? const Color(0xFFF8F0DD) : const Color(0xFF161525),
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: accent.withValues(alpha: .75), width: .6),
    ),
    child: Text(
      switch (role) {
        Role.king => 'K',
        Role.queen => 'Q',
        Role.bishop => 'B',
        Role.knight => 'N',
        Role.rook => 'R',
        Role.pawn => 'P',
      },
      style: TextStyle(
        fontSize: 8,
        height: 1,
        fontWeight: FontWeight.w900,
        color: white ? Colors.black87 : Colors.white,
      ),
    ),
  );
}
