import 'dart:async';
import 'dart:convert';

import 'package:battle_chess_arena/src/domain/cinematic_replay.dart';
import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/play/board_appearance.dart';
import 'package:battle_chess_arena/src/features/online/online_game_screen.dart';
import 'package:battle_chess_arena/src/services/game_history_storage.dart';
import 'package:battle_chess_arena/src/services/home_chess_set.dart';
import 'package:battle_chess_arena/src/services/match_appearance_storage.dart';
import 'package:battle_chess_arena/src/services/online_game_archive.dart';
import 'package:battle_chess_arena/src/services/online_match_client.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/online_fixtures.dart';

GameSession played(List<String> moves) {
  final game = GameSession();
  for (final move in moves) {
    expect(game.playUci(move), isNotNull);
  }
  return game;
}

BoardAppearance appearance(PiecePackId id) =>
    BoardAppearance.forPack(piecePacks.firstWhere((pack) => pack.id == id));

class CountingStorage extends GameHistoryStorage {
  final written = <GameHistoryRecord>[];
  int failures = 0;

  @override
  Future<void> save(GameHistoryRecord record) async {
    if (failures > 0) {
      failures--;
      throw StateError('Storage temporarily unavailable');
    }
    written.add(record);
    await super.save(record);
  }
}

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('initial displayed chess set is persisted and archived', (
    tester,
  ) async {
    final archive = OnlineGameArchive();
    final channel = FakeChannel();
    final client = OnlineMatchClient(
      channelFactory: (_) => channel,
      gameArchive: archive,
    );
    await client.connect(Uri.parse('ws://localhost:8080'));
    channel.seat(state: stateJson(game: played(['e2e4'])));
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        home: OnlineGameScreen(
          client: client,
          pack: piecePacks.firstWhere(
            (pack) => pack.id == PiecePackId.futuristic,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await archive.pending;
    final saved = await MatchAppearanceStorage.load('room', 'w');
    expect(saved, isNotNull);
    expect(saved!.white.id, PiecePackId.futuristic);
    expect(saved.standardPieces, isFalse);
    final record = (await GameHistoryStorage().load()).single;
    expect(record.whitePackId, PiecePackId.futuristic);
    expect(record.classicPieces, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    client.dispose();
    archive.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'loading a saved appearance does not overwrite it with initial defaults',
    (tester) async {
      final retained = appearance(
        PiecePackId.egyptian,
      ).withStandardPieces(ClassicPieceStyle.metal);
      SharedPreferences.setMockInitialValues({
        MatchAppearanceStorage.key('room', 'w'): [
          retained.white.id.name,
          retained.black.id.name,
          retained.board.id.name,
          'classic',
          retained.classicStyle.name,
        ],
      });
      final archive = OnlineGameArchive();
      final channel = FakeChannel();
      final client = OnlineMatchClient(
        channelFactory: (_) => channel,
        gameArchive: archive,
      );
      await client.connect(Uri.parse('ws://localhost:8080'));
      channel.seat(state: stateJson(game: played(['e2e4'])));
      await tester.pump();
      await tester.pumpWidget(
        MaterialApp(
          home: OnlineGameScreen(
            client: client,
            pack: piecePacks.firstWhere(
              (pack) => pack.id == PiecePackId.futuristic,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await archive.pending;
      final saved = await MatchAppearanceStorage.load('room', 'w');
      expect(saved!.white.id, PiecePackId.egyptian);
      expect(saved.standardPieces, isTrue);
      expect(saved.classicStyle, ClassicPieceStyle.metal);
      final record = (await GameHistoryStorage().load()).single;
      expect(record.whitePackId, PiecePackId.egyptian);
      expect(record.classicPieces, isTrue);
      expect(record.classicStyle, ClassicPieceStyle.metal);
      await tester.pumpWidget(const SizedBox.shrink());
      client.dispose();
      archive.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'lobby active-game snapshots archive without selecting a room',
    () async {
      final archive = OnlineGameArchive();
      final channel = FakeChannel();
      final client = OnlineMatchClient(
        channelFactory: (_) => channel,
        gameArchive: archive,
      );
      addTearDown(client.dispose);
      addTearDown(archive.dispose);
      await client.connect(Uri.parse('ws://localhost:8080'));
      final game = played(['e2e4', 'e7e5']);
      channel.receive({
        'type': 'active_games',
        'games': [
          {
            'gameId': 'room',
            'seat': 'b',
            'seatToken': 'private-seat-token',
            'state': stateJson(game: game, sequence: 5),
          },
        ],
      });
      await flush();
      await archive.pending;
      expect(client.gameId, isNull);
      expect(client.state, isNull);
      final record = (await GameHistoryStorage().load()).single;
      expect(record.moves, game.uciMoves);
      expect(record.humanSide, Side.black);
      expect(record.status, GameHistoryStatus.unfinished);
      expect(
        jsonEncode(record.toJson()),
        isNot(contains('private-seat-token')),
      );
      channel.receive({
        'type': 'active_games',
        'games': [
          {
            'gameId': 'room',
            'seat': 'b',
            'seatToken': 'private-seat-token',
            'state': stateJson(game: played(['e2e4']), sequence: 4),
          },
        ],
      });
      await flush();
      await archive.pending;
      expect((await GameHistoryStorage().load()).single.moves, game.uciMoves);
    },
  );

  test(
    'accepted client snapshots archive without opening the game route',
    () async {
      final storage = CountingStorage();
      final archive = OnlineGameArchive(storage: storage);
      final channel = FakeChannel();
      final client = OnlineMatchClient(
        channelFactory: (_) => channel,
        gameArchive: archive,
      );
      addTearDown(client.dispose);
      addTearDown(archive.dispose);
      await client.connect(Uri.parse('ws://localhost:8080/private-address'));
      final first = played(['e2e4']);
      channel.seat(state: stateJson(game: first, sequence: 2));
      await flush();
      await archive.pending;
      var records = await GameHistoryStorage().load();
      expect(records.single.status, GameHistoryStatus.unfinished);
      expect(records.single.moves, ['e2e4']);

      final finished = played(['e2e4', 'e7e5']);
      channel.receive({
        'type': 'game_state',
        'state': stateJson(
          game: finished,
          sequence: 3,
          status: 'complete',
          result: {'reason': 'resignation', 'winner': 'w'},
        ),
      });
      await flush();
      await archive.pending;
      // Simulate leaving online play; the replay loads using only local storage.
      await client.disconnect();
      records = await GameHistoryStorage().load();
      final record = records.single;
      expect(record.status, GameHistoryStatus.completed);
      expect(record.mode, GameHistoryMode.online);
      expect(record.id, OnlineGameArchive.recordId('room', 1, 'w'));
      expect(record.moves, finished.uciMoves);
      expect(record.finalFen, finished.position.fen);
      expect(record.resultTitle, 'Resignation · White wins');
      expect(record.whiteName, 'White Hero');
      expect(record.blackName, 'Black Hero');
      expect(record.humanSide, Side.white);
      expect(record.opponentLabel, 'Black Hero');
      final encoded = jsonEncode(record.toJson());
      expect(encoded, isNot(contains('test-secret')));
      expect(encoded, isNot(contains('private-address')));
      expect(encoded, isNot(contains('localhost')));
    },
  );

  test(
    'restored completed rounds, rematches and seats keep distinct IDs',
    () async {
      final storage = CountingStorage();
      final archive = OnlineGameArchive(storage: storage);
      addTearDown(archive.dispose);
      final first = OnlineGameState.fromJson(
        stateJson(
          game: played(['f2f3', 'e7e5', 'g2g4', 'd8h4']),
          sequence: 9,
          status: 'complete',
          result: {'reason': 'checkmate', 'winner': 'b'},
        ),
      );
      await archive.recordAcceptedState(first, seat: 'b');
      final rematch = OnlineGameState.fromJson(
        stateJson(
          round: 2,
          sequence: 12,
          status: 'complete',
          result: {'reason': 'agreement'},
        ),
      );
      await archive.recordAcceptedState(rematch, seat: 'b');
      await archive.recordAcceptedState(rematch, seat: 'w');
      final records = await GameHistoryStorage().load();
      expect(records.length, 3);
      expect(records.map((r) => r.id).toSet(), {
        OnlineGameArchive.recordId('room', 1, 'b'),
        OnlineGameArchive.recordId('room', 2, 'b'),
        OnlineGameArchive.recordId('room', 2, 'w'),
      });
      expect(
        records.every((r) => r.status == GameHistoryStatus.completed),
        isTrue,
      );
      final mate = records.firstWhere((r) => r.moves.isNotEmpty);
      expect(mate.resultTitle, 'Checkmate · Black wins');
      expect(mate.humanSide, Side.black);
      expect(mate.opponentLabel, 'White Hero');
      expect(
        CinematicReplay.fromMoves(
          moves: mate.moves,
          resultTitle: mate.resultTitle,
        ).finalPosition.isCheckmate,
        isTrue,
      );
      expect(records.where((r) => r.moves.isEmpty).length, 2);
    },
  );

  test(
    'empty active/waiting rooms are skipped but zero-move endings saved',
    () async {
      final archive = OnlineGameArchive();
      addTearDown(archive.dispose);
      await archive.recordAcceptedState(
        OnlineGameState.fromJson(stateJson(status: 'waiting')),
        seat: 'w',
      );
      await archive.recordAcceptedState(
        OnlineGameState.fromJson(stateJson(sequence: 2)),
        seat: 'w',
      );
      expect(await GameHistoryStorage().load(), isEmpty);
      await archive.recordAcceptedState(
        OnlineGameState.fromJson(
          stateJson(
            sequence: 3,
            status: 'complete',
            result: {'reason': 'timeout', 'winner': 'b'},
          ),
        ),
        seat: 'w',
      );
      final record = (await GameHistoryStorage().load()).single;
      expect(record.moves, isEmpty);
      expect(record.finalFen, Chess.initial.fen);
      expect(record.resultTitle, 'Winner by timeout · Black wins');
    },
  );

  test('client ignores snapshots rejected by session.apply', () async {
    final storage = CountingStorage();
    final archive = OnlineGameArchive(storage: storage);
    final channel = FakeChannel();
    final client = OnlineMatchClient(
      channelFactory: (_) => channel,
      gameArchive: archive,
    );
    addTearDown(client.dispose);
    addTearDown(archive.dispose);
    await client.connect(Uri.parse('ws://localhost:8080'));
    final current = played(['e2e4', 'e7e5']);
    channel.seat(state: stateJson(game: current, sequence: 5));
    await flush();
    await archive.pending;
    final old = stateJson(
      game: played(['e2e4']),
      sequence: 4,
      status: 'complete',
      result: {'reason': 'resignation', 'winner': 'b'},
    );
    channel.receive({'type': 'game_state', 'state': old});
    channel.receive({
      'type': 'game_state',
      'state': {...old, 'sequence': 5},
    });
    await flush();
    await archive.pending;
    expect(client.state!.fen, current.position.fen);
    final record = (await storage.load()).single;
    expect(record.status, GameHistoryStatus.unfinished);
    expect(record.moves, current.uciMoves);
    expect(storage.written.length, 1);
  });

  test(
    'SAN/FEN mismatch and malformed notation never create a recording',
    () async {
      final failures = <Object>[];
      final archive = OnlineGameArchive(
        reportFailure: (error, stack) => failures.add(error),
      );
      addTearDown(archive.dispose);
      final mismatched = stateJson(game: played(['e2e4']));
      mismatched['san'] = ['d4'];
      await archive.recordAcceptedState(
        OnlineGameState.fromJson(mismatched),
        seat: 'w',
      );
      expect(await GameHistoryStorage().load(), isEmpty);
      expect(archive.error, isNotNull);
      expect(failures.single, isA<FormatException>());
      await archive.recordAcceptedState(
        OnlineGameState.fromJson({
          ...mismatched,
          'sequence': 2,
          'san': [''],
        }),
        seat: 'w',
      );
      expect(await GameHistoryStorage().load(), isEmpty);
      expect(failures.length, 2);
      await archive.recordAcceptedState(
        OnlineGameState.fromJson(
          stateJson(game: played(['e2e4']), sequence: 3),
        ),
        seat: 'w',
      );
      expect(archive.error, isNull);
      expect((await GameHistoryStorage().load()).single.moves, ['e2e4']);
    },
  );

  test(
    'serialized saves survive appearance reads finishing out of order',
    () async {
      final appearances = [
        Completer<BoardAppearance?>(),
        Completer<BoardAppearance?>(),
      ];
      var read = 0;
      final storage = CountingStorage();
      final archive = OnlineGameArchive(
        storage: storage,
        loadMatchAppearance: (_, _) => appearances[read++].future,
        now: () => DateTime.fromMillisecondsSinceEpoch(1000),
      );
      addTearDown(archive.dispose);
      final first = archive.recordAcceptedState(
        OnlineGameState.fromJson(
          stateJson(game: played(['e2e4']), sequence: 1),
        ),
        seat: 'w',
      );
      final second = archive.recordAcceptedState(
        OnlineGameState.fromJson(
          stateJson(game: played(['e2e4', 'e7e5']), sequence: 2),
        ),
        seat: 'w',
      );
      appearances[1].complete(appearance(PiecePackId.futuristic));
      await flush();
      expect(storage.written, isEmpty);
      appearances[0].complete(appearance(PiecePackId.greek));
      await Future.wait([first, second]);
      expect(storage.written.map((r) => r.moves.length), [1, 2]);
      expect(
        storage.written.last.completedAt.isAfter(
          storage.written.first.completedAt,
        ),
        isTrue,
      );
      final record = (await storage.load()).single;
      expect(record.moves, ['e2e4', 'e7e5']);
      expect(record.whitePackId, PiecePackId.futuristic);
    },
  );

  test(
    'clock snapshots deduplicate and older sequences cannot overwrite',
    () async {
      final storage = CountingStorage();
      final archive = OnlineGameArchive(storage: storage);
      addTearDown(archive.dispose);
      final game = played(['e2e4', 'e7e5']);
      await archive.recordAcceptedState(
        OnlineGameState.fromJson(stateJson(game: game, sequence: 5)),
        seat: 'w',
      );
      await archive.recordAcceptedState(
        OnlineGameState.fromJson(
          stateJson(game: game, sequence: 6, whiteMs: 12345),
        ),
        seat: 'w',
      );
      await archive.recordAcceptedState(
        OnlineGameState.fromJson(
          stateJson(game: played(['e2e4']), sequence: 4),
        ),
        seat: 'w',
      );
      expect(storage.written.length, 1);
      expect((await storage.load()).single.moves, game.uciMoves);
    },
  );

  test(
    'room appearance precedes Home fallback and live display enriches active records',
    () async {
      await const HomeChessSet(
        pack: PiecePackId.futuristic,
        classic: true,
        style: ClassicPieceStyle.wood,
      ).save();
      final archive = OnlineGameArchive();
      addTearDown(archive.dispose);
      final game = played(['e2e4']);
      await archive.recordAcceptedState(
        OnlineGameState.fromJson(stateJson(game: game)),
        seat: 'w',
      );
      var record = (await GameHistoryStorage().load()).single;
      expect(record.whitePackId, PiecePackId.futuristic);
      expect(record.classicPieces, isTrue);
      expect(record.classicStyle, ClassicPieceStyle.wood);
      final displayed = BoardAppearance(
        white: appearance(PiecePackId.greek).white,
        black: appearance(PiecePackId.egyptian).black,
        board: appearance(PiecePackId.japanese).board,
      );
      await archive.rememberAppearance(
        gameId: 'room',
        round: 1,
        seat: 'w',
        appearance: displayed,
      );
      record = (await GameHistoryStorage().load()).single;
      expect(record.whitePackId, PiecePackId.greek);
      expect(record.blackPackId, PiecePackId.egyptian);
      expect(record.boardPackId, PiecePackId.japanese);
      expect(record.classicPieces, isFalse);

      await MatchAppearanceStorage.save('room', 'b', displayed);
      await archive.recordAcceptedState(
        OnlineGameState.fromJson(
          stateJson(
            game: game,
            status: 'complete',
            result: {'reason': 'agreement'},
          ),
        ),
        seat: 'b',
      );
      final black = (await GameHistoryStorage().load()).firstWhere(
        (r) => r.humanSide == Side.black,
      );
      expect(black.whitePackId, PiecePackId.greek);
      expect(black.blackPackId, PiecePackId.egyptian);
      expect(black.boardPackId, PiecePackId.japanese);
      expect(black.classicPieces, isFalse);
    },
  );

  test(
    'retry retains failed completed snapshot after leaving for another room',
    () async {
      final storage = CountingStorage()..failures = 1;
      final errors = <Object>[];
      final archive = OnlineGameArchive(
        storage: storage,
        reportFailure: (error, stack) => errors.add(error),
      );
      addTearDown(archive.dispose);
      await archive.recordAcceptedState(
        OnlineGameState.fromJson(
          stateJson(
            game: played(['e2e4']),
            status: 'complete',
            result: {'reason': 'resignation', 'winner': 'w'},
          ),
        ),
        seat: 'w',
      );
      expect(archive.error, isNotNull);
      expect(errors.single, isA<StateError>());
      await archive.recordAcceptedState(
        OnlineGameState.fromJson(
          stateJson(
            gameId: 'another-room',
            status: 'complete',
            result: {'reason': 'agreement'},
          ),
        ),
        seat: 'w',
      );
      await archive.retryFailed();
      expect(archive.error, isNull);
      final records = await GameHistoryStorage().load();
      expect(records.length, 2);
      final original = records.firstWhere(
        (r) => r.id == OnlineGameArchive.recordId('room', 1, 'w'),
      );
      expect(original.moves, ['e2e4']);
      expect(original.resultTitle, 'Resignation · White wins');
      expect(original.status, GameHistoryStatus.completed);
    },
  );

  test(
    'archive writes finish after client and owned service disposal',
    () async {
      final appearanceReady = Completer<BoardAppearance?>();
      final archive = OnlineGameArchive(
        loadMatchAppearance: (_, _) => appearanceReady.future,
      );
      final channel = FakeChannel();
      final client = OnlineMatchClient(
        channelFactory: (_) => channel,
        gameArchive: archive,
      );
      await client.connect(Uri.parse('ws://localhost:8080'));
      channel.seat(
        state: stateJson(
          game: played(['e2e4']),
          status: 'complete',
          result: {'reason': 'agreement'},
        ),
      );
      await flush();
      client.dispose();
      archive.dispose();
      appearanceReady.complete(appearance(PiecePackId.futuristic));
      await archive.pending;
      expect((await GameHistoryStorage().load()).single.moves, ['e2e4']);
    },
  );
}
