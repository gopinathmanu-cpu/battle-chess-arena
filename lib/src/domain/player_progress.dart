// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:math' as math;

class ArenaBadge {
  const ArenaBadge({
    required this.name,
    required this.minimumPoints,
    required this.icon,
    required this.creditReward,
  });

  final String name;
  final int minimumPoints;
  final String icon;
  final int creditReward;
}

const arenaBadges = <ArenaBadge>[
  ArenaBadge(
    name: 'Arena Rookie',
    minimumPoints: 0,
    icon: '♙',
    creditReward: 0,
  ),
  ArenaBadge(
    name: 'Bronze Knight',
    minimumPoints: 250,
    icon: '♘',
    creditReward: 25,
  ),
  ArenaBadge(
    name: 'Silver Strategist',
    minimumPoints: 750,
    icon: '♗',
    creditReward: 50,
  ),
  ArenaBadge(
    name: 'Gold Tactician',
    minimumPoints: 1500,
    icon: '♖',
    creditReward: 75,
  ),
  ArenaBadge(
    name: 'Platinum Commander',
    minimumPoints: 3000,
    icon: '♕',
    creditReward: 100,
  ),
  ArenaBadge(
    name: 'Diamond Champion',
    minimumPoints: 6000,
    icon: '♔',
    creditReward: 150,
  ),
  ArenaBadge(
    name: 'Arena Grandmaster',
    minimumPoints: 10000,
    icon: '★',
    creditReward: 250,
  ),
];

ArenaBadge badgeForPoints(int points) => arenaBadges.lastWhere(
  (badge) => points >= badge.minimumPoints,
  orElse: () => arenaBadges.first,
);

int experienceForCompletedGame(int moveCount) =>
    10 + math.min(math.max(moveCount, 0), 100);

class PlayerProgress {
  const PlayerProgress({
    this.experience = 0,
    this.trophies = 0,
    this.completedGames = 0,
    this.wins = 0,
    this.awardedCompletionIds = const <String>[],
  });

  final int experience;
  final int trophies;
  final int completedGames;
  final int wins;
  final List<String> awardedCompletionIds;

  int get overallPoints => experience + trophies * 100;
  ArenaBadge get badge => badgeForPoints(overallPoints);

  ArenaBadge? get nextBadge {
    final index = arenaBadges.indexOf(badge);
    return index == arenaBadges.length - 1 ? null : arenaBadges[index + 1];
  }

  double get badgeProgress {
    final next = nextBadge;
    if (next == null) return 1;
    final span = next.minimumPoints - badge.minimumPoints;
    return ((overallPoints - badge.minimumPoints) / span).clamp(0, 1);
  }

  Map<String, Object> toJson() => {
    'version': 1,
    'experience': experience,
    'trophies': trophies,
    'completedGames': completedGames,
    'wins': wins,
    'awardedCompletionIds': awardedCompletionIds,
  };

  factory PlayerProgress.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unknown player progress version');
    }
    return PlayerProgress(
      experience: (json['experience'] as int?) ?? 0,
      trophies: (json['trophies'] as int?) ?? 0,
      completedGames: (json['completedGames'] as int?) ?? 0,
      wins: (json['wins'] as int?) ?? 0,
      awardedCompletionIds: List<String>.unmodifiable(
        (json['awardedCompletionIds'] as List? ?? const []).cast<String>(),
      ),
    );
  }
}

class ProgressAward {
  const ProgressAward({
    required this.experience,
    required this.trophies,
    required this.badge,
    this.unlockedBadge,
    this.badgeCredits = 0,
    this.alreadyAwarded = false,
  });

  final int experience;
  final int trophies;
  final ArenaBadge badge;
  final ArenaBadge? unlockedBadge;
  final int badgeCredits;
  final bool alreadyAwarded;

  ProgressAward withBadgeCredits(int value) => ProgressAward(
    experience: experience,
    trophies: trophies,
    badge: badge,
    unlockedBadge: unlockedBadge,
    badgeCredits: value,
    alreadyAwarded: alreadyAwarded,
  );
}
