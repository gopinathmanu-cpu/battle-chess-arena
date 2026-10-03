import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> openGameSettings(WidgetTester tester, {Finder? target}) async {
  await tester.tap(find.byTooltip('Game settings'));
  await tester.pumpAndSettle();
  if (target != null) {
    await tester.scrollUntilVisible(
      target,
      100,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('game-settings-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }
}
