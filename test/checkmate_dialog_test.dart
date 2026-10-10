import 'package:battle_chess_arena/src/domain/game_result_analysis.dart';
import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/play/animation_lab_screen.dart';
import 'package:battle_chess_arena/src/features/play/checkmate_dialog.dart';
import 'package:battle_chess_arena/src/features/play/checkmate_animation.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:battle_chess_arena/src/features/play/neon_cinematic_screen.dart';
import 'package:battle_chess_arena/src/features/online/online_game_screen.dart';
import 'package:battle_chess_arena/src/services/computer_player.dart';
import 'package:battle_chess_arena/src/services/last_game_storage.dart';
import 'package:battle_chess_arena/src/services/online_match_client.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/online_fixtures.dart';

Future<void> finishMatePresentation(
  WidgetTester tester, {
  bool waitForAnimatedMove = false,
}) async {
  if (waitForAnimatedMove) {
    await tester.pump(const Duration(milliseconds: 850));
  }
  await tester.pump();
  expect(find.byType(CheckmateAnimation), findsOneWidget);
  expect(find.byKey(const ValueKey('checkmate-heading')), findsNothing);
  await tester.pump(
    checkmateAnimationDuration + const Duration(milliseconds: 1),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
  expect(find.byType(CheckmateAnimation), findsNothing);
}

void main() {
  setUp(() {
    AnimationLabScreen.debugClockFactory = () =>
        TestWidgetsFlutterBinding.ensureInitialized().clock.stopwatch();
  });
  tearDown(() => AnimationLabScreen.debugClockFactory = null);
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
    await finishMatePresentation(tester, waitForAnimatedMove: true);

    expect(find.byKey(const ValueKey('checkmate-heading')), findsOneWidget);
    expect(find.text('Black Wins!'), findsOneWidget);
    expect(find.byKey(const ValueKey('result-sentiment')), findsOneWidget);
    expect(find.byKey(const ValueKey('result-analysis')), findsOneWidget);
    expect(find.text('Review Board'), findsOneWidget);
    expect(find.text('New Game'), findsOneWidget);
    expect(find.text('Watch cinematic summary'), findsWidgets);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Review Board'));
    // The game clock intentionally remains periodic behind the closing dialog,
    // so bounded pumps are more accurate than waiting for global quiescence.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
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

  testWidgets('cinematic action returns to the same result dialog', (
    tester,
  ) async {
    var opens = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showGameResultDialog(
                context: context,
                outcome: GameResultOutcome.draw,
                heading: 'DRAW',
                title: 'Game Drawn',
                message: const GameResultMessage(
                  sentiment: 'Well played.',
                  comment: 'The match is complete.',
                ),
                onWatchCinematic: () async {
                  opens++;
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) =>
                          Scaffold(appBar: AppBar(title: const Text('Movie'))),
                    ),
                  );
                },
              ),
              child: const Text('Finish'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Finish'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.text('Watch cinematic summary'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(opens, 1);
    expect(find.text('Movie'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Game Drawn'), findsOneWidget);
    expect(find.text('Review Board'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('watch-cinematic-summary')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Neon result and completed board replay the full game', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final neon = piecePacks.firstWhere(
      (pack) => pack.id == PiecePackId.futuristic,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AnimationLabScreen(
          pack: neon,
          initialClassicPieces: true,
          initialAnimatedArena: true,
        ),
      ),
    );
    for (final move in ['f2f3', 'e7e5', 'g2g4', 'd8h4']) {
      await tester.tap(find.byKey(ValueKey('square-${move.substring(0, 2)}')));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey('square-${move.substring(2)}')));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await finishMatePresentation(tester, waitForAnimatedMove: true);
    expect(find.byKey(const ValueKey('result-neon-city')), findsOneWidget);
    expect(
      tester
          .widget<ChessBoard>(find.byType(ChessBoard))
          .appearance!
          .standardPieces,
      isTrue,
    );
    await tester.ensureVisible(find.text('Watch cinematic summary').last);
    await tester.tap(find.text('Watch cinematic summary').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final movie = tester.widget<NeonCinematicScreen>(
      find.byType(NeonCinematicScreen),
    );
    expect(movie.moves, ['f2f3', 'e7e5', 'g2g4', 'd8h4']);
    expect(movie.resultTitle, 'Black Wins! · Checkmate');
    expect(movie.playerSide, isNull);
    expect(movie.winnerSide, Side.black);
    Navigator.of(tester.element(find.byType(NeonCinematicScreen))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Black Wins!'), findsOneWidget);
    await tester.ensureVisible(find.text('Review Board'));
    await tester.tap(find.text('Review Board'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    final finishedBoard = tester.widget<ChessBoard>(find.byType(ChessBoard));
    expect(finishedBoard.position.isCheckmate, isTrue);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('finished-match-cinematic')),
      180,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('landscape-match-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(
      find.byKey(const ValueKey('finished-match-cinematic')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Classic Neon keeps its movie while mixed armies do not', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final neon = piecePacks.firstWhere(
      (pack) => pack.id == PiecePackId.futuristic,
    );
    for (final classic in [true, false]) {
      final saved = SavedGame(
        mode: PlayerMode.local,
        homePack: neon.id,
        difficulty: ComputerDifficulty.medium,
        moves: const ['f2f3', 'e7e5', 'g2g4', 'd8h4'],
        whiteMilliseconds: 60000,
        blackMilliseconds: 60000,
        fastBattles: false,
        classicPieces: classic,
        whitePack: neon.id,
        blackPack: classic ? neon.id : PiecePackId.anime,
        boardPack: neon.id,
        updatedAtEpochMs: 1,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: AnimationLabScreen(pack: neon, savedGame: saved),
        ),
      );
      final scroll = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(const ValueKey('landscape-match-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('finished-match-cinematic')),
        classic ? findsOneWidget : findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('completed online Neon game replays validated SAN history', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final channel = FakeChannel();
    final client = OnlineMatchClient(channelFactory: (_) => channel);
    await client.connect(Uri.parse('ws://localhost:8080'));
    channel.seat();
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        home: OnlineGameScreen(
          client: client,
          pack: piecePacks.firstWhere(
            (pack) => pack.id == PiecePackId.futuristic,
          ),
        ),
      ),
    );
    final game = GameSession.fromMoves(
      mode: PlayerMode.local,
      moves: const ['f2f3', 'e7e5', 'g2g4', 'd8h4'],
    );
    channel.receive({
      'type': 'game_state',
      'state': stateJson(
        game: game,
        sequence: 2,
        status: 'complete',
        result: {'reason': 'checkmate', 'winner': 'b'},
      ),
    });
    await tester.pump(const Duration(milliseconds: 1000));
    await finishMatePresentation(tester);
    await tester.ensureVisible(find.text('Watch cinematic summary').last);
    await tester.tap(find.text('Watch cinematic summary').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final movie = tester.widget<NeonCinematicScreen>(
      find.byType(NeonCinematicScreen),
    );
    expect(movie.moves, game.uciMoves);
    expect(movie.resultTitle, 'Checkmate · Black wins');
    expect(movie.playerSide, Side.white);
    expect(movie.winnerSide, Side.black);
    expect(channel.sent.any((frame) => frame['type'] == 'move'), isFalse);
    await tester.pumpWidget(const SizedBox());
    client.dispose();
  });

  testWidgets('online movie is hidden for corrupt or truncated history', (
    tester,
  ) async {
    final neon = piecePacks.firstWhere(
      (pack) => pack.id == PiecePackId.futuristic,
    );
    for (final san in [
      <String>[],
      <String>['invalid'],
    ]) {
      SharedPreferences.setMockInitialValues({});
      final channel = FakeChannel();
      final client = OnlineMatchClient(channelFactory: (_) => channel);
      await client.connect(Uri.parse('ws://localhost:8080'));
      channel.seat();
      await tester.pump();
      await tester.pumpWidget(
        MaterialApp(
          home: OnlineGameScreen(client: client, pack: neon),
        ),
      );
      final game = GameSession.fromMoves(
        mode: PlayerMode.local,
        moves: const ['e2e4'],
      );
      final state = stateJson(
        game: game,
        sequence: 2,
        status: 'complete',
        result: {'reason': 'resignation', 'winner': 'b'},
      )..['san'] = san;
      channel.receive({'type': 'game_state', 'state': state});
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('RESIGNATION'), findsOneWidget);
      expect(find.text('Watch cinematic summary'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      client.dispose();
    }
  });
}
