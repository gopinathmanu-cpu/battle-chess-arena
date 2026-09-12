// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../../domain/piece_pack.dart';
import '../play/board_appearance.dart';

class OnlineAvatarImage extends StatelessWidget {
  const OnlineAvatarImage({required this.avatarId, this.size = 44, super.key});

  final String avatarId;
  final double size;

  (PiecePack, Piece) get _character => switch (avatarId) {
    'knight' => (
      piecePacks[0],
      const Piece(color: Side.white, role: Role.knight),
    ),
    'mage' => (
      piecePacks[2],
      const Piece(color: Side.black, role: Role.bishop),
    ),
    'dragon' => (
      piecePacks[1],
      const Piece(color: Side.black, role: Role.rook),
    ),
    'robot' => (piecePacks[3], const Piece(color: Side.white, role: Role.pawn)),
    'ranger' => (
      piecePacks[0],
      const Piece(color: Side.black, role: Role.bishop),
    ),
    'sun' => (piecePacks[1], const Piece(color: Side.white, role: Role.queen)),
    'moon' => (piecePacks[2], const Piece(color: Side.black, role: Role.queen)),
    _ => (piecePacks[4], const Piece(color: Side.white, role: Role.king)),
  };

  @override
  Widget build(BuildContext context) {
    final (pack, piece) = _character;
    return Semantics(
      image: true,
      label: '$avatarId avatar',
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: pack.darkSquare.withValues(alpha: .8),
          border: Border.all(color: pack.accent.withValues(alpha: .75)),
        ),
        child: ClipOval(
          child: CharacterPiece(piece: piece, pack: pack, showRole: false),
        ),
      ),
    );
  }
}
