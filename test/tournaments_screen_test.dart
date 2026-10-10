import 'package:battle_chess_arena/src/domain/bot_tournament.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/play/animation_lab_screen.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:battle_chess_arena/src/features/tournaments/tournaments_screen.dart';
import 'package:battle_chess_arena/src/services/computer_player.dart';
import 'package:battle_chess_arena/src/services/arena_credit_controller.dart';
import 'package:battle_chess_arena/src/services/game_history_storage.dart';
import 'package:battle_chess_arena/src/services/last_game_storage.dart';
import 'package:battle_chess_arena/src/services/tournament_storage.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bot_tournament_test.dart' show tournamentSave;
import 'support/piece_choice.dart';
import 'support/autoplay.dart';

class TournamentComputer implements ComputerPlayer {
  ComputerDifficulty? requestedDifficulty;
  int? requestedBotLevel;
  String reply = 'e7e5';
  @override
  Future<String?> bestMove(
    String fen, {
    ComputerDifficulty difficulty = ComputerDifficulty.medium,
    int? botLevel,
  }) async {
    requestedDifficulty = difficulty;
    requestedBotLevel = botLevel;
    return reply;
  }

  @override
  void dispose() {}
}

void main() {
  setUp(() {
    AnimationLabScreen.debugClockFactory = () =>
        TestWidgetsFlutterBinding.ensureInitialized().clock.stopwatch();
  });
  tearDown(() => AnimationLabScreen.debugClockFactory = null);
  final cup = builtInTournaments.first;
  late TournamentStorage storage;
  late TournamentComputer computer;
  late ArenaCreditController wallet;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LastGameStorage.clear();
    storage = TournamentStorage();
    computer = TournamentComputer();
    wallet = ArenaCreditController();
    addTearDown(wallet.dispose);
  });

  Future<void> openCup(WidgetTester tester) async {
    await tester.pumpWidget(
      ArenaCreditScope(
        controller: wallet,
        child: MaterialApp(
          home: TournamentsScreen(
            pack: piecePacks.first,
            storage: storage,
            computerFactory: () => computer,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(ValueKey('open-tournament-${cup.id}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('open-tournament-${cup.id}')));
    await tester.pumpAndSettle();
  }

  Future<void> startRound(WidgetTester tester) async {
    await tester.ensureVisible(
      find.byKey(const ValueKey('play-tournament-round')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('play-tournament-round')));
    await tester.pumpAndSettle();
    if (find.text('Colour toss result').evaluate().isNotEmpty) {
      expect(find.byKey(const ValueKey('piece-type-choice')), findsNothing);
      return;
    }
    await chooseGamePieces(tester);
  }

  Future<void> finishComputerPreview(
    WidgetTester tester, {
    required Square from,
    required Square to,
  }) async {
    ChessBoard board() => tester.widget<ChessBoard>(find.byType(ChessBoard));
    for (var frame = 0; board().previewFrom == null && frame < 70; frame++) {
      // The Animated move finishes before the two-second reply pause begins.
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump();
    expect(board().previewFrom, from);
    expect(board().blinkingSquare, from);
    final movingPiece = board().position.board.pieceAt(from);
    expect(movingPiece, isNotNull);
    await tester.pump();
    for (var halfCycle = 0; halfCycle < 6; halfCycle++) {
      await tester.pump(const Duration(microseconds: 200001));
    }
    expect(board().blinkingSquare, to);
    expect(board().position.board.pieceAt(from), isNull);
    expect(board().position.board.pieceAt(to), movingPiece);
    await tester.pump();
    for (var halfCycle = 0; halfCycle < 6; halfCycle++) {
      await tester.pump(const Duration(microseconds: 200001));
    }
    expect(board().previewFrom, isNull);
  }

  Future<void> waitForResult(WidgetTester tester, Finder result) async {
    for (var frame = 0; result.evaluate().isEmpty && frame < 100; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(result, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
  }

  void testTournament(
    String description,
    Future<void> Function(WidgetTester tester) body,
  ) => testWidgets(description, (tester) async {
    try {
      await body(tester);
    } finally {
      // Saving the finished/unfinished recording is asynchronous. Complete both
      // queues in this test's FakeAsync zone before its preferences are replaced.
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      var settled = 0;
      Object? error;
      void complete(Object? _) => settled++;
      void failQueue(Object failure) {
        error = failure;
        settled++;
      }

      GameHistoryStorage().loadSnapshot().then(complete, onError: failQueue);
      storage.load(cup).then(complete, onError: failQueue);
      for (var frame = 0; settled < 2 && frame < 80; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(settled, 2, reason: 'History and tournament writes must complete');
      expect(error, isNull);
      await tester.pump();
    }
  });

  testTournament(
    'round uses bot strength, saves separately, and resumes its board',
    (tester) async {
      await LastGameStorage.save(tournamentSave(cup));
      final regular = (await LastGameStorage.load())!.toJson();
      await openCup(tester);
      expect(find.text('Play Quarterfinal'), findsOneWidget);
      await startRound(tester);
      expect(find.byType(AnimationLabScreen), findsOneWidget);
      expect(
        find.byKey(const ValueKey('match-difficulty-selector')),
        findsNothing,
      );
      expect(find.byTooltip('Undo'), findsNothing);
      expect(find.byTooltip('New game'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('square-e2')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('square-e4')));
      await tester.pump();
      await finishComputerPreview(tester, from: Square.e7, to: Square.e5);
      expect(computer.requestedDifficulty, ComputerDifficulty.easy);
      final match = tester.widget<AnimationLabScreen>(
        find.byType(AnimationLabScreen),
      );
      expect(
        computer.requestedBotLevel,
        match.tournamentMatch!.opponent.botLevel,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('play-tournament-round')),
        -250,
      );
      await tester.pumpAndSettle();
      expect(find.text('Resume round'), findsOneWidget);
      final saved = (await storage.load(cup))!;
      expect(saved.game!.moves, ['e2e4', 'e7e5']);
      expect((await LastGameStorage.load())!.toJson(), regular);
      await startRound(tester);
      final board = tester.widget<ChessBoard>(find.byType(ChessBoard));
      final resumed = tester.widget<AnimationLabScreen>(
        find.byType(AnimationLabScreen),
      );
      expect(
        resumed.tournamentMatch!.opponent.botLevel,
        computer.requestedBotLevel,
      );
      expect(board.position.board.pieceAt(Square.e4)?.role, Role.pawn);
      expect(board.position.board.pieceAt(Square.e5)?.role, Role.pawn);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testTournament(
    'resigning saves a loss and reopening offers the same opponent',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await openCup(tester);
      await startRound(tester);
      final first = tester
          .widget<AnimationLabScreen>(find.byType(AnimationLabScreen))
          .tournamentMatch!
          .opponent;
      await tester.scrollUntilVisible(
        find.text('Resign round'),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('portrait-match-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resign round'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Resign'));
      await waitForResult(tester, find.text('${first.name} wins'));
      expect(find.text('${first.name} wins'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Tournament'));
      await tester.pumpAndSettle();
      expect(find.text('Rematch this round'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await openCup(tester);
      expect(find.text('Rematch this round'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('tournament-retry-countdown')),
        findsNothing,
      );
      expect(wallet.credits, 300);
      await startRound(tester);
      expect(wallet.credits, 300);
      expect(wallet.lastChange?.reason, isNot('tournament_immediate_retry'));
      final retry = tester.widget<AnimationLabScreen>(
        find.byType(AnimationLabScreen),
      );
      expect(retry.tournamentMatch!.opponent.id, first.id);
      expect(retry.savedGame!.moves, isEmpty);
      expect((await storage.load(cup))!.run.wonRounds, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testTournament(
    'toss is saved before round starts and resume keeps the colour',
    (tester) async {
      await openCup(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('tournament-colour-toss')),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('tournament-colour-toss')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tournament-colour-toss')));
      await startRound(tester);
      expect(find.text('Colour toss result'), findsOneWidget);
      final tossed = (await storage.load(cup))!.game!;
      expect(tossed.moves, isEmpty);
      computer.reply = 'e2e4';
      await tester.tap(find.text('Start round'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ChessBoard>(find.byType(ChessBoard)).orientation,
        tossed.humanSide,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await openCup(tester);
      await startRound(tester);
      expect(find.text('Colour toss result'), findsNothing);
      expect(
        tester.widget<ChessBoard>(find.byType(ChessBoard)).orientation,
        tossed.humanSide,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testTournament('Black tournament checkmate awards the human a win', (
    tester,
  ) async {
    await storage.enter(cup);
    final progress = await storage.beginAttempt(cup);
    final saved = SavedGame.fromJson(
      tournamentSave(cup, moves: ['f2f3', 'e7e5', 'g2g4']).toJson()
        ..['humanSide'] = 'black',
    );
    await storage.saveMatch(
      cup,
      runId: progress.run.runId,
      attempt: progress.run.attempt,
      game: saved,
    );
    await openCup(tester);
    await startRound(tester);
    await tester.tap(find.byKey(const ValueKey('square-d8')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('square-h4')));
    await waitForResult(tester, find.text('Round won!'));
    expect(find.text('Round won!'), findsOneWidget);
    expect((await storage.load(cup))!.run.wonRounds, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testTournament(
    'checkmate advances once, including leaving after the result',
    (tester) async {
      await storage.enter(cup);
      final progress = await storage.beginAttempt(cup);
      await storage.saveMatch(
        cup,
        runId: progress.run.runId,
        attempt: progress.run.attempt,
        game: tournamentSave(
          cup,
          moves: ['e2e4', 'e7e5', 'f1c4', 'b8c6', 'd1h5', 'g8f6'],
        ),
      );
      await openCup(tester);
      await startRound(tester);
      await tester.tap(find.byKey(const ValueKey('square-h5')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('square-f7')));
      await tester.pump();
      await tester.tap(find.text('Skip'));
      await waitForResult(tester, find.text('Round won!'));
      expect(find.text('Round won!'), findsOneWidget);
      expect(
        find.text('+100 points added to your tournament total!'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Tournament'));
      await tester.pumpAndSettle();
      expect(find.text('Play Semifinal'), findsOneWidget);
      final restored = (await storage.load(cup))!;
      expect(restored.run.wonRounds, 1);
      expect(restored.run.results.first, [TournamentRoundResult.win]);
      expect(restored.game, isNull);
      expect((await storage.loadPlayerScore()).points, 100);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testTournament('threefold draw saves a replay without advancing', (
    tester,
  ) async {
    await storage.enter(cup);
    final progress = await storage.beginAttempt(cup);
    computer.reply = 'f6g8';
    await storage.saveMatch(
      cup,
      runId: progress.run.runId,
      attempt: progress.run.attempt,
      game: tournamentSave(
        cup,
        moves: ['g1f3', 'g8f6', 'f3g1', 'f6g8', 'g1f3', 'g8f6', 'f3g1'],
      ),
    );
    await openCup(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('play-tournament-round')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('play-tournament-round')));
    await tester.pump();
    await tester.pump();
    await finishComputerPreview(tester, from: Square.f6, to: Square.g8);
    await waitForResult(tester, find.text('Round drawn'));
    expect(find.text('Round drawn'), findsOneWidget);
    final saved = (await storage.load(cup))!;
    expect(saved.run.lastResult, TournamentRoundResult.draw);
    expect(saved.run.wonRounds, 0);
    expect(saved.game, isNull);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.tap(find.widgetWithText(FilledButton, 'Tournament'));
    await tester.pumpAndSettle();
    expect(find.text('Rematch this round'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testTournament(
    'final win celebrates, keeps points, and allows a reward-free replay',
    (tester) async {
      await storage.enter(cup);
      for (var round = 0; round < cup.roundCount - 1; round++) {
        final run = (await storage.beginAttempt(cup)).run;
        await storage.saveMatch(
          cup,
          runId: run.runId,
          attempt: run.attempt,
          game: tournamentSave(cup),
          result: TournamentRoundResult.win,
        );
      }
      final run = (await storage.beginAttempt(cup)).run;
      await storage.saveMatch(
        cup,
        runId: run.runId,
        attempt: run.attempt,
        game: tournamentSave(
          cup,
          moves: ['e2e4', 'e7e5', 'f1c4', 'b8c6', 'd1h5', 'g8f6'],
        ),
      );
      await openCup(tester);
      await startRound(tester);
      await tester.tap(find.byKey(const ValueKey('square-h5')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('square-f7')));
      await tester.pump();
      await tester.tap(find.text('Skip'));
      await waitForResult(
        tester,
        find.byKey(const ValueKey('championship-celebration')),
      );
      expect(
        find.byKey(const ValueKey('championship-celebration')),
        findsOneWidget,
      );
      expect(find.text('+100 points · Final victory'), findsOneWidget);
      expect(find.text('300 cup points earned'), findsOneWidget);
      expect((await storage.loadPlayerScore()).points, 300);
      await tester.ensureVisible(
        find.byKey(const ValueKey('championship-continue')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('championship-continue')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tournament-champion')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('replay-championship')),
        150,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('replay-championship')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 650));
      expect(
        find.text('Already in your total · No additional points'),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('championship-continue')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('championship-continue')));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, 1000));
      await tester.pumpAndSettle();
      expect(find.text('300 points'), findsOneWidget);
      expect((await TournamentStorage().loadPlayerScore()).trophies, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testTournament(
    'background pauses the clock; timeout records a retryable loss',
    (tester) async {
      await storage.enter(cup);
      final progress = await storage.beginAttempt(cup);
      final game = SavedGame.fromJson(
        tournamentSave(cup).toJson()..['whiteMilliseconds'] = 1500,
      );
      await storage.saveMatch(
        cup,
        runId: progress.run.runId,
        attempt: progress.run.attempt,
        game: game,
      );
      await openCup(tester);
      await startRound(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 5));
      expect((await storage.load(cup))!.run.lastResult, isNull);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 2));
      await waitForResult(tester, find.text('TIMEOUT'));
      expect(find.text('TIMEOUT'), findsOneWidget);
      expect(
        (await storage.load(cup))!.run.lastResult,
        TournamentRoundResult.loss,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Tournament'));
      await tester.pumpAndSettle();
      expect(find.text('Rematch this round'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testTournament(
    'timeout during an auto source preview cancels the pending move',
    (tester) async {
      await storage.enter(cup);
      final progress = await storage.beginAttempt(cup);
      final game = SavedGame.fromJson(
        tournamentSave(cup).toJson()..['whiteMilliseconds'] = 2500,
      );
      await storage.saveMatch(
        cup,
        runId: progress.run.runId,
        attempt: progress.run.attempt,
        game: game,
      );
      computer.reply = 'g1f3';
      await openCup(tester);
      await startRound(tester);
      await toggleAutoPlay(tester);
      await tester.pump(const Duration(microseconds: 2000001));
      expect(
        tester.widget<ChessBoard>(find.byType(ChessBoard)).previewFrom,
        Square.g1,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await waitForResult(tester, find.text('TIMEOUT'));
      expect(find.text('TIMEOUT'), findsOneWidget);
      final board = tester.widget<ChessBoard>(find.byType(ChessBoard));
      expect(board.previewFrom, isNull);
      expect(board.blinkingSquare, isNull);
      expect(board.position.board.pieceAt(Square.g1)?.role, Role.knight);
      expect(board.position.board.pieceAt(Square.f3), isNull);
      expect(
        (await storage.load(cup))!.run.lastResult,
        TournamentRoundResult.loss,
      );
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
