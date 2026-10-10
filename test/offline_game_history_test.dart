// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';

import 'package:battle_chess_arena/src/app.dart';
import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/domain/game_time_control.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/history/game_history_screen.dart';
import 'package:battle_chess_arena/src/features/play/animation_lab_screen.dart';
import 'package:battle_chess_arena/src/features/play/capture_battle_overlay.dart';
import 'package:battle_chess_arena/src/features/play/checkmate_dialog.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:battle_chess_arena/src/services/computer_player.dart';
import 'package:battle_chess_arena/src/services/game_history_storage.dart';
import 'package:battle_chess_arena/src/services/last_game_storage.dart';
import 'package:battle_chess_arena/src/services/player_progress_controller.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Hold the actual platform write while the board remains visible.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'theme_music_test.dart' show FakeMusicOutput;
import 'support/piece_choice.dart';

const _beforeMate = ['e2e4', 'e7e5', 'f1c4', 'b8c6', 'd1h5', 'g8f6'];
const _captureMate = [..._beforeMate, 'h5f7'];
const _mateResult = 'White wins by checkmate';

class _BlockedHistoryPreferencesStore extends InMemorySharedPreferencesStore {
  _BlockedHistoryPreferencesStore() : super.empty();

  final releaseHistoryWrites = Completer<void>();
  int historyWrites = 0;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == 'flutter.${GameHistoryStorage.storageKey}') {
      historyWrites++;
      await releaseHistoryWrites.future;
    }
    return super.setValue(valueType, key, value);
  }
}

SavedGame _saved({
  List<String> moves = _beforeMate,
  String id = 'original-progress-session',
  GameTimeControl timeControl = GameTimeControl.practice,
}) => SavedGame(
  mode: PlayerMode.local,
  homePack: PiecePackId.greek,
  difficulty: ComputerDifficulty.medium,
  moves: moves,
  whiteMilliseconds: 600000,
  blackMilliseconds: 600000,
  fastBattles: false,
  whitePack: PiecePackId.greek,
  blackPack: PiecePackId.futuristic,
  boardPack: PiecePackId.anime,
  updatedAtEpochMs: DateTime(2026, 10, 3, 12).millisecondsSinceEpoch,
  timeControl: timeControl,
  progressGameId: id,
  historyGameId: id,
);

Finder _key(String key) => find.byKey(ValueKey(key));
ChessBoard _board(WidgetTester tester) =>
    tester.widget<ChessBoard>(find.byType(ChessBoard).first);

/// Inspect the durable archive directly. Calling loadSnapshot here would also
/// migrate a resumable slot and could conceal a missing completion/leave hook.
Future<List<GameHistoryRecord>> _persistedHistory() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final encoded = prefs.getString(GameHistoryStorage.storageKey);
  if (encoded == null) return [];
  final archive = jsonDecode(encoded) as Map;
  return [
    for (final record in archive['records'] as List)
      GameHistoryRecord.fromJson((record as Map).cast<String, Object?>()),
  ];
}

Future<void> _screenSize(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1200, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void _historyTestWidgets(
  String description,
  Future<void> Function(WidgetTester tester) body,
) => testWidgets(description, (tester) async {
  try {
    await body(tester);
  } finally {
    // Future callbacks belonging to this FakeAsync zone must finish before the
    // next test replaces its preferences. Disposal also records an open game.
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
    for (var frame = 0; !settled && frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(
      settled,
      isTrue,
      reason: 'History writes must finish in this test zone',
    );
    expect(error, isNull);
    await tester.pump();
  }
});

Future<PlayerProgressController> _openLocal(
  WidgetTester tester, {
  SavedGame? saved,
}) async {
  await _screenSize(tester);
  if (saved != null) await LastGameStorage.save(saved);
  final progress = PlayerProgressController();
  addTearDown(progress.dispose);
  await tester.pumpWidget(
    PlayerProgressScope(
      controller: progress,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                key: const ValueKey('open-local-game'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AnimationLabScreen(
                      pack: piecePacks.firstWhere(
                        (pack) => pack.id == PiecePackId.greek,
                      ),
                      savedGame: saved,
                      timeControl: GameTimeControl.practice,
                    ),
                  ),
                ),
                child: const Text('Open local game'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(_key('open-local-game'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return progress;
}

Future<void> _move(WidgetTester tester, String uci) async {
  final from = Square.fromName(uci.substring(0, 2));
  final to = Square.fromName(uci.substring(2, 4));
  final source = _key('square-${from.name}');
  await tester.ensureVisible(source);
  await tester.pump();
  await tester.tap(source);
  await tester.pump();
  expect(_board(tester).legalTargets, contains(to));
  await tester.tap(_key('square-${to.name}'));
  await tester.pump();
}

Future<void> _leave(WidgetTester tester) async {
  await tester.pageBack();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
  expect(_key('open-local-game'), findsOneWidget);
  expect(find.byType(AnimationLabScreen), findsNothing);
}

Future<void> _finishCaptureResult(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 1700));
  await tester.pump();
  expect(_key('checkmate-animation'), findsOneWidget);
  expect(_key('checkmate-heading'), findsNothing);
  await tester.pump(
    checkmateAnimationDuration + const Duration(milliseconds: 1),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pump(const Duration(milliseconds: 100));
  expect(find.text('White Wins!'), findsOneWidget);
}

void main() {
  setUp(() {
    AnimationLabScreen.debugClockFactory = () =>
        TestWidgetsFlutterBinding.ensureInitialized().clock.stopwatch();
  });
  tearDown(() => AnimationLabScreen.debugClockFactory = null);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LastGameStorage.clear();
  });

  _historyTestWidgets(
    'leaving a played local game archives its full immutable record',
    (tester) async {
      final progress = await _openLocal(tester);
      await _move(tester, 'e2e4');
      await _move(tester, 'e7e5');
      final finalFen = _board(tester).position.fen;
      final resumable = (await LastGameStorage.load())!;
      await _leave(tester);

      final record = (await _persistedHistory()).single;
      expect(record.mode, GameHistoryMode.local);
      expect(record.status, GameHistoryStatus.unfinished);
      expect(record.resultTitle, 'Game unfinished');
      expect(record.moves, ['e2e4', 'e7e5']);
      expect(record.finalFen, finalFen);
      expect(record.id, resumable.historyGameId);
      expect(record.whitePackId, PiecePackId.greek);
      expect(() => record.moves.add('d2d4'), throwsUnsupportedError);
      expect((await LastGameStorage.load())!.moves, record.moves);
      expect(progress.progress.completedGames, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  _historyTestWidgets(
    'capturing mate persists before the capture ends or dialog opens',
    (tester) async {
      final progress = await _openLocal(tester, saved: _saved());
      await _move(tester, 'h5f7');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CaptureBattleOverlay), findsOneWidget);
      expect(_key('checkmate-heading'), findsNothing);
      expect(_board(tester).position.isCheckmate, isTrue);

      final record = (await _persistedHistory()).single;
      expect(record.moves, _captureMate);
      expect(record.status, GameHistoryStatus.completed);
      expect(record.resultTitle, _mateResult);
      expect(record.finalFen, _board(tester).position.fen);
      expect(await LastGameStorage.load(), isNull);
      expect(progress.progress.completedGames, 0);

      await _finishCaptureResult(tester);
      expect(progress.progress.completedGames, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      final afterDisposal = await _persistedHistory();
      expect(afterDisposal, hasLength(1));
      expect(afterDisposal.single.toJson(), record.toJson());
      expect(tester.takeException(), isNull);
    },
  );

  _historyTestWidgets(
    'rule draw locks further moves while its durable archive is pending',
    (tester) async {
      final platform = _BlockedHistoryPreferencesStore();
      await tester.runAsync(() async {
        SharedPreferences.resetStatic();
        SharedPreferencesStorePlatform.instance = platform;
        await SharedPreferences.getInstance();
      });
      const sevenPlies = [
        'g1f3',
        'g8f6',
        'f3g1',
        'f6g8',
        'g1f3',
        'g8f6',
        'f3g1',
      ];
      const drawnMoves = [...sevenPlies, 'f6g8'];
      final saved = _saved(
        moves: sevenPlies,
        id: 'local-repetition-draw',
        timeControl: GameTimeControl.legacy,
      );
      try {
        final progress = await _openLocal(tester, saved: saved);
        await _move(tester, 'f6g8');
        final drawnFen = _board(tester).position.fen;
        // This fixture deliberately uses landscape, whose detail panel keeps
        // the full MatchHeader rather than the compact portrait status bar.
        final drawnClocks = tester.widget<MatchHeader>(
          find.byType(MatchHeader),
        );
        expect(GameSession.fromMoves(moves: drawnMoves).isRuleDraw, isTrue);
        expect(platform.historyWrites, greaterThan(0));
        expect(find.text('Game Drawn'), findsNothing);
        await tester.pump(const Duration(seconds: 2));
        final pausedClocks = tester.widget<MatchHeader>(
          find.byType(MatchHeader),
        );
        expect(pausedClocks.whiteTime, drawnClocks.whiteTime);
        expect(pausedClocks.blackTime, drawnClocks.blackTime);

        // e2-e4 is legal in this position, but the recorded result is final.
        await tester.tap(_key('square-e2'));
        await tester.pump();
        expect(_board(tester).legalTargets, isEmpty);
        await tester.tap(_key('square-e4'));
        await tester.pump();
        expect(_board(tester).position.fen, drawnFen);
        expect(progress.progress.completedGames, 0);
        final preferences = await SharedPreferences.getInstance();
        final source = SavedGame.fromJson(
          (jsonDecode(preferences.getString('lastOpenGameV1')!) as Map)
              .cast<String, Object?>(),
        );
        expect(source.moves, drawnMoves);
        expect(source.historyResultTitle, 'Game drawn');
        expect(source.whiteMilliseconds, drawnClocks.whiteTime.inMilliseconds);
        expect(source.blackMilliseconds, drawnClocks.blackTime.inMilliseconds);

        platform.releaseHistoryWrites.complete();
        for (
          var frame = 0;
          frame < 80 && find.text('Game Drawn').evaluate().isEmpty;
          frame++
        ) {
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(find.text('Game Drawn'), findsOneWidget);
        final record = (await _persistedHistory()).single;
        expect(record.id, saved.historyGameId);
        expect(record.status, GameHistoryStatus.completed);
        expect(record.resultTitle, 'Game drawn');
        expect(record.moves, drawnMoves);
        expect(record.finalFen, drawnFen);
        expect(_board(tester).position.fen, drawnFen);
        expect(progress.progress.completedGames, 1);
        expect(tester.takeException(), isNull);
      } finally {
        if (!platform.releaseHistoryWrites.isCompleted) {
          platform.releaseHistoryWrites.complete();
        }
      }
    },
  );

  _historyTestWidgets(
    'New Game preserves the previous played game under a distinct ID',
    (tester) async {
      final progress = await _openLocal(tester);
      await _move(tester, 'e2e4');
      await _move(tester, 'e7e5');
      final originalFen = _board(tester).position.fen;
      final originalId = (await LastGameStorage.load())!.historyGameId;
      await tester.ensureVisible(find.byTooltip('New game'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('New game'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('New Game'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await chooseGamePieces(tester);
      expect(_board(tester).position.fen, Chess.initial.fen);
      final original = (await _persistedHistory()).single;
      expect(original.id, originalId);
      expect(original.moves, ['e2e4', 'e7e5']);
      expect(original.finalFen, originalFen);

      await _move(tester, 'd2d4');
      await _move(tester, 'd7d5');
      final nextId = (await LastGameStorage.load())!.historyGameId;
      expect(nextId, isNot(originalId));
      await _leave(tester);
      final records = await _persistedHistory();
      expect(records, hasLength(2));
      expect(
        records.singleWhere((record) => record.id == originalId).toJson(),
        original.toJson(),
      );
      expect(records.singleWhere((record) => record.id == nextId).moves, [
        'd2d4',
        'd7d5',
      ]);
      expect(progress.progress.completedGames, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  _historyTestWidgets(
    'replacing Home resume slot keeps played moves accessible in history',
    (tester) async {
      await _screenSize(tester);
      final saved = _saved(moves: const ['e2e4', 'e7e5', 'g1f3']);
      await LastGameStorage.save(saved);
      await tester.pumpWidget(
        BattleChessArenaApp(
          musicOutput: FakeMusicOutput(),
          incomingLinks: const Stream.empty(),
        ),
      );
      await tester.pumpAndSettle();
      final play = _key('play-computer-button');
      await tester.ensureVisible(play);
      await tester.pumpAndSettle();
      await tester.tap(play);
      await tester.pumpAndSettle();
      expect(find.text('Resume last game?'), findsOneWidget);
      await tester.tap(find.text('New Game'));
      await tester.pumpAndSettle();
      expect(await LastGameStorage.load(), isNull);
      expect(find.text('Choose computer difficulty'), findsOneWidget);
      final record = (await _persistedHistory()).single;
      expect(record.id, saved.historyGameId);
      expect(record.moves, saved.moves);
      expect(record.status, GameHistoryStatus.unfinished);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      final history = _key('game-history-button');
      await tester.ensureVisible(history);
      await tester.pumpAndSettle();
      await tester.tap(history);
      await tester.pumpAndSettle();
      expect(find.byType(GameHistoryScreen), findsOneWidget);
      await tester.tap(_key('history-record-${record.id}'));
      await tester.pumpAndSettle();
      expect(find.byType(GameHistoryDetailScreen), findsOneWidget);
      expect(_board(tester).position.fen, record.finalFen);
      expect(find.text('Game unfinished'), findsOneWidget);
      expect(find.byType(AnimationLabScreen), findsNothing);
      final context = tester.element(find.byType(GameHistoryDetailScreen));
      expect(PlayerProgressScope.maybeOf(context)!.progress.completedGames, 0);
      expect((await _persistedHistory()).single.toJson(), record.toJson());
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  _historyTestWidgets(
    'undo after completion keeps history separate and reward session stable',
    (tester) async {
      final saved = _saved();
      final progress = await _openLocal(tester, saved: saved);
      await _move(tester, 'h5f7');
      await _finishCaptureResult(tester);
      final original = (await _persistedHistory()).single;
      expect(progress.progress.completedGames, 1);
      final originalProgress = progress.progress.toJson();
      await tester.tap(find.text('Review Board'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.ensureVisible(find.byTooltip('Undo'));
      // The checkmated board retains its animated check emphasis on review.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byTooltip('Undo'));
      await tester.pump();
      final continued = (await LastGameStorage.load())!;
      expect(continued.moves, _beforeMate);
      expect(continued.historyGameId, isNot(original.id));
      expect(continued.progressGameId, saved.progressGameId);
      expect((await _persistedHistory()).single.toJson(), original.toJson());

      await _move(tester, 'h5f7');
      await _finishCaptureResult(tester);
      final records = await _persistedHistory();
      expect(records, hasLength(2));
      expect(
        records.singleWhere((record) => record.id == original.id).toJson(),
        original.toJson(),
      );
      final continuation = records.singleWhere(
        (record) => record.id == continued.historyGameId,
      );
      expect(continuation.moves, _captureMate);
      expect(continuation.resultTitle, _mateResult);
      expect(continuation.status, GameHistoryStatus.completed);
      expect(progress.progress.toJson(), originalProgress);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
