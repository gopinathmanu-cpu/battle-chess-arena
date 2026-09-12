// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

enum OnlinePlayerLevel { beginner, intermediate, advanced }

extension OnlinePlayerLevelDetails on OnlinePlayerLevel {
  String get label => switch (this) {
    OnlinePlayerLevel.beginner => 'Beginner',
    OnlinePlayerLevel.intermediate => 'Intermediate',
    OnlinePlayerLevel.advanced => 'Advanced',
  };

  String get description => switch (this) {
    OnlinePlayerLevel.beginner => 'Learning the game',
    OnlinePlayerLevel.intermediate => 'Comfortable with tactics',
    OnlinePlayerLevel.advanced => 'Experienced competitive player',
  };
}

OnlinePlayerLevel onlinePlayerLevel(String? value) =>
    OnlinePlayerLevel.values
        .where((level) => level.name == value)
        .firstOrNull ??
    OnlinePlayerLevel.intermediate;

class OnlinePlayerProfile {
  const OnlinePlayerProfile({
    required this.name,
    required this.avatarId,
    this.level = OnlinePlayerLevel.intermediate,
    this.playerToken,
  });

  final String name;
  final String avatarId;
  final OnlinePlayerLevel level;
  final String? playerToken;

  OnlinePlayerProfile copyWith({String? playerToken}) => OnlinePlayerProfile(
    name: name,
    avatarId: avatarId,
    level: level,
    playerToken: playerToken ?? this.playerToken,
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'avatarId': avatarId,
    'level': level.name,
    'playerToken': playerToken,
  };

  factory OnlinePlayerProfile.fromJson(Map<String, dynamic> json) =>
      OnlinePlayerProfile(
        name: json['name'] as String,
        avatarId: json['avatarId'] as String,
        level: onlinePlayerLevel(json['level'] as String?),
        playerToken: json['playerToken'] as String?,
      );
}

class OnlineAvatarChoice {
  const OnlineAvatarChoice(this.id, this.label, this.icon);
  final String id;
  final String label;
  final IconData icon;
}

const onlineAvatarChoices = <OnlineAvatarChoice>[
  OnlineAvatarChoice('crown', 'Crown', Icons.workspace_premium),
  OnlineAvatarChoice('knight', 'Knight', Icons.shield),
  OnlineAvatarChoice('mage', 'Mage', Icons.auto_awesome),
  OnlineAvatarChoice('dragon', 'Dragon', Icons.local_fire_department),
  OnlineAvatarChoice('robot', 'Robot', Icons.smart_toy),
  OnlineAvatarChoice('ranger', 'Ranger', Icons.my_location),
  OnlineAvatarChoice('sun', 'Sun Guard', Icons.wb_sunny),
  OnlineAvatarChoice('moon', 'Moon Guard', Icons.dark_mode),
];

OnlineAvatarChoice onlineAvatar(String id) => onlineAvatarChoices.firstWhere(
  (choice) => choice.id == id,
  orElse: () => onlineAvatarChoices.first,
);

class OnlineLeaderboardEntry {
  const OnlineLeaderboardEntry({
    required this.name,
    required this.avatarId,
    this.level = OnlinePlayerLevel.intermediate,
    required this.points,
    required this.wins,
    required this.draws,
    required this.losses,
  });

  factory OnlineLeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      OnlineLeaderboardEntry(
        name: json['name'] as String,
        avatarId: json['avatarId'] as String,
        level: onlinePlayerLevel(json['level'] as String?),
        points: json['points'] as int,
        wins: json['wins'] as int,
        draws: json['draws'] as int,
        losses: json['losses'] as int,
      );

  final String name;
  final String avatarId;
  final OnlinePlayerLevel level;
  final int points;
  final int wins;
  final int draws;
  final int losses;
}

class OnlinePlayerSearchResult {
  const OnlinePlayerSearchResult({
    required this.name,
    required this.avatarId,
    required this.online,
    this.level = OnlinePlayerLevel.intermediate,
  });

  factory OnlinePlayerSearchResult.fromJson(Map<String, dynamic> json) =>
      OnlinePlayerSearchResult(
        name: json['name'] as String,
        avatarId: json['avatarId'] as String,
        online: json['online'] as bool,
        level: onlinePlayerLevel(json['level'] as String?),
      );

  final String name;
  final String avatarId;
  final bool online;
  final OnlinePlayerLevel level;
}

class OnlinePointRecord {
  const OnlinePointRecord({
    required this.recordId,
    required this.gameId,
    required this.opponentName,
    required this.opponentAvatarId,
    required this.result,
    required this.points,
    required this.completedAt,
  });

  factory OnlinePointRecord.fromJson(Map<String, dynamic> json) =>
      OnlinePointRecord(
        recordId:
            json['recordId'] as String? ??
            '${json['gameId']}-${json['completedAt']}',
        gameId: json['gameId'] as String,
        opponentName: json['opponentName'] as String,
        opponentAvatarId: json['opponentAvatarId'] as String,
        result: json['result'] as String,
        points: json['points'] as int,
        completedAt: DateTime.fromMillisecondsSinceEpoch(
          json['completedAt'] as int,
        ),
      );

  final String gameId;
  final String recordId;
  final String opponentName;
  final String opponentAvatarId;
  final String result;
  final int points;
  final DateTime completedAt;
}
