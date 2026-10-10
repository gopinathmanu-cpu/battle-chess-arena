import 'dart:async';
import 'dart:convert';

import 'package:battle_chess_arena/src/app.dart';
import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/play/animation_lab_screen.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:battle_chess_arena/src/services/computer_player.dart';
import 'package:battle_chess_arena/src/services/game_history_storage.dart';
import 'package:battle_chess_arena/src/services/last_game_storage.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Exercise the actual platform failure and delayed initialization contracts.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/types.dart';

import 'theme_music_test.dart' show FakeMusicOutput;
import 'support/piece_choice.dart';

SavedGame savedGame({
  PlayerMode mode = PlayerMode.local,
  List<String> moves = const ['e2e4', 'e7e5', 'g1f3'],
  bool classicPieces = false,
  bool? animatedArena,
  ClassicPieceStyle classicStyle = ClassicPieceStyle.magneticTeaching,
  String? progressGameId,
  String? historyGameId,
  String? historyResultTitle,
  int whiteMilliseconds = 574000,
  int blackMilliseconds = 581000,
}) => SavedGame(
  mode: mode,
  homePack: PiecePackId.greek,
  difficulty: ComputerDifficulty.hard,
  moves: moves,
  whiteMilliseconds: whiteMilliseconds,
  blackMilliseconds: blackMilliseconds,
  fastBattles: true,
  whitePack: PiecePackId.greek,
  blackPack: PiecePackId.futuristic,
  boardPack: PiecePackId.anime,
  updatedAtEpochMs: 123456789,
  lifelinesRemaining: 2,
  classicPieces: classicPieces,
  animatedArena: animatedArena,
  classicStyle: classicStyle,
  progressGameId: progressGameId,
  historyGameId: historyGameId,
  historyResultTitle: historyResultTitle,
);

const _resumeKey = 'lastOpenGameV1';

class _ControlledPreferencesStore extends InMemorySharedPreferencesStore {
  _ControlledPreferencesStore(super.data) : super.withData();

  Completer<void>? readGate;
  bool failNextWrite = false;
  bool throwNextWrite = false;
  int removals = 0;

  @override
  Future<Map<String, Object>> getAllWithParameters(
    GetAllParameters parameters,
  ) async {
    await readGate?.future;
    return super.getAllWithParameters(parameters);
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == 'flutter.$_resumeKey') {
      if (throwNextWrite) {
        throwNextWrite = false;
        throw PlatformException(code: 'write-failed');
      }
      if (failNextWrite) {
        failNextWrite = false;
        return false;
      }
    }
    return super.setValue(valueType, key, value);
  }

  @override
  Future<bool> remove(String key) async {
    removals++;
    return super.remove(key);
  }
}

Future<void> _waitUntil(WidgetTester tester, bool Function() condition) async {
  for (var frame = 0; frame < 80 && !condition(); frame++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(condition(), isTrue, reason: 'Expected async UI operation to finish');
}

Future<void> _disposeAndDrain(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  var settled = false;
  Object? error;
  GameHistoryStorage().loadSnapshot().then(
    (_) => settled = true,
    onError: (Object failure) {
      error = failure;
      settled = true;
    },
  );
  await _waitUntil(tester, () => settled);
  expect(error, isNull);
  // Complete idle-tail cleanup in this test's zone before resetting mocks.
  await tester.pump();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LastGameStorage.clear();
  });

  test('saved game round trip restores legal history and settings', () async {
    final original = savedGame(
      classicPieces: true,
      classicStyle: ClassicPieceStyle.metal,
    );
    await LastGameStorage.save(original);
    final restored = await LastGameStorage.load();
    expect(restored?.moves, original.moves);
    expect(restored?.difficulty, ComputerDifficulty.hard);
    expect(restored?.blackPack, PiecePackId.futuristic);
    expect(restored?.lifelinesRemaining, 2);
    expect(restored?.classicPieces, isTrue);
    expect(restored?.classicStyle, ClassicPieceStyle.metal);
    final session = GameSession.fromMoves(
      mode: restored!.mode,
      moves: restored.moves,
    );
    expect(session.position.turn, Side.black);
    expect(session.sanMoves, ['e4', 'e5', 'Nf3']);
    session.undo();
    expect(session.uciMoves, ['e2e4', 'e7e5']);
  });

  test('older saved games receive all three lifelines', () {
    final json = savedGame().toJson()..remove('lifelinesRemaining');
    expect(SavedGame.fromJson(json).lifelinesRemaining, 3);
  });

  for (final arena in [true, false]) {
    test(
      'saved page mode $arena survives JSON and device storage independently of icons',
      () async {
        final original = savedGame(classicPieces: arena, animatedArena: arena);
        final json = (jsonDecode(jsonEncode(original.toJson())) as Map)
            .cast<String, Object?>();
        expect(json['animatedArena'], arena);
        final decoded = SavedGame.fromJson(json);
        expect(decoded.animatedArena, arena);
        expect(decoded.classicPieces, arena);
        await LastGameStorage.save(decoded);
        final restored = await LastGameStorage.load();
        expect(restored!.animatedArena, arena);
        expect(restored.classicPieces, arena);
        expect(restored.moves, original.moves);
      },
    );
  }

  test('legacy saves without page mode retain a null migration marker', () {
    for (final classic in [true, false]) {
      final json = savedGame(classicPieces: classic).toJson()
        ..remove('animatedArena');
      final legacy = SavedGame.fromJson(json);
      expect(legacy.animatedArena, isNull);
      expect(legacy.classicPieces, classic);
      expect(legacy.toJson().containsKey('animatedArena'), isFalse);
    }
  });

  test(
    'history identity and pending ending round trip independently of XP',
    () {
      final original = savedGame(
        progressGameId: 'xp-game',
        historyGameId: 'continued-film',
        historyResultTitle: 'White wins by resignation',
      );
      final restored = SavedGame.fromJson(
        (jsonDecode(jsonEncode(original.toJson())) as Map)
            .cast<String, Object?>(),
      );
      expect(restored.progressGameId, 'xp-game');
      expect(restored.historyGameId, 'continued-film');
      expect(restored.historyResultTitle, 'White wins by resignation');
      expect(restored.moves, original.moves);
      expect(restored.canResume, isFalse);
      expect(GameHistoryRecord.idForSavedGame(restored), 'continued-film');
    },
  );

  test('older resume schema needs no history fields', () {
    final json = savedGame(progressGameId: 'old-xp-id').toJson()
      ..remove('historyGameId')
      ..remove('historyResultTitle');
    final restored = SavedGame.fromJson(json);
    expect(restored.historyGameId, isNull);
    expect(restored.historyResultTitle, isNull);
    expect(restored.canResume, isTrue);
    expect(GameHistoryRecord.idForSavedGame(restored), 'old-xp-id');
    json.remove('progressGameId');
    final older = SavedGame.fromJson(json);
    expect(older.progressGameId, isNull);
    expect(older.canResume, isTrue);
  });

  test(
    'pending resignation source remains durable until archive migration',
    () async {
      final terminal = savedGame(
        historyGameId: 'resigned-game',
        historyResultTitle: 'White wins by resignation',
      );
      final revision = await LastGameStorage.saveHistorySource(terminal);
      final preferences = await SharedPreferences.getInstance();
      final source = preferences.getString(_resumeKey);
      expect(source, isNotNull);
      final restored = SavedGame.fromJson(
        (jsonDecode(source!) as Map).cast<String, Object?>(),
      );
      expect(restored.moves, terminal.moves);
      expect(restored.canResume, isFalse);
      expect(await LastGameStorage.load(), isNull);
      expect(preferences.getString(_resumeKey), source);
      await GameHistoryStorage().migrateRetainedGames();
      final records = await GameHistoryStorage().load();
      expect(records, hasLength(1));
      expect(records.single.id, 'resigned-game');
      expect(records.single.resultTitle, 'White wins by resignation');
      expect(records.single.status, GameHistoryStatus.completed);
      expect(records.single.moves, terminal.moves);
      expect(preferences.getString(_resumeKey), source);
      await LastGameStorage.clear(expectedRevision: revision);
      expect(preferences.getString(_resumeKey), isNull);
      expect((await GameHistoryStorage().load()).single.moves, terminal.moves);
    },
  );

  test(
    'zero-move timeout source bypasses resume filter and survives raw load',
    () async {
      final terminal = savedGame(
        historyGameId: 'opening-timeout',
        moves: const [],
        whiteMilliseconds: 0,
        blackMilliseconds: 0,
        historyResultTitle: 'Black wins on time',
      );
      await LastGameStorage.saveHistorySource(terminal);
      final preferences = await SharedPreferences.getInstance();
      final source = preferences.getString(_resumeKey);
      expect(source, isNotNull);
      // Clear the process cache without removing the retained raw source.
      await LastGameStorage.clear();
      await preferences.setString(_resumeKey, source!);
      expect(await LastGameStorage.load(), isNull);
      expect(preferences.getString(_resumeKey), source);
      await GameHistoryStorage().migrateRetainedGames();
      final record = (await GameHistoryStorage().load()).single;
      expect(record.id, 'opening-timeout');
      expect(record.moves, isEmpty);
      expect(record.resultTitle, 'Black wins on time');
      expect(record.status, GameHistoryStatus.completed);
    },
  );

  test('stale completion ticket cannot clear a newer game', () async {
    final revision = await LastGameStorage.saveHistorySource(
      savedGame(
        historyGameId: 'old-completed',
        historyResultTitle: 'White wins by resignation',
      ),
    );
    final next = savedGame(historyGameId: 'new-game', moves: ['d2d4']);
    await LastGameStorage.save(next);
    await LastGameStorage.clear(expectedRevision: revision);
    expect((await LastGameStorage.load())?.historyGameId, 'new-game');
    final preferences = await SharedPreferences.getInstance();
    final raw = SavedGame.fromJson(
      (jsonDecode(preferences.getString(_resumeKey)!) as Map)
          .cast<String, Object?>(),
    );
    expect(raw.historyGameId, 'new-game');
    expect(raw.moves, ['d2d4']);
    expect(raw.historyResultTitle, isNull);
  });

  test('delayed normal clear cannot remove a newer save', () async {
    SharedPreferences.resetStatic();
    final platform = _ControlledPreferencesStore({
      'flutter.$_resumeKey': jsonEncode(savedGame().toJson()),
    })..readGate = Completer<void>();
    SharedPreferencesStorePlatform.instance = platform;
    final clearing = LastGameStorage.clear();
    final next = savedGame(historyGameId: 'newer-during-read', moves: ['d2d4']);
    final saving = LastGameStorage.save(next);
    platform.readGate!.complete();
    await Future.wait([clearing, saving]);
    expect(platform.removals, 0);
    expect((await LastGameStorage.load())?.historyGameId, 'newer-during-read');
    final preferences = await SharedPreferences.getInstance();
    expect(
      SavedGame.fromJson(
        (jsonDecode(preferences.getString(_resumeKey)!) as Map)
            .cast<String, Object?>(),
      ).moves,
      ['d2d4'],
    );
  });

  for (final corruptSource in [false, true]) {
    test(
      'cold load cannot ${corruptSource ? 'clear' : 'replace'} a newer in-memory game',
      () async {
        SharedPreferences.resetStatic();
        final platform = _ControlledPreferencesStore({
          'flutter.$_resumeKey': corruptSource
              ? '{invalid old source'
              : jsonEncode(savedGame(historyGameId: 'old-game').toJson()),
        })..readGate = Completer<void>();
        SharedPreferencesStorePlatform.instance = platform;
        final loading = LastGameStorage.load();
        final next = savedGame(
          historyGameId: 'new-game-during-load',
          moves: ['d2d4'],
        );
        final saving = LastGameStorage.save(next);
        platform.readGate!.complete();
        final loaded = await loading;
        await saving;
        expect(loaded?.historyGameId, next.historyGameId);
        expect(
          (await LastGameStorage.load())?.historyGameId,
          next.historyGameId,
        );
        expect(platform.removals, 0);
        final preferences = await SharedPreferences.getInstance();
        final raw = SavedGame.fromJson(
          (jsonDecode(preferences.getString(_resumeKey)!) as Map)
              .cast<String, Object?>(),
        );
        expect(raw.historyGameId, next.historyGameId);
        expect(raw.moves, ['d2d4']);
      },
    );
  }

  test('cold load cannot resume a newer pending completion', () async {
    SharedPreferences.resetStatic();
    final platform = _ControlledPreferencesStore({
      'flutter.$_resumeKey': jsonEncode(
        savedGame(historyGameId: 'old-game').toJson(),
      ),
    })..readGate = Completer<void>();
    SharedPreferencesStorePlatform.instance = platform;
    final loading = LastGameStorage.load();
    final terminal = savedGame(
      historyGameId: 'pending-completion',
      historyResultTitle: 'Black wins by resignation',
    );
    final saving = LastGameStorage.saveHistorySource(terminal);
    platform.readGate!.complete();
    expect(await loading, isNull);
    await saving;
    expect(await LastGameStorage.load(), isNull);
    expect(platform.removals, 0);
    final preferences = await SharedPreferences.getInstance();
    final raw = SavedGame.fromJson(
      (jsonDecode(preferences.getString(_resumeKey)!) as Map)
          .cast<String, Object?>(),
    );
    expect(raw.historyGameId, terminal.historyGameId);
    expect(raw.historyResultTitle, terminal.historyResultTitle);
    expect(raw.canResume, isFalse);
  });

  for (final throwsFailure in [false, true]) {
    test(
      'failed terminal source ${throwsFailure ? 'exception' : 'return'} restores prior resume',
      () async {
        SharedPreferences.resetStatic();
        final platform = _ControlledPreferencesStore({});
        SharedPreferencesStorePlatform.instance = platform;
        final previous = savedGame(historyGameId: 'resumable-before-failure');
        await LastGameStorage.save(previous);
        platform.failNextWrite = !throwsFailure;
        platform.throwNextWrite = throwsFailure;
        await expectLater(
          LastGameStorage.saveHistorySource(
            savedGame(
              historyGameId: 'failed-ending',
              historyResultTitle: 'Black wins by resignation',
            ),
          ),
          throwsFailure ? throwsA(isA<PlatformException>()) : throwsStateError,
        );
        expect(
          (await LastGameStorage.load())?.historyGameId,
          'resumable-before-failure',
        );
        final preferences = await SharedPreferences.getInstance();
        final raw = SavedGame.fromJson(
          (jsonDecode(preferences.getString(_resumeKey)!) as Map)
              .cast<String, Object?>(),
        );
        expect(raw.historyGameId, previous.historyGameId);
        expect(raw.historyResultTitle, isNull);
      },
    );
  }

  test('saved Royal Classic selections migrate to Manga Vanguard', () {
    final json = savedGame().toJson()
      ..['homePack'] = 'classic'
      ..['whitePack'] = 'classic'
      ..['blackPack'] = 'classic'
      ..['boardPack'] = 'classic';
    final migrated = SavedGame.fromJson(json);
    expect(migrated.homePack, PiecePackId.anime);
    expect(migrated.whitePack, PiecePackId.anime);
    expect(migrated.blackPack, PiecePackId.anime);
    expect(migrated.boardPack, PiecePackId.anime);
  });

  testWidgets('home prompts only after Play Computer and resumes the game', (
    tester,
  ) async {
    try {
      await LastGameStorage.save(savedGame(mode: PlayerMode.computer));
      await tester.pumpWidget(
        BattleChessArenaApp(musicOutput: FakeMusicOutput()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Resume last game?'), findsNothing);
      expect(find.byType(AnimationLabScreen), findsNothing);

      final playComputer = find.byKey(const ValueKey('play-computer-button'));
      await tester.ensureVisible(playComputer);
      await tester.pumpAndSettle();
      await tester.tap(playComputer);
      await tester.pumpAndSettle();
      await _waitUntil(
        tester,
        () => find.text('Resume last game?').evaluate().isNotEmpty,
      );

      expect(find.text('Resume last game?'), findsOneWidget);
      expect(find.text('Resume Last Game'), findsOneWidget);
      expect(find.text('New Game'), findsOneWidget);
      await tester.tap(find.text('Resume Last Game'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('piece-type-choice')), findsNothing);
      final match = tester.widget<AnimationLabScreen>(
        find.byType(AnimationLabScreen),
      );
      expect(match.savedGame?.moves, ['e2e4', 'e7e5', 'g1f3']);
      final board = tester.widget<ChessBoard>(find.byType(ChessBoard));
      expect(board.position.turn, Side.black);
      expect(board.position.board.pieceAt(Square.f3)?.role, Role.knight);
    } finally {
      await _disposeAndDrain(tester);
      // The native computer fallback owns a 12-second timeout started on resume.
      await tester.pump(const Duration(seconds: 13));
    }
  });

  testWidgets('Play Computer asks difficulty when no game can be resumed', (
    tester,
  ) async {
    try {
      await LastGameStorage.save(
        savedGame(mode: PlayerMode.computer, moves: const []),
      );
      await tester.pumpWidget(
        BattleChessArenaApp(musicOutput: FakeMusicOutput()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Resume last game?'), findsNothing);
      expect(find.byType(AnimationLabScreen), findsNothing);
      expect(await LastGameStorage.load(), isNull);

      final playComputer = find.byKey(const ValueKey('play-computer-button'));
      await tester.ensureVisible(playComputer);
      await tester.pumpAndSettle();
      await tester.tap(playComputer);
      await tester.pumpAndSettle();
      await _waitUntil(
        tester,
        () => find.text('Choose computer difficulty').evaluate().isNotEmpty,
      );

      expect(find.text('Resume last game?'), findsNothing);
      expect(find.byType(AnimationLabScreen), findsNothing);
      expect(find.text('Choose computer difficulty'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('computer-difficulty-medium')),
      );
      await tester.tap(find.byKey(const ValueKey('start-computer-game')));
      await chooseGamePieces(tester);
      await tester.pumpAndSettle();
      expect(find.byType(AnimationLabScreen), findsOneWidget);
    } finally {
      await _disposeAndDrain(tester);
    }
  });

  testWidgets('discarding a saved game asks difficulty for the new game', (
    tester,
  ) async {
    try {
      await LastGameStorage.save(savedGame(mode: PlayerMode.computer));
      await tester.pumpWidget(
        BattleChessArenaApp(musicOutput: FakeMusicOutput()),
      );
      await tester.pumpAndSettle();

      final playComputer = find.byKey(const ValueKey('play-computer-button'));
      await tester.ensureVisible(playComputer);
      await tester.pumpAndSettle();
      await tester.tap(playComputer);
      await tester.pumpAndSettle();
      await _waitUntil(
        tester,
        () => find.text('New Game').evaluate().isNotEmpty,
      );
      await tester.tap(find.text('New Game'));
      await tester.pumpAndSettle();
      await _waitUntil(
        tester,
        () => find.text('Choose computer difficulty').evaluate().isNotEmpty,
      );

      expect(find.text('Choose computer difficulty'), findsOneWidget);
      expect(find.byType(AnimationLabScreen), findsNothing);
      await tester.tap(find.byKey(const ValueKey('computer-difficulty-easy')));
      await tester.tap(find.byKey(const ValueKey('start-computer-game')));
      await chooseGamePieces(tester);
      await tester.pumpAndSettle();

      final match = tester.widget<AnimationLabScreen>(
        find.byType(AnimationLabScreen),
      );
      expect(match.difficulty, ComputerDifficulty.easy);
      expect(match.savedGame, isNull);
    } finally {
      await _disposeAndDrain(tester);
    }
  });

  testWidgets('new game requires confirmation before clearing progress', (
    tester,
  ) async {
    try {
      await LastGameStorage.save(savedGame());
      await tester.pumpWidget(
        MaterialApp(
          home: AnimationLabScreen(
            pack: piecePacks.firstWhere((p) => p.id == PiecePackId.greek),
            savedGame: savedGame(),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester.widget<ChessBoard>(find.byType(ChessBoard)).position.turn,
        Side.black,
      );
      await tester.ensureVisible(find.byTooltip('New game'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('New game'));
      await tester.pump();
      expect(find.text('Start a new game?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(
        tester.widget<ChessBoard>(find.byType(ChessBoard)).position.turn,
        Side.black,
      );
      expect(await LastGameStorage.load(), isNotNull);
      await tester.ensureVisible(find.byTooltip('New game'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('New game'));
      await tester.pump();
      await tester.tap(find.text('New Game'));
      await tester.pump();
      await chooseGamePieces(tester, classic: false);
      await _waitUntil(
        tester,
        () =>
            tester.widget<ChessBoard>(find.byType(ChessBoard)).position.turn ==
            Side.white,
      );
      expect(
        tester.widget<ChessBoard>(find.byType(ChessBoard)).position.turn,
        Side.white,
      );
      expect(await LastGameStorage.load(), isNull);
      expect(
        tester
            .widget<ChessBoard>(find.byType(ChessBoard))
            .appearance!
            .standardPieces,
        isFalse,
      );
    } finally {
      await _disposeAndDrain(tester);
    }
  });
}
