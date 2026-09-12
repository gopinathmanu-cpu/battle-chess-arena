import 'package:battle_chess_arena/src/domain/game_result_analysis.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('victory message praises play without improvement advice', () {
    final result = analyzeUserGame(
      sanMoves: const ['e4', 'e5', 'Qh5', 'Nc6', 'Bc4', 'Nf6', 'Qxf7#'],
      uciMoves: const ['e2e4', 'e7e5', 'd1h5', 'b8c6', 'f1c4', 'g8f6', 'h5f7'],
      userWon: true,
    );
    expect(result.sentiment, contains('victory'));
    expect(result.comment, contains('checkmate'));
    expect(result.comment, isNot(contains('next time')));
  });

  test('computer victory message encourages and gives specific advice', () {
    final result = analyzeUserGame(
      sanMoves: const [
        'e4',
        'e5',
        'Qh5',
        'Nc6',
        'Qh3',
        'Nf6',
        'a3',
        'Bc5',
        'a4',
        'O-O',
        'h3',
        'Re8',
      ],
      uciMoves: const [
        'e2e4',
        'e7e5',
        'd1h5',
        'b8c6',
        'h5h3',
        'g8f6',
        'a2a3',
        'f8c5',
        'a3a4',
        'e8g8',
        'h2h3',
        'f8e8',
      ],
      userSide: Side.white,
      userWon: false,
    );
    expect(result.sentiment, contains('better luck next time'));
    expect(result.comment, contains('develop knights and bishops sooner'));
  });
}
