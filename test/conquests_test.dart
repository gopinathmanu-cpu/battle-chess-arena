import 'package:battle_chess_arena/src/domain/adaptive_difficulty.dart';
import 'package:battle_chess_arena/src/domain/bot_tournament.dart';
import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/services/last_game_storage.dart';
import 'package:battle_chess_arena/src/services/arena_credit_controller.dart';
import 'package:battle_chess_arena/src/services/tournament_storage.dart';
import 'package:battle_chess_arena/src/features/tournaments/tournaments_screen.dart';
import 'package:battle_chess_arena/src/features/play/animation_lab_screen.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tournaments_screen_test.dart' show TournamentComputer;
import 'support/piece_choice.dart';

SavedGame saveFor(BotTournament cup, TournamentRun run) => SavedGame(
  mode: PlayerMode.computer,
  homePack: cup.armies[run.wonRounds].id,
  difficulty: tournamentDifficulty(run.currentOpponent(cup).level),
  moves: const [],
  whiteMilliseconds: 900000,
  blackMilliseconds: 900000,
  fastBattles: false,
  whitePack: cup.armies[run.wonRounds].id,
  blackPack: cup.armies[run.wonRounds].id,
  boardPack: cup.armies[run.wonRounds].id,
  updatedAtEpochMs: 1,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('conquest catalog provides small, medium, large and full routes', () {
    expect(builtInTournaments.length, 3);
    expect(builtInTournaments.every((cup) => !cup.isConquest), isTrue);
    expect(builtInConquests.map((cup) => cup.roundCount), [3, 5, 10, 19]);
    expect(builtInConquests.map((cup) => cup.conquestSize), [
      ConquestSize.small,
      ConquestSize.medium,
      ConquestSize.large,
      ConquestSize.full,
    ]);
    expect(builtInConquests.map((cup) => cup.title), [
      'Indo-Arabian Conquest',
      'European Conquest',
      'Asian Conquest',
      'World Conquest',
    ]);
    for (final cup in builtInConquests) {
      expect(
        cup.armies.every((pack) => pack.group == cup.conquestGroup),
        isTrue,
      );
      expect(
        cup.armies.map((pack) => pack.id).toSet(),
        hasLength(cup.roundCount),
      );
      final sizeRanks = cup.armies
          .map((pack) => historicalConquestArmySizeRank(pack.id))
          .toList();
      expect(sizeRanks, everyElement(greaterThanOrEqualTo(0)));
      expect(
        sizeRanks,
        orderedEquals([...sizeRanks]..sort()),
        reason: '${cup.title} must progress from smaller to larger armies',
      );
      var run = TournamentRun.start(cup, seed: 7);
      for (final army in cup.armies) {
        expect(run.currentOpponent(cup).name, army.name);
        run = run
            .beginAttempt(adaptiveLevel: 6)
            .finish(TournamentRoundResult.win);
        run = TournamentRun.fromJson(run.toJson(), cup);
      }
      expect(run.completed, isTrue);
      expect(run.pointsEarned(cup), cup.roundCount * cup.pointsPerWin);
    }
    final world = builtInConquests.last;
    expect(world.id, 'history-conquest-v1');
    expect(world.armies.last.id, PiecePackId.chinese);
    expect(
      world.armies.map((pack) => pack.id).toSet(),
      piecePacks
          .where((pack) => pack.group == PiecePackGroup.historical)
          .map((pack) => pack.id)
          .toSet(),
    );
  });

  test('adaptive estimate is bounded, draws steady and rounds ramp', () {
    const player = AdaptiveDifficulty();
    expect(player.record(1).level, 7);
    expect(player.record(0).level, 5);
    expect(player.record(.5).level, 6);
    expect(player.opponentLevel(8), greaterThan(player.opponentLevel(0)));
    expect(const AdaptiveDifficulty(level: 20).record(1).level, 20);
    expect(const AdaptiveDifficulty(level: 1).record(0).level, 1);
    expect(
      () => AdaptiveDifficulty.fromJson({'level': 21, 'games': 0}),
      throwsFormatException,
    );
    final cup = builtInConquests.first;
    final run = TournamentRun.start(
      cup,
    ).beginAttempt(adaptiveLevel: 20).finish(TournamentRoundResult.loss);
    expect(run.nextConquestLevel(const AdaptiveDifficulty(level: 20)), 19);
  });

  test(
    'results update once; rematch eases; win increases; resume freezes level',
    () async {
      final storage = TournamentStorage();
      final cup = builtInConquests.first;
      await storage.enter(cup);
      var progress = await storage.beginAttempt(cup);
      expect(progress.run.adaptiveLevel, 6);
      final initial = progress.run;
      final game = saveFor(cup, initial);
      await storage.saveMatch(
        cup,
        runId: initial.runId,
        attempt: initial.attempt,
        game: game,
      );
      expect(
        (await TournamentStorage().beginAttempt(cup)).run.adaptiveLevel,
        6,
      );
      Future<void> loss() => storage.saveMatch(
        cup,
        runId: initial.runId,
        attempt: initial.attempt,
        game: game,
        result: TournamentRoundResult.loss,
      );
      await Future.wait([loss(), loss()]);
      expect((await storage.loadAdaptivePlayer()).games, 1);
      progress = await storage.beginAttempt(cup);
      expect(progress.run.adaptiveLevel, 5);
      expect(progress.run.wonRounds, 0);
      await storage.saveMatch(
        cup,
        runId: progress.run.runId,
        attempt: progress.run.attempt,
        game: saveFor(cup, progress.run),
        result: TournamentRoundResult.win,
      );
      progress = await TournamentStorage().beginAttempt(cup);
      expect(progress.run.wonRounds, 1);
      expect(progress.run.adaptiveLevel, greaterThan(5));
      expect((await storage.loadAdaptivePlayer()).games, 2);
      expect((await storage.loadPlayerScore()).points, 0);
      final other = builtInConquests.last;
      await storage.enter(other);
      final otherRun = (await storage.beginAttempt(other)).run;
      await storage.saveMatch(
        other,
        runId: otherRun.runId,
        attempt: otherRun.attempt,
        game: saveFor(other, otherRun),
        result: TournamentRoundResult.win,
      );
      expect((await storage.loadAdaptivePlayer()).games, 3);
      expect(
        (await storage.beginAttempt(cup)).run.adaptiveLevel,
        progress.run.adaptiveLevel,
      );
    },
  );

  testWidgets('conquest retry offers paid now or free after cooldown', (
    tester,
  ) async {
    final cup = builtInConquests.first;
    final storage = TournamentStorage();
    await storage.enter(cup);
    final attempt = await storage.beginAttempt(cup);
    await storage.saveMatch(
      cup,
      runId: attempt.run.runId,
      attempt: attempt.run.attempt,
      game: saveFor(cup, attempt.run),
      result: TournamentRoundResult.loss,
    );
    final wallet = ArenaCreditController();
    addTearDown(wallet.dispose);

    await tester.pumpWidget(
      ArenaCreditScope(
        controller: wallet,
        child: MaterialApp(
          home: TournamentsScreen(
            pack: piecePacks.first,
            conquests: true,
            initialClassicPieces: true,
            initialAnimatedArena: false,
            storage: storage,
            computerFactory: TournamentComputer.new,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final entry = find.byKey(ValueKey('open-tournament-${cup.id}'));
    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();
    await tester.tap(entry);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('play-tournament-round')),
      250,
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('tournament-retry-countdown')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('conquest-proceed-button')), findsNothing);
    expect(find.text('Rematch this round'), findsOneWidget);
    expect(find.text('5'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('play-tournament-round')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('piece-type-choice')), findsNothing);
    await chooseGamePieces(tester, classic: true);
    await tester.pumpAndSettle();
    expect(find.byType(AnimationLabScreen), findsOneWidget);
    expect(
      tester
          .widget<ChessBoard>(find.byType(ChessBoard))
          .appearance!
          .standardPieces,
      isTrue,
    );
    expect(wallet.credits, 300);
    expect(wallet.lastChange?.reason, isNot('conquest_immediate_retry'));
  });

  testWidgets(
    'conquests list is separate and army theme and level reach the game',
    (tester) async {
      final computer = TournamentComputer();
      AnimationLabScreen.debugClockFactory = () =>
          tester.binding.clock.stopwatch();
      addTearDown(() => AnimationLabScreen.debugClockFactory = null);
      await tester.pumpWidget(
        MaterialApp(
          home: TournamentsScreen(
            pack: piecePacks.first,
            conquests: true,
            initialClassicPieces: false,
            initialAnimatedArena: true,
            computerFactory: () => computer,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Conquests'), findsOneWidget);
      expect(find.text('Indo-Arabian Conquest'), findsOneWidget);
      expect(find.text('Rising Knights Cup'), findsNothing);
      final cup = builtInConquests.first;
      final entry = find.byKey(ValueKey('open-tournament-${cup.id}'));
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('conquest-roadmap')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('tournament-colour-toss')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('conquest-roadmap-stop-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('conquest-roadmap-stop-2')),
        findsOneWidget,
      );
      final proceed = find.byKey(const ValueKey('conquest-proceed-button'));
      expect(find.text('Proceed to next match'), findsOneWidget);
      await tester.tap(proceed);
      await chooseGamePieces(tester, classic: false);
      await tester.pumpAndSettle();
      final screen = tester.widget<AnimationLabScreen>(
        find.byType(AnimationLabScreen),
      );
      expect(screen.pack.id, PiecePackId.chola);
      expect(screen.savedGame!.classicPieces, isFalse);
      expect(screen.tournamentMatch!.opponent.botLevel, 6);
      final board = tester.widget<ChessBoard>(find.byType(ChessBoard));
      expect(board.appearance!.white.id, PiecePackId.anime);
      expect(board.appearance!.black.id, PiecePackId.chola);
      expect(board.appearance!.board.id, PiecePackId.chola);

      await tester.drag(find.byType(ChessBoard), const Offset(-90, 0));
      await tester.pumpAndSettle();
      var changedBoard = tester.widget<ChessBoard>(find.byType(ChessBoard));
      expect(changedBoard.appearance!.white.id, PiecePackId.anime);
      expect(changedBoard.appearance!.standardPieces, isTrue);
      expect(changedBoard.appearance!.black.id, PiecePackId.chola);
      expect(changedBoard.appearance!.board.id, PiecePackId.chola);

      await tester.tap(find.byKey(const ValueKey('quick-piece-style-toggle')));
      await tester.pumpAndSettle();
      changedBoard = tester.widget<ChessBoard>(find.byType(ChessBoard));
      expect(changedBoard.appearance!.standardPieces, isFalse);
      await tester.tap(find.byKey(const ValueKey('quick-piece-style-toggle')));
      await tester.pumpAndSettle();
      changedBoard = tester.widget<ChessBoard>(find.byType(ChessBoard));
      expect(changedBoard.appearance!.standardPieces, isTrue);
      expect(changedBoard.appearance!.white.id, PiecePackId.anime);
      expect(changedBoard.appearance!.black.id, PiecePackId.chola);
      await tester.tap(find.byKey(const ValueKey('square-e2')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('square-e4')));
      await tester.pumpAndSettle();
      expect(computer.requestedBotLevel, isNull);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(computer.requestedBotLevel, 6);
      final returnToMap = find.byKey(const ValueKey('return-to-tournament'));
      final portraitScroll = find.byKey(
        const ValueKey('portrait-match-scroll'),
      );
      final gameScroll = portraitScroll.evaluate().isNotEmpty
          ? portraitScroll
          : find.byKey(const ValueKey('landscape-match-scroll'));
      for (
        var attempt = 0;
        attempt < 8 && returnToMap.evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(gameScroll, const Offset(0, -280));
        await tester.pumpAndSettle();
      }
      expect(find.text('Save & return to conquest'), findsNothing);
      expect(find.text('Return to conquest'), findsOneWidget);
      tester.widget<TextButton>(returnToMap).onPressed!();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('conquest-roadmap')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('conquest-proceed-button')),
        findsOneWidget,
      );
      expect(find.text('Resume current match'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
