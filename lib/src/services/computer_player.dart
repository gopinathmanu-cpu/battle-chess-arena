import 'dart:math';

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
  ReliableComputerPlayer({ComputerPlayer? primary, Random? random})
    : _primary = primary ?? createPrimaryComputerPlayer(),
      _random = random ?? Random();

  final ComputerPlayer _primary;
  final Random _random;
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
    if (difficulty == ComputerDifficulty.easy) {
      return _easyMove(position, fen)?.uci;
    }
    if (difficulty == ComputerDifficulty.medium) {
      return _bestFallback(position, difficulty.fallbackDepth)?.uci;
    }
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
    return _bestFallback(position, difficulty.fallbackDepth)?.uci;
  }

  NormalMove? _easyMove(Position position, String fen) {
    final ranked = <(NormalMove, int, bool, int)>[];
    for (final move in _moves(position)) {
      final next = position.play(move);
      final piece = position.board.pieceAt(move.from);
      final target = position.board.pieceAt(move.to);
      final quiet =
          (target == null || target.color == piece?.color) && !next.isCheck;
      var development = 0;
      if ({Square.d4, Square.e4, Square.d5, Square.e5}.contains(move.to)) {
        development += 20;
      }
      if ((piece?.role == Role.knight || piece?.role == Role.bishop) &&
          (move.from.rank == Rank.first || move.from.rank == Rank.eighth)) {
        development += 25;
      }
      if (piece?.role == Role.king && target?.color == piece?.color) {
        development += 50;
      }
      ranked.add((move, -_search(next, 1), quiet, development));
    }
    if (ranked.isEmpty) return null;
    ranked.sort(
      (a, b) => b.$2.compareTo(a.$2) != 0
          ? b.$2.compareTo(a.$2)
          : b.$4.compareTo(a.$4),
    );
    final bestScore = ranked.first.$2;
    final sensible = ranked
        .where((candidate) => candidate.$2 >= bestScore - 40)
        .toList();

    final fullMove =
        int.tryParse(fen.split(' ').elementAtOrNull(5) ?? '') ?? 99;
    if (fullMove <= 4) {
      final standardMoves = position.turn == Side.white
          ? _whiteOpeningMoves
          : _blackOpeningMoves;
      final openingChoices = sensible
          .where((candidate) => standardMoves.contains(candidate.$1.uci))
          .toList();
      if (openingChoices.isNotEmpty) {
        return openingChoices[_random.nextInt(openingChoices.length)].$1;
      }
    }

    final quiet = sensible.where((candidate) => candidate.$3).toList();
    final choices = quiet.isNotEmpty ? quiet : sensible;
    final choiceCount = choices.length.clamp(1, 3);
    return choices[_random.nextInt(choiceCount)].$1;
  }

  static const _whiteOpeningMoves = {
    'e2e4',
    'd2d4',
    'c2c4',
    'g1f3',
    'b1c3',
    'f1b5',
    'f1c4',
    'f1e2',
  };

  static const _blackOpeningMoves = {
    'e7e5',
    'c7c5',
    'e7e6',
    'c7c6',
    'd7d5',
    'g8f6',
    'b8c6',
    'f8b4',
    'f8c5',
    'f8e7',
  };

  static NormalMove? _bestFallback(Position position, int depth) {
    NormalMove? best;
    var bestScore = -1000000;
    for (final move in _moves(position)) {
      final score = -_search(position.play(move), depth);
      if (score > bestScore) {
        bestScore = score;
        best = move;
      }
    }
    return best;
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
