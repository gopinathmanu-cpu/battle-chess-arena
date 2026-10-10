// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:dartchess/dartchess.dart';

import 'game_session.dart';

/// Resolve a recorded winner without turning draws or unfinished games into
/// victories. Live callers can supply the authoritative side for player-facing
/// labels such as "You Win" or a named tournament opponent.
Side? cinematicWinner({
  required String resultTitle,
  Position? finalPosition,
  Side? winnerSide,
}) {
  final result = resultTitle.toLowerCase();
  if (RegExp(
        r'\b(draw|drawn|stalemate|unfinished|incomplete|cancelled|canceled|cancel|aborted|abort)\b',
      ).hasMatch(result) ||
      result.contains('in progress') ||
      result.contains('insufficient material')) {
    return null;
  }
  if (winnerSide != null) return winnerSide;
  final white = RegExp(r'\bwhite\s+wins?\b').hasMatch(result);
  final black = RegExp(r'\bblack\s+wins?\b').hasMatch(result);
  if (white && black) return null;
  if (white) return Side.white;
  if (black) return Side.black;
  // The board cannot identify the winner of a resignation or clock ending.
  if (result.contains('resign') ||
      result.contains('time') ||
      result.contains('clock')) {
    return null;
  }
  return finalPosition?.isCheckmate == true
      ? finalPosition!.turn.opposite
      : null;
}

/// A read-only recording of every ply, reconstructed from the real game.
///
/// The positions and resolutions are immutable snapshots. Playback can never
/// advance, undo, or otherwise change the session that supplied the history.
class CinematicReplay {
  const CinematicReplay._({
    required this.uciMoves,
    required this.scenes,
    required this.finalPosition,
    required this.resultTitle,
  });

  factory CinematicReplay.fromMoves({
    required Iterable<String> moves,
    String? resultTitle,
  }) {
    final snapshot = List<String>.unmodifiable(moves);
    final session = GameSession();
    final scenes = <CinematicReplayScene>[];
    final uciPattern = RegExp(r'^[a-h][1-8][a-h][1-8][qrbn]?$');
    for (var i = 0; i < snapshot.length; i++) {
      final uci = snapshot[i];
      final before = session.position;
      final requested = uciPattern.hasMatch(uci) ? Move.parse(uci) : null;
      if (requested is! NormalMove) {
        throw FormatException('Invalid cinematic move at ply ${i + 1}: $uci');
      }
      final resolution = session.playUci(uci);
      if (resolution == null ||
          resolution.move.promotion != requested.promotion) {
        throw FormatException('Invalid cinematic move at ply ${i + 1}: $uci');
      }
      scenes.add(
        CinematicReplayScene._create(
          ply: i + 1,
          before: before,
          after: session.position,
          resolution: resolution,
        ),
      );
    }
    return CinematicReplay._(
      uciMoves: snapshot,
      scenes: List<CinematicReplayScene>.unmodifiable(scenes),
      finalPosition: session.position,
      resultTitle: resultTitle?.trim().isNotEmpty == true
          ? resultTitle!.trim()
          : _resultTitle(session),
    );
  }

  factory CinematicReplay.fromSan({
    required Iterable<String> moves,
    String? resultTitle,
  }) => CinematicReplay.fromMoves(
    moves: replayUciMovesFromSan(moves),
    resultTitle: resultTitle,
  );

  final List<String> uciMoves;
  final List<CinematicReplayScene> scenes;
  final Position finalPosition;
  final String resultTitle;

  Position get initialPosition => Chess.initial;
  int get totalPlies => scenes.length;
  int get totalMoves => (totalPlies + 1) ~/ 2;
  int get captureCount => scenes.where((scene) => scene.isCapture).length;
  int get checkCount => scenes.where((scene) => scene.isCheck).length;
  int get promotionCount => scenes.where((scene) => scene.isPromotion).length;
  int get castleCount => scenes.where((scene) => scene.isCastling).length;

  static String _resultTitle(GameSession session) {
    final position = session.position;
    if (position.isCheckmate) {
      return '${_sideName(position.turn.opposite)} wins by checkmate';
    }
    if (position.isStalemate) return 'Draw by stalemate';
    if (position.isInsufficientMaterial) return 'Draw by insufficient material';
    if (session.isRuleDraw) return 'Game drawn';
    return 'Game complete';
  }
}

/// A complete, validated conversion for authoritative SAN histories.
///
/// Canonical SAN must agree with the actual position, including capture and
/// check markers. Missing or corrupt history is rejected instead of guessed.
List<String> replayUciMovesFromSan(
  Iterable<String> sanMoves, {
  String? expectedFen,
}) {
  final session = GameSession();
  var ply = 0;
  for (final san in sanMoves) {
    ply++;
    NormalMove? parsed;
    try {
      final candidate = session.position.parseSan(san);
      if (candidate is NormalMove) parsed = candidate;
    } on RangeError {
      // The notation parser indexes empty/malformed input before rejecting it.
    }
    final resolution = parsed == null ? null : session.playUci(parsed.uci);
    if (resolution == null || resolution.san != san) {
      throw FormatException('Invalid cinematic notation at ply $ply: $san');
    }
  }
  if (expectedFen != null && session.position.fen != expectedFen) {
    throw const FormatException(
      'Cinematic history does not match the final position',
    );
  }
  return List<String>.unmodifiable(session.uciMoves);
}

class CinematicReplayScene {
  const CinematicReplayScene._({
    required this.ply,
    required this.before,
    required this.after,
    required this.resolution,
    required this.target,
    required this.captureSquare,
    required this.headline,
    required this.narration,
  });

  factory CinematicReplayScene._create({
    required int ply,
    required Position before,
    required Position after,
    required MoveResolution resolution,
  }) {
    final move = resolution.move;
    final castle = resolution.san.startsWith('O-O');
    final target = castle
        ? Square.fromCoords(
            move.to.file > move.from.file ? File.g : File.c,
            move.from.rank,
          )
        : move.to;
    final enPassant =
        resolution.isCapture &&
        resolution.attacker.role == Role.pawn &&
        before.board.pieceAt(target) == null;
    final captureSquare = resolution.isCapture
        ? (enPassant ? Square.fromCoords(target.file, move.from.rank) : target)
        : null;
    final (headline, narration) = _describeNeonMove(
      resolution: resolution,
      after: after,
      target: target,
      enPassant: enPassant,
      castling: castle,
    );
    return CinematicReplayScene._(
      ply: ply,
      before: before,
      after: after,
      resolution: resolution,
      target: target,
      captureSquare: captureSquare,
      headline: headline,
      narration: narration,
    );
  }

  final int ply;
  final Position before;
  final Position after;
  final MoveResolution resolution;

  /// Familiar king destination for castling, rather than the engine's rook.
  final Square target;

  /// The victim's square; en passant captures away from [target].
  final Square? captureSquare;
  final String headline;
  final String narration;

  int get moveNumber => (ply + 1) ~/ 2;
  Side get side => resolution.attacker.color;
  String get san => resolution.san;
  Square get source => resolution.move.from;
  bool get isCapture => resolution.isCapture;
  bool get isCheck => after.isCheck;
  bool get isCheckmate => after.isCheckmate;
  bool get isCastling => san.startsWith('O-O');
  bool get isPromotion => resolution.move.promotion != null;
  bool get isEnPassant =>
      isCapture && captureSquare != null && captureSquare != target;
}

(String, String) _describeNeonMove({
  required MoveResolution resolution,
  required Position after,
  required Square target,
  required bool enPassant,
  required bool castling,
}) {
  final attacker = resolution.attacker;
  final side = _sideName(attacker.color);
  final enemy = _sideName(attacker.color.opposite);
  final unit = _unitName(attacker.role);
  final route = '${resolution.move.from.name} to ${target.name}';
  final defender = resolution.defender;
  final promotion = resolution.move.promotion;

  String headline;
  String action;
  if (castling) {
    headline = '$side activates the fortress';
    action =
        '$side castles ${target.file == File.g ? 'kingside' : 'queenside'}. '
        'The core king moves $route as the siege rook joins its defense.';
  } else if (promotion != null) {
    headline = '$side unlocks a new ${promotion.name}';
    action =
        '$side\'s sentinel pawn reaches ${target.name} from '
        '${resolution.move.from.name}'
        '${defender == null ? '' : ', capturing $enemy\'s ${_unitName(defender.role)}'}, '
        'and transforms into a ${_unitName(promotion)}.';
  } else if (enPassant) {
    headline = 'An interception on the neon grid';
    action =
        '$side\'s sentinel pawn moves $route and captures $enemy\'s pawn '
        'en passant, removing it from ${target.file.name}${resolution.move.from.rank.name}.';
  } else if (defender != null) {
    headline = '$side takes a ${defender.role.name}';
    action =
        '$side\'s $unit moves $route and captures $enemy\'s '
        '${_unitName(defender.role)}.';
  } else {
    headline = '$side moves the ${attacker.role.name}';
    action = '$side\'s $unit moves $route across the neon grid.';
  }

  if (after.isCheckmate) {
    headline = '$enemy\'s core is defeated';
    action += ' Checkmate. $enemy has no legal response; $side wins.';
  } else if (after.isCheck) {
    if (!resolution.isCapture && promotion == null && !castling) {
      headline = '$enemy\'s core is under attack';
    }
    action += ' Check. $enemy must answer the attack on the core king.';
  }
  return (headline, action);
}

String _sideName(Side side) => side == Side.white ? 'White' : 'Black';

String _unitName(Role role) => switch (role) {
  Role.pawn => 'sentinel pawn',
  Role.knight => 'strider knight',
  Role.bishop => 'beam bishop',
  Role.rook => 'siege rook',
  Role.queen => 'command queen',
  Role.king => 'core king',
};
