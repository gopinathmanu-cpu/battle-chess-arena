import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/play/animation_lab_screen.dart';
import 'package:battle_chess_arena/src/features/play/capture_battle_overlay.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:battle_chess_arena/src/services/computer_player.dart';
import 'package:battle_chess_arena/src/services/last_game_storage.dart';
import 'package:battle_chess_arena/src/services/arena_credit_controller.dart';
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
    int? botLevel,
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
    int? botLevel,
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
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final player = HintPlayer();
    final credits = ArenaCreditController();
    addTearDown(credits.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ArenaCreditScope(
          controller: credits,
          child: AnimationLabScreen(
            pack: piecePacks.first,
            mode: PlayerMode.computer,
            computerPlayer: player,
          ),
        ),
      ),
    );
    final button = find.byKey(const ValueKey('use-computer-lifeline'));
    final threatButton = find.byKey(const ValueKey('analyse-threats'));
    await tester.scrollUntilVisible(
      button,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final suggestRect = tester.getRect(button);
    final threatRect = tester.getRect(threatButton);
    expect(suggestRect.bottom, threatRect.bottom);
    expect(suggestRect.bottom, lessThanOrEqualTo(844));
    expect(threatRect.bottom, lessThanOrEqualTo(844));
    tester.widget<FilledButton>(button).onPressed!();
    await tester.pump();

    expect(player.calls, 1);
    expect(credits.credits, 299);
    expect(credits.lastChange?.reason, 'move_suggestion');
    expect(player.difficulty, ComputerDifficulty.hard);
    expect(find.text('Suggested move: e2 → e4'), findsOneWidget);
    expect(find.text('Suggest move'), findsOneWidget);
    final board = tester.widget<ChessBoard>(find.byType(ChessBoard));
    expect(board.selected, isNull);
    expect(board.legalTargets, isEmpty);
    expect(board.suggestedFrom, Square.e2);
    expect(board.suggestedTo, Square.e4);
    expect(board.position.board.pieceAt(Square.e2)?.role, Role.pawn);
    expect(board.position.board.pieceAt(Square.e4), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'quick piece toggle changes both armies and preserves the board',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: AnimationLabScreen(pack: piecePacks.first)),
      );

      final toggle = find.byKey(const ValueKey('quick-piece-style-toggle'));
      expect(find.text('Game settings'), findsNothing);
      await tester.tap(toggle);
      await tester.pump();

      final board = tester.widget<ChessBoard>(find.byType(ChessBoard));
      expect(board.appearance?.white.id, PiecePackId.anime);
      expect(board.appearance?.black.id, PiecePackId.anime);
      expect(board.appearance?.board.id, PiecePackId.anime);
      expect(board.appearance?.standardPieces, isTrue);
      expect(find.byTooltip('Use animated character pieces'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('computer opponent move remains highlighted after the reply', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const saved = SavedGame(
      mode: PlayerMode.computer,
      homePack: PiecePackId.greek,
      difficulty: ComputerDifficulty.easy,
      moves: ['e2e4', 'e7e5', 'g1f3'],
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
          computerPlayer: CaptureReplyPlayer(),
        ),
      ),
    );

    final board = tester.widget<ChessBoard>(find.byType(ChessBoard));
    expect(board.lastMoveFrom, Square.e7);
    expect(board.lastMoveTo, Square.e5);
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
      // Skipping the overlay still lets the Olympian live strike finish.
      await tester.pump(const Duration(milliseconds: 850));
      expect(player.calls, 0);
      await tester.pump(const Duration(milliseconds: 1999));
      expect(player.calls, 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(player.calls, 1);
      expect(find.byType(CaptureBattleOverlay), findsNothing);
      expect(
        tester.widget<ChessBoard>(find.byType(ChessBoard)).previewFrom,
        Square.d8,
      );
      await tester.pump();
      for (var halfCycle = 0; halfCycle < 6; halfCycle++) {
        await tester.pump(const Duration(microseconds: 200001));
      }
      expect(find.byType(CaptureBattleOverlay), findsOneWidget);
      final committed = tester.widget<ChessBoard>(find.byType(ChessBoard));
      expect(committed.position.board.pieceAt(Square.d8), isNull);
      expect(committed.position.board.pieceAt(Square.d5)?.role, Role.queen);
      expect(committed.blinkingSquare, isNull);
      await tester.tap(find.text('Skip'));
      await tester.pump();
      expect(
        tester.widget<ChessBoard>(find.byType(ChessBoard)).blinkingSquare,
        Square.d5,
      );
      await tester.pump();
      for (var halfCycle = 0; halfCycle < 6; halfCycle++) {
        await tester.pump(const Duration(microseconds: 200001));
      }
      final completed = tester.widget<ChessBoard>(find.byType(ChessBoard));
      expect(completed.previewFrom, isNull);
      expect(completed.lastMoveFrom, Square.d8);
      expect(completed.lastMoveTo, Square.d5);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
