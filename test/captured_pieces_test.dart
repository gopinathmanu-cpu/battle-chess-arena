import 'package:battle_chess_arena/src/domain/captured_pieces.dart';
import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/domain/online_game_state.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/online_fixtures.dart';

void main() {
  test(
    'captures belong to the captor; quiet moves and invalid moves add none',
    () {
      final game = GameSession.fromMoves(moves: ['e2e4', 'd7d5', 'e4d5']);
      expect(game.capturedPieces, [
        const Piece(color: Side.black, role: Role.pawn),
      ]);
      expect(game.playUci('d8d5')?.isCapture, isTrue);
      expect(
        game.capturedPieces.last,
        const Piece(color: Side.white, role: Role.pawn),
      );
      final captures = game.capturedPieces;
      expect(game.playUci('e2e5'), isNull);
      game.playUci('b1c3');
      expect(game.capturedPieces, captures);
      expect(() => captures.clear(), throwsUnsupportedError);
      game.undo();
      expect(game.capturedPieces.length, 2);
      game.undo();
      expect(game.capturedPieces.length, 1);
      game.undo();
      expect(game.capturedPieces, isEmpty);
    },
  );

  test(
    'en passant records the pawn from its actual off-destination square',
    () {
      final game = GameSession.fromMoves(
        moves: ['e2e4', 'a7a6', 'e4e5', 'd7d5', 'e5d6'],
      );
      expect(game.capturedPieces, [
        const Piece(color: Side.black, role: Role.pawn),
      ]);
      expect(game.pieceAt(Square.d5), isNull);
      game.undo();
      expect(game.capturedPieces, isEmpty);
      expect(game.pieceAt(Square.d5)?.role, Role.pawn);
    },
  );

  test('castling does not capture its own rook', () {
    final game = GameSession.fromMoves(
      moves: ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4', 'g8f6', 'e1g1'],
    );
    expect(game.capturedPieces, isEmpty);
    game.reset();
    expect(game.capturedPieces, isEmpty);
  });

  test(
    'promotion is not a lost pawn; captured promoted pieces keep their role',
    () {
      final game = GameSession(
        position: Chess.fromSetup(
          Setup.parseFen('1rk5/P7/8/8/8/8/8/7K w - - 0 1'),
        ),
      );
      expect(game.playUci('a7b8q'), isNotNull);
      expect(game.capturedPieces, [
        const Piece(color: Side.black, role: Role.rook),
      ]);
      expect(game.playUci('c8b8'), isNotNull);
      expect(
        game.capturedPieces.last,
        const Piece(color: Side.white, role: Role.queen),
      );
      game.reset();
      expect(game.capturedPieces, isEmpty);
    },
  );

  test(
    'saved UCI and online SAN replay restore captures including promotions',
    () {
      final game = GameSession.fromMoves(
        moves: [
          'a2a4',
          'h7h5',
          'a4a5',
          'h5h4',
          'a5a6',
          'h4h3',
          'a6b7',
          'h3g2',
          'b7a8q',
          'g2h1q',
          'b1c3',
          'h1a8',
        ],
      );
      expect(game.capturedPieces.length, 5);
      expect(game.capturedPieces.last.role, Role.queen);
      final saved = GameSession.fromMoves(moves: game.uciMoves);
      expect(saved.capturedPieces, game.capturedPieces);
      final state = OnlineGameState.fromJson(stateJson(game: game));
      expect(state.capturedPieces, game.capturedPieces);
      expect(identical(state.capturedPieces, state.capturedPieces), isTrue);
      final rematch = OnlineGameState.fromJson(
        stateJson(sequence: 10, round: 2),
      );
      expect(rematch.capturedPieces, isEmpty);
    },
  );

  test(
    'unverified or incomplete online history is not displayed as captures',
    () {
      final game = GameSession.fromMoves(moves: ['e2e4', 'd7d5', 'e4d5']);
      expect(
        capturedPiecesFromSan(['invalid'], expectedPosition: game.position),
        isNull,
      );
      expect(
        capturedPiecesFromSan(['e4'], expectedPosition: game.position),
        isNull,
      );
      expect(
        capturedPiecesFromSan([], expectedPosition: Chess.initial),
        isEmpty,
      );
    },
  );
}
