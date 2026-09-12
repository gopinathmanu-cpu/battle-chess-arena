import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/play/animation_lab_screen.dart';
import 'package:battle_chess_arena/src/services/computer_player.dart';
import 'package:battle_chess_arena/src/services/last_game_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('checkmate move opens the animated result popup once', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(home: AnimationLabScreen(pack: piecePacks.first)),
    );

    Future<void> move(String from, String to) async {
      await tester.tap(find.byKey(ValueKey('square-$from')));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey('square-$to')));
      await tester.pump(const Duration(milliseconds: 30));
    }

    await move('f2', 'f3');
    await move('e7', 'e5');
    await move('g2', 'g4');
    await move('d8', 'h4');
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byKey(const ValueKey('checkmate-heading')), findsOneWidget);
    expect(find.text('Black Wins!'), findsOneWidget);
    expect(find.byKey(const ValueKey('result-sentiment')), findsOneWidget);
    expect(find.byKey(const ValueKey('result-analysis')), findsOneWidget);
    expect(find.text('Review Board'), findsOneWidget);
    expect(find.text('New Game'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Review Board'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('checkmate-heading')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('local clock expiry announces the opposing winner', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final pack = piecePacks.first;
    final saved = SavedGame(
      mode: PlayerMode.local,
      homePack: pack.id,
      difficulty: ComputerDifficulty.medium,
      moves: const [],
      whiteMilliseconds: 500,
      blackMilliseconds: 60000,
      fastBattles: false,
      whitePack: pack.id,
      blackPack: pack.id,
      boardPack: pack.id,
      updatedAtEpochMs: 1,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AnimationLabScreen(pack: pack, savedGame: saved),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('WINNER BY TIMEOUT'), findsOneWidget);
    expect(find.text('Black Wins!'), findsOneWidget);
    expect(find.byKey(const ValueKey('result-atmosphere')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
