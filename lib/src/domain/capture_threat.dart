// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:dartchess/dartchess.dart';

class CaptureThreat {
  const CaptureThreat({
    required this.from,
    required this.to,
    required this.targetSquare,
    required this.attacker,
    required this.target,
    this.promotes = false,
    this.isCheck = false,
  });
  final Square from;
  final Square to;

  /// Differs from the landing square for en passant.
  final Square targetSquare;
  final Piece attacker;
  final Piece target;
  final bool promotes;
  final bool isCheck;
  bool get enPassant => targetSquare != to;

  String get description =>
      '${isCheck ? 'Check · ' : ''}${attacker.color.name} ${attacker.role.name} ${from.name} → ${to.name}: ${target.role.name} on ${targetSquare.name}${enPassant
          ? ' (en passant)'
          : promotes
          ? ' (promotion)'
          : ''}';
}

/// Current-board capture opportunities for the opposing army, not a search over
/// the player's possible next moves. A hypothetical turn flip never carries the
/// player's en-passant right forward. The real board/history remain unchanged.
List<CaptureThreat> immediateCaptureThreats(
  Position position, {
  required Side defender,
}) {
  final attackingSide = defender.opposite;
  final view = position.turn == attackingSide
      ? position
      : position.copyWith(turn: attackingSide, epSquare: null);
  final threats = <CaptureThreat>[];
  final kingSquare = view.board.kingOf(defender);
  if (kingSquare != null) {
    final king = view.board.pieceAt(kingSquare)!;
    for (final from
        in view.board.attacksTo(kingSquare, attackingSide).squares) {
      threats.add(
        CaptureThreat(
          from: from,
          to: kingSquare,
          targetSquare: kingSquare,
          attacker: view.board.pieceAt(from)!,
          target: king,
          isCheck: true,
        ),
      );
    }
  }
  for (final entry in view.legalMoves.entries) {
    final attacker = view.board.pieceAt(entry.key)!;
    for (final to in entry.value.squares) {
      var targetSquare = to;
      var target = view.board.pieceAt(to);
      if (target == null &&
          attacker.role == Role.pawn &&
          view.epSquare == to &&
          entry.key.file != to.file) {
        targetSquare = Square.fromCoords(to.file, entry.key.rank);
        target = view.board.pieceAt(targetSquare);
        if (target?.role != Role.pawn) continue;
      }
      // Castling is encoded king-to-own-rook. Kings are checked, never captured.
      if (target == null ||
          target.color != defender ||
          target.role == Role.king) {
        continue;
      }
      final promotes =
          attacker.role == Role.pawn &&
          (to.rank == Rank.first || to.rank == Rank.eighth);
      final move = NormalMove(
        from: entry.key,
        to: to,
        promotion: promotes ? Role.queen : null,
      );
      if (!view.isLegal(move)) continue;
      // All four promotion choices share a source/victim pair; show it once.
      threats.add(
        CaptureThreat(
          from: entry.key,
          to: to,
          targetSquare: targetSquare,
          attacker: attacker,
          target: target,
          promotes: promotes,
        ),
      );
    }
  }
  const values = {
    Role.queen: 900,
    Role.rook: 500,
    Role.bishop: 330,
    Role.knight: 320,
    Role.pawn: 100,
  };
  threats.sort((a, b) {
    if (a.isCheck != b.isCheck) return a.isCheck ? -1 : 1;
    final value = (values[b.target.role] ?? 10000).compareTo(
      values[a.target.role] ?? 10000,
    );
    if (value != 0) return value;
    final source = a.from.name.compareTo(b.from.name);
    return source != 0 ? source : a.to.name.compareTo(b.to.name);
  });
  return List.unmodifiable(threats);
}
