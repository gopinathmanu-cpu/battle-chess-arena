// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:dartchess/dartchess.dart';

import 'game_session.dart';

/// Reconstructs captures from the complete authoritative history, including
/// reconnect gaps. Never guesses from material counts, which fail on promotions.
List<Piece>? capturedPiecesFromSan(
  Iterable<String> san, {
  required Position expectedPosition,
}) {
  final replay = GameSession();
  for (final notation in san) {
    final move = replay.position.parseSan(notation);
    if (move is! NormalMove ||
        replay.play(
              move.from,
              move.to,
              promotion: move.promotion ?? Role.queen,
            ) ==
            null) {
      return null;
    }
  }
  return replay.position.fen == expectedPosition.fen
      ? replay.capturedPieces
      : null;
}
