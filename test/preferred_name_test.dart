import 'package:battle_chess_arena/src/features/profile/preferred_name.dart';
import 'package:battle_chess_arena/src/services/player_identity_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('nickname and no-name decision both persist', () async {
    final named = PlayerIdentityController();
    await named.restore();
    expect(named.shouldPrompt, isTrue);
    await named.saveNickname('  Maya  ');

    final restored = PlayerIdentityController();
    await restored.restore();
    expect(restored.nickname, 'Maya');
    expect(restored.shouldPrompt, isFalse);

    await restored.continueWithoutNickname();
    final anonymous = PlayerIdentityController();
    await anonymous.restore();
    expect(anonymous.nickname, isNull);
    expect(anonymous.shouldPrompt, isFalse);
  });

  testWidgets('optional sheet saves a respectful preferred name', (
    tester,
  ) async {
    final controller = PlayerIdentityController();
    await controller.restore();
    await tester.pumpWidget(
      PlayerIdentityScope(
        controller: controller,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showPreferredNameSheet(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('preferred-name-field')),
      'Arjun',
    );
    await tester.tap(find.byKey(const ValueKey('save-preferred-name')));
    await tester.pumpAndSettle();

    expect(controller.nickname, 'Arjun');
    expect(controller.shouldPrompt, isFalse);
  });

  testWidgets('continue without name is a permanent respected choice', (
    tester,
  ) async {
    final controller = PlayerIdentityController();
    await controller.restore();
    await tester.pumpWidget(
      PlayerIdentityScope(
        controller: controller,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showPreferredNameSheet(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('continue-without-name')));
    await tester.pumpAndSettle();

    expect(controller.nickname, isNull);
    expect(controller.shouldPrompt, isFalse);
  });
}
