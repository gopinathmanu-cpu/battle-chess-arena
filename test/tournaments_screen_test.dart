import 'package:battle_chess_arena/src/domain/bot_tournament.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/play/animation_lab_screen.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:battle_chess_arena/src/features/tournaments/tournaments_screen.dart';
import 'package:battle_chess_arena/src/services/computer_player.dart';
import 'package:battle_chess_arena/src/services/arena_credit_controller.dart';
import 'package:battle_chess_arena/src/services/last_game_storage.dart';
import 'package:battle_chess_arena/src/services/tournament_storage.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bot_tournament_test.dart' show tournamentSave;

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
  }

  testWidgets(
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
      await tester.pumpAndSettle();
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

  testWidgets('resigning saves a loss and reopening offers the same opponent', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await openCup(tester);
    await startRound(tester);
    final first = tester
        .widget<AnimationLabScreen>(find.byType(AnimationLabScreen))
        .tournamentMatch!
        .opponent;
    await tester.ensureVisible(find.text('Resign round'));
    await tester.ensureVisible(find.text('Resign round'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resign round'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Resign'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
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
      findsOneWidget,
    );
    expect(wallet.credits, 300);
    await startRound(tester);
    expect(wallet.credits, 295);
    expect(wallet.lastChange?.reason, 'tournament_immediate_retry');
    final retry = tester.widget<AnimationLabScreen>(
      find.byType(AnimationLabScreen),
    );
    expect(retry.tournamentMatch!.opponent.id, first.id);
    expect(retry.savedGame!.moves, isEmpty);
    expect((await storage.load(cup))!.run.wonRounds, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('toss is saved before round starts and resume keeps the colour', (
    tester,
  ) async {
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
  });

  testWidgets('Black tournament checkmate awards the human a win', (
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Round won!'), findsOneWidget);
    expect((await storage.load(cup))!.run.wonRounds, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('checkmate advances once, including leaving after the result', (
    tester,
  ) async {
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
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
  });

  testWidgets('threefold draw saves a replay without advancing', (
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
    await tester.pump(const Duration(milliseconds: 800));
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

  testWidgets(
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
      await tester.pumpAndSettle();
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
      await tester.pumpAndSettle();
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

  testWidgets('background pauses the clock; timeout records a retryable loss', (
    tester,
  ) async {
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
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('TIMEOUT'), findsOneWidget);
    expect(
      (await storage.load(cup))!.run.lastResult,
      TournamentRoundResult.loss,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Tournament'));
    await tester.pumpAndSettle();
    expect(find.text('Rematch this round'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
