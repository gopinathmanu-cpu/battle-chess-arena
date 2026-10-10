// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:ui' as ui;

import 'package:battle_chess_arena/src/domain/cinematic_replay.dart';
import 'package:battle_chess_arena/src/domain/animated_army_theme.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/history/game_history_screen.dart';
import 'package:battle_chess_arena/src/features/play/board_appearance.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:battle_chess_arena/src/features/play/neon_cinematic_screen.dart';
import 'package:battle_chess_arena/src/features/play/neon_illustrated_stage.dart';
import 'package:battle_chess_arena/src/services/cinematic_audio.dart';
import 'package:battle_chess_arena/src/services/game_history_storage.dart';
import 'package:battle_chess_arena/src/services/theme_music.dart';
import 'package:battle_chess_arena/src/theme/app_theme.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _mateMoves = ['f2f3', 'e7e5', 'g2g4', 'd8h4'];
const _mateResult = 'Black wins by checkmate';
final _previewKey = GlobalKey();

GameHistoryRecord _record({
  String id = 'recorded-game',
  int day = 3,
  List<String> moves = _mateMoves,
  GameHistoryStatus status = GameHistoryStatus.completed,
  GameHistoryMode mode = GameHistoryMode.computer,
  String? resultTitle,
  PiecePackId pack = PiecePackId.anime,
  bool classic = false,
  String? customId,
  String? customName,
  String opponent = 'Recorded opponent',
  Side? humanSide = Side.white,
}) => GameHistoryRecord(
  id: id,
  completedAt: DateTime(2026, 10, day, 18, 42),
  resultTitle:
      resultTitle ??
      (status == GameHistoryStatus.unfinished
          ? 'Game unfinished'
          : _mateResult),
  mode: mode,
  status: status,
  moves: moves,
  whiteName: 'Player one',
  blackName: opponent,
  humanSide: humanSide,
  opponentLabel: opponent,
  whitePackId: pack,
  blackPackId: pack,
  boardPackId: pack,
  classicPieces: classic,
  classicStyle: ClassicPieceStyle.wood,
  whiteCustomSetId: customId,
  blackCustomSetId: customId,
  whiteCustomName: customName,
  blackCustomName: customName,
);

class _HistoryStorage extends GameHistoryStorage {
  _HistoryStorage(this.loader);
  final Future<GameHistorySnapshot> Function() loader;
  int loads = 0;
  int saves = 0;

  @override
  Future<GameHistorySnapshot> loadSnapshot() {
    loads++;
    return loader();
  }

  @override
  Future<void> save(GameHistoryRecord record) async => saves++;
}

class _SilentNarrator implements CinematicNarrator {
  @override
  bool get supported => false;
  @override
  Future<void> narrate(String text, {double rate = 1}) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

class _SilentScore implements CinematicScore {
  @override
  Future<void> play({bool ducked = false}) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> impact({bool finale = false}) async {}
  @override
  Future<void> dispose() async {}
}

Finder _key(String key) => find.byKey(ValueKey(key));
ChessBoard _board(WidgetTester tester) =>
    tester.widget<ChessBoard>(_key('history-replay-board'));

Future<void> _mount(
  WidgetTester tester,
  Widget screen, {
  Size size = const Size(800, 1000),
  double scale = 1,
  EdgeInsets insets = EdgeInsets.zero,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final previewTheme = buildAppTheme();
  await tester.pumpWidget(
    MaterialApp(
      theme: const bool.fromEnvironment('CAPTURE_HISTORY_PREVIEWS')
          ? previewTheme.copyWith(
              textTheme: previewTheme.textTheme.apply(fontFamily: 'Roboto'),
              primaryTextTheme: previewTheme.primaryTextTheme.apply(
                fontFamily: 'Roboto',
              ),
            )
          : null,
      navigatorObservers: [musicRoutes],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: true,
          padding: insets,
          viewPadding: insets,
        ),
        child: RepaintBoundary(key: _previewKey, child: child!),
      ),
      home: screen,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      220,
      maxScrolls: 30,
      scrollable: find
          .descendant(
            of: _key('history-records'),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  testWidgets('lists all modes with newest status, date and recorded theme', (
    tester,
  ) async {
    final storage = _HistoryStorage(
      () async => GameHistorySnapshot(
        records: [
          _record(id: 'older', day: 1, mode: GameHistoryMode.local),
          _record(
            id: 'unfinished',
            day: 4,
            status: GameHistoryStatus.unfinished,
            moves: const ['e2e4', 'e7e5', 'd1h5'],
            pack: PiecePackId.futuristic,
            mode: GameHistoryMode.online,
          ),
          _record(id: 'middle', day: 2, mode: GameHistoryMode.tournament),
          _record(id: 'computer', day: 3),
        ],
      ),
    );
    await _mount(tester, GameHistoryScreen(storage: storage));
    expect(
      tester.getTopLeft(_key('history-record-unfinished')).dy,
      lessThan(tester.getTopLeft(_key('history-record-computer')).dy),
    );
    expect(
      find.descendant(
        of: _key('history-record-unfinished'),
        matching: find.text('Unfinished'),
      ),
      findsOneWidget,
    );
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('Neon Dominion'), findsOneWidget);
    expect(find.text('4 Oct 2026 · 18:42'), findsOneWidget);
    expect(find.text('2 moves'), findsWidgets);
    await tester.scrollUntilVisible(_key('history-record-older'), 200);
    expect(find.text('Local'), findsOneWidget);
    expect(find.text('Tournament'), findsOneWidget);
    expect(storage.saves, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('status filters preserve newest order and recorded replay', (
    tester,
  ) async {
    final unfinished = _record(
      id: 'open',
      day: 3,
      status: GameHistoryStatus.unfinished,
      moves: const ['e2e4', 'e7e5', 'd1h5'],
    );
    final records = [
      _record(id: 'older', day: 1),
      unfinished,
      _record(id: 'newer', day: 4),
    ];
    final storage = _HistoryStorage(
      () async => GameHistorySnapshot(records: records),
    );
    await _mount(tester, GameHistoryScreen(storage: storage));
    expect(
      tester.widget<ChoiceChip>(_key('history-filter-all')).selected,
      isTrue,
    );
    expect(_key('history-record-newer'), findsOneWidget);
    expect(_key('history-record-open'), findsOneWidget);
    expect(_key('history-record-older'), findsOneWidget);
    await _tapVisible(tester, _key('history-filter-completed'));
    expect(
      tester.widget<ChoiceChip>(_key('history-filter-completed')).selected,
      isTrue,
    );
    expect(_key('history-record-open'), findsNothing);
    expect(
      tester.getTopLeft(_key('history-record-newer')).dy,
      lessThan(tester.getTopLeft(_key('history-record-older')).dy),
    );
    await _tapVisible(tester, _key('history-filter-unfinished'));
    expect(_key('history-record-newer'), findsNothing);
    expect(_key('history-record-older'), findsNothing);
    expect(_key('history-record-open'), findsOneWidget);
    await _tapVisible(tester, _key('history-record-open'));
    expect(_board(tester).position.fen, unfinished.finalFen);
    expect(find.text('Game unfinished'), findsWidgets);
    expect(find.textContaining('Resume'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      tester.widget<ChoiceChip>(_key('history-filter-unfinished')).selected,
      isTrue,
    );
    await _tapVisible(tester, _key('history-filter-all'));
    expect(_key('history-record-open'), findsOneWidget);
    expect(_key('history-record-newer'), findsOneWidget);
    await _tapVisible(tester, _key('history-refresh'));
    expect(
      tester.widget<ChoiceChip>(_key('history-filter-all')).selected,
      isTrue,
    );
    expect(storage.loads, 2);
    expect(storage.saves, 0);
    expect(records[1].moves, ['e2e4', 'e7e5', 'd1h5']);
    expect(tester.takeException(), isNull);
  });

  for (final (status, filter, message) in [
    (GameHistoryStatus.completed, 'unfinished', 'No unfinished games'),
    (GameHistoryStatus.unfinished, 'completed', 'No completed games yet'),
  ]) {
    testWidgets('an empty $filter filter keeps other recordings', (
      tester,
    ) async {
      final storage = _HistoryStorage(
        () async => GameHistorySnapshot(
          records: [
            _record(
              status: status,
              moves: status == GameHistoryStatus.unfinished
                  ? const ['e2e4']
                  : _mateMoves,
            ),
          ],
        ),
      );
      await _mount(tester, GameHistoryScreen(storage: storage));
      await _tapVisible(tester, _key('history-filter-$filter'));
      expect(find.text(message), findsOneWidget);
      expect(find.text('No games saved yet'), findsNothing);
      expect(_key('history-record-recorded-game'), findsNothing);
      await _tapVisible(tester, _key('history-filter-all'));
      expect(_key('history-record-recorded-game'), findsOneWidget);
      expect(storage.loads, 1);
      expect(storage.saves, 0);
    });
  }

  testWidgets('unavailable warnings stay visible in an empty status filter', (
    tester,
  ) async {
    final storage = _HistoryStorage(
      () async => GameHistorySnapshot(
        records: [_record()],
        unavailable: [
          const GameHistoryUnavailableRecord(
            id: 'damaged',
            label: 'Retained damaged round',
            reason: 'Invalid moves',
          ),
        ],
      ),
    );
    await _mount(tester, GameHistoryScreen(storage: storage));
    await _tapVisible(tester, _key('history-filter-unfinished'));
    expect(_key('history-unavailable-notice'), findsOneWidget);
    expect(find.text('No unfinished games'), findsOneWidget);
    expect(find.text('Retained damaged round'), findsOneWidget);
    expect(_key('history-record-recorded-game'), findsNothing);
    await _tapVisible(tester, _key('history-filter-completed'));
    expect(_key('history-unavailable-notice'), findsOneWidget);
    expect(_key('history-record-recorded-game'), findsOneWidget);
    expect(storage.saves, 0);
  });

  for (final (size, scale) in [
    (const Size(390, 844), 1.0),
    (const Size(320, 568), 2.0),
    (const Size(650, 360), 2.0),
  ]) {
    testWidgets('all history filters remain accessible at $size / $scale', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        final storage = _HistoryStorage(
          () async => GameHistorySnapshot(
            records: [
              _record(id: 'complete'),
              _record(
                id: 'open',
                status: GameHistoryStatus.unfinished,
                moves: const ['e2e4'],
              ),
            ],
          ),
        );
        await _mount(
          tester,
          GameHistoryScreen(storage: storage),
          size: size,
          scale: scale,
        );
        for (final filter in ['completed', 'unfinished', 'all']) {
          final chip = _key('history-filter-$filter');
          await _tapVisible(tester, chip);
          // Filtering reflows the count/subtitle and can change scroll extent.
          // Check accessibility in the new layout after bringing it into view.
          await tester.ensureVisible(chip);
          await tester.pumpAndSettle();
          expect(
            tester
                .getSemantics(chip)
                .getSemanticsData()
                .flagsCollection
                .isSelected,
            ui.Tristate.isTrue,
          );
          expect(chip.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
        expect(storage.loads, 1);
        expect(storage.saves, 0);
      } finally {
        // Flutter checks active handles before external test tear-downs run.
        semantics.dispose();
      }
    });
  }

  testWidgets('empty history is useful and does not offer game resume', (
    tester,
  ) async {
    final storage = _HistoryStorage(
      () async => GameHistorySnapshot(records: const []),
    );
    await _mount(tester, GameHistoryScreen(storage: storage));
    expect(find.text('No games saved yet'), findsOneWidget);
    expect(
      tester.widget<ChoiceChip>(_key('history-filter-all')).selected,
      isTrue,
    );
    await _tapVisible(tester, _key('history-filter-completed'));
    expect(find.text('No games saved yet'), findsOneWidget);
    expect(find.text('No completed games yet'), findsNothing);
    expect(find.textContaining('Resume'), findsNothing);
    expect(storage.saves, 0);
  });

  testWidgets('load error retries without deleting the saved recording', (
    tester,
  ) async {
    var fails = true;
    final storage = _HistoryStorage(() async {
      if (fails) throw StateError('unavailable storage');
      return GameHistorySnapshot(records: [_record()]);
    });
    await _mount(tester, GameHistoryScreen(storage: storage));
    expect(find.text('History could not be loaded'), findsOneWidget);
    expect(
      find.textContaining('saved recordings have been kept'),
      findsOneWidget,
    );
    fails = false;
    await _tapVisible(tester, _key('history-retry'));
    expect(_key('history-record-recorded-game'), findsOneWidget);
    expect(storage.loads, 2);
    expect(storage.saves, 0);
  });

  testWidgets('corrupt individual history preserves metadata and valid games', (
    tester,
  ) async {
    final storage = _HistoryStorage(
      () async => GameHistorySnapshot(
        records: [_record()],
        unavailable: [
          GameHistoryUnavailableRecord(
            id: 'damaged',
            label: 'Retained tournament final',
            reason: 'Saved notation is invalid',
            resultTitle: 'White wins on time',
            completedAt: DateTime(2026, 10, 2, 14),
          ),
        ],
      ),
    );
    await _mount(tester, GameHistoryScreen(storage: storage));
    expect(_key('history-unavailable-notice'), findsOneWidget);
    expect(_key('history-record-recorded-game'), findsOneWidget);
    expect(find.text('Retained tournament final'), findsOneWidget);
    expect(find.text('White wins on time'), findsOneWidget);
    expect(
      find.textContaining('saved recording has been kept'),
      findsOneWidget,
    );
    expect(storage.saves, 0);
  });

  testWidgets('read-only replay steps through actual positions and SAN', (
    tester,
  ) async {
    final record = _record();
    final replay = CinematicReplay.fromMoves(
      moves: record.moves,
      resultTitle: record.resultTitle,
    );
    final storage = _HistoryStorage(
      () async => GameHistorySnapshot(records: [record]),
    );
    await _mount(tester, GameHistoryScreen(storage: storage));
    await _tapVisible(tester, _key('history-record-recorded-game'));
    await tester.ensureVisible(_key('history-replay-board'));
    expect(_board(tester).position.fen, record.finalFen);
    expect(_board(tester).selected, isNull);
    expect(_board(tester).legalTargets, isEmpty);
    expect(_board(tester).onSetSwipe, isNull);
    expect(
      find.ancestor(
        of: _key('history-replay-board'),
        matching: find.byWidgetPredicate(
          (widget) => widget is AbsorbPointer && widget.absorbing,
        ),
      ),
      findsOneWidget,
    );
    expect(tester.widget<IconButton>(_key('history-last')).onPressed, isNull);
    await _tapVisible(tester, _key('history-first'));
    expect(_board(tester).position.fen, Chess.initial.fen);
    expect(find.text('Opening position'), findsOneWidget);
    expect(
      tester.widget<IconButton>(_key('history-previous')).onPressed,
      isNull,
    );
    await _tapVisible(tester, _key('history-next'));
    expect(_board(tester).position.fen, replay.scenes.first.after.fen);
    expect(_board(tester).lastMoveFrom, Square.f2);
    expect(_board(tester).lastMoveTo, Square.f3);
    tester.widget<Slider>(_key('history-position-slider')).onChanged!(2);
    await tester.pump();
    expect(_board(tester).position.fen, replay.scenes[1].after.fen);
    await _tapVisible(tester, _key('history-move-4'));
    expect(find.text('Qh4#'), findsWidgets);
    // The board may be outside the viewport after selecting SAN; bring it back.
    await tester.ensureVisible(_key('history-replay-board'));
    await tester.pump();
    expect(_board(tester).position.fen, record.finalFen);
    expect(find.text(_mateResult), findsWidgets);
    expect(record.moves, _mateMoves);
    expect(storage.saves, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unfinished replay keeps its outcome through seeking', (
    tester,
  ) async {
    final record = _record(
      status: GameHistoryStatus.unfinished,
      moves: const ['e2e4', 'e7e5', 'd1h5'],
    );
    await _mount(tester, GameHistoryDetailScreen(record: record));
    expect(find.text('Unfinished'), findsOneWidget);
    expect(find.text('Game unfinished'), findsOneWidget);
    await _tapVisible(tester, _key('history-first'));
    expect(_board(tester).position.fen, Chess.initial.fen);
    expect(find.text('Game unfinished'), findsOneWidget);
    await _tapVisible(tester, _key('history-watch-cinematic'));
    expect(find.byType(NeonCinematicScreen), findsOneWidget);
    final film = tester.widget<NeonCinematicScreen>(
      find.byType(NeonCinematicScreen),
    );
    expect(film.moves, record.moves);
    expect(film.resultTitle, 'Game unfinished');
    expect(film.playerSide, Side.white);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('Black player history retains its loss perspective', (
    tester,
  ) async {
    final record = _record(
      humanSide: Side.black,
      moves: const ['e2e4', 'e7e5'],
      resultTitle: 'White wins on time',
    );
    await _mount(tester, GameHistoryDetailScreen(record: record));
    await _tapVisible(tester, _key('history-watch-cinematic'));
    final film = tester.widget<NeonCinematicScreen>(
      find.byType(NeonCinematicScreen),
    );
    expect(film.playerSide, Side.black);
    expect(film.resultTitle, record.resultTitle);
    expect(film.moves, record.moves);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('local replays do not assign a player loss perspective', (
    tester,
  ) async {
    final record = _record(mode: GameHistoryMode.local);
    await _mount(tester, GameHistoryDetailScreen(record: record));
    await _tapVisible(tester, _key('history-watch-cinematic'));
    final film = tester.widget<NeonCinematicScreen>(
      find.byType(NeonCinematicScreen),
    );
    expect(film.playerSide, isNull);
    expect(film.moves, record.moves);
    expect(film.resultTitle, record.resultTitle);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
    'legacy and custom appearances retain explicitly labeled Neon films',
    (tester) async {
      for (final record in [
        _record(pack: PiecePackId.egyptian),
        _record(pack: PiecePackId.japanese, classic: true),
        _record(customId: 'personal-army', customName: 'My champions'),
      ]) {
        GameHistoryRecord? viewed;
        await _mount(
          tester,
          GameHistoryDetailScreen(
            key: ObjectKey(record),
            record: record,
            cinematicBuilder: (selected) {
              viewed = selected;
              return NeonCinematicScreen(
                moves: selected.moves,
                resultTitle: selected.resultTitle,
                narrator: _SilentNarrator(),
                score: _SilentScore(),
              );
            },
          ),
        );
        await tester.ensureVisible(_key('history-watch-cinematic'));
        await tester.pump();
        expect(_key('history-film-interpretation'), findsOneWidget);
        if (record.whiteCustomSetId != null) {
          expect(
            find.text('Standard pieces show this custom-set recording.'),
            findsOneWidget,
          );
        }
        await _tapVisible(tester, _key('history-watch-cinematic'));
        expect(viewed, same(record));
        expect(find.byType(NeonCinematicScreen), findsOneWidget);
        final film = tester.widget<NeonCinematicScreen>(
          find.byType(NeonCinematicScreen),
        );
        expect(film.moves, record.moves);
        expect(film.resultTitle, _mateResult);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      }
    },
  );

  for (final theme in AnimatedArmyTheme.values) {
    testWidgets(
      '${theme.displayName} history keeps its world with either piece type',
      (tester) async {
        for (final classic in [false, true]) {
          final record = _record(pack: theme.packId, classic: classic);
          await _mount(tester, GameHistoryDetailScreen(record: record));
          await tester.ensureVisible(_key('history-watch-cinematic'));
          await tester.pump();
          expect(_key('history-film-interpretation'), findsNothing);
          await _tapVisible(tester, _key('history-watch-cinematic'));
          final film = tester.widget<NeonCinematicScreen>(
            find.byType(NeonCinematicScreen),
          );
          expect(film.theme, theme);
          expect(film.moves, record.moves);
          expect(film.resultTitle, record.resultTitle);
          expect(film.playerSide, record.humanSide);
          expect(record.classicPieces, classic);
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
        }
      },
    );
  }

  testWidgets('native Neon keeps its theme without interpretation label', (
    tester,
  ) async {
    await _mount(
      tester,
      GameHistoryDetailScreen(record: _record(pack: PiecePackId.futuristic)),
    );
    await tester.ensureVisible(_key('history-watch-cinematic'));
    await tester.pump();
    expect(_key('history-film-interpretation'), findsNothing);
    expect(_board(tester).appearance!.white.id, PiecePackId.futuristic);
    expect(_board(tester).appearance!.black.id, PiecePackId.futuristic);
  });

  testWidgets('zero-move unfinished game has a stable opening replay', (
    tester,
  ) async {
    await _mount(
      tester,
      GameHistoryDetailScreen(
        record: _record(status: GameHistoryStatus.unfinished, moves: const []),
      ),
    );
    expect(_board(tester).position.fen, Chess.initial.fen);
    expect(
      tester.widget<Slider>(_key('history-position-slider')).onChanged,
      isNull,
    );
    for (final control in ['first', 'previous', 'next', 'last']) {
      expect(
        tester.widget<IconButton>(_key('history-$control')).onPressed,
        isNull,
      );
    }
    await tester.ensureVisible(_key('history-watch-cinematic'));
    expect(
      tester.widget<FilledButton>(_key('history-watch-cinematic')).onPressed,
      isNotNull,
    );
    await tester.ensureVisible(find.text('No moves were recorded.'));
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 568), const Size(760, 330)]) {
    testWidgets('history and replay fit $size with large text', (tester) async {
      final record = _record(
        status: GameHistoryStatus.unfinished,
        moves: const ['e2e4', 'e7e5', 'd1h5'],
        customId: 'custom',
        customName: 'Original custom champions',
      );
      final storage = _HistoryStorage(
        () async => GameHistorySnapshot(records: [record]),
      );
      await _mount(
        tester,
        GameHistoryScreen(storage: storage),
        size: size,
        scale: 1.5,
      );
      expect(tester.takeException(), isNull);
      await _tapVisible(tester, _key('history-record-recorded-game'));
      expect(tester.takeException(), isNull);
      await _tapVisible(tester, _key('history-first'));
      expect(_board(tester).position.fen, Chess.initial.fen);
      await _tapVisible(tester, _key('history-last'));
      expect(_board(tester).position.fen, record.finalFen);
      await tester.ensureVisible(_key('history-watch-cinematic'));
      await tester.pump();
      expect(_key('history-film-interpretation'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(storage.saves, 0);
    });
  }

  testWidgets('a late storage load cannot update a disposed history screen', (
    tester,
  ) async {
    final pending = Completer<GameHistorySnapshot>();
    final storage = _HistoryStorage(() => pending.future);
    await tester.pumpWidget(
      MaterialApp(home: GameHistoryScreen(storage: storage)),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    pending.complete(GameHistorySnapshot(records: [_record()]));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(storage.saves, 0);
  });

  if (const bool.fromEnvironment('CAPTURE_HISTORY_PREVIEWS')) {
    testWidgets('capture optional history list and replay review frames', (
      tester,
    ) async {
      await _loadPreviewFonts(tester);
      final records = [
        _record(
          id: 'neon-computer',
          day: 4,
          pack: PiecePackId.futuristic,
          opponent: 'Medium computer',
        ),
        _record(
          id: 'online-unfinished',
          day: 3,
          mode: GameHistoryMode.online,
          status: GameHistoryStatus.unfinished,
          moves: const ['e2e4', 'e7e5', 'd1h5'],
          pack: PiecePackId.egyptian,
          opponent: 'Moon Mage',
        ),
        _record(
          id: 'classic-tournament',
          day: 2,
          mode: GameHistoryMode.tournament,
          classic: true,
          opponent: 'Tower Keeper',
        ),
        _record(
          id: 'local-custom',
          day: 1,
          mode: GameHistoryMode.local,
          customId: 'personal-army',
          customName: 'My champions',
          opponent: 'White player vs Black player',
        ),
      ];
      final storage = _HistoryStorage(
        () async => GameHistorySnapshot(records: records),
      );
      await _mount(
        tester,
        GameHistoryScreen(storage: storage),
        size: const Size(390, 844),
        insets: const EdgeInsets.fromLTRB(0, 24, 0, 16),
      );
      await _saveHistoryFrame(tester, 'list-portrait');
      await tester.scrollUntilVisible(_key('history-record-local-custom'), 160);
      await _saveHistoryFrame(tester, 'list-portrait-lower');
      await tester.pumpWidget(const SizedBox());
      await _mount(
        tester,
        GameHistoryDetailScreen(record: records.first),
        size: const Size(390, 844),
        insets: const EdgeInsets.fromLTRB(0, 24, 0, 16),
      );
      await _saveHistoryFrame(tester, 'detail-portrait');
      await tester.ensureVisible(_key('history-move-list'));
      await tester.pump();
      await _saveHistoryFrame(tester, 'detail-portrait-moves');
      await tester.pumpWidget(const SizedBox());
      await _mount(
        tester,
        GameHistoryDetailScreen(record: records[1]),
        size: const Size(650, 360),
        scale: 1.5,
        insets: const EdgeInsets.symmetric(vertical: 24),
      );
      await _saveHistoryFrame(tester, 'detail-landscape-large-text');
      await tester.ensureVisible(_key('history-move-list'));
      await tester.ensureVisible(_key('history-last'));
      await tester.pump();
      await _saveHistoryFrame(tester, 'detail-landscape-moves-large-text');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
}

Future<void> _loadPreviewFonts(WidgetTester tester) async {
  await tester.runAsync(() async {
    final packageConfig = io.File('.dart_tool/package_config.json').absolute;
    final data = jsonDecode(await packageConfig.readAsString()) as Map;
    final flutter = (data['packages'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((package) => package['name'] == 'flutter');
    final flutterPackage = packageConfig.uri.resolve('${flutter['rootUri']}/');
    final fontDirectory = flutterPackage.resolve(
      '../../bin/cache/artifacts/material_fonts/',
    );
    final text = FontLoader('Roboto');
    for (final name in [
      'Roboto-Regular.ttf',
      'Roboto-Bold.ttf',
      'Roboto-Black.ttf',
    ]) {
      text.addFont(
        io.File.fromUri(
          fontDirectory.resolve(name),
        ).readAsBytes().then(ByteData.sublistView),
      );
    }
    await text.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
}

Future<void> _saveHistoryFrame(WidgetTester tester, String name) async {
  final context = _previewKey.currentContext!;
  final atlases = tester
      .widgetList<CharacterPiece>(find.byType(CharacterPiece))
      .map(
        (piece) => piece.standard
            ? 'assets/characters/classic-piece-variations-atlas.png'
            : piece.atlasAsset,
      )
      .toSet();
  atlases.addAll(
    tester
        .widgetList<NeonFigureSprite>(find.byType(NeonFigureSprite))
        .map((figure) => figure.theme.castAsset(figure.piece.color)),
  );
  await tester.runAsync(() async {
    for (final asset in atlases) {
      await precacheImage(
        AssetImage(asset),
        context,
        onError: (error, stack) => fail('Cannot render $asset: $error'),
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  });
  await tester.pump();
  final boundary =
      _previewKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = io.Directory('build/history-preview-v1');
    await directory.create(recursive: true);
    await io.File('${directory.path}/$name.png').writeAsBytes(
      bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
    image.dispose();
  });
}
