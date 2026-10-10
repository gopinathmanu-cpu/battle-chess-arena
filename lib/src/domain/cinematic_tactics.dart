// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:dartchess/dartchess.dart';

import 'capture_threat.dart';
import 'cinematic_replay.dart';
import 'cinematic_threats.dart';

/// A single piece newly attacking at least two non-pawn targets. A checked king
/// can be one target; it is never a capturable piece. This describes the present
/// board, without claiming the fork wins material or cannot be answered.
class CinematicFork {
  CinematicFork({
    required this.attacker,
    required this.source,
    required List<CinematicThreat> targets,
  }) : targets = List.unmodifiable(targets);

  final Piece attacker;
  final Square source;
  final List<CinematicThreat> targets;
}

/// Factual consequences of a recorded move. Opponent threats use legal capture
/// opportunities projected for the moving army; replies use the opponent's real
/// turn, including check restrictions and its actual en-passant right.
class CinematicTactics {
  const CinematicTactics._({
    required this.opponentThreats,
    required this.ownPiecesAtRisk,
    required this.newForks,
    required this.materialBefore,
    required this.materialAfter,
  });

  factory CinematicTactics.after(CinematicReplayScene scene) {
    final threats = cinematicThreatsAfter(scene);
    final beforeAttacks = immediateCaptureThreats(
      scene.before,
      defender: scene.side.opposite,
    );
    final priorTargets = <Square, Set<Square>>{};
    for (final attack in beforeAttacks) {
      if (attack.target.role == Role.pawn) continue;
      priorTargets.putIfAbsent(attack.from, () => {}).add(attack.targetSquare);
    }
    final targetsBySource = <Square, List<CinematicThreat>>{};
    for (final threat in threats) {
      if (threat.piece.role == Role.pawn) continue;
      for (final source in threat.sourceSquares) {
        targetsBySource.putIfAbsent(source, () => []).add(threat);
      }
    }
    final forks = <CinematicFork>[];
    for (final entry in targetsBySource.entries) {
      if (entry.value.length < 2) continue;
      final previous = priorTargets[entry.key] ?? const <Square>{};
      if (entry.value.every((target) => previous.contains(target.square))) {
        continue;
      }
      forks.add(
        CinematicFork(
          attacker: scene.after.board.pieceAt(entry.key)!,
          source: entry.key,
          targets: entry.value,
        ),
      );
    }
    int priority(CinematicFork fork) => fork.targets.fold(
      0,
      (total, target) =>
          total + (target.isCheck ? 100 : _value(target.piece.role)),
    );
    forks.sort((a, b) {
      final comparison = priority(b).compareTo(priority(a));
      return comparison != 0
          ? comparison
          : a.source.name.compareTo(b.source.name);
    });
    return CinematicTactics._(
      opponentThreats: threats,
      ownPiecesAtRisk: _groupReplies(scene),
      newForks: List.unmodifiable(forks),
      materialBefore: _balance(scene.before, scene.side),
      materialAfter: _balance(scene.after, scene.side),
    );
  }

  final List<CinematicThreat> opponentThreats;
  final List<CinematicThreat> ownPiecesAtRisk;
  final List<CinematicFork> newForks;

  /// Conventional material points relative to the army that just moved:
  /// pawn=1, knight/bishop=3, rook=5, queen=9. This is not an engine evaluation.
  final int materialBefore;
  final int materialAfter;
  int get materialGain => materialAfter - materialBefore;
}

List<CinematicThreat> _groupReplies(CinematicReplayScene scene) {
  final existing = immediateCaptureThreats(
    scene.before,
    defender: scene.side,
  ).map((attack) => attack.targetSquare).toSet();
  final grouped = <Square, List<CaptureThreat>>{};
  for (final attack in immediateCaptureThreats(
    scene.after,
    defender: scene.side,
  )) {
    grouped.putIfAbsent(attack.targetSquare, () => []).add(attack);
  }
  final replies = grouped.entries
      .map(
        (entry) => CinematicThreat(
          piece: entry.value.first.target,
          square: entry.key,
          attacks: entry.value,
          newlyThreatened: !existing.contains(entry.key),
        ),
      )
      .toList();
  replies.sort((a, b) {
    final value = _value(b.piece.role).compareTo(_value(a.piece.role));
    return value != 0 ? value : a.square.name.compareTo(b.square.name);
  });
  return List.unmodifiable(replies);
}

int _balance(Position position, Side side) {
  var total = 0;
  for (final square in position.board.occupied.squares) {
    final piece = position.board.pieceAt(square)!;
    total += _value(piece.role) * (piece.color == side ? 1 : -1);
  }
  return total;
}

int _value(Role role) => switch (role) {
  Role.pawn => 1,
  Role.knight || Role.bishop => 3,
  Role.rook => 5,
  Role.queen => 9,
  Role.king => 0,
};
