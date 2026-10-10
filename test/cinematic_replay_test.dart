import 'package:battle_chess_arena/src/domain/cinematic_replay.dart';
import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('cinematic winner', () {
    test(
      'uses authoritative winners for personal and named-opponent labels',
      () {
        expect(
          cinematicWinner(
            resultTitle: 'You Win! · Timeout',
            winnerSide: Side.black,
          ),
          Side.black,
        );
        expect(
          cinematicWinner(
            resultTitle: 'Tournament opponent wins · Resignation',
            winnerSide: Side.white,
          ),
          Side.white,
        );
        expect(
          cinematicWinner(resultTitle: 'Timeout · Black wins'),
          Side.black,
        );
        expect(cinematicWinner(resultTitle: 'White Wins!'), Side.white);
        expect(cinematicWinner(resultTitle: 'Snowwhite wins'), isNull);
      },
    );

    test(
      'neutral records never celebrate even with stale winner information',
      () {
        final mate = CinematicReplay.fromMoves(
          moves: ['f2f3', 'e7e5', 'g2g4', 'd8h4'],
        ).finalPosition;
        for (final result in [
          'Game unfinished',
          'Game incomplete',
          'Game drawn',
          'Draw by stalemate',
          'Cancelled',
          'Aborted',
          'Game in progress',
        ]) {
          expect(
            cinematicWinner(
              resultTitle: result,
              finalPosition: mate,
              winnerSide: Side.black,
            ),
            isNull,
            reason: result,
          );
        }
        expect(
          cinematicWinner(resultTitle: 'Game complete', finalPosition: mate),
          Side.black,
        );
        expect(
          cinematicWinner(resultTitle: 'Ended on time', finalPosition: mate),
          isNull,
        );
        expect(
          cinematicWinner(
            resultTitle: 'Ended by resignation',
            finalPosition: mate,
          ),
          isNull,
        );
      },
    );
  });

  group('CinematicReplay', () {
    test('replays every actual ply without mutating the source game', () {
      final game = GameSession.fromMoves(
        moves: ['e2e4', 'd7d5', 'e4d5', 'd8d5'],
      );
      final savedFen = game.position.fen;
      final moves = game.uciMoves.toList();
      final replay = CinematicReplay.fromMoves(
        moves: moves,
        resultTitle: 'White wins on time',
      );
      moves.clear();
      game.undo();

      expect(replay.totalPlies, 4);
      expect(replay.totalMoves, 2);
      expect(replay.initialPosition.fen, Chess.initial.fen);
      expect(replay.finalPosition.fen, savedFen);
      expect(replay.resultTitle, 'White wins on time');
      expect(replay.uciMoves, ['e2e4', 'd7d5', 'e4d5', 'd8d5']);
      expect(replay.scenes.map((scene) => scene.san), [
        'e4',
        'd5',
        'exd5',
        'Qxd5',
      ]);
      expect(replay.scenes.map((scene) => scene.ply), [1, 2, 3, 4]);
      expect(replay.scenes.map((scene) => scene.moveNumber), [1, 1, 2, 2]);
      expect(replay.captureCount, 2);
      expect(replay.checkCount, 0);
      for (var i = 1; i < replay.scenes.length; i++) {
        expect(replay.scenes[i].before.fen, replay.scenes[i - 1].after.fen);
      }
      expect(
        replay.scenes.first.before.board.pieceAt(Square.e2),
        Piece.whitePawn,
      );
      expect(
        replay.scenes.first.after.board.pieceAt(Square.e4),
        Piece.whitePawn,
      );
      expect(replay.scenes[2].captureSquare, Square.d5);
      expect(
        replay.scenes[2].narration,
        contains('captures Black\'s sentinel pawn'),
      );
      expect(replay.scenes.last.side, Side.black);
      expect(() => replay.scenes.clear(), throwsUnsupportedError);
      expect(() => replay.uciMoves.add('a2a3'), throwsUnsupportedError);
    });

    test('ends with the real checkmate and a matching result', () {
      final replay = CinematicReplay.fromMoves(
        moves: ['f2f3', 'e7e5', 'g2g4', 'd8h4'],
      );
      final finalScene = replay.scenes.last;
      expect(replay.finalPosition.isCheckmate, isTrue);
      expect(replay.resultTitle, 'Black wins by checkmate');
      expect(replay.checkCount, 1);
      expect(finalScene.isCheck, isTrue);
      expect(finalScene.isCheckmate, isTrue);
      expect(finalScene.san, 'Qh4#');
      expect(finalScene.source, Square.d8);
      expect(finalScene.target, Square.h4);
      expect(finalScene.headline, 'White\'s core is defeated');
      expect(finalScene.narration, contains('Black wins'));
      expect(finalScene.narration, contains('d8 to h4'));
    });

    test(
      'keeps both castling destinations accurate and never invents capture',
      () {
        final prefix = ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4', 'g8f6'];
        for (final uci in ['e1g1', 'e1h1']) {
          final replay = CinematicReplay.fromMoves(moves: [...prefix, uci]);
          final castle = replay.scenes.last;
          expect(castle.isCastling, isTrue);
          expect(castle.source, Square.e1);
          expect(castle.target, Square.g1);
          expect(castle.after.board.pieceAt(Square.g1), Piece.whiteKing);
          expect(castle.after.board.pieceAt(Square.f1), Piece.whiteRook);
          expect(castle.isCapture, isFalse);
          expect(castle.captureSquare, isNull);
          expect(castle.narration, contains('castles kingside'));
          expect(replay.castleCount, 1);
          expect(replay.captureCount, 0);
        }
      },
    );

    test('en passant shows the off-destination victim square', () {
      final replay = CinematicReplay.fromMoves(
        moves: ['e2e4', 'a7a6', 'e4e5', 'd7d5', 'e5d6'],
      );
      final intercept = replay.scenes.last;
      expect(intercept.isEnPassant, isTrue);
      expect(intercept.target, Square.d6);
      expect(intercept.captureSquare, Square.d5);
      expect(intercept.before.board.pieceAt(Square.d5), Piece.blackPawn);
      expect(intercept.after.board.pieceAt(Square.d5), isNull);
      expect(intercept.after.board.pieceAt(Square.d6), Piece.whitePawn);
      expect(intercept.narration, contains('en passant'));
      expect(intercept.narration, contains('d5'));
      expect(replay.captureCount, 1);
    });

    test('promotions keep actual roles and captures across the whole game', () {
      final replay = CinematicReplay.fromMoves(
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
      final promotion = replay.scenes[8];
      expect(promotion.isPromotion, isTrue);
      expect(promotion.isCapture, isTrue);
      expect(promotion.resolution.defender?.role, Role.rook);
      expect(promotion.after.board.pieceAt(Square.a8), Piece.whiteQueen);
      expect(promotion.narration, contains('transforms into a command queen'));
      expect(replay.promotionCount, 2);
      expect(replay.captureCount, 5);
      expect(replay.scenes.last.resolution.defender?.role, Role.queen);
      expect(replay.scenes.last.narration, contains('White\'s command queen'));
    });

    test('supports an empty final history without creating scenes', () {
      final replay = CinematicReplay.fromMoves(
        moves: [],
        resultTitle: 'Game cancelled',
      );
      expect(replay.scenes, isEmpty);
      expect(replay.totalMoves, 0);
      expect(replay.captureCount, 0);
      expect(replay.finalPosition.fen, Chess.initial.fen);
      expect(replay.resultTitle, 'Game cancelled');
    });

    test('rejects corrupt UCI histories at the offending ply', () {
      for (final invalid in ['', 'a', 'Q@a3', 'e2e5', 'e9e4', 'e2e4q']) {
        expect(
          () => CinematicReplay.fromMoves(moves: [invalid]),
          throwsA(isA<FormatException>()),
        );
      }
      expect(
        () => CinematicReplay.fromMoves(moves: ['e2e4', 'e2e3']),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'ply',
            contains('ply 2'),
          ),
        ),
      );
    });

    test('SAN replay retains the same castling, capture and checkmate', () {
      for (final moves in [
        ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4', 'g8f6', 'e1g1'],
        ['e2e4', 'a7a6', 'e4e5', 'd7d5', 'e5d6'],
        ['f2f3', 'e7e5', 'g2g4', 'd8h4'],
      ]) {
        final game = GameSession.fromMoves(moves: moves);
        final replay = CinematicReplay.fromSan(moves: game.sanMoves);
        expect(replay.finalPosition.fen, game.position.fen);
        expect(replay.uciMoves, game.uciMoves);
        expect(replay.scenes.map((scene) => scene.san), game.sanMoves);
      }
      final converted = replayUciMovesFromSan(['e4', 'd5', 'exd5']);
      expect(converted, ['e2e4', 'd7d5', 'e4d5']);
      expect(() => converted.clear(), throwsUnsupportedError);
    });

    test('rejects legal but truncated SAN against the authoritative board', () {
      final game = GameSession.fromMoves(moves: ['e2e4', 'd7d5', 'e4d5']);
      expect(
        replayUciMovesFromSan(game.sanMoves, expectedFen: game.position.fen),
        game.uciMoves,
      );
      expect(
        () =>
            replayUciMovesFromSan(['e4', 'd5'], expectedFen: game.position.fen),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects invalid SAN and incorrect check or capture claims', () {
      for (final notation in ['', '#', 'not-a-move', 'e4+', 'e4#', 'xe4']) {
        expect(
          () => replayUciMovesFromSan([notation]),
          throwsA(isA<FormatException>()),
        );
      }
      expect(
        () => replayUciMovesFromSan(['e4', 'e5', 'O-O']),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'ply',
            contains('ply 3'),
          ),
        ),
      );
    });
  });
}
