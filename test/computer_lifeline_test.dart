import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/play/animation_lab_screen.dart';
import 'package:battle_chess_arena/src/features/play/capture_battle_overlay.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:battle_chess_arena/src/services/computer_player.dart';
import 'package:battle_chess_arena/src/services/last_game_storage.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class CaptureReplyPlayer implements ComputerPlayer {
  int calls = 0;

  @override
  Future<String?> bestMove(
    String fen, {
    ComputerDifficulty difficulty = ComputerDifficulty.medium,
  }) async {
    calls++;
    return 'd8d5';
  }

  @override
  void dispose() {}
}

void main() {
  testWidgets('lifeline highlights a hard-level move without playing it', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
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

  testWidgets(
    'computer capture waits two seconds after the previous cinematic',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final player = CaptureReplyPlayer();
      const saved = SavedGame(
        mode: PlayerMode.computer,
        homePack: PiecePackId.greek,
        difficulty: ComputerDifficulty.easy,
        moves: ['e2e4', 'd7d5'],
        whiteMilliseconds: 600000,
        blackMilliseconds: 600000,
        fastBattles: false,
        whitePack: PiecePackId.greek,
        blackPack: PiecePackId.greek,
        boardPack: PiecePackId.greek,
        updatedAtEpochMs: 1,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: AnimationLabScreen(
            pack: piecePacks.first,
            mode: PlayerMode.computer,
            savedGame: saved,
            computerPlayer: player,
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('square-e4')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('square-d5')));
      await tester.pump();
      expect(find.byType(CaptureBattleOverlay), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pump();
      expect(player.calls, 0);
      await tester.pump(const Duration(milliseconds: 1999));
      expect(player.calls, 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(player.calls, 1);
      expect(find.byType(CaptureBattleOverlay), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
