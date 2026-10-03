// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/bot_tournament.dart';
import '../domain/adaptive_difficulty.dart';
import '../domain/game_session.dart';
import 'last_game_storage.dart';

class TournamentProgress {
  const TournamentProgress(this.run, {this.game});
  final TournamentRun run;
  final SavedGame? game;
}

/// Derived from persisted round wins, never from visits to a result screen.
/// Existing version-1 saves automatically receive credit for earlier wins.
class TournamentPlayerScore {
  const TournamentPlayerScore({
    this.points = 0,
    this.wins = 0,
    this.trophies = 0,
  });
  final int points;
  final int wins;
  final int trophies;

  factory TournamentPlayerScore.fromRuns(
    Map<BotTournament, TournamentRun> runs,
  ) {
    var points = 0;
    var wins = 0;
    var trophies = 0;
    for (final entry in runs.entries) {
      points += entry.value.pointsEarned(entry.key);
      wins += entry.value.wonRounds;
      if (entry.value.completed) trophies++;
    }
    return TournamentPlayerScore(
      points: points,
      wins: wins,
      trophies: trophies,
    );
  }
}

/// One independent save per event; never writes the regular game's save slot.
/// Serializes updates and ignores callbacks from finished or superseded attempts.
class TournamentStorage {
  static Future<void>? _tail;
  static const _conquestKey = 'conquest_player_v1';
  Future<Map<String, dynamic>> _conquestState() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_conquestKey);
    return value == null
        ? <String, dynamic>{}
        : (jsonDecode(value) as Map).cast<String, dynamic>();
  }

  AdaptiveDifficulty _rating(Map<String, dynamic> state) =>
      state['player'] == null
      ? const AdaptiveDifficulty()
      : AdaptiveDifficulty.fromJson(
          (state['player'] as Map).cast<String, dynamic>(),
        );
  Future<AdaptiveDifficulty> loadAdaptivePlayer() =>
      _serial(() async => _rating(await _conquestState()));
  String _key(BotTournament tournament) => 'bot_tournament_${tournament.id}';

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _tail == null
        ? Future<T>.sync(operation)
        : _tail!.then((_) => operation());
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    _tail = tail;
    tail.then((_) {
      if (identical(_tail, tail)) _tail = null;
    });
    return result;
  }

  Future<TournamentProgress?> load(BotTournament tournament) =>
      _serial(() => _read(tournament));

  Future<TournamentPlayerScore> loadPlayerScore() => _serial(() async {
    final runs = <BotTournament, TournamentRun>{};
    for (final cup in builtInTournaments) {
      final progress = await _read(cup);
      if (progress != null) runs[cup] = progress.run;
    }
    return TournamentPlayerScore.fromRuns(runs);
  });

  Future<TournamentProgress?> _read(BotTournament tournament) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = tournament.isConquest
        ? (await _conquestState())[tournament.id] as String?
        : prefs.getString(_key(tournament));
    if (encoded == null) return null;
    final json = jsonDecode(encoded) as Map<String, dynamic>;
    if (json['version'] != 1) {
      throw const FormatException('Unsupported tournament save');
    }
    final run = TournamentRun.fromJson(
      json['run'] as Map<String, dynamic>,
      tournament,
    );
    final game = json['game'] == null
        ? null
        : SavedGame.fromJson((json['game'] as Map).cast<String, Object?>());
    if (game != null) {
      final session = GameSession.fromMoves(
        mode: game.mode,
        humanSide: game.humanSide,
        moves: game.moves,
      );
      if (!run.playing ||
          game.mode != PlayerMode.computer ||
          session.position.isGameOver ||
          session.isRuleDraw ||
          game.whiteMilliseconds <= 0 ||
          game.blackMilliseconds <= 0 ||
          game.lifelinesRemaining < 0 ||
          game.lifelinesRemaining > 3 ||
          game.difficulty !=
              tournamentDifficulty(run.currentOpponent(tournament).level)) {
        throw const FormatException('Invalid saved tournament game');
      }
    }
    return TournamentProgress(run, game: game);
  }

  Future<void> _write(
    BotTournament tournament,
    TournamentProgress progress, {
    AdaptiveDifficulty? player,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode({
      'version': 1,
      'run': progress.run.toJson(),
      'game': progress.game?.toJson(),
    });
    final state = tournament.isConquest ? await _conquestState() : null;
    if (state != null) {
      state[tournament.id] = encoded;
      if (player != null) state['player'] = player.toJson();
    }
    // Result and player update share one persisted value: retries cannot apply
    // the adjustment twice, even after a restart or a failed write.
    final saved = await prefs.setString(
      state == null ? _key(tournament) : _conquestKey,
      state == null ? encoded : jsonEncode(state),
    );
    if (!saved) throw StateError('Unable to save tournament progress');
  }

  Future<TournamentProgress> enter(BotTournament tournament) =>
      _serial(() async {
        final existing = await _read(tournament);
        if (existing != null) return existing;
        final progress = TournamentProgress(TournamentRun.start(tournament));
        await _write(tournament, progress);
        return progress;
      });

  Future<TournamentProgress> beginAttempt(BotTournament tournament) =>
      _serial(() async {
        final current = await _read(tournament);
        if (current == null || current.run.completed) {
          throw StateError('No playable tournament');
        }
        final progress = TournamentProgress(
          current.run.beginAttempt(
            adaptiveLevel: tournament.isConquest
                ? current.run.nextConquestLevel(_rating(await _conquestState()))
                : null,
          ),
          game: current.game,
        );
        await _write(tournament, progress);
        return progress;
      });

  Future<void> saveMatch(
    BotTournament tournament, {
    required String runId,
    required int attempt,
    required SavedGame game,
    TournamentRoundResult? result,
  }) => _serial(() async {
    final current = await _read(tournament);
    if (current == null ||
        current.run.runId != runId ||
        current.run.attempt != attempt ||
        !current.run.playing) {
      return;
    }
    await _write(
      tournament,
      result == null
          ? TournamentProgress(current.run, game: game)
          : TournamentProgress(current.run.finish(result)),
      player: tournament.isConquest && result != null
          ? _rating(await _conquestState()).record(switch (result) {
              TournamentRoundResult.win => 1,
              TournamentRoundResult.loss => 0,
              TournamentRoundResult.draw => .5,
            })
          : null,
    );
  });
}
