import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/play/animation_lab_screen.dart';
import 'package:battle_chess_arena/src/features/play/capture_battle_overlay.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:battle_chess_arena/src/services/theme_music.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('capture attacker travels from source to target square', (
    tester,
  ) async {
    final game = GameSession()
      ..playUci('e2e4')
      ..playUci('d7d5');
    final capture = game.playUci('e4d5')!;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox.square(
              dimension: 320,
              child: Stack(
                children: [
                  CaptureBattleOverlay(
                    battle: capture,
                    accent: Colors.redAccent,
                    reduced: false,
                    useCharacterAsset: false,
                    onSkip: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final flight = find.byKey(const ValueKey('capture-flight-e4-d5'));
    expect(find.byKey(const ValueKey('capture-target-d5')), findsOneWidget);
    expect(find.text('White Pawn (e4) takes Black Pawn (d5)'), findsOneWidget);
    expect(find.text('VICTOR'), findsOneWidget);
    expect(find.text('DEFEATED'), findsOneWidget);
    final start = tester.getTopLeft(flight);
    await tester.pump(const Duration(milliseconds: 480));
    final target = tester.getTopLeft(flight);
    expect(target.dx, closeTo(start.dx - 40, 1));
    expect(target.dy, closeTo(start.dy - 40, 1));
  });

  test('capture description uses standard piece notation', () {
    final game = GameSession(
      position: Chess.fromSetup(
        Setup.parseFen('7k/8/8/2p5/4N3/8/8/7K w - - 0 1'),
      ),
    );
    final capture = game.playUci('e4c5')!;
    expect(
      captureDescription(capture),
      'White Knight (Ne4) takes Black Pawn (c5)',
    );
    expect(cinematicImpactSound(capture), CinematicSound.lightImpact);
  });

  testWidgets(
    'local landscape keeps the complete board and right panel visible',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(650, 360));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: AnimationLabScreen(
            pack: piecePacks.first,
            mode: PlayerMode.local,
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('landscape-match-layout')),
        findsOneWidget,
      );
      final board = tester.getRect(find.byType(ChessBoard));
      expect(board.width, closeTo(board.height, .1));
      expect(board.left, greaterThanOrEqualTo(0));
      expect(board.top, greaterThanOrEqualTo(0));
      expect(board.right, lessThanOrEqualTo(650));
      expect(board.bottom, lessThanOrEqualTo(360));
      expect(find.text('Fast battle mode'), findsOneWidget);
      await tester.tap(find.byTooltip('Hide top bar'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Show top bar'), findsOneWidget);
      final restore = tester.getRect(find.byTooltip('Show top bar'));
      final blackClockLabel = tester.getRect(find.text('BLACK'));
      expect(restore.bottom, lessThanOrEqualTo(blackClockLabel.top));
      final expandedBoard = tester.getRect(find.byType(ChessBoard));
      expect(expandedBoard.height, greaterThan(board.height));
      expect(expandedBoard.height, closeTo(344, .1));
      expect(expandedBoard.top, closeTo(8, .1));
      expect(expandedBoard.bottom, lessThanOrEqualTo(360));
      await tester.tap(find.byTooltip('Show top bar'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Hide top bar'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('hidden top bar expands portrait board to screen width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: AnimationLabScreen(pack: piecePacks.first)),
    );
    await tester.pump();
    final board = tester.getRect(find.byType(ChessBoard));
    await tester.tap(find.byTooltip('Hide top bar'));
    await tester.pumpAndSettle();
    final expandedBoard = tester.getRect(find.byType(ChessBoard));
    expect(expandedBoard.width, greaterThan(board.width));
    expect(expandedBoard.width, closeTo(374, .1));
    expect(expandedBoard.left, closeTo(8, .1));
  });
}
