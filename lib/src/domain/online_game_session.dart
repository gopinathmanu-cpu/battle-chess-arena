// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:dartchess/dartchess.dart';

import 'game_session.dart';
import 'online_game_state.dart';

/// Rules and display state only. Never mutates the canonical position locally.
class OnlineGameSession {
  OnlineGameSession({int Function()? nowMs}) {
    final stopwatch = Stopwatch()..start();
    _nowMs = nowMs ?? () => stopwatch.elapsedMilliseconds;
  }
  late final int Function() _nowMs;
  OnlineGameState? state;
  MoveResolution? committedCapture;
  int captureSequence = -1;
  int _receivedAt = 0;

  void clear() {
    state = null;
    committedCapture = null;
    captureSequence = -1;
    _receivedAt = 0;
  }

  bool apply(OnlineGameState next, {bool animate = true}) {
    final previous = state;
    if (previous != null &&
        (next.gameId != previous.gameId ||
            next.sequence <= previous.sequence)) {
      return false;
    }
    committedCapture = animate && previous != null
        ? detectCommittedCapture(previous, next)
        : null;
    if (committedCapture != null) captureSequence = next.sequence;
    state = next;
    _receivedAt = _nowMs();
    return true;
  }

  bool canMove(String? seat) =>
      state?.status == 'active' && state!.turn == seat;

  Set<Square> legalDestinations(Square from, String? seat) {
    if (!canMove(seat)) return const {};
    return GameSession(position: state!.position).legalDestinations(from);
  }

  Map<String, String>? moveRequest(
    Square from,
    Square to,
    String? seat, {
    Role promotion = Role.queen,
  }) {
    if (!legalDestinations(from, seat).contains(to)) return null;
    final game = GameSession(position: state!.position);
    if (game.play(from, to, promotion: promotion) == null) return null;
    return {
      'from': from.name,
      'to': to.name,
      'promotion': switch (promotion) {
        Role.queen => 'q',
        Role.rook => 'r',
        Role.bishop => 'b',
        Role.knight => 'n',
        _ => 'q',
      },
    };
  }

  int clockMs(String side) {
    final value = state;
    if (value == null) return 0;
    final base = side == 'w' ? value.whiteMs : value.blackMs;
    final elapsed = value.status == 'active' && value.turn == side
        ? (_nowMs() - _receivedAt).clamp(0, base)
        : 0;
    return base - elapsed;
  }
}

/// Only animate a single verified transition; reconnect gaps never replay battles.
MoveResolution? detectCommittedCapture(
  OnlineGameState previous,
  OnlineGameState next,
) {
  if (previous.gameId != next.gameId ||
      previous.round != next.round ||
      previous.status != 'active' ||
      next.san.length != previous.san.length + 1) {
    return null;
  }
  for (var i = 0; i < previous.san.length; i++) {
    if (previous.san[i] != next.san[i]) return null;
  }
  final move = previous.position.parseSan(next.san.last);
  if (move is! NormalMove) return null;
  final game = GameSession(position: previous.position);
  final result = game.play(
    move.from,
    move.to,
    promotion: move.promotion ?? Role.queen,
  );
  if (result == null || !result.isCapture) return null;
  // Compare the authoritative positions, not just a capture marker in SAN.
  // FENs are normalized through the same rules engine before comparison.
  if (game.position.fen != next.position.fen) return null;
  return result;
}
