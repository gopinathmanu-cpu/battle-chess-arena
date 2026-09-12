import 'package:battle_chess_arena/src/app.dart';
import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/play/animation_lab_screen.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:battle_chess_arena/src/services/computer_player.dart';
import 'package:battle_chess_arena/src/services/last_game_storage.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme_music_test.dart' show FakeMusicOutput;

SavedGame savedGame({PlayerMode mode = PlayerMode.local}) => SavedGame(
  mode: mode,
  homePack: PiecePackId.greek,
  difficulty: ComputerDifficulty.hard,
  moves: const ['e2e4', 'e7e5', 'g1f3'],
  whiteMilliseconds: 574000,
  blackMilliseconds: 581000,
  fastBattles: true,
  whitePack: PiecePackId.greek,
  blackPack: PiecePackId.futuristic,
  boardPack: PiecePackId.classic,
  updatedAtEpochMs: 123456789,
  lifelinesRemaining: 2,
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LastGameStorage.clear();
  });

  test('saved game round trip restores legal history and settings', () async {
    final original = savedGame();
    await LastGameStorage.save(original);
    final restored = await LastGameStorage.load();
    expect(restored?.moves, original.moves);
    expect(restored?.difficulty, ComputerDifficulty.hard);
    expect(restored?.blackPack, PiecePackId.futuristic);
    expect(restored?.lifelinesRemaining, 2);
    final session = GameSession.fromMoves(
      mode: restored!.mode,
      moves: restored.moves,
    );
    expect(session.position.turn, Side.black);
    expect(session.sanMoves, ['e4', 'e5', 'Nf3']);
    session.undo();
    expect(session.uciMoves, ['e2e4', 'e7e5']);
  });

  test('older saved games receive all three lifelines', () {
    final json = savedGame().toJson()..remove('lifelinesRemaining');
    expect(SavedGame.fromJson(json).lifelinesRemaining, 3);
  });

  testWidgets('home prompts and resumes the unfinished game', (tester) async {
    await LastGameStorage.save(savedGame());
    await tester.pumpWidget(
      BattleChessArenaApp(musicOutput: FakeMusicOutput()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Resume last game?'), findsOneWidget);
    expect(find.text('Resume Last Game'), findsOneWidget);
    expect(find.text('New Game'), findsOneWidget);
    await tester.tap(find.text('Resume Last Game'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final match = tester.widget<AnimationLabScreen>(
      find.byType(AnimationLabScreen),
    );
    expect(match.savedGame?.moves, ['e2e4', 'e7e5', 'g1f3']);
    final board = tester.widget<ChessBoard>(find.byType(ChessBoard));
    expect(board.position.turn, Side.black);
    expect(board.position.board.pieceAt(Square.f3)?.role, Role.knight);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('new game requires confirmation before clearing progress', (
    tester,
  ) async {
    await LastGameStorage.save(savedGame());
    await tester.pumpWidget(
      MaterialApp(
        home: AnimationLabScreen(
          pack: piecePacks.firstWhere((p) => p.id == PiecePackId.greek),
          savedGame: savedGame(),
        ),
      ),
    );
    await tester.pump();
    expect(
      tester.widget<ChessBoard>(find.byType(ChessBoard)).position.turn,
      Side.black,
    );
    await tester.tap(find.byTooltip('New game'));
    await tester.pump();
    expect(find.text('Start a new game?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(
      tester.widget<ChessBoard>(find.byType(ChessBoard)).position.turn,
      Side.black,
    );
    expect(await LastGameStorage.load(), isNotNull);
    await tester.tap(find.byTooltip('New game'));
    await tester.pump();
    await tester.tap(find.text('New Game'));
    await tester.pump();
    expect(
      tester.widget<ChessBoard>(find.byType(ChessBoard)).position.turn,
      Side.white,
    );
    expect(await LastGameStorage.load(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
