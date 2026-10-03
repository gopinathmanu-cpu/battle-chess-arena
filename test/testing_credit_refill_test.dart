import 'package:battle_chess_arena/src/app.dart';
import 'package:battle_chess_arena/src/services/arena_credit_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme_music_test.dart' show FakeMusicOutput;

void main() {
  testWidgets(
    'mobile test Top-up accepts the active monthly code and adds 100 credits',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        BattleChessArenaApp(
          musicOutput: FakeMusicOutput(),
          incomingLinks: const Stream.empty(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('home-settings-button')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('testing-credit-top-up')),
        160,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('game-settings-list')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('Top-up Credits'), findsOneWidget);
      expect(
        find.textContaining(ArenaCreditController.september2026TopUpCode),
        findsNothing,
      );
      await tester.scrollUntilVisible(
        find.text('Top up'),
        100,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('game-settings-list')),
          matching: find.byType(Scrollable),
        ),
      );
      tester
          .widget<FilledButton>(
            find.ancestor(
              of: find.text('Top up'),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed!();
      await tester.pumpAndSettle();
      expect(
        find.textContaining(ArenaCreditController.september2026TopUpCode),
        findsOneWidget,
      );
      expect(
        find.textContaining(ArenaCreditController.october2026TopUpCode),
        findsOneWidget,
      );
      expect(find.textContaining('September 2026 only'), findsOneWidget);
      expect(find.textContaining('October 2026 only'), findsOneWidget);
      expect(find.textContaining('1,000-credit balance'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('credit-top-up-code-field')),
        'wrong',
      );
      await tester.tap(find.byKey(const ValueKey('redeem-credit-top-up-code')));
      await tester.pump();
      expect(find.text('Invalid or inactive Top-up code'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('credit-top-up-code-field')),
        ArenaCreditController.september2026TopUpCode,
      );
      await tester.tap(find.byKey(const ValueKey('redeem-credit-top-up-code')));
      await tester.pumpAndSettle();
      expect(find.text('400'), findsWidgets);
    },
    skip: !ArenaCreditController.testingCreditsEnabled,
  );
}
