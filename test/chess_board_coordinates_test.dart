// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _key(String value) => find.byKey(ValueKey(value));

Future<void> _open(
  WidgetTester tester, {
  Side orientation = Side.white,
  double extent = 320,
  double textScale = 1,
  bool coordinates = true,
  ValueChanged<Square>? onTap,
  ValueChanged<int>? onSwipe,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(textScale),
          // The grid must not inherit page safe-area padding inside its frame.
          padding: const EdgeInsets.only(top: 24, bottom: 12),
        ),
        child: Scaffold(
          body: Center(
            child: SizedBox.square(
              dimension: extent,
              child: ChessBoard(
                position: Chess.initial,
                selected: null,
                legalTargets: const {},
                accent: Colors.cyan,
                orientation: orientation,
                showCoordinates: coordinates,
                onSquareTap: onTap ?? (_) {},
                onSetSwipe: onSwipe,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Rect _grid(WidgetTester tester) =>
    tester.getRect(_key('board-playable-squares'));

void _expectLabelsOutsideGrid(WidgetTester tester) {
  final frame = tester.getRect(_key('board-coordinate-frame'));
  final grid = _grid(tester);
  expect(frame.width, closeTo(frame.height, .001));
  expect(grid.width, closeTo(grid.height, .001));
  expect(grid.left - frame.left, greaterThan(0));
  expect(grid.left - frame.left, closeTo(frame.right - grid.right, .001));
  expect(grid.top - frame.top, closeTo(frame.bottom - grid.bottom, .001));

  for (final side in ['top', 'bottom']) {
    for (final file in 'ABCDEFGH'.split('')) {
      final bounds = tester.getRect(_key('board-file-$side-$file'));
      expect(frame.contains(bounds.center), isTrue);
      expect(bounds.left, greaterThanOrEqualTo(grid.left - .001));
      expect(bounds.right, lessThanOrEqualTo(grid.right + .001));
      if (side == 'top') {
        expect(bounds.bottom, lessThanOrEqualTo(grid.top + .001));
      } else {
        expect(bounds.top, greaterThanOrEqualTo(grid.bottom - .001));
      }
    }
  }
  for (final side in ['left', 'right']) {
    for (final rank in '12345678'.split('')) {
      final bounds = tester.getRect(_key('board-rank-$side-$rank'));
      expect(frame.contains(bounds.center), isTrue);
      expect(bounds.top, greaterThanOrEqualTo(grid.top - .001));
      expect(bounds.bottom, lessThanOrEqualTo(grid.bottom + .001));
      if (side == 'left') {
        expect(bounds.right, lessThanOrEqualTo(grid.left + .001));
      } else {
        expect(bounds.left, greaterThanOrEqualTo(grid.right - .001));
      }
    }
  }

  for (final square in Square.values) {
    final bounds = tester.getRect(_key('square-${square.name}'));
    expect(bounds.width, closeTo(bounds.height, .001));
    expect(bounds.left, greaterThanOrEqualTo(grid.left - .001));
    expect(bounds.right, lessThanOrEqualTo(grid.right + .001));
    expect(bounds.top, greaterThanOrEqualTo(grid.top - .001));
    expect(bounds.bottom, lessThanOrEqualTo(grid.bottom + .001));
  }
}

void main() {
  testWidgets('coordinates remain opt-in for existing boards', (tester) async {
    await _open(tester, coordinates: false);
    expect(
      tester.widget<ChessBoard>(find.byType(ChessBoard)).showCoordinates,
      isFalse,
    );
    expect(_key('board-coordinate-frame'), findsNothing);
    expect(_key('board-file-top-A'), findsNothing);
    expect(_key('board-rank-left-1'), findsNothing);
    expect(_key('square-a1'), findsOneWidget);
    expect(_key('square-h8'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final orientation in Side.values) {
    testWidgets(
      '${orientation.name} orientation aligns all side references with their squares',
      (tester) async {
        await _open(tester, orientation: orientation);
        final files = orientation == Side.white ? 'ABCDEFGH' : 'HGFEDCBA';
        final ranks = orientation == Side.white ? '87654321' : '12345678';
        final grid = _grid(tester);
        final squareExtent = grid.width / 8;

        for (var index = 0; index < 8; index++) {
          final file = files[index];
          final rank = ranks[index];
          for (final side in ['top', 'bottom']) {
            final finder = _key('board-file-$side-$file');
            expect(tester.widget<Text>(finder).data, file);
            expect(
              tester.getCenter(finder).dx,
              closeTo(grid.left + (index + .5) * squareExtent, .001),
            );
          }
          for (final side in ['left', 'right']) {
            final finder = _key('board-rank-$side-$rank');
            expect(tester.widget<Text>(finder).data, rank);
            expect(
              tester.getCenter(finder).dy,
              closeTo(grid.top + (index + .5) * squareExtent, .001),
            );
          }
        }
        final upperLeft = orientation == Side.white ? Square.a8 : Square.h1;
        final lowerRight = orientation == Side.white ? Square.h1 : Square.a8;
        final first = tester.getTopLeft(_key('square-${upperLeft.name}'));
        final last = tester.getBottomRight(_key('square-${lowerRight.name}'));
        expect(first.dx, closeTo(grid.left, .001));
        expect(first.dy, closeTo(grid.top, .001));
        expect(last.dx, closeTo(grid.right, .001));
        expect(last.dy, closeTo(grid.bottom, .001));
        _expectLabelsOutsideGrid(tester);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('${orientation.name} board preserves every square tap', (
      tester,
    ) async {
      final tapped = <Square>[];
      await _open(tester, orientation: orientation, onTap: tapped.add);
      for (final square in Square.values) {
        await tester.tap(_key('square-${square.name}'));
      }
      expect(tapped, Square.values);
      await tester.tapAt(tester.getCenter(_key('board-file-bottom-E')));
      await tester.tapAt(tester.getCenter(_key('board-rank-left-4')));
      expect(tapped, Square.values);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('horizontal swipes remain usable on both cells and gutters', (
    tester,
  ) async {
    final swipes = <int>[];
    final tapped = <Square>[];
    await _open(tester, onTap: tapped.add, onSwipe: swipes.add);
    await tester.drag(_key('square-e4'), const Offset(-100, 0));
    expect(swipes, [1]);
    expect(tapped, isEmpty);

    await tester.dragFrom(
      tester.getCenter(_key('board-file-top-C')),
      const Offset(100, 0),
    );
    expect(swipes, [1, -1]);
    expect(tapped, isEmpty);

    await tester.drag(_key('square-d4'), const Offset(0, 70));
    await tester.drag(_key('square-d4'), const Offset(-20, 0));
    expect(swipes, [1, -1]);
    await tester.tap(_key('square-e2'));
    expect(tapped, [Square.e2]);
    expect(tester.takeException(), isNull);
  });

  for (final extent in [140.0, 304.0]) {
    for (final textScale in [1.0, 3.0]) {
      testWidgets(
        'coordinate gutters stay separate at ${extent}px and text scale $textScale',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(320, 568));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final tapped = <Square>[];
          await _open(
            tester,
            orientation: Side.black,
            extent: extent,
            textScale: textScale,
            onTap: tapped.add,
          );
          _expectLabelsOutsideGrid(tester);
          final frame = tester.getRect(_key('board-coordinate-frame'));
          final grid = _grid(tester);
          expect(frame.width, extent);
          expect(frame.bottom, lessThanOrEqualTo(568));
          expect(
            grid.left - frame.left,
            closeTo(ChessBoard.coordinateInset(extent), .001),
          );
          expect(
            tester.getSize(_key('square-a1')).width,
            closeTo(
              (extent - 2 * ChessBoard.coordinateInset(extent)) / 8,
              .001,
            ),
          );
          await tester.tap(_key('square-h8'));
          expect(tapped, [Square.h8]);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
