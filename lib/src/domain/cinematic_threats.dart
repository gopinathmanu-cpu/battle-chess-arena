// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:dartchess/dartchess.dart';

import 'capture_threat.dart';
import 'cinematic_replay.dart';

/// One opposing piece threatened after a recorded move, displayed once even
/// when several members of the moving army attack it.
class CinematicThreat {
  CinematicThreat({
    required this.piece,
    required this.square,
    required List<CaptureThreat> attacks,
    required this.newlyThreatened,
  }) : attacks = List.unmodifiable(attacks),
       sourceSquares = Set.unmodifiable(attacks.map((attack) => attack.from));

  final Piece piece;
  final Square square;
  final List<CaptureThreat> attacks;
  final Set<Square> sourceSquares;

  /// The victim was not already threatened by this army in the before-position.
  /// A second attacker joining an existing threat does not make the victim new.
  final bool newlyThreatened;

  /// The king is checked, never presented as a capturable piece.
  bool get isCheck => attacks.any((attack) => attack.isCheck);
}

/// All immediate threats from the army that just moved, in the actual resulting
/// position. This includes discovered attacks from pieces other than the mover;
/// it is not an engine forecast or a list of only newly created threats.
///
/// Non-king victims require a legal capture for that army on the current board.
/// The hypothetical turn projection discards the opponent's en-passant right.
/// Captured victims have already left [CinematicReplayScene.after] and cannot
/// appear. The replay and its immutable position snapshots remain unchanged.
List<CinematicThreat> cinematicThreatsAfter(CinematicReplayScene scene) {
  final defender = scene.side.opposite;
  final existingSquares = immediateCaptureThreats(
    scene.before,
    defender: defender,
  ).map((threat) => threat.targetSquare).toSet();
  final after = immediateCaptureThreats(scene.after, defender: defender);
  final victims = <Square, List<CaptureThreat>>{};
  for (final attack in after) {
    victims.putIfAbsent(attack.targetSquare, () => []).add(attack);
  }
  final threats = victims.entries.map((entry) {
    return CinematicThreat(
      piece: entry.value.first.target,
      square: entry.key,
      attacks: entry.value,
      newlyThreatened: !existingSquares.contains(entry.key),
    );
  }).toList();
  const values = {
    Role.king: 10000,
    Role.queen: 900,
    Role.rook: 500,
    Role.bishop: 330,
    Role.knight: 320,
    Role.pawn: 100,
  };
  threats.sort((a, b) {
    if (a.isCheck != b.isCheck) return a.isCheck ? -1 : 1;
    final value = values[b.piece.role]!.compareTo(values[a.piece.role]!);
    return value != 0 ? value : a.square.name.compareTo(b.square.name);
  });
  return List.unmodifiable(threats);
}
