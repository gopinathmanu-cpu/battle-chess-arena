import 'dart:convert';

import 'package:battle_chess_arena/src/domain/bot_tournament.dart';
import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/domain/online_player_profile.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/services/last_game_storage.dart';
import 'package:battle_chess_arena/src/services/tournament_storage.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

SavedGame tournamentSave(
  BotTournament cup, {
  List<String> moves = const ['e2e4', 'e7e5'],
}) => SavedGame(
  mode: PlayerMode.computer,
  homePack: PiecePackId.anime,
  difficulty: tournamentDifficulty(cup.level),
  moves: moves,
  whiteMilliseconds: 570000,
  blackMilliseconds: 580000,
  fastBattles: true,
  whitePack: PiecePackId.anime,
  blackPack: PiecePackId.greek,
  boardPack: PiecePackId.anime,
  updatedAtEpochMs: 1,
  lifelinesRemaining: 2,
);

void main() {
  test('tournament retry cooldown persists and expires predictably', () {
    final cup = builtInTournaments.first;
    final finishedAt = DateTime.utc(2026, 9, 26, 12);
    final run = TournamentRun.start(cup, seed: 42).beginAttempt().finish(
      TournamentRoundResult.loss,
      completedAt: finishedAt,
    );

    expect(run.retryWaitAt(finishedAt), tournamentRetryCooldown);
    expect(
      run.retryWaitAt(finishedAt.add(const Duration(minutes: 14))),
      const Duration(minutes: 1),
    );
    expect(
      run.retryWaitAt(finishedAt.add(tournamentRetryCooldown)),
      Duration.zero,
    );

    final restored = TournamentRun.fromJson(run.toJson(), cup);
    expect(restored.lastResultAt, finishedAt);
    expect(restored.freeRetryAt, finishedAt.add(tournamentRetryCooldown));
  });

  test('personas have unique fixed levels within their proficiency tier', () {
    expect(
      builtInComputerOpponents.map((bot) => bot.botLevel),
      List.generate(20, (i) => i + 1),
    );
    for (final bot in builtInComputerOpponents) {
      expect(
        bot.level,
        bot.botLevel <= 7
            ? OnlinePlayerLevel.beginner
            : bot.botLevel <= 14
            ? OnlinePlayerLevel.intermediate
            : OnlinePlayerLevel.advanced,
      );
    }
  });
  test(
    'each bot enters exactly one proficiency cup and brackets have valid byes',
    () {
      final roster = <String>[];
      for (final cup in builtInTournaments) {
        expect(cup.opponents.every((bot) => bot.level == cup.level), isTrue);
        roster.addAll(cup.opponents.map((bot) => bot.id));
        for (var seed = 0; seed < 30; seed++) {
          final run = TournamentRun.start(cup, seed: seed);
          final first = run.bracket(cup).first;
          final entrants = first
              .expand((pair) => [pair.first, pair.second])
              .whereType<String>()
              .toList();
          expect(entrants.toSet().length, cup.opponents.length + 1);
          expect(entrants.length, entrants.toSet().length);
          expect(
            first
                .where((pair) => pair.first == null || pair.second == null)
                .length,
            cup.bracketSize - cup.opponents.length - 1,
          );
          expect(
            first.every((pair) => pair.first != null || pair.second != null),
            isTrue,
          );
          expect(run.currentOpponent(cup).level, cup.level);
        }
      }
      expect(
        roster.toSet(),
        builtInComputerOpponents.map((bot) => bot.id).toSet(),
      );
      expect(roster.length, 20);
    },
  );

  test(
    'losses, draws, and restored runs keep opponents; wins advance exactly once to champion',
    () {
      for (final cup in builtInTournaments) {
        var run = TournamentRun.start(cup, seed: 42);
        final played = <String>{};
        for (var round = 0; round < cup.roundCount; round++) {
          final opponent = run.currentOpponent(cup).id;
          expect(played.add(opponent), isTrue);
          for (final result in [
            TournamentRoundResult.loss,
            TournamentRoundResult.draw,
          ]) {
            run = run.beginAttempt().finish(result);
            run = TournamentRun.fromJson(
              jsonDecode(jsonEncode(run.toJson())),
              cup,
            );
            expect(run.wonRounds, round);
            expect(run.currentOpponent(cup).id, opponent);
            expect(run.playing, isFalse);
          }
          run = run.beginAttempt().finish(TournamentRoundResult.win);
          expect(run.wonRounds, round + 1);
          expect(run.finish(TournamentRoundResult.win).wonRounds, round + 1);
          final bracket = run.bracket(cup);
          for (var i = 1; i <= round && i < bracket.length; i++) {
            expect(
              bracket[i].expand((pair) => [pair.first, pair.second]).toList(),
              bracket[i - 1].map((pair) => pair.winner).toList(),
            );
          }
        }
        expect(run.completed, isTrue);
        expect(run.bracket(cup).last.single.winner, tournamentHumanId);
        expect(run.beginAttempt(), same(run));
      }
    },
  );

  test('invalid saved progress cannot skip rounds', () {
    final cup = builtInTournaments.first;
    final json = TournamentRun.start(cup).toJson();
    json['results'] = [
      <String>[],
      ['win'],
      <String>[],
    ];
    json['attempt'] = 1;
    expect(() => TournamentRun.fromJson(json, cup), throwsFormatException);
  });

  test(
    'repetition and fifty-move rule are recognized for tournament draws',
    () {
      final game = GameSession.fromMoves(
        moves: ['g1f3', 'g8f6', 'f3g1', 'f6g8', 'g1f3', 'g8f6', 'f3g1', 'f6g8'],
      );
      expect(game.isRuleDraw, isTrue);
      game.undo();
      expect(game.isRuleDraw, isFalse);
      final fifty = GameSession(
        position: Chess.fromSetup(
          Setup.parseFen('7k/8/8/8/8/8/8/R3K3 w Q - 100 70'),
        ),
      );
      expect(fifty.isRuleDraw, isTrue);
    },
  );

  group('tournament persistence', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LastGameStorage.clear();
    });

    test(
      'wins award proficiency points once, across retries and reloads',
      () async {
        final storage = TournamentStorage();
        expect((await storage.loadPlayerScore()).points, 0);
        expect(builtInTournaments.map((cup) => cup.pointsPerWin), [
          100,
          200,
          300,
        ]);
        var expectedPoints = 0;
        var expectedWins = 0;
        for (final cup in builtInTournaments) {
          await storage.enter(cup);
          for (var round = 0; round < cup.roundCount; round++) {
            for (final result in [
              TournamentRoundResult.loss,
              TournamentRoundResult.draw,
              TournamentRoundResult.win,
            ]) {
              final attempt = (await storage.beginAttempt(cup)).run;
              Future<void> save(TournamentRoundResult? result) =>
                  storage.saveMatch(
                    cup,
                    runId: attempt.runId,
                    attempt: attempt.attempt,
                    game: tournamentSave(cup),
                    result: result,
                  );
              // Terminal callbacks may be delivered multiple times, including a
              // late board save and a conflicting outcome. Only the first counts.
              await Future.wait([
                save(result),
                save(result),
                save(null),
                save(TournamentRoundResult.win),
              ]);
              if (result == TournamentRoundResult.win) {
                expectedPoints += cup.pointsPerWin;
                expectedWins++;
              }
              final score = await TournamentStorage().loadPlayerScore();
              expect(score.points, expectedPoints);
              expect(score.wins, expectedWins);
              if (result != TournamentRoundResult.win) {
                final retry = (await storage.beginAttempt(cup)).run;
                await save(
                  TournamentRoundResult.win,
                ); // Old attempt after retry.
                expect(
                  (await storage.loadPlayerScore()).points,
                  expectedPoints,
                );
                expect((await storage.load(cup))!.run.attempt, retry.attempt);
              }
            }
          }
        }
        final score = await TournamentStorage().loadPlayerScore();
        expect(score.points, 1800);
        expect(score.wins, 9);
        expect(score.trophies, 3);
      },
    );

    test(
      'version-1 victories receive points without rewriting the save',
      () async {
        final cup = builtInTournaments.first;
        final run = TournamentRun.start(
          cup,
        ).beginAttempt().finish(TournamentRoundResult.win);
        final encoded = jsonEncode({
          'version': 1,
          'run': run.toJson(),
          'game': null,
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('bot_tournament_${cup.id}', encoded);
        final score = await TournamentStorage().loadPlayerScore();
        expect(score.points, 100);
        expect(score.wins, 1);
        expect(score.trophies, 0);
        expect(prefs.getString('bot_tournament_${cup.id}'), encoded);
        await prefs.setString('bot_tournament_${cup.id}', 'invalid');
        await expectLater(
          TournamentStorage().loadPlayerScore(),
          throwsFormatException,
        );
      },
    );

    test(
      'resumes clocks and moves, keeps regular games, and ignores late callbacks',
      () async {
        final cup = builtInTournaments.first;
        final storage = TournamentStorage();
        await LastGameStorage.save(tournamentSave(cup));
        final regular = await LastGameStorage.load();
        await storage.enter(cup);
        final attempt = await storage.beginAttempt(cup);
        final game = tournamentSave(cup);
        Future<void> update({TournamentRoundResult? result}) =>
            storage.saveMatch(
              cup,
              runId: attempt.run.runId,
              attempt: attempt.run.attempt,
              game: game,
              result: result,
            );
        await update();
        final restored = (await TournamentStorage().load(cup))!;
        expect(restored.game!.moves, game.moves);
        expect(restored.game!.whiteMilliseconds, 570000);
        expect(restored.game!.lifelinesRemaining, 2);
        expect(
          (await storage.beginAttempt(cup)).run.attempt,
          attempt.run.attempt,
        );
        // A delayed save arriving after the terminal update must not resurrect it.
        await Future.wait([
          update(result: TournamentRoundResult.loss),
          update(),
        ]);
        final lost = (await storage.load(cup))!;
        expect(lost.game, isNull);
        expect(lost.run.lastResult, TournamentRoundResult.loss);
        final retry = await storage.beginAttempt(cup);
        await update(result: TournamentRoundResult.win);
        final afterStale = (await storage.load(cup))!;
        expect(afterStale.run.wonRounds, 0);
        expect(afterStale.run.attempt, retry.run.attempt);
        expect(
          afterStale.run.currentOpponent(cup).id,
          attempt.run.currentOpponent(cup).id,
        );
        expect((await LastGameStorage.load())!.toJson(), regular!.toJson());
      },
    );

    test(
      'empty opening positions and each cup survive independent reloads',
      () async {
        final storage = TournamentStorage();
        for (final cup in builtInTournaments) {
          await storage.enter(cup);
          final progress = await storage.beginAttempt(cup);
          await storage.saveMatch(
            cup,
            runId: progress.run.runId,
            attempt: progress.run.attempt,
            game: tournamentSave(cup, moves: []),
          );
        }
        for (final cup in builtInTournaments) {
          final restored = (await TournamentStorage().load(cup))!;
          expect(restored.run.playing, isTrue);
          expect(restored.game!.moves, isEmpty);
          expect(restored.run.currentOpponent(cup).level, cup.level);
        }
        expect(await LastGameStorage.load(), isNull);
      },
    );
  });
}
