import 'package:battle_chess_arena/src/domain/game_time_control.dart';
import 'package:battle_chess_arena/src/domain/online_time_control.dart';
import 'package:battle_chess_arena/src/domain/bot_tournament.dart';
import 'package:battle_chess_arena/src/domain/online_game_state.dart';
import 'package:battle_chess_arena/src/domain/online_game_session.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/play/animation_lab_screen.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:battle_chess_arena/src/services/last_game_storage.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'last_game_storage_test.dart' show savedGame;
import 'support/online_fixtures.dart';

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

  test('presets distinguish daily, rapid, classical and untimed practice', () {
    expect(GameTimeControl.rapid.baseMs, 900000);
    expect(GameTimeControl.rapid.incrementMs, 10000);
    expect(GameTimeControl.practice.timed, false);
    expect(friendTimeControls.first, dailyTimeControl);
    expect(dailyTimeControl.baseMs, 86400000);
    expect(onlineTimeControls.first.incrementMs, 10000);
    expect(onlineTimeControls.every((control) => !control.isDaily), true);
    expect(builtInTournaments.every((cup) => cup.minutesPerSide == 15), true);
  });

  test('legacy saves keep 10+0 and new clocks round trip', () {
    final json = savedGame().toJson()..remove('timeControl');
    final legacy = SavedGame.fromJson(json);
    expect(legacy.timeControl.baseMs, 600000);
    expect(legacy.timeControl.incrementMs, 0);
    for (final clock in [GameTimeControl.rapid, GameTimeControl.practice]) {
      final restored = SavedGame.fromJson({
        ...json,
        'timeControl': clock.toJson(),
      });
      expect(restored.timeControl.toJson(), clock.toJson());
    }
    final practice = SavedGame.fromJson({
      ...json,
      'timeControl': GameTimeControl.practice.toJson(),
      'whiteMilliseconds': 0,
      'blackMilliseconds': 0,
    });
    expect(practice.canResume, true);
  });

  test('online display counts down Daily but never an untimed clock', () {
    var now = 0;
    final session = OnlineGameSession(nowMs: () => now);
    session.apply(
      OnlineGameState.fromJson({
        ...stateJson(whiteMs: 86400000, blackMs: 86400000),
        'clockMode': 'daily',
        'turnDeadlineEpochMs': 86400000,
      }),
    );
    now = 3600000;
    expect(session.clockMs('w'), 82800000);
    expect(session.clockMs('b'), 86400000);
    session.clear();
    session.apply(OnlineGameState.fromJson(stateJson(timed: false)));
    now += 3600000;
    expect(session.clockMs('w'), 60000);
  });

  testWidgets(
    'Rapid adds one increment to mover, undo revokes it, and save retains rules',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: AnimationLabScreen(pack: piecePacks.first)),
      );
      ChessBoard board() => tester.widget<ChessBoard>(find.byType(ChessBoard));
      MatchHeader header() =>
          tester.widget<MatchHeader>(find.byType(MatchHeader));
      expect(header().whiteTime.inMilliseconds, 900000);
      board().onSquareTap(Square.e2);
      await tester.pump();
      board().onSquareTap(Square.e4);
      await tester.pump();
      expect(
        header().whiteTime.inMilliseconds,
        inInclusiveRange(909000, 910000),
      );
      expect(header().blackTime.inMilliseconds, 900000);
      final saved = (await LastGameStorage.load())!;
      expect(saved.timeControl.incrementMs, 10000);
      await tester.tap(find.byTooltip('Undo'));
      await tester.pump();
      expect(header().whiteTime.inMilliseconds, lessThanOrEqualTo(900000));
      expect(board().position.fen, Chess.initial.fen);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Untimed Practice does not decrement or increment and can resume',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AnimationLabScreen(
            pack: piecePacks.first,
            timeControl: GameTimeControl.practice,
          ),
        ),
      );
      ChessBoard board() => tester.widget<ChessBoard>(find.byType(ChessBoard));
      board().onSquareTap(Square.e2);
      await tester.pump();
      board().onSquareTap(Square.e4);
      await tester.pump(const Duration(seconds: 3));
      final header = tester.widget<MatchHeader>(find.byType(MatchHeader));
      expect(header.timed, false);
      expect(header.whiteTime.inMilliseconds, 900000);
      expect(header.blackTime.inMilliseconds, 900000);
      final saved = (await LastGameStorage.load())!;
      expect(saved.timeControl.timed, false);
      expect(saved.canResume, true);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
