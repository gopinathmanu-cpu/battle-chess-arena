import 'dart:convert';

import 'package:battle_chess_arena/src/domain/player_progress.dart';
import 'package:battle_chess_arena/src/services/player_progress_controller.dart';
import 'package:battle_chess_arena/src/features/progression/progress_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('completed games earn capped move-based experience', () {
    expect(experienceForCompletedGame(0), 10);
    expect(experienceForCompletedGame(34), 44);
    expect(experienceForCompletedGame(500), 110);
  });

  test('badge upgrades have escalating credit rewards', () {
    expect(arenaBadges.map((badge) => badge.creditReward), [
      0,
      25,
      50,
      75,
      100,
      150,
      250,
    ]);
  });

  testWidgets('badge summary previews the credit reward for every level', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showPlayerProgress(
              context,
              const PlayerProgress(experience: 260),
            ),
            child: const Text('Open badges'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open badges'));
    await tester.pumpAndSettle();

    for (final badge in arenaBadges) {
      expect(find.text(badge.name), findsOneWidget);
      expect(find.text('+${badge.creditReward}'), findsOneWidget);
    }
    expect(
      find.text(
        'The displayed credits are awarded once when each badge is unlocked.',
      ),
      findsOneWidget,
    );
  });

  test('wins add a trophy and losses still earn experience', () async {
    final controller = PlayerProgressController();

    final loss = await controller.recordCompletion(
      completionId: 'loss-1',
      moveCount: 24,
      won: false,
    );
    expect(loss.experience, 34);
    expect(loss.trophies, 0);
    expect(controller.progress.completedGames, 1);

    final win = await controller.recordCompletion(
      completionId: 'win-1',
      moveCount: 40,
      won: true,
    );
    expect(win.experience, 50);
    expect(win.trophies, 1);
    expect(controller.progress.experience, 84);
    expect(controller.progress.trophies, 1);
    expect(controller.progress.overallPoints, 184);
  });

  test('same completion can never award progress twice', () async {
    final controller = PlayerProgressController();
    await controller.recordCompletion(
      completionId: 'online:abc:1',
      moveCount: 30,
      won: true,
    );
    final duplicate = await controller.recordCompletion(
      completionId: 'online:abc:1',
      moveCount: 30,
      won: true,
    );

    expect(duplicate.alreadyAwarded, isTrue);
    expect(controller.progress.completedGames, 1);
    expect(controller.progress.trophies, 1);
  });

  test('progress restores with its earned badge', () async {
    SharedPreferences.setMockInitialValues({
      PlayerProgressController.storageKey: jsonEncode(
        const PlayerProgress(
          experience: 160,
          trophies: 1,
          completedGames: 4,
          wins: 1,
          awardedCompletionIds: ['one'],
        ).toJson(),
      ),
    });
    final controller = PlayerProgressController();
    await controller.restore();

    expect(controller.progress.overallPoints, 260);
    expect(controller.progress.badge.name, 'Bronze Knight');
    expect(controller.progress.awardedCompletionIds, ['one']);
  });
}
