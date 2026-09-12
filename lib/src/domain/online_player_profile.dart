// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

class OnlinePlayerProfile {
  const OnlinePlayerProfile({
    required this.name,
    required this.avatarId,
    this.playerToken,
  });

  final String name;
  final String avatarId;
  final String? playerToken;

  OnlinePlayerProfile copyWith({String? playerToken}) => OnlinePlayerProfile(
    name: name,
    avatarId: avatarId,
    playerToken: playerToken ?? this.playerToken,
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'avatarId': avatarId,
    'playerToken': playerToken,
  };

  factory OnlinePlayerProfile.fromJson(Map<String, dynamic> json) =>
      OnlinePlayerProfile(
        name: json['name'] as String,
        avatarId: json['avatarId'] as String,
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
    required this.points,
    required this.wins,
    required this.draws,
    required this.losses,
  });

  factory OnlineLeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      OnlineLeaderboardEntry(
        name: json['name'] as String,
        avatarId: json['avatarId'] as String,
        points: json['points'] as int,
        wins: json['wins'] as int,
        draws: json['draws'] as int,
        losses: json['losses'] as int,
      );

  final String name;
  final String avatarId;
  final int points;
  final int wins;
  final int draws;
  final int losses;
}
