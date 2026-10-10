import 'package:battle_chess_arena/src/features/play/game_header_ribbon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in [
    const Size(320, 720),
    const Size(420, 900),
    const Size(960, 420),
  ]) {
    testWidgets('header spacing and fixed credits at ${size.width}px', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Local Match'),
              titleSpacing: 12,
              actionsPadding: const EdgeInsets.only(right: 12),
              actions: [
                GameHeaderRibbon(
                  hasTitle: true,
                  scrollKey: const ValueKey('ribbon-scroll'),
                  icons: [
                    for (var i = 0; i < 7; i++)
                      IconButton(
                        key: ValueKey('action-$i'),
                        onPressed: () {},
                        icon: const Icon(Icons.settings),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final first = tester.getRect(find.byKey(const ValueKey('action-0')));
      final second = tester.getRect(find.byKey(const ValueKey('action-1')));
      expect(first.width, 48);
      expect(second.left - first.right, 12);
      final counter = find.byKey(const ValueKey('arena-credit-header'));
      final originalCounter = tester.getRect(counter);
      final scroll = find.byKey(const ValueKey('ribbon-scroll'));
      await tester.drag(scroll, const Offset(-1200, 0));
      await tester.pumpAndSettle();
      final last = tester.getRect(find.byKey(const ValueKey('action-6')));
      final afterScroll = tester.getRect(counter);
      expect(afterScroll, originalCounter);
      expect(afterScroll.left - last.right, closeTo(12, 0.01));
      expect(afterScroll.right, lessThanOrEqualTo(size.width - 12));
      expect(
        find.byKey(const ValueKey('action-6')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
