import 'package:dartchess/dartchess.dart';
import 'computer_player_contract.dart';
import 'stockfish_computer_player_web.dart'
    if (dart.library.io) 'stockfish_computer_player_native.dart';

export 'computer_player_contract.dart';
export 'stockfish_computer_player_web.dart'
    if (dart.library.io) 'stockfish_computer_player_native.dart'
    show StockfishComputerPlayer;

/// Keeps a playable local opponent when native initialization or search stalls.
class ReliableComputerPlayer implements ComputerPlayer {
  ReliableComputerPlayer({ComputerPlayer? primary})
    : _primary = primary ?? createPrimaryComputerPlayer();

  final ComputerPlayer _primary;
  bool reducedStrength = false;
  bool _disposed = false;

  @override
  Future<String?> bestMove(
    String fen, {
    ComputerDifficulty difficulty = ComputerDifficulty.medium,
  }) async {
    if (_disposed) return null;
    final position = Chess.fromSetup(Setup.parseFen(fen));
    if (position.isGameOver) return null;
    if (!reducedStrength) {
      try {
        final move = await _primary
            .bestMove(fen, difficulty: difficulty)
            .timeout(const Duration(seconds: 12));
        if (_disposed) return null;
        final parsed = move == null ? null : Move.parse(move);
        if (parsed != null && position.isLegal(parsed)) return move;
      } catch (_) {
        // Switch once for the rest of this session; do not overlap searches.
      }
      if (_disposed) return null;
      reducedStrength = true;
      _primary.dispose();
    }
    NormalMove? best;
    var bestScore = -1000000;
    for (final move in _moves(position)) {
      final score = -_search(position.play(move), difficulty.fallbackDepth);
      if (score > bestScore) {
        bestScore = score;
        best = move;
      }
    }
    return best?.uci;
  }

  static Iterable<NormalMove> _moves(Position position) sync* {
    for (final entry in position.legalMoves.entries) {
      for (final to in entry.value.squares) {
        final promotion =
            position.board.pieceAt(entry.key)?.role == Role.pawn &&
            (to.rank == Rank.first || to.rank == Rank.eighth);
        for (final role
            in promotion
                ? <Role?>[Role.queen, Role.rook, Role.bishop, Role.knight]
                : <Role?>[null]) {
          yield NormalMove(from: entry.key, to: to, promotion: role);
        }
      }
    }
  }

  static int _search(Position position, int depth) {
    if (position.isCheckmate) return -100000;
    if (position.isGameOver) return 0;
    if (depth > 0) {
      var best = -1000000;
      for (final move in _moves(position)) {
        final value = -_search(position.play(move), depth - 1);
        if (value > best) best = value;
      }
      return best;
    }
    const values = {
      Role.pawn: 100,
      Role.knight: 320,
      Role.bishop: 330,
      Role.rook: 500,
      Role.queen: 900,
      Role.king: 0,
    };
    var score = 0;
    for (final square in position.board.occupied.squares) {
      final piece = position.board.pieceAt(square)!;
      score += values[piece.role]! * (piece.color == position.turn ? 1 : -1);
    }
    return score;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (!reducedStrength) _primary.dispose();
  }
}
