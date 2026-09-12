import 'package:dartchess/dartchess.dart';

class GameResultMessage {
  const GameResultMessage({required this.sentiment, required this.comment});

  final String sentiment;
  final String comment;
}

GameResultMessage analyzeUserGame({
  required List<String> sanMoves,
  required List<String> uciMoves,
  Side userSide = Side.white,
  required bool userWon,
}) {
  final offset = userSide == Side.white ? 0 : 1;
  final userSan = <String>[
    for (var i = offset; i < sanMoves.length; i += 2) sanMoves[i],
  ];
  final userUci = <String>[
    for (var i = offset; i < uciMoves.length; i += 2) uciMoves[i],
  ];
  final captures = userSan.where((move) => move.contains('x')).length;
  final checks = userSan
      .where((move) => move.endsWith('+') || move.endsWith('#'))
      .length;
  final castled = userSan.any((move) => move.startsWith('O-O'));
  final homeSquares = userSide == Side.white
      ? const {'b1', 'g1', 'c1', 'f1'}
      : const {'b8', 'g8', 'c8', 'f8'};
  final developed = userUci
      .map((move) => move.length >= 2 ? move.substring(0, 2) : '')
      .where(homeSquares.contains)
      .toSet()
      .length;
  final moves = userSan.length;

  if (userWon) {
    if (checks >= 3) {
      return GameResultMessage(
        sentiment:
            'Brilliant victory! Your attack kept the computer under constant pressure.',
        comment:
            'You created $checks checks and converted the initiative into checkmate${captures == 0 ? '.' : ' while winning $captures tactical exchanges.'}',
      );
    }
    if (captures >= 4) {
      return GameResultMessage(
        sentiment: 'Congratulations! You played a sharp and commanding game.',
        comment:
            'You converted $captures captures efficiently and delivered checkmate in $moves moves.',
      );
    }
    if (castled || developed >= 3) {
      return GameResultMessage(
        sentiment:
            'Excellent victory! Your position was composed and well coordinated.',
        comment:
            'You developed $developed major supporting pieces${castled ? ', protected your king,' : ''} and turned that control into checkmate.',
      );
    }
    return GameResultMessage(
      sentiment:
          'Congratulations on your victory! You found a decisive route to the king.',
      comment:
          'You stayed focused and completed checkmate in $moves moves with confident play.',
    );
  }

  const encouragement =
      'Good fight—better luck next time! Every game makes the next one stronger.';
  if (!castled && moves >= 7) {
    return GameResultMessage(
      sentiment: encouragement,
      comment:
          'You found $captures captures, but your king stayed in the centre; castle earlier and connect your pieces before attacking.',
    );
  }
  if (developed < 2 && moves >= 6) {
    return GameResultMessage(
      sentiment: encouragement,
      comment:
          'Your opening used only $developed supporting piece${developed == 1 ? '' : 's'}; develop knights and bishops sooner to defend more squares.',
    );
  }
  if (checks > 0) {
    return GameResultMessage(
      sentiment: encouragement,
      comment:
          'You created $checks checking chance${checks == 1 ? '' : 's'}; prepare the attack with one more defender before committing your pieces.',
    );
  }
  return const GameResultMessage(
    sentiment: encouragement,
    comment:
        'You kept the game competitive; next time, look for checks, captures, and threats before each move.',
  );
}
