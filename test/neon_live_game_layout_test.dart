// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:battle_chess_arena/src/features/play/neon_live_game_layout.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _arena = ValueKey('layout-test-arena');
const _board = ValueKey('layout-test-board');
const _header = ValueKey('layout-test-header');
const _scroll = ValueKey('layout-test-scroll');
const _suggest = ValueKey('layout-test-suggest');
const _threats = ValueKey('layout-test-threats');

Future<void> _mount(
  WidgetTester tester,
  ScrollController controller, {
  required Size size,
  double scale = 1,
  VoidCallback? tapBoard,
  VoidCallback? tapControl,
  VoidCallback? tapSuggest,
  VoidCallback? tapThreats,
}) async {
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(size: size, textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: NeonLiveGameLayout(
          arena: const ColoredBox(
            key: _arena,
            color: Colors.deepPurple,
            child: Center(child: Text('Live character action')),
          ),
          board: GestureDetector(
            key: _board,
            onTap: tapBoard,
            child: const ColoredBox(
              color: Colors.teal,
              child: Center(child: Text('Interactive chessboard')),
            ),
          ),
          header: const NeonLiveStatusBar(
            key: _header,
            whiteTime: Duration(minutes: 9),
            blackTime: Duration(minutes: 10),
            status: 'Black to move',
            turn: Side.black,
            timed: true,
          ),
          quickActions: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: _suggest,
                  onPressed: tapSuggest ?? () {},
                  child: const Text('Suggest move', maxLines: 2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  key: _threats,
                  onPressed: tapThreats ?? () {},
                  child: const Text('Analyse threats', maxLines: 2),
                ),
              ),
            ],
          ),
          boardFooter: const SizedBox(height: 80, child: Text('Move record')),
          details: [
            const SizedBox(
              height: 150,
              child: Text('Captured pieces and assists'),
            ),
            TextButton(
              key: const ValueKey('layout-test-control'),
              onPressed: tapControl,
              child: const Text('Match settings'),
            ),
            const SizedBox(height: 180, child: Text('Further match controls')),
          ],
          scrollController: controller,
          portraitScrollKey: _scroll,
          landscapeScrollKey: _scroll,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  for (final size in [const Size(650, 360), const Size(760, 330)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'landscape $size at $scale shows action left and board right',
        (tester) async {
          final controller = ScrollController();
          var boardTaps = 0, controlTaps = 0, suggestions = 0, threats = 0;
          try {
            await _mount(
              tester,
              controller,
              size: size,
              scale: scale,
              tapBoard: () => boardTaps++,
              tapControl: () => controlTaps++,
              tapSuggest: () => suggestions++,
              tapThreats: () => threats++,
            );
            final arena = tester.getRect(find.byKey(_arena));
            final board = tester.getRect(find.byKey(_board));
            final row = tester.getRect(
              find.byKey(
                const ValueKey('neon-live-landscape-action-board-row'),
              ),
            );
            expect(arena.right, lessThan(board.left));
            expect(arena.top, board.top);
            expect(board.width, board.height);
            final actions = tester.getRect(
              find.byKey(const ValueKey('neon-live-quick-actions')),
            );
            expect(arena.height, lessThan(board.height));
            expect(actions.top, greaterThan(arena.bottom));
            expect(actions.right, lessThan(board.left));
            expect(actions.bottom, lessThanOrEqualTo(row.bottom));
            expect(row.bottom, lessThanOrEqualTo(size.height));
            expect(row.left, greaterThanOrEqualTo(0));
            expect(row.right, lessThanOrEqualTo(size.width));
            expect(
              tester.getRect(find.byKey(_header)).top,
              greaterThanOrEqualTo(row.bottom),
            );
            expect(find.byType(ListView), findsOneWidget);
            await tester.tap(find.byKey(_suggest));
            await tester.tap(find.byKey(_threats));
            await tester.pump();
            expect(suggestions, 1);
            expect(threats, 1);
            await tester.tap(find.byKey(_board));
            await tester.pump();
            expect(boardTaps, 1);
            await tester.scrollUntilVisible(
              find.byKey(const ValueKey('layout-test-control')),
              150,
              scrollable: find.descendant(
                of: find.byKey(_scroll),
                matching: find.byType(Scrollable),
              ),
            );
            await Scrollable.ensureVisible(
              tester.element(find.byKey(const ValueKey('layout-test-control'))),
              alignment: .5,
            );
            await tester.pump();
            await tester.tap(find.byKey(const ValueKey('layout-test-control')));
            await tester.pump();
            expect(controlTaps, 1);
            expect(controller.offset, greaterThan(0));
            expect(tester.takeException(), isNull);
          } finally {
            await tester.pumpWidget(const SizedBox());
            controller.dispose();
            await tester.binding.setSurfaceSize(null);
          }
        },
      );
    }
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'portrait keeps board and two quick actions visible at $scale',
      (tester) async {
        final controller = ScrollController();
        var suggestions = 0, threats = 0;
        try {
          await _mount(
            tester,
            controller,
            size: const Size(320, 568),
            scale: scale,
            tapSuggest: () => suggestions++,
            tapThreats: () => threats++,
          );
          final arena = tester.getRect(find.byKey(_arena));
          final board = tester.getRect(find.byKey(_board));
          final actions = tester.getRect(
            find.byKey(const ValueKey('neon-live-quick-actions')),
          );
          expect(arena.bottom, lessThan(board.top));
          expect(board.width, closeTo(board.height, .001));
          expect(board.bottom, lessThan(actions.top));
          expect(actions.bottom, lessThanOrEqualTo(568));
          expect(controller.offset, 0);
          expect(
            find.byKey(const ValueKey('neon-live-landscape-action-board-row')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('neon-live-controls-button')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('neon-live-board-button')),
            findsNothing,
          );
          await tester.tap(find.byKey(_suggest));
          await tester.tap(find.byKey(_threats));
          await tester.pump();
          expect(suggestions, 1);
          expect(threats, 1);
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('layout-test-control')),
            150,
            scrollable: find.descendant(
              of: find.byKey(_scroll),
              matching: find.byType(Scrollable),
            ),
          );
          expect(controller.offset, greaterThan(0));
          expect(tester.getRect(find.byKey(_arena)), arena);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
          controller.dispose();
          await tester.binding.setSurfaceSize(null);
        }
      },
    );
  }

  testWidgets('landscape swap keeps actions with arena and survives rotation', (
    tester,
  ) async {
    final controller = ScrollController();
    var boardTaps = 0, suggestions = 0;
    try {
      Future<void> mount(Size size) => _mount(
        tester,
        controller,
        size: size,
        tapBoard: () => boardTaps++,
        tapSuggest: () => suggestions++,
      );
      await mount(const Size(650, 360));
      await tester.tap(find.byKey(const ValueKey('neon-live-swap-panels')));
      await tester.pump();
      expect(
        tester.getRect(find.byKey(_board)).right,
        lessThan(tester.getRect(find.byKey(_arena)).left),
      );
      expect(
        tester.getRect(find.byKey(_suggest)).left,
        greaterThan(tester.getRect(find.byKey(_board)).right),
      );
      await tester.tap(find.byKey(_board));
      await tester.tap(find.byKey(_suggest));
      await tester.pump();
      expect(boardTaps, 1);
      expect(suggestions, 1);
      await mount(const Size(320, 568));
      expect(find.byKey(const ValueKey('neon-live-swap-panels')), findsNothing);
      await mount(const Size(650, 360));
      expect(
        tester.getRect(find.byKey(_board)).right,
        lessThan(tester.getRect(find.byKey(_arena)).left),
      );
      await tester.tap(find.byKey(const ValueKey('neon-live-swap-panels')));
      await tester.pump();
      expect(
        tester.getRect(find.byKey(_arena)).right,
        lessThan(tester.getRect(find.byKey(_board)).left),
      );
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      await tester.binding.setSurfaceSize(null);
    }
  });
}
