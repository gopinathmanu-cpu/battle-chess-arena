import 'package:battle_chess_arena/src/app.dart';
import 'package:battle_chess_arena/src/domain/online_player_profile.dart';
import 'package:battle_chess_arena/src/features/progression/progress_widgets.dart';
import 'package:battle_chess_arena/src/services/online_game_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme_music_test.dart' show FakeMusicOutput;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final (width, scale, abbreviation) in [
    (500.0, 1.0, false),
    (160.0, 1.0, true),
    (500.0, 2.0, true),
  ]) {
    testWidgets('experience label adapts to $width at text scale $scale', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: const HomeExperienceSummary(
                  experience: 12345,
                  trophies: 12,
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        find.text(
          '${abbreviation ? 'Exp' : 'Experience'} 12345 XP  ·  Trophies 12',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Experience 12345 XP  ·  Trophies 12'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'Home keeps avatar, compact credits and Exp at $width / $scale',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 844));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await OnlineGameHistory.saveProfile(
            const OnlinePlayerProfile(
              name: 'Nova Knight',
              avatarId: 'avatar-07',
            ),
          );
          final semantics = tester.ensureSemantics();
          await tester.pumpWidget(
            BattleChessArenaApp(
              musicOutput: FakeMusicOutput(),
              incomingLinks: const Stream.empty(),
            ),
          );
          await tester.pumpAndSettle();
          final details = find.byKey(const ValueKey('home-avatar-details'));
          expect(
            find.descendant(
              of: details,
              matching: find.text('Exp 0 XP  ·  Trophies 0'),
            ),
            findsOneWidget,
          );
          expect(
            find.bySemanticsLabel('Experience 0 XP  ·  Trophies 0'),
            findsOneWidget,
          );
          final balance = tester.getRect(
            find.byKey(const ValueKey('arena-credit-header-balance')),
          );
          expect(balance.width, lessThanOrEqualTo(100));
          expect(balance.right, lessThanOrEqualTo(width));
          expect(balance.left, greaterThanOrEqualTo(0));
          expect(
            tester
                .getRect(find.byKey(const ValueKey('home-avatar-image')))
                .overlaps(balance),
            isFalse,
          );
          expect(find.text('Nova Knight'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          semantics.dispose();
        },
      );
    }
  }
}
