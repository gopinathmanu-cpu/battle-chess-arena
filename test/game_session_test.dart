import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GameSession', () {
    test('rejects illegal moves and accepts legal moves', () {
      final game = GameSession();
      expect(game.play(Square.e2, Square.e5), isNull);
      final move = game.play(Square.e2, Square.e4);
      expect(move?.san, 'e4');
      expect(game.position.turn, Side.black);
    });

    test('records captures and supports undo', () {
      final game = GameSession();
      game.playUci('e2e4');
      game.playUci('d7d5');
      final capture = game.playUci('e4d5');
      expect(capture?.isCapture, isTrue);
      expect(capture?.defender?.role, Role.pawn);
      expect(game.sanMoves, ['e4', 'd5', 'exd5']);
      game.undo();
      expect(game.position.turn, Side.white);
      expect(game.pieceAt(Square.e4)?.role, Role.pawn);
    });

    test('detects checkmate', () {
      final game = GameSession();
      game.playUci('f2f3');
      game.playUci('e7e5');
      game.playUci('g2g4');
      game.playUci('d8h4');
      expect(game.position.isCheckmate, isTrue);
      expect(game.sanMoves.last, 'Qh4#');
    });

    test('maps standard king destination to castling move', () {
      final game = GameSession();
      game.playUci('e2e4');
      game.playUci('e7e5');
      game.playUci('g1f3');
      game.playUci('b8c6');
      game.playUci('f1c4');
      game.playUci('g8f6');
      expect(game.legalDestinations(Square.e1), contains(Square.g1));
      expect(game.play(Square.e1, Square.g1)?.san, 'O-O');
    });
  });
}
