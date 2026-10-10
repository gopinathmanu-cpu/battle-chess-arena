// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:dartchess/dartchess.dart';

import 'capture_threat.dart';
import 'game_session.dart';

/// One victim or king bubble. Capture destinations can differ from the victim's
/// square for en passant. A possible check maps legal checking destinations;
/// an actual checked king has no capture destination.
class NeonLiveThreat {
  NeonLiveThreat({
    required this.piece,
    required this.square,
    required Iterable<Square> destinations,
    this.isCheck = false,
    this.possibleCheck = false,
  }) : destinations = Set.unmodifiable(destinations),
       assert(!(isCheck && possibleCheck)),
       assert(!(isCheck || possibleCheck) || piece.role == Role.king);

  final Piece piece;
  final Square square;
  final Set<Square> destinations;
  final bool isCheck;
  final bool possibleCheck;
  bool get isKingThreat => piece.role == Role.king;
}

/// The rook's verified part of a committed castle. A selected king has no
/// companion move, even when castling is one of its legal destinations.
class NeonLiveCastling {
  const NeonLiveCastling({
    required this.rook,
    required this.source,
    required this.target,
    required this.kingside,
  });

  final Piece rook;
  final Square source;
  final Square target;
  final bool kingside;
}

/// Immutable facts for the live illustrated arena. Selection and committed
/// moves use the same viewer-relative lane so a character keeps its facing.
class NeonLiveAction {
  const NeonLiveAction._({
    required this.actor,
    required this.source,
    required this.target,
    required this.actorOnLeft,
    required this.isSelection,
    required this.threats,
    required this.captured,
    required this.captureSquare,
    required this.castling,
  });

  final Piece actor;
  final Square source;
  final Square? target;
  final bool actorOnLeft;
  final bool isSelection;
  final List<NeonLiveThreat> threats;
  final Piece? captured;
  final Square? captureSquare;
  final NeonLiveCastling? castling;

  static NeonLiveAction? selection({
    required Position position,
    required Square source,
    Side viewerSide = Side.white,
  }) {
    final piece = position.board.pieceAt(source);
    if (piece == null || piece.color != position.turn || _terminal(position)) {
      return null;
    }
    final captures = <Square, Set<Square>>{};
    final checkDestinations = <Square>{};
    for (final destination in position.legalMovesOf(source).squares) {
      final promotion =
          piece.role == Role.pawn &&
          (destination.rank == Rank.first || destination.rank == Rank.eighth);
      for (final role
          in promotion
              ? const [Role.queen, Role.rook, Role.bishop, Role.knight]
              : const <Role?>[null]) {
        final move = NormalMove(from: source, to: destination, promotion: role);
        if (!position.isLegal(move)) continue;
        final target = _target(piece, move);
        final victimSquare = _victimSquare(position, piece, move);
        if (victimSquare != null) {
          captures.putIfAbsent(victimSquare, () => {}).add(target);
        }
        if (position.play(move).isCheck) checkDestinations.add(target);
      }
    }
    final threats = <NeonLiveThreat>[
      for (final entry in captures.entries)
        NeonLiveThreat(
          piece: position.board.pieceAt(entry.key)!,
          square: entry.key,
          destinations: entry.value,
        ),
    ];
    final king = position.board.kingOf(piece.color.opposite);
    if (king != null && checkDestinations.isNotEmpty) {
      threats.add(
        NeonLiveThreat(
          piece: position.board.pieceAt(king)!,
          square: king,
          destinations: checkDestinations,
          possibleCheck: true,
        ),
      );
    }
    return NeonLiveAction._(
      actor: piece,
      source: source,
      target: null,
      actorOnLeft: piece.color == viewerSide,
      isSelection: true,
      threats: _ordered(threats),
      captured: null,
      captureSquare: null,
      castling: null,
    );
  }

  static NeonLiveAction? move({
    required Position before,
    required Position after,
    required MoveResolution resolution,
    required Side viewerSide,
  }) {
    final move = resolution.move;
    final original = before.board.pieceAt(move.from);
    if (original != resolution.attacker ||
        original == null ||
        original.color != before.turn ||
        _terminal(before) ||
        !before.isLegal(move)) {
      return null;
    }
    final (expected, san) = before.makeSan(move);
    if (expected.fen != after.fen || san != resolution.san) return null;
    final target = _target(original, move);
    final actor = after.board.pieceAt(target);
    if (actor == null || actor.color != original.color) return null;
    final capturedSquare = _victimSquare(before, original, move);
    final captured = capturedSquare == null
        ? null
        : before.board.pieceAt(capturedSquare);
    if (captured != resolution.defender) return null;
    final castling = _castling(before, after, original, move);
    final grouped = <Square, Set<Square>>{};
    for (final threat in immediateCaptureThreats(
      after,
      defender: actor.color.opposite,
    )) {
      if (threat.from != target || threat.isCheck) continue;
      grouped.putIfAbsent(threat.targetSquare, () => {}).add(threat.to);
    }
    final threats = <NeonLiveThreat>[
      for (final entry in grouped.entries)
        NeonLiveThreat(
          piece: after.board.pieceAt(entry.key)!,
          square: entry.key,
          destinations: entry.value,
        ),
    ];
    final king = after.board.kingOf(actor.color.opposite);
    // A move can uncover another piece's check (including the castled rook).
    if (after.isCheck && king != null) {
      threats.add(
        NeonLiveThreat(
          piece: after.board.pieceAt(king)!,
          square: king,
          destinations: const [],
          isCheck: true,
        ),
      );
    }
    return NeonLiveAction._(
      actor: actor,
      source: move.from,
      target: target,
      actorOnLeft: actor.color == viewerSide,
      isSelection: false,
      threats: _ordered(threats),
      captured: captured,
      captureSquare: capturedSquare,
      castling: castling,
    );
  }
}

NeonLiveCastling? _castling(
  Position before,
  Position after,
  Piece actor,
  NormalMove move,
) {
  if (actor.role != Role.king ||
      move.from.file != File.e ||
      move.from.rank != move.to.rank ||
      (move.to.file != File.h && move.to.file != File.a)) {
    return null;
  }
  final rook = before.board.pieceAt(move.to);
  if (rook?.role != Role.rook || rook!.color != actor.color) return null;
  final kingside = move.to.file == File.h;
  final target = Square.fromCoords(kingside ? File.f : File.d, move.from.rank);
  if (after.board.pieceAt(target) != rook ||
      after.board.pieceAt(move.to) != null) {
    return null;
  }
  return NeonLiveCastling(
    rook: rook,
    source: move.to,
    target: target,
    kingside: kingside,
  );
}

bool _terminal(Position position) =>
    position.isGameOver || position.halfmoves >= 100;

Square _target(Piece piece, NormalMove move) =>
    piece.role == Role.king &&
        move.from.file == File.e &&
        (move.to.file == File.h || move.to.file == File.a)
    ? Square.fromCoords(
        move.to.file == File.h ? File.g : File.c,
        move.from.rank,
      )
    : move.to;

Square? _victimSquare(Position position, Piece piece, NormalMove move) {
  final victim = position.board.pieceAt(move.to);
  if (victim != null) {
    return victim.color != piece.color && victim.role != Role.king
        ? move.to
        : null;
  }
  if (piece.role == Role.pawn &&
      position.epSquare == move.to &&
      move.from.file != move.to.file) {
    final square = Square.fromCoords(move.to.file, move.from.rank);
    final pawn = position.board.pieceAt(square);
    if (pawn?.role == Role.pawn && pawn!.color != piece.color) return square;
  }
  return null;
}

List<NeonLiveThreat> _ordered(List<NeonLiveThreat> threats) {
  const values = {
    Role.king: 10000,
    Role.queen: 9,
    Role.rook: 5,
    Role.bishop: 3,
    Role.knight: 3,
    Role.pawn: 1,
  };
  threats.sort((a, b) {
    final value = values[b.piece.role]!.compareTo(values[a.piece.role]!);
    return value != 0 ? value : a.square.name.compareTo(b.square.name);
  });
  return List.unmodifiable(threats);
}
