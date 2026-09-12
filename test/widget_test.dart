import 'package:battle_chess_arena/src/app.dart';
import 'package:battle_chess_arena/src/features/play/animation_lab_screen.dart';
import 'package:battle_chess_arena/src/services/computer_player.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_music_test.dart' show FakeMusicOutput;

void main() {
  testWidgets('selected computer difficulty is passed into the match', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      BattleChessArenaApp(musicOutput: FakeMusicOutput()),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('home-difficulty-selector')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('home-difficulty-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hard').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Play Computer'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Play Computer'));
    await tester.pumpAndSettle();
    final match = tester.widget<AnimationLabScreen>(
      find.byType(AnimationLabScreen),
    );
    expect(match.difficulty, ComputerDifficulty.hard);
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
    expect(find.text('Enter Arena'), findsOneWidget);
    expect(find.textContaining('wss://'), findsNothing);
  });

  testWidgets('tournaments shows the coming-soon message', (tester) async {
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
    await tester.pump();
    expect(find.text('Coming Soon!!!'), findsOneWidget);
  });
}
