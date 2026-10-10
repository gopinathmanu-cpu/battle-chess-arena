// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:battle_chess_arena/src/features/play/match_opponent_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> mount(
    WidgetTester tester, {
    double? height,
    double textScale = 1,
  }) => tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 280,
            height: height,
            child: MatchOpponentPanel(
              name: 'Alexandra Chess Champion',
              details: 'Advanced · Level 18 · Computer · Timed game',
              avatarBuilder: (size) => Container(
                key: const ValueKey('original-opponent-avatar'),
                color: Colors.indigo,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('portrait opponent card keeps its content height and avatar', (
    tester,
  ) async {
    // An unbounded portrait slot models the compact match layout.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              MatchOpponentPanel(
                name: 'Alex',
                details: 'Intermediate · Online player · No timer',
                avatarBuilder: (size) => SizedBox.square(
                  key: const ValueKey('original-opponent-avatar'),
                  dimension: size,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(MatchOpponentPanel)).height,
      lessThan(120),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('match-opponent-avatar'))),
      const Size.square(64),
    );
    expect(
      find.byKey(const ValueKey('original-opponent-avatar')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('roomy landscape promotes the existing opponent avatar', (
    tester,
  ) async {
    await mount(tester, height: 290);
    final avatar = tester.getRect(
      find.byKey(const ValueKey('match-opponent-avatar')),
    );
    final name = tester.getRect(
      find.byKey(const ValueKey('match-opponent-name')),
    );
    expect(avatar.size, const Size.square(96));
    expect(avatar.bottom, lessThan(name.top));
    expect(
      find.text('Advanced · Level 18 · Computer · Timed game'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('short opponent lane keeps enlarged details scrollable', (
    tester,
  ) async {
    await mount(tester, height: 90, textScale: 2);
    expect(
      find.byKey(const ValueKey('original-opponent-avatar')),
      findsOneWidget,
    );
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(MatchOpponentPanel),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -80));
    await tester.pump();
    expect(scrollable.position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);
  });
}
