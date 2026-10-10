import 'dart:async';
import 'dart:convert';

import 'package:battle_chess_arena/src/domain/bot_tournament.dart';
import 'package:battle_chess_arena/src/domain/cinematic_replay.dart';
import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/domain/game_time_control.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/services/computer_player_contract.dart';
import 'package:battle_chess_arena/src/services/game_history_storage.dart';
import 'package:battle_chess_arena/src/services/last_game_storage.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Tests exercise the platform's real failure contract behind SharedPreferences.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

const _mate = ['f2f3', 'e7e5', 'g2g4', 'd8h4'];

class _FailingPreferencesStore extends InMemorySharedPreferencesStore {
  _FailingPreferencesStore(super.data) : super.withData();
  bool failNextHistoryWrite = true;
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == 'flutter.${GameHistoryStorage.storageKey}' &&
        failNextHistoryWrite) {
      failNextHistoryWrite = false;
      return false;
    }
    return super.setValue(valueType, key, value);
  }
}

GameHistoryRecord _record({
  String id = 'record-one',
  int at = 2000,
  List<String> moves = _mate,
  GameHistoryStatus status = GameHistoryStatus.completed,
  String result = 'Black wins by checkmate',
}) => GameHistoryRecord(
  id: id,
  completedAt: DateTime.fromMillisecondsSinceEpoch(at, isUtc: true),
  resultTitle: result,
  status: status,
  mode: GameHistoryMode.computer,
  moves: moves,
  humanSide: Side.white,
  whiteName: 'Alex',
  blackName: 'Medium computer',
  whitePackId: PiecePackId.futuristic,
  blackPackId: PiecePackId.greek,
  boardPackId: PiecePackId.anime,
  classicPieces: true,
  classicStyle: ClassicPieceStyle.metal,
  whiteCustomSetId: 'custom-white',
  whiteCustomName: 'Aurora workshop',
  difficulty: ComputerDifficulty.medium,
);

SavedGame _saved({
  String? id,
  String? historyId,
  String? historyResultTitle,
  List<String> moves = const ['e2e4', 'e7e5'],
  PlayerMode mode = PlayerMode.computer,
  int at = 1000,
  int whiteMs = 30000,
  int blackMs = 30000,
}) => SavedGame(
  mode: mode,
  humanSide: Side.white,
  homePack: PiecePackId.greek,
  difficulty: ComputerDifficulty.hard,
  moves: moves,
  whiteMilliseconds: whiteMs,
  blackMilliseconds: blackMs,
  fastBattles: true,
  whitePack: PiecePackId.greek,
  blackPack: PiecePackId.futuristic,
  boardPack: PiecePackId.anime,
  updatedAtEpochMs: at,
  classicPieces: true,
  classicStyle: ClassicPieceStyle.metal,
  timeControl: GameTimeControl.rapid,
  progressGameId: id,
  historyGameId: historyId,
  historyResultTitle: historyResultTitle,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'record round trip freezes moves and retains actual appearance and result',
    () {
      final moves = _mate.toList();
      final record = _record(moves: moves);
      moves.clear();
      final restored = GameHistoryRecord.fromJson(
        (jsonDecode(jsonEncode(record.toJson())) as Map)
            .cast<String, Object?>(),
      );
      expect(restored.toJson(), record.toJson());
      expect(restored.moves, _mate);
      expect(
        restored.finalFen,
        CinematicReplay.fromMoves(moves: _mate).finalPosition.fen,
      );
      expect(restored.initialFen, Chess.initial.fen);
      expect(restored.completedAt.isUtc, isTrue);
      expect(restored.recordedAt, restored.completedAt);
      expect(restored.opponentLabel, 'Medium computer');
      expect(restored.modeLabel, 'Computer');
      expect(restored.statusLabel, 'Completed');
      expect(restored.whiteCustomName, 'Aurora workshop');
      expect(restored.classicStyle, ClassicPieceStyle.metal);
      expect(() => restored.moves.clear(), throwsUnsupportedError);
    },
  );

  test(
    'invalid moves and mismatched final or initial positions are rejected',
    () {
      expect(() => _record(moves: ['e2e5']), throwsFormatException);
      expect(
        () => GameHistoryRecord(
          id: 'bad-final',
          completedAt: DateTime.fromMillisecondsSinceEpoch(1000),
          resultTitle: 'Game unfinished',
          mode: GameHistoryMode.local,
          moves: ['e2e4'],
          finalFen: Chess.initial.fen,
        ),
        throwsFormatException,
      );
      final json = _record().toJson()..['initialFen'] = 'unsupported start';
      expect(() => GameHistoryRecord.fromJson(json), throwsFormatException);
      expect(() => _record(id: ''), throwsFormatException);
      expect(() => _record(at: -1), throwsFormatException);
    },
  );

  test(
    'persistent history reloads from a new instance newest first without eviction',
    () async {
      final store = GameHistoryStorage();
      for (var i = 0; i < 60; i++) {
        await store.save(_record(id: 'game-$i', at: 1000 + i));
      }
      final restored = await GameHistoryStorage().load();
      expect(restored, hasLength(60));
      expect(restored.first.id, 'game-59');
      expect(restored.last.id, 'game-0');
      expect(() => restored.clear(), throwsUnsupportedError);
      final prefs = await SharedPreferences.getInstance();
      expect(
        (jsonDecode(prefs.getString(GameHistoryStorage.storageKey)!)
            as Map)['records'],
        hasLength(60),
      );
    },
  );

  test(
    'concurrent saves across instances cannot overwrite one another',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final gate = Completer<SharedPreferences>();
      var firstRequested = false;
      var secondRequested = false;
      final first = GameHistoryStorage(
        preferences: () {
          firstRequested = true;
          return gate.future;
        },
      );
      final second = GameHistoryStorage(
        preferences: () async {
          secondRequested = true;
          return prefs;
        },
      );
      final saveFirst = first.save(_record(id: 'first'));
      await Future<void>.delayed(Duration.zero);
      final saveSecond = second.save(_record(id: 'second'));
      await Future<void>.delayed(Duration.zero);
      expect(firstRequested, isTrue);
      expect(secondRequested, isFalse);
      gate.complete(prefs);
      await Future.wait([saveFirst, saveSecond]);
      expect(
        (await GameHistoryStorage().load()).map((record) => record.id).toSet(),
        {'first', 'second'},
      );
    },
  );

  test(
    'repeated terminal callbacks retain one original completion record',
    () async {
      final store = GameHistoryStorage();
      await store.save(_record(at: 2000));
      await store.save(_record(at: 3000));
      await store.save(_record(at: 4000));
      final records = await store.load();
      expect(records, hasLength(1));
      expect(records.single.completedAtEpochMs, 2000);
      expect(records.single.moves, _mate);
    },
  );

  test(
    'a completed ID cannot silently identify a different completed game',
    () async {
      final store = GameHistoryStorage();
      await store.save(_record());
      await expectLater(
        store.save(_record(moves: ['e2e4'], result: 'White wins on time')),
        throwsStateError,
      );
      expect((await store.load()).single.moves, _mate);
      await store.save(_record(id: 'other'));
      expect(await store.load(), hasLength(2));
    },
  );

  test(
    'unfinished snapshots update then upgrade without late regression',
    () async {
      final store = GameHistoryStorage();
      await store.save(
        _record(
          at: 1000,
          moves: ['f2f3'],
          status: GameHistoryStatus.unfinished,
          result: 'Game unfinished',
        ),
      );
      await store.save(
        _record(
          at: 2000,
          moves: ['f2f3', 'e7e5'],
          status: GameHistoryStatus.unfinished,
          result: 'Game unfinished',
        ),
      );
      await store.save(
        _record(
          at: 1500,
          moves: ['f2f3'],
          status: GameHistoryStatus.unfinished,
          result: 'Game unfinished',
        ),
      );
      var records = await store.load();
      expect(records.single.moves, ['f2f3', 'e7e5']);
      expect(records.single.statusLabel, 'Unfinished');
      // A clock correction must not prevent a real completion from upgrading it.
      await store.save(_record(at: 1800));
      await store.save(
        _record(
          at: 9000,
          moves: ['f2f3'],
          status: GameHistoryStatus.unfinished,
          result: 'Game unfinished',
        ),
      );
      records = await store.load();
      expect(records, hasLength(1));
      expect(records.single.status, GameHistoryStatus.completed);
      expect(records.single.moves, _mate);
      expect(records.single.recordedAtEpochMs, 1800);
    },
  );

  test(
    'individual corrupt records are isolated and preserved on later writes',
    () async {
      final valid = _record(id: 'valid');
      final invalidMoves = _record(id: 'bad-moves').toJson()
        ..['moves'] = ['e2e5'];
      final invalidFinal = _record(id: 'bad-fen').toJson()
        ..['finalFen'] = Chess.initial.fen;
      final futureSchema = _record(id: 'future-version').toJson()
        ..['version'] = 9;
      SharedPreferences.setMockInitialValues({
        GameHistoryStorage.storageKey: jsonEncode({
          'version': 1,
          'records': [valid.toJson(), invalidMoves, invalidFinal, futureSchema],
        }),
      });
      final store = GameHistoryStorage();
      var snapshot = await store.loadSnapshot();
      expect(snapshot.records.map((record) => record.id), ['valid']);
      expect(snapshot.unavailable, hasLength(3));
      expect(snapshot.unavailable.map((record) => record.id).toSet(), {
        'bad-moves',
        'bad-fen',
        'future-version',
      });
      expect(() => snapshot.unavailable.clear(), throwsUnsupportedError);
      await store.save(_record(id: 'another'));
      snapshot = await store.loadSnapshot();
      expect(snapshot.records, hasLength(2));
      expect(snapshot.unavailable, hasLength(3));
      final prefs = await SharedPreferences.getInstance();
      final raw =
          jsonDecode(prefs.getString(GameHistoryStorage.storageKey)!) as Map;
      expect(
        raw['records'],
        containsAll([invalidMoves, invalidFinal, futureSchema]),
      );
    },
  );

  test(
    'duplicate IDs do not hide other valid games or cause whole-archive failure',
    () async {
      final one = _record().toJson();
      SharedPreferences.setMockInitialValues({
        GameHistoryStorage.storageKey: jsonEncode({
          'version': 1,
          'records': [one, one, _record(id: 'other').toJson()],
        }),
      });
      final snapshot = await GameHistoryStorage().loadSnapshot();
      expect(snapshot.records, hasLength(2));
      expect(snapshot.unavailable, hasLength(1));
    },
  );

  test(
    'an unreadable root archive is never replaced with an empty library',
    () async {
      const encoded = '{broken archive';
      SharedPreferences.setMockInitialValues({
        GameHistoryStorage.storageKey: encoded,
      });
      final store = GameHistoryStorage();
      final snapshot = await store.loadSnapshot();
      expect(snapshot.records, isEmpty);
      expect(snapshot.unavailable, hasLength(1));
      await expectLater(store.save(_record()), throwsStateError);
      expect(
        (await SharedPreferences.getInstance()).getString(
          GameHistoryStorage.storageKey,
        ),
        encoded,
      );
    },
  );

  test(
    'saved-game factory and migration share stable IDs and immutable moves',
    () {
      final saved = _saved();
      final first = GameHistoryRecord.fromSavedGame(saved);
      final second = GameHistoryRecord.fromSavedGame(saved);
      expect(first.id, second.id);
      expect(first.id, legacySavedGameId(saved));
      expect(first.id, GameHistoryRecord.idForSavedGame(saved));
      expect(first.status, GameHistoryStatus.unfinished);
      expect(first.resultTitle, 'Game unfinished');
      expect(first.classicPieces, isTrue);
      expect(first.whitePackId, PiecePackId.greek);
      expect(first.difficulty, ComputerDifficulty.hard);
      expect(
        GameHistoryRecord.fromSavedGame(_saved(id: 'stable-session')).id,
        'stable-session',
      );
      expect(
        GameHistoryRecord.fromSavedGame(
          _saved(id: 'reward-session', historyId: 'continued-history'),
        ).id,
        'continued-history',
      );
      expect(
        GameHistoryRecord.fromSavedGame(_saved(moves: _mate)).resultTitle,
        'Black wins by checkmate',
      );
      expect(
        GameHistoryRecord.fromSavedGame(_saved(whiteMs: 0)).resultTitle,
        'Black wins on time',
      );
    },
  );

  test(
    'retained open and terminal last-game snapshots migrate without touching resume data',
    () async {
      final open = jsonEncode(_saved(id: 'legacy-open').toJson());
      SharedPreferences.setMockInitialValues({'lastOpenGameV1': open});
      final store = GameHistoryStorage();
      await store.migrateRetainedGames();
      await store.migrateRetainedGames();
      var records = await store.load();
      expect(records, hasLength(1));
      expect(records.single.status, GameHistoryStatus.unfinished);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('lastOpenGameV1'), open);

      final complete = jsonEncode(
        _saved(id: 'legacy-complete', moves: _mate).toJson(),
      );
      await prefs.setString('lastOpenGameV1', complete);
      records = await store.load();
      expect(records, hasLength(2));
      expect(
        records.singleWhere((record) => record.id == 'legacy-complete').status,
        GameHistoryStatus.completed,
      );
      expect(prefs.getString('lastOpenGameV1'), complete);
    },
  );

  test(
    'tournament and conquest retained games migrate but overwritten rounds are not invented',
    () async {
      final cup = builtInTournaments.firstWhere((cup) => !cup.isConquest);
      final conquest = builtInConquests.first;
      final retained = jsonEncode({
        'version': 1,
        'run': {
          'runId': 'run-kept',
          'attempt': 3,
          'results': [
            ['loss', 'win'],
          ],
        },
        'game': _saved(id: 'retained-tournament').toJson(),
      });
      final ledgerOnly = jsonEncode({
        'version': 1,
        'run': {
          'runId': 'overwritten-run',
          'attempt': 2,
          'results': [
            ['loss', 'win'],
          ],
        },
        'game': null,
      });
      final conquestState = jsonEncode({
        'player': {'rating': 1200},
        conquest.id: jsonEncode({
          'version': 1,
          'run': {'runId': 'conquest-run', 'attempt': 1},
          'game': _saved(id: 'retained-conquest', moves: _mate).toJson(),
        }),
        'past-only': ledgerOnly,
      });
      SharedPreferences.setMockInitialValues({
        'bot_tournament_${cup.id}': retained,
        'bot_tournament_past-only': ledgerOnly,
        'conquest_player_v1': conquestState,
        'bot_tournament_broken': 'not json',
      });
      final records = await GameHistoryStorage().load();
      expect(records, hasLength(2));
      expect(
        records.every((record) => record.mode == GameHistoryMode.tournament),
        isTrue,
      );
      expect(
        records
            .singleWhere((record) => record.id == 'retained-tournament')
            .tournamentTitle,
        cup.title,
      );
      expect(
        records
            .singleWhere((record) => record.id == 'retained-conquest')
            .status,
        GameHistoryStatus.completed,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('bot_tournament_${cup.id}'), retained);
      expect(prefs.getString('conquest_player_v1'), conquestState);
      expect(prefs.getString('bot_tournament_past-only'), ledgerOnly);
      expect(prefs.getString('bot_tournament_broken'), 'not json');
    },
  );

  test(
    'corrupt legacy slots are skipped without erasing other retained sources',
    () async {
      final bad = _saved().toJson()..['moves'] = ['e2e5'];
      final cup = builtInTournaments.first;
      final retained = jsonEncode({
        'version': 1,
        'game': _saved(id: 'good-source').toJson(),
      });
      SharedPreferences.setMockInitialValues({
        'lastOpenGameV1': jsonEncode(bad),
        'bot_tournament_${cup.id}': retained,
      });
      final records = await GameHistoryStorage().load();
      expect(records.map((record) => record.id), ['good-source']);
      expect(
        (await SharedPreferences.getInstance()).getString('lastOpenGameV1'),
        jsonEncode(bad),
      );
    },
  );

  test(
    'legacy tournament migration and resume factory identify the same game',
    () async {
      final saved = _saved(at: 7777);
      final cup = builtInTournaments.first;
      SharedPreferences.setMockInitialValues({
        'bot_tournament_${cup.id}': jsonEncode({
          'version': 1,
          'run': {'runId': 'old-run', 'attempt': 2},
          'game': saved.toJson(),
        }),
      });
      final store = GameHistoryStorage();
      final migrated = (await store.load()).single;
      expect(migrated.id, GameHistoryRecord.idForSavedGame(saved));
      await store.save(
        GameHistoryRecord.fromSavedGame(
          saved,
          id: GameHistoryRecord.idForSavedGame(saved),
          mode: GameHistoryMode.tournament,
          status: GameHistoryStatus.completed,
          resultTitle: 'White wins by resignation',
        ),
      );
      final records = await store.load();
      expect(records, hasLength(1));
      expect(records.single.status, GameHistoryStatus.completed);
      expect(records.single.resultTitle, 'White wins by resignation');
    },
  );

  test(
    'online recordings contain public game data without seat or auth tokens',
    () async {
      final original = GameHistoryRecord(
        id: 'online-public-game-round-2',
        completedAt: DateTime.fromMillisecondsSinceEpoch(3000, isUtc: true),
        resultTitle: 'Draw by agreement',
        mode: GameHistoryMode.online,
        moves: ['e2e4', 'e7e5'],
        whiteName: 'Alex',
        blackName: 'Riley',
        humanSide: Side.black,
      );
      final json = original.toJson()..['seatToken'] = 'private-seat-token';
      final validated = GameHistoryRecord.fromJson(json);
      await GameHistoryStorage().save(validated);
      final encoded = (await SharedPreferences.getInstance()).getString(
        GameHistoryStorage.storageKey,
      )!;
      expect(encoded, isNot(contains('seatToken')));
      expect(encoded, isNot(contains('private-seat-token')));
      expect((await GameHistoryStorage().load()).single.opponentLabel, 'Alex');
    },
  );

  test(
    'a rejected platform write rolls back optimistic cache and allows retry',
    () async {
      final original = jsonEncode({
        'version': 1,
        'records': [_record(id: 'kept').toJson()],
      });
      SharedPreferences.resetStatic();
      SharedPreferencesStorePlatform.instance = _FailingPreferencesStore({
        'flutter.${GameHistoryStorage.storageKey}': original,
      });
      addTearDown(() => SharedPreferences.setMockInitialValues({}));
      final store = GameHistoryStorage();
      await expectLater(
        store.save(_record(id: 'not-written')),
        throwsStateError,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(GameHistoryStorage.storageKey), original);
      expect((await store.load()).map((record) => record.id), ['kept']);
      await store.save(_record(id: 'retry'));
      expect((await store.load()).map((record) => record.id).toSet(), {
        'kept',
        'retry',
      });
    },
  );

  test(
    'a failed migration preserves resumable source for the next durable retry',
    () async {
      final original = jsonEncode(_saved(id: 'retained-for-retry').toJson());
      SharedPreferences.resetStatic();
      SharedPreferencesStorePlatform.instance = _FailingPreferencesStore({
        'flutter.lastOpenGameV1': original,
      });
      addTearDown(() => SharedPreferences.setMockInitialValues({}));
      final store = GameHistoryStorage();
      await expectLater(store.migrateRetainedGames(), throwsStateError);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('lastOpenGameV1'), original);
      expect(prefs.getString(GameHistoryStorage.storageKey), isNull);
      await store.migrateRetainedGames();
      expect((await store.load()).single.id, 'retained-for-retry');
      expect(prefs.getString('lastOpenGameV1'), original);
    },
  );

  test(
    'pending zero-move completion retains its supplied outcome on migration',
    () async {
      final saved = _saved(
        historyId: 'before-first-move-timeout',
        historyResultTitle: 'Black wins on time',
        moves: [],
        whiteMs: 0,
        blackMs: 0,
      );
      expect(saved.canResume, isFalse);
      final raw = jsonEncode(saved.toJson());
      SharedPreferences.setMockInitialValues({'lastOpenGameV1': raw});
      final record = (await GameHistoryStorage().load()).single;
      expect(record.id, 'before-first-move-timeout');
      expect(record.moves, isEmpty);
      expect(record.status, GameHistoryStatus.completed);
      expect(record.resultTitle, 'Black wins on time');
      expect(record.finalFen, Chess.initial.fen);
      expect(
        (await SharedPreferences.getInstance()).getString('lastOpenGameV1'),
        raw,
      );
    },
  );

  test(
    'pending resignation completion survives migration despite a nonterminal board',
    () async {
      final saved = _saved(
        historyId: 'pending-resignation',
        historyResultTitle: 'White wins by resignation',
      );
      final raw = jsonEncode(saved.toJson());
      SharedPreferences.setMockInitialValues({'lastOpenGameV1': raw});
      final record = (await GameHistoryStorage().load()).single;
      expect(record.id, 'pending-resignation');
      expect(record.status, GameHistoryStatus.completed);
      expect(record.resultTitle, 'White wins by resignation');
      expect(record.moves, saved.moves);
      expect(
        CinematicReplay.fromMoves(moves: record.moves).finalPosition.isGameOver,
        isFalse,
      );
      expect(
        (await SharedPreferences.getInstance()).getString('lastOpenGameV1'),
        raw,
      );
    },
  );
}
