import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/domain/online_game_session.dart';
import 'package:battle_chess_arena/src/domain/online_game_state.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/online_fixtures.dart';

void main() {
  test('parses FEN, clocks, result and draw/rematch fields', () {
    final json = stateJson(
      status: 'complete',
      result: {'reason': 'timeout', 'winner': 'b'},
    );
    json['rematchOffers'] = ['w'];
    final state = OnlineGameState.fromJson(json);
    expect(state.position.board.pieceAt(Square.e1)?.role, Role.king);
    expect(state.whiteMs, 60000);
    expect(state.winner, 'b');
    expect(state.statusLabel, 'Winner by timeout · Black wins');
    expect(state.rematchOffers, ['w']);
    expect(() => state.san.add('e4'), throwsUnsupportedError);
  });

  test('rejects invalid FEN and inconsistent turns and results', () {
    for (final change in [
      {'fen': 'invalid'},
      {'turn': 'b'},
      {
        'whiteMs': -1,
        'clocks': {'w': -1, 'b': 1},
      },
      {'status': 'complete'},
      {'round': 0},
    ]) {
      expect(
        () => OnlineGameState.fromJson({...stateJson(), ...change}),
        throwsA(anything),
      );
    }
  });

  test(
    'rejects stale, duplicate and foreign states without rewinding clocks',
    () {
      var now = 0;
      final session = OnlineGameSession(nowMs: () => now);
      expect(
        session.apply(OnlineGameState.fromJson(stateJson(sequence: 5))),
        isTrue,
      );
      now = 2000;
      for (final json in [
        stateJson(sequence: 4),
        stateJson(sequence: 5),
        stateJson(sequence: 6, gameId: 'other'),
      ]) {
        expect(session.apply(OnlineGameState.fromJson(json)), isFalse);
        expect(session.clockMs('w'), 58000);
      }
      session.apply(
        OnlineGameState.fromJson(stateJson(sequence: 6, whiteMs: 57000)),
      );
      expect(session.clockMs('w'), 57000);
      expect(session.clockMs('b'), 60000);
      now = 90000;
      expect(session.clockMs('w'), 0);
      expect(
        session.state!.status,
        'active',
      ); // Client clock never declares a result.
    },
  );

  test(
    'seat and turn restrictions prevent opponent moves; prediction does not commit',
    () {
      final session = OnlineGameSession()
        ..apply(OnlineGameState.fromJson(stateJson()));
      expect(session.legalDestinations(Square.e7, 'w'), isEmpty);
      expect(session.legalDestinations(Square.e2, 'b'), isEmpty);
      expect(session.legalDestinations(Square.e2, null), isEmpty);
      expect(
        session.legalDestinations(Square.e2, 'w'),
        containsAll([Square.e3, Square.e4]),
      );
      expect(session.moveRequest(Square.e2, Square.e4, 'w'), {
        'from': 'e2',
        'to': 'e4',
        'promotion': 'q',
      });
      expect(session.state!.position.board.pieceAt(Square.e2)?.role, Role.pawn);
      session.apply(
        OnlineGameState.fromJson(
          stateJson(
            sequence: 2,
            status: 'complete',
            result: {'reason': 'agreement', 'winner': null},
          ),
        ),
      );
      expect(session.legalDestinations(Square.e2, 'w'), isEmpty);
    },
  );

  test('promotion requests preserve each chosen role', () {
    final game = GameSession(
      position: Chess.fromSetup(Setup.parseFen('7k/P7/8/8/8/8/8/7K w - - 0 1')),
    );
    final session = OnlineGameSession()
      ..apply(OnlineGameState.fromJson(stateJson(game: game)));
    for (final entry in {
      Role.queen: 'q',
      Role.rook: 'r',
      Role.bishop: 'b',
      Role.knight: 'n',
    }.entries) {
      expect(
        session.moveRequest(
          Square.a7,
          Square.a8,
          'w',
          promotion: entry.key,
        )?['promotion'],
        entry.value,
      );
    }
    expect(session.state!.position.board.pieceAt(Square.a7)?.role, Role.pawn);
  });

  test(
    'capture detection verifies committed positions and skips sync gaps',
    () {
      final game = GameSession()
        ..playUci('e2e4')
        ..playUci('d7d5');
      final before = OnlineGameState.fromJson(stateJson(game: game));
      game.playUci('e4d5');
      final after = OnlineGameState.fromJson(
        stateJson(game: game, sequence: 2),
      );
      expect(detectCommittedCapture(before, after)?.defender?.role, Role.pawn);
      final session = OnlineGameSession()..apply(before);
      session.apply(after, animate: false);
      expect(session.committedCapture, isNull);
      expect(
        detectCommittedCapture(OnlineGameState.fromJson(stateJson()), after),
        isNull,
      );
      expect(
        detectCommittedCapture(
          before,
          OnlineGameState.fromJson({
            ...stateJson(game: game, sequence: 3),
            'fen': before.fen,
            'turn': before.turn,
          }),
        ),
        isNull,
      );
      expect(
        detectCommittedCapture(
          before,
          OnlineGameState.fromJson(
            stateJson(game: game, sequence: 4, round: 2),
          ),
        ),
        isNull,
      );
    },
  );

  test(
    'en passant and promotion captures are detected, castling is not a capture',
    () {
      for (final entry in [
        ('4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1', 'e5d6'),
        ('1r5k/P7/8/8/8/8/8/7K w - - 0 1', 'a7b8n'),
      ]) {
        final game = GameSession(
          position: Chess.fromSetup(Setup.parseFen(entry.$1)),
        );
        final before = OnlineGameState.fromJson(stateJson(game: game));
        expect(game.playUci(entry.$2)?.isCapture, isTrue);
        expect(
          detectCommittedCapture(
            before,
            OnlineGameState.fromJson(stateJson(game: game, sequence: 2)),
          ),
          isNotNull,
        );
      }
      final game = GameSession(
        position: Chess.fromSetup(
          Setup.parseFen('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1'),
        ),
      );
      final before = OnlineGameState.fromJson(stateJson(game: game));
      expect(game.playUci('e1g1')?.san, 'O-O');
      expect(
        detectCommittedCapture(
          before,
          OnlineGameState.fromJson(stateJson(game: game, sequence: 2)),
        ),
        isNull,
      );
    },
  );
}
