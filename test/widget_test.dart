import 'package:battle_chess_arena/src/app.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/play/animation_lab_screen.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:battle_chess_arena/src/services/computer_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_music_test.dart' show FakeMusicOutput;

void main() {
  testWidgets('new computer game asks for difficulty before opening', (
    tester,
  ) async {
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
    await tester.tap(find.byKey(const ValueKey('computer-difficulty-hard')));
    await tester.pump();
    expect(find.byType(AnimationLabScreen), findsNothing);
    expect(find.text('Choose computer difficulty'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('start-computer-game')));
    await tester.pumpAndSettle();
    final match = tester.widget<AnimationLabScreen>(
      find.byType(AnimationLabScreen),
    );
    expect(match.difficulty, ComputerDifficulty.hard);
    expect(find.byKey(const ValueKey('opponent-profile')), findsOneWidget);
    expect(find.text('Computer opponent'), findsOneWidget);
    expect(
      tester.getBottomLeft(find.byKey(const ValueKey('opponent-profile'))).dy,
      lessThan(tester.getTopLeft(find.byType(ChessBoard)).dy),
    );
  });

  testWidgets('local match shows Player 2 details above the board', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(home: AnimationLabScreen(pack: piecePacks.first)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('opponent-profile')), findsOneWidget);
    expect(find.text('Player 2'), findsOneWidget);
    expect(find.textContaining('Local player'), findsOneWidget);
    expect(
      tester.getBottomLeft(find.byKey(const ValueKey('opponent-profile'))).dy,
      lessThan(tester.getTopLeft(find.byType(ChessBoard)).dy),
    );
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
