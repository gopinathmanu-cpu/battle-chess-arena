import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Launches keep the family selected on Home, without another piece chooser.
Future<void> chooseGamePieces(WidgetTester tester, {bool? classic}) async {
  final board = find.byType(ChessBoard);
  for (var frame = 0; board.evaluate().isEmpty && frame < 60; frame++) {
    expect(find.byKey(const ValueKey('piece-type-choice')), findsNothing);
    await tester.pump(const Duration(milliseconds: 20));
  }
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('piece-type-choice')), findsNothing);
  expect(board, findsOneWidget);
  if (classic != null) {
    expect(
      tester.widget<ChessBoard>(board).appearance!.standardPieces,
      classic,
    );
  }
}
