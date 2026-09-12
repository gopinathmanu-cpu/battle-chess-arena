import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/play/animation_lab_screen.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:battle_chess_arena/src/services/computer_player.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class HintPlayer implements ComputerPlayer {
  int calls = 0;
  ComputerDifficulty? difficulty;

  @override
  Future<String?> bestMove(
    String fen, {
    ComputerDifficulty difficulty = ComputerDifficulty.medium,
  }) async {
    calls++;
    this.difficulty = difficulty;
    return 'e2e4';
  }

  @override
  void dispose() {}
}

void main() {
  testWidgets('lifeline highlights a hard-level move without playing it', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final player = HintPlayer();
    await tester.pumpWidget(
      MaterialApp(
        home: AnimationLabScreen(
          pack: piecePacks.first,
          mode: PlayerMode.computer,
          computerPlayer: player,
        ),
      ),
    );
    final button = find.byKey(const ValueKey('use-computer-lifeline'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();

    expect(player.calls, 1);
    expect(player.difficulty, ComputerDifficulty.hard);
    expect(find.text('Suggested move: e2 → e4'), findsOneWidget);
    expect(find.text('Suggest best move (2 left)'), findsOneWidget);
    final board = tester.widget<ChessBoard>(find.byType(ChessBoard));
    expect(board.selected, Square.e2);
    expect(board.legalTargets, {Square.e4});
    expect(board.position.board.pieceAt(Square.e2)?.role, Role.pawn);
    expect(board.position.board.pieceAt(Square.e4), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
