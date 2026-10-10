import 'package:battle_chess_arena/src/app.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/play/animation_lab_screen.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:battle_chess_arena/src/features/play/neon_live_arena.dart';
import 'package:battle_chess_arena/src/services/computer_player.dart';
import 'package:flutter/material.dart';
import 'package:dartchess/dartchess.dart' as chess;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_music_test.dart' show FakeMusicOutput;
import 'support/piece_choice.dart';

void main() {
  testWidgets(
    'Classic computer game asks difficulty and opens without a piece popup',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        BattleChessArenaApp(musicOutput: FakeMusicOutput()),
      );
      expect(
        find.byKey(const ValueKey('home-difficulty-selector')),
        findsNothing,
      );
      final playComputer = find.byKey(const ValueKey('play-computer-button'));
      await tester.ensureVisible(playComputer);
      await tester.pumpAndSettle();
      await tester.tap(playComputer);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('computer-difficulty-dialog')),
        findsOneWidget,
      );
      expect(find.text('Choose computer difficulty'), findsOneWidget);
      expect(find.text('Unlimited (No timer limit)'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('computer-difficulty-hard')));
      await tester.pump();
      expect(find.byType(AnimationLabScreen), findsNothing);
      expect(find.text('Choose computer difficulty'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('start-computer-game')));
      await tester.pumpAndSettle();
      await chooseGamePieces(tester, classic: true);
      await tester.pumpAndSettle();
      final match = tester.widget<AnimationLabScreen>(
        find.byType(AnimationLabScreen),
      );
      expect(match.difficulty, ComputerDifficulty.hard);
      expect(match.timeControl.timed, isFalse);
      expect(match.initialClassicPieces, isTrue);
      expect(match.initialAnimatedArena, isFalse);
      expect(find.byType(NeonLiveArena), findsNothing);
      expect(
        tester
            .widget<ChessBoard>(find.byType(ChessBoard))
            .appearance!
            .standardPieces,
        isTrue,
      );
      expect(
        find.text('Swipe left or right to change classic chess pieces'),
        findsOneWidget,
      );
      final board = tester.getRect(find.byType(ChessBoard));
      for (final key in ['use-computer-lifeline', 'analyse-threats']) {
        final action = find.byKey(ValueKey(key));
        expect(action.hitTestable(), findsOneWidget);
        expect(tester.getRect(action).top, greaterThanOrEqualTo(board.bottom));
      }
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('opponent-profile')),
        150,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('portrait-match-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Computer opponent'), findsOneWidget);
    },
  );

  testWidgets(
    'Animated Home choice supports Rapid clock and Classic icon swipe',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        BattleChessArenaApp(musicOutput: FakeMusicOutput()),
      );
      await tester.pumpAndSettle();
      final animated = find.byKey(const ValueKey('choose-themed'));
      await tester.ensureVisible(animated);
      await tester.pumpAndSettle();
      await tester.tap(animated);
      await tester.pumpAndSettle();
      final play = find.byKey(const ValueKey('play-computer-button'));
      await tester.ensureVisible(play);
      await tester.pumpAndSettle();
      await tester.tap(play);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unlimited (No timer limit)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('15 min · Rapid').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('computer-difficulty-easy')));
      await tester.tap(find.byKey(const ValueKey('start-computer-game')));
      await chooseGamePieces(tester, classic: false);
      final match = tester.widget<AnimationLabScreen>(
        find.byType(AnimationLabScreen),
      );
      expect(match.initialAnimatedArena, isTrue);
      expect(match.timeControl.timed, isTrue);
      expect(find.byType(NeonLiveArena), findsOneWidget);
      await tester.drag(find.byType(ChessBoard), const Offset(-100, 0));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChessBoard>(find.byType(ChessBoard))
            .appearance!
            .standardPieces,
        isTrue,
      );
      expect(find.byType(NeonLiveArena), findsOneWidget);
      expect(find.byKey(const ValueKey('piece-type-choice')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'local match keeps quick actions below board and Player 2 details',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(home: AnimationLabScreen(pack: piecePacks.first)),
      );
      await tester.pumpAndSettle();

      final board = tester.getRect(find.byType(ChessBoard));
      final action = find.byKey(const ValueKey('analyse-threats'));
      expect(action.hitTestable(), findsOneWidget);
      expect(tester.getRect(action).top, greaterThanOrEqualTo(board.bottom));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('opponent-profile')),
        150,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('portrait-match-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Player 2'), findsOneWidget);
      expect(find.textContaining('Local player'), findsOneWidget);
    },
  );

  testWidgets('board swipe hint disappears after a valid first selection', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(home: AnimationLabScreen(pack: piecePacks.first)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('board-swipe-hint')), findsOneWidget);
    tester
        .widget<ChessBoard>(find.byType(ChessBoard))
        .onSquareTap(chess.Square.e4);
    await tester.pump();
    expect(find.byKey(const ValueKey('board-swipe-hint')), findsOneWidget);
    tester
        .widget<ChessBoard>(find.byType(ChessBoard))
        .onSquareTap(chess.Square.e2);
    await tester.pump();
    expect(find.byKey(const ValueKey('board-swipe-hint')), findsNothing);
    tester
        .widget<ChessBoard>(find.byType(ChessBoard))
        .onSquareTap(chess.Square.a3);
    await tester.pump();
    expect(find.byKey(const ValueKey('board-swipe-hint')), findsNothing);
  });

  testWidgets('compact home keeps primary actions visible without scrolling', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      BattleChessArenaApp(musicOutput: FakeMusicOutput()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Computer difficulty'), findsNothing);
    expect(find.text('Play Computer').hitTestable(), findsOneWidget);
    expect(find.text('Play Online').hitTestable(), findsOneWidget);
    expect(find.text('Tournaments').hitTestable(), findsOneWidget);
    expect(find.text('Magnetic 3D'), findsOneWidget);
    expect(find.byKey(const ValueKey('chess-set-carousel')), findsOneWidget);
  });

  testWidgets('home offers four Classic material sets', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      BattleChessArenaApp(musicOutput: FakeMusicOutput()),
    );
    await tester.pumpAndSettle();

    final classic = find.byKey(const ValueKey('choose-classic'));
    await tester.ensureVisible(classic);
    await tester.pumpAndSettle();
    await tester.tap(classic);
    await tester.pumpAndSettle();

    for (final label in [
      'Magnetic 3D',
      'Wooden 3D',
      'Flat Club',
      'Flat Teaching',
    ]) {
      expect(find.text(label), findsOneWidget);
      final next = find.byKey(const ValueKey('next-chess-set'));
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
    }
    expect(find.text('Magnetic 3D'), findsOneWidget);
  });

  testWidgets('home opens the online lobby', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      BattleChessArenaApp(musicOutput: FakeMusicOutput()),
    );
    await tester.scrollUntilVisible(
      find.text('Play Online'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play Online'));
    await tester.pumpAndSettle();
    expect(find.text('Play Online'), findsOneWidget);
    expect(find.text('Create your online Avatar ID'), findsOneWidget);
    expect(find.text('Save & Enter Arena'), findsOneWidget);
    expect(find.textContaining('wss://'), findsNothing);
  });

  testWidgets('home online play uses the configured Firebase network', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      BattleChessArenaApp(musicOutput: FakeMusicOutput()),
    );
    await tester.scrollUntilVisible(
      find.text('Play Online'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Play Online'));
    await tester.pumpAndSettle();

    expect(find.text('Play Online'), findsOneWidget);
    expect(find.text('Online play'), findsOneWidget);
    expect(find.text('Ready to connect.'), findsOneWidget);
    final enter = tester.widget<FilledButton>(
      find.byKey(const ValueKey('enter-arena-button')),
    );
    expect(enter.onPressed, isNotNull);
  });

  testWidgets('home opens the three bot tournaments', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      BattleChessArenaApp(musicOutput: FakeMusicOutput()),
    );
    await tester.scrollUntilVisible(
      find.text('Tournaments'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Tournaments'));
    await tester.pumpAndSettle();
    expect(find.text('Rising Knights Cup'), findsOneWidget);
    expect(find.text('0 points'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Tactician Cup'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Tactician Cup'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Mastery Cup'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Mastery Cup'), findsOneWidget);
    expect(find.text('Coming Soon!!!'), findsNothing);
  });
}
