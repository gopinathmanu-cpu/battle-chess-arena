// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';
import 'adaptive_difficulty.dart';

import '../services/computer_player_contract.dart';
import 'online_player_profile.dart';
import 'piece_pack.dart';

enum ConquestSize { small, medium, large, full }

extension ConquestSizeDetails on ConquestSize {
  String get label => switch (this) {
    ConquestSize.small => 'Small',
    ConquestSize.medium => 'Medium',
    ConquestSize.large => 'Large',
    ConquestSize.full => 'Full',
  };
}

enum TournamentRoundResult { win, loss, draw }

/// Legacy timing retained for saved-game compatibility. Immediate Tournament
/// and Conquest retries are free and no longer use this cooldown.
const tournamentRetryCooldown = Duration(minutes: 15);

/// Approximate smallest-to-largest order of peak forces that each historical
/// theme could mobilize. Surviving figures mix field armies and empire-wide
/// establishments and are often disputed, so conquest progression uses a
/// stable relative rank rather than presenting questionable exact headcounts.
const historicalConquestArmyOrder = <PiecePackId>[
  PiecePackId.sparta,
  PiecePackId.mewar,
  PiecePackId.zulu,
  PiecePackId.english,
  PiecePackId.egyptian,
  PiecePackId.french,
  PiecePackId.macedonian,
  PiecePackId.chola,
  PiecePackId.persian,
  PiecePackId.maratha,
  PiecePackId.japanese,
  PiecePackId.aztec,
  PiecePackId.mongolian,
  PiecePackId.arab,
  PiecePackId.achaemenid,
  PiecePackId.inca,
  PiecePackId.ottoman,
  PiecePackId.roman,
  PiecePackId.chinese,
];

int historicalConquestArmySizeRank(PiecePackId id) =>
    historicalConquestArmyOrder.indexOf(id);

/// Stable, declarative catalog entries; themed cups can supply their own roster
/// and board pack without changing bracket, persistence, or match screens.
class BotTournament {
  const BotTournament({
    required this.id,
    required this.title,
    required this.description,
    required this.level,
    this.opponentIds,
    this.theme,
    this.conquestGroup,
    this.conquestArmyIds,
    this.conquestSize,
    this.minutesPerSide = 15,
    this.pointsPerWin = 100,
  }) : assert(pointsPerWin > 0);

  final String id;
  final String title;
  final String description;
  final OnlinePlayerLevel level;
  final List<String>? opponentIds;
  final PiecePackId? theme;
  final PiecePackGroup? conquestGroup;
  final List<PiecePackId>? conquestArmyIds;
  final ConquestSize? conquestSize;
  bool get isConquest => conquestGroup != null || conquestArmyIds != null;
  List<PiecePack> get armies {
    final ids = conquestArmyIds;
    final selected = ids != null
        ? ids
              .map((id) => piecePacks.singleWhere((pack) => pack.id == id))
              .toList()
        : piecePacks.where((pack) => pack.group == conquestGroup).toList();
    if (!isConquest || conquestGroup != PiecePackGroup.historical) {
      return List.unmodifiable(selected);
    }
    selected.sort(
      (left, right) => historicalConquestArmySizeRank(
        left.id,
      ).compareTo(historicalConquestArmySizeRank(right.id)),
    );
    return List.unmodifiable(selected);
  }

  final int minutesPerSide;

  /// Keep rewards stable for a versioned event: saved wins are the score ledger.
  final int pointsPerWin;

  List<BuiltInComputerOpponent> get opponents => List.unmodifiable(
    isConquest
        ? armies.map(
            (pack) => BuiltInComputerOpponent(
              id: 'army-${pack.id.name}',
              name: pack.name,
              avatarId: 'avatar-01',
              level: level,
              botLevel: 6,
            ),
          )
        : builtInComputerOpponents.where(
            (bot) => opponentIds == null
                ? bot.level == level
                : opponentIds!.contains(bot.id),
          ),
  );

  int get bracketSize {
    var size = 2;
    while (size < opponents.length + 1) {
      size *= 2;
    }
    return size;
  }

  int get roundCount => isConquest ? armies.length : bracketSize.bitLength - 1;
  String roundName(int index) => isConquest
      ? 'Quest ${index + 1}: ${armies[index].name}'
      : switch (roundCount - index) {
          1 => 'Final',
          2 => 'Semifinal',
          3 => 'Quarterfinal',
          final remaining => 'Round of ${1 << remaining}',
        };
}

const builtInTournaments = [
  BotTournament(
    id: 'beginner-cup-v1',
    title: 'Rising Knights Cup',
    description:
        'Build confidence, win three rounds, and claim your first cup.',
    level: OnlinePlayerLevel.beginner,
  ),
  BotTournament(
    id: 'intermediate-cup-v1',
    title: 'Tactician Cup',
    description:
        'Find the combinations that carry you all the way to the final.',
    level: OnlinePlayerLevel.intermediate,
    pointsPerWin: 200,
  ),
  BotTournament(
    id: 'advanced-cup-v1',
    title: 'Mastery Cup',
    description:
        'Take on the strongest built-in opponents for the championship.',
    level: OnlinePlayerLevel.advanced,
    pointsPerWin: 300,
  ),
];

const builtInConquests = [
  BotTournament(
    id: 'indo-arab-conquest-v1',
    title: 'Indo-Arabian Conquest',
    description:
        'A short three-realm campaign that rises from regional forces to the largest imperial army.',
    level: OnlinePlayerLevel.beginner,
    conquestGroup: PiecePackGroup.historical,
    conquestArmyIds: [PiecePackId.chola, PiecePackId.persian, PiecePackId.arab],
    conquestSize: ConquestSize.small,
    pointsPerWin: 150,
  ),
  BotTournament(
    id: 'european-conquest-v1',
    title: 'European Conquest',
    description:
        'A five-match march from compact warrior forces to Europe’s largest imperial army.',
    level: OnlinePlayerLevel.beginner,
    conquestGroup: PiecePackGroup.historical,
    conquestArmyIds: [
      PiecePackId.sparta,
      PiecePackId.macedonian,
      PiecePackId.roman,
      PiecePackId.french,
      PiecePackId.english,
    ],
    conquestSize: ConquestSize.medium,
    pointsPerWin: 150,
  ),
  BotTournament(
    id: 'asian-conquest-v1',
    title: 'Asian Conquest',
    description:
        'A ten-match expedition ordered from regional armies to Asia’s largest mobilized forces.',
    level: OnlinePlayerLevel.beginner,
    conquestGroup: PiecePackGroup.historical,
    conquestArmyIds: [
      PiecePackId.japanese,
      PiecePackId.chinese,
      PiecePackId.mongolian,
      PiecePackId.achaemenid,
      PiecePackId.persian,
      PiecePackId.ottoman,
      PiecePackId.arab,
      PiecePackId.chola,
      PiecePackId.maratha,
      PiecePackId.mewar,
    ],
    conquestSize: ConquestSize.large,
    pointsPerWin: 150,
  ),
  BotTournament(
    id: 'history-conquest-v1',
    title: 'World Conquest',
    description:
        'The full campaign from the smallest historical forces to the largest imperial armies.',
    level: OnlinePlayerLevel.beginner,
    conquestGroup: PiecePackGroup.historical,
    conquestSize: ConquestSize.full,
    pointsPerWin: 150,
  ),
];

ComputerDifficulty tournamentDifficulty(OnlinePlayerLevel level) =>
    switch (level) {
      OnlinePlayerLevel.beginner => ComputerDifficulty.easy,
      OnlinePlayerLevel.intermediate => ComputerDifficulty.medium,
      OnlinePlayerLevel.advanced => ComputerDifficulty.hard,
    };

const tournamentHumanId = 'human';

class TournamentPairing {
  const TournamentPairing(this.first, this.second, this.winner);
  final String? first;
  final String? second;
  final String? winner;
  bool get involvesHuman =>
      first == tournamentHumanId || second == tournamentHumanId;
  String? get opponentId =>
      involvesHuman ? (first == tournamentHumanId ? second : first) : null;
}

/// A saved seed fixes seeding and simulated bot results across retries/restarts.
/// Losing or drawing never advances the bracket or discards earlier wins.
class TournamentRun {
  TournamentRun({
    required this.runId,
    required this.seed,
    required this.results,
    this.attempt = 0,
    this.playing = false,
    this.adaptiveLevel,
    this.lastResultAt,
  });

  factory TournamentRun.start(BotTournament tournament, {int? seed}) {
    final random = Random.secure();
    return TournamentRun(
      runId:
          '${DateTime.now().microsecondsSinceEpoch}-${random.nextInt(1 << 30)}',
      seed: seed ?? random.nextInt(1 << 30),
      results: List.generate(tournament.roundCount, (_) => []),
    );
  }

  final String runId;
  final int seed;
  final List<List<TournamentRoundResult>> results;
  final int attempt;
  final bool playing;
  final DateTime? lastResultAt;

  /// Strength snapshot: immutable throughout a saved attempt.
  final int? adaptiveLevel;

  int nextConquestLevel(AdaptiveDifficulty player) {
    if (playing && adaptiveLevel != null) return adaptiveLevel!;
    final target = player.opponentLevel(wonRounds);
    final last = results.expand((round) => round).lastOrNull;
    if (adaptiveLevel == null || last == null) return target;
    // Round bonuses must not hide a loss adjustment at the upper boundary.
    return switch (last) {
      TournamentRoundResult.loss => min(
        target,
        adaptiveLevel! - 1,
      ).clamp(1, 20),
      TournamentRoundResult.win => max(target, adaptiveLevel! + 1).clamp(1, 20),
      TournamentRoundResult.draw => adaptiveLevel!,
    };
  }

  int get wonRounds => results
      .where((round) => round.contains(TournamentRoundResult.win))
      .length;
  bool get completed => wonRounds == results.length;
  int pointsEarned(BotTournament tournament) =>
      wonRounds * tournament.pointsPerWin;
  TournamentRoundResult? get lastResult =>
      completed || results[wonRounds].isEmpty ? null : results[wonRounds].last;

  TournamentRun beginAttempt({int? adaptiveLevel}) {
    if (completed || playing) return this;
    return TournamentRun(
      runId: runId,
      seed: seed,
      results: results,
      attempt: attempt + 1,
      playing: true,
      adaptiveLevel: adaptiveLevel ?? this.adaptiveLevel,
      lastResultAt: lastResultAt,
    );
  }

  TournamentRun finish(TournamentRoundResult result, {DateTime? completedAt}) {
    if (!playing || completed) return this;
    final updated = results
        .map((round) => List<TournamentRoundResult>.of(round))
        .toList();
    updated[wonRounds].add(result);
    return TournamentRun(
      runId: runId,
      seed: seed,
      results: updated,
      attempt: attempt,
      adaptiveLevel: adaptiveLevel,
      lastResultAt: result == TournamentRoundResult.win
          ? null
          : (completedAt ?? DateTime.now()).toUtc(),
    );
  }

  DateTime? get freeRetryAt => lastResult == null || lastResultAt == null
      ? null
      : lastResultAt!.add(tournamentRetryCooldown);

  Duration retryWaitAt(DateTime now) {
    final available = freeRetryAt;
    if (available == null) return Duration.zero;
    final remaining = available.difference(now.toUtc());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  List<List<TournamentPairing>> bracket(BotTournament tournament) {
    if (tournament.isConquest) {
      return List.generate(
        tournament.roundCount,
        (round) => [
          TournamentPairing(
            tournamentHumanId,
            tournament.opponents[round].id,
            round < wonRounds ? tournamentHumanId : null,
          ),
        ],
      );
    }
    final random = Random(seed);
    final bots = tournament.opponents.map((bot) => bot.id).toList()
      ..shuffle(random);
    // Always give the human a real opening opponent. Distribute remaining byes
    // across bot pairings, never pairing two empty seats.
    var entrants = <String?>[tournamentHumanId, bots.removeLast()];
    final byes = tournament.bracketSize - tournament.opponents.length - 1;
    for (var i = 0; i < byes; i++) {
      entrants.addAll([bots.removeLast(), null]);
    }
    entrants.addAll(bots);
    final rounds = <List<TournamentPairing>>[];
    for (var round = 0; round < tournament.roundCount; round++) {
      final pairings = <TournamentPairing>[];
      final next = <String?>[];
      for (var i = 0; i < entrants.length; i += 2) {
        final first = entrants[i];
        final second = entrants[i + 1];
        final human = first == tournamentHumanId || second == tournamentHumanId;
        final botWinner = first == null
            ? second
            : second == null
            ? first
            : (random.nextBool() ? first : second);
        final winner = round > wonRounds
            ? null
            : human
            ? (round < wonRounds ? tournamentHumanId : null)
            : botWinner;
        pairings.add(TournamentPairing(first, second, winner));
        next.add(winner);
      }
      rounds.add(pairings);
      entrants = next;
    }
    return rounds;
  }

  BuiltInComputerOpponent currentOpponent(BotTournament tournament) {
    if (completed) throw StateError('Tournament is complete');
    if (tournament.isConquest) {
      final bot = tournament.opponents[wonRounds];
      final strength = adaptiveLevel ?? 6;
      return BuiltInComputerOpponent(
        id: bot.id,
        name: bot.name,
        avatarId: bot.avatarId,
        botLevel: strength,
        level: strength <= 7
            ? OnlinePlayerLevel.beginner
            : strength <= 14
            ? OnlinePlayerLevel.intermediate
            : OnlinePlayerLevel.advanced,
      );
    }
    final id = bracket(
      tournament,
    )[wonRounds].singleWhere((pair) => pair.involvesHuman).opponentId;
    return tournament.opponents.singleWhere((bot) => bot.id == id);
  }

  Map<String, Object> toJson() => {
    'runId': runId,
    'seed': seed,
    'attempt': attempt,
    'playing': playing,
    if (adaptiveLevel != null) 'adaptiveLevel': adaptiveLevel!,
    if (lastResultAt != null)
      'lastResultAtEpochMs': lastResultAt!.millisecondsSinceEpoch,
    'results': results
        .map((round) => round.map((result) => result.name).toList())
        .toList(),
  };

  factory TournamentRun.fromJson(
    Map<String, dynamic> json,
    BotTournament tournament,
  ) {
    final run = TournamentRun(
      runId: json['runId'] as String,
      seed: json['seed'] as int,
      attempt: json['attempt'] as int,
      playing: json['playing'] as bool,
      adaptiveLevel: json['adaptiveLevel'] as int?,
      lastResultAt: json['lastResultAtEpochMs'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              json['lastResultAtEpochMs'] as int,
              isUtc: true,
            ),
      results: (json['results'] as List)
          .map(
            (round) => (round as List)
                .map(
                  (result) =>
                      TournamentRoundResult.values.byName(result as String),
                )
                .toList(),
          )
          .toList(),
    );
    if ((tournament.isConquest &&
            run.attempt > 0 &&
            run.adaptiveLevel == null) ||
        (run.adaptiveLevel != null &&
            (run.adaptiveLevel! < 1 || run.adaptiveLevel! > 20)) ||
        run.runId.isEmpty ||
        run.seed < 0 ||
        run.attempt < 0 ||
        run.results.length != tournament.roundCount) {
      throw const FormatException('Invalid tournament progress');
    }
    var unfinished = false;
    for (final round in run.results) {
      if ((unfinished && round.isNotEmpty) ||
          (round.contains(TournamentRoundResult.win) &&
              (round.last != TournamentRoundResult.win ||
                  round.where((r) => r == TournamentRoundResult.win).length !=
                      1))) {
        throw const FormatException('Invalid tournament results');
      }
      if (!round.contains(TournamentRoundResult.win)) unfinished = true;
    }
    final finishedAttempts = run.results.fold<int>(
      0,
      (sum, round) => sum + round.length,
    );
    if (run.attempt != finishedAttempts + (run.playing ? 1 : 0) ||
        (run.completed && run.playing)) {
      throw const FormatException('Invalid tournament attempt');
    }
    return run;
  }
}
