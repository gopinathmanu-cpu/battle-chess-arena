import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/play/animation_lab_screen.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:battle_chess_arena/src/features/play/neon_live_game_layout.dart';
import 'package:battle_chess_arena/src/services/computer_player.dart';
import 'package:battle_chess_arena/src/services/last_game_storage.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/piece_choice.dart';

class WhiteComputer implements ComputerPlayer {
  final turns = <Side>[];
  @override
  Future<String?> bestMove(
    String fen, {
    ComputerDifficulty difficulty = ComputerDifficulty.medium,
    int? botLevel,
  }) async {
    final position = Chess.fromSetup(Setup.parseFen(fen));
    turns.add(position.turn);
    if (position.turn == Side.black) return 'e7e5'; // hint
    return position.board.pieceAt(Square.e2) != null ? 'e2e4' : 'g1f3';
  }

  @override
  void dispose() {}
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LastGameStorage.clear();
  });

  test('Black human turn and save migration preserve side', () {
    final game = GameSession(mode: PlayerMode.computer, humanSide: Side.black);
    expect(game.isHumanTurn, false);
    game.playUci('e2e4');
    expect(game.isHumanTurn, true);
    final saved = SavedGame(
      mode: game.mode,
      humanSide: game.humanSide,
      homePack: piecePacks.first.id,
      difficulty: ComputerDifficulty.easy,
      moves: game.uciMoves,
      whiteMilliseconds: 60000,
      blackMilliseconds: 60000,
      fastBattles: true,
      whitePack: piecePacks.first.id,
      blackPack: piecePacks.first.id,
      boardPack: piecePacks.first.id,
      updatedAtEpochMs: 1,
    );
    expect(SavedGame.fromJson(saved.toJson()).humanSide, Side.black);
    final legacy = saved.toJson()..remove('humanSide');
    expect(SavedGame.fromJson(legacy).humanSide, Side.white);
    expect(
      () => SavedGame.fromJson(saved.toJson()..['humanSide'] = 'invalid'),
      throwsArgumentError,
    );
  });

  testWidgets(
    'Black starts with White bot move, flipped board, hint, undo and resume',
    (tester) async {
      final computer = WhiteComputer();
      await tester.pumpWidget(
        MaterialApp(
          home: AnimationLabScreen(
            pack: piecePacks.first,
            mode: PlayerMode.computer,
            humanSide: Side.black,
            computerPlayer: computer,
          ),
        ),
      );
      await tester.pumpAndSettle();
      ChessBoard board() => tester.widget<ChessBoard>(find.byType(ChessBoard));
      expect(computer.turns, [Side.white]);
      expect(board().orientation, Side.black);
      expect(board().position.turn, Side.black);
      expect(find.text('YOUR TURN · BLACK'), findsOneWidget);
      expect(
        tester.getCenter(find.byKey(const ValueKey('square-a8'))).dy,
        greaterThan(
          tester.getCenter(find.byKey(const ValueKey('square-a1'))).dy,
        ),
      );
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('use-computer-lifeline')),
          )
          .onPressed!();
      await tester.pump();
      expect(board().suggestedFrom, Square.e7);
      expect(board().suggestedTo, Square.e5);
      board().onSquareTap(Square.e7);
      await tester.pump();
      board().onSquareTap(Square.e5);
      await tester.pump();
      expect(board().position.turn, Side.white);
      for (
        var frame = 0;
        board().position.turn != Side.black && frame < 120;
        frame++
      ) {
        // Finish the Animated move, reply pause, and source preview first.
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();
      expect(board().position.turn, Side.black);
      expect(computer.turns, [Side.white, Side.black, Side.white]);
      await tester.ensureVisible(find.byTooltip('Undo'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();
      expect(board().position.board.pieceAt(Square.e7)?.role, Role.pawn);
      expect(board().position.board.pieceAt(Square.e4)?.role, Role.pawn);
      final saved = (await LastGameStorage.load())!;
      expect(saved.humanSide, Side.black);
      expect(saved.moves, ['e2e4']);
      await tester.pumpWidget(const SizedBox());
      final resumed = WhiteComputer();
      await tester.pumpWidget(
        MaterialApp(
          home: AnimationLabScreen(
            pack: piecePacks.first,
            mode: PlayerMode.computer,
            savedGame: saved,
            computerPlayer: resumed,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(board().orientation, Side.black);
      expect(resumed.turns, isEmpty);
      await tester.ensureVisible(find.byTooltip('Game settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Game settings'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('New game'),
        150,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('game-settings-list')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(find.text('New game'));
      await tester.pumpAndSettle();
      expect(find.text('Unlimited (No timer limit)'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('White'),
        ),
      );
      await tester.tap(find.text('New Game'));
      await chooseGamePieces(tester);
      await tester.pumpAndSettle();
      expect(board().orientation, Side.white);
      expect(board().position.turn, Side.white);
      expect(resumed.turns, isEmpty);
      expect(
        tester.widget<NeonLiveStatusBar>(find.byType(NeonLiveStatusBar)).timed,
        isFalse,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
