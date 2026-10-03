// SPDX-License-Identifier: GPL-3.0-or-later

/// Local practice estimate, not a rated Elo. Shared by both conquest campaigns.
class AdaptiveDifficulty {
  const AdaptiveDifficulty({this.level = 6, this.games = 0});
  final double level;
  final int games;

  int opponentLevel(int round) => (level + round * .35).round().clamp(1, 20);

  AdaptiveDifficulty record(double score) => AdaptiveDifficulty(
    level: (level + (score - .5) * 2).clamp(1, 20),
    games: games + 1,
  );

  Map<String, Object> toJson() => {'level': level, 'games': games};
  factory AdaptiveDifficulty.fromJson(Map<String, dynamic> json) {
    final level = (json['level'] as num).toDouble();
    final games = json['games'] as int;
    if (!level.isFinite || level < 1 || level > 20 || games < 0) {
      throw const FormatException('Invalid adaptive player level');
    }
    return AdaptiveDifficulty(level: level, games: games);
  }
}
