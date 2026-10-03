// SPDX-License-Identifier: GPL-3.0-or-later
enum OnlinePlayerLevel { beginner, intermediate, advanced }

enum AvatarVoice { male, female }

/// Voice used for short character announcements. Unknown and non-human
/// avatars intentionally fall back to male, as documented in the UI behavior.
AvatarVoice avatarVoice(String? avatarId) {
  if (avatarId == null) return AvatarVoice.male;
  const femaleBots = {
    'bot_amina',
    'bot_mei',
    'bot_sofia',
    'bot_ana',
    'bot_priya',
    'bot_nadia',
    'bot_thandi',
    'bot_fatima',
    'bot_elena',
    'bot_emma',
  };
  if (femaleBots.contains(avatarId)) return AvatarVoice.female;
  final match = RegExp(r'^avatar-(\d{2})$').firstMatch(avatarId);
  final number = match == null ? null : int.tryParse(match.group(1)!);
  const femalePortraits = {
    1,
    3,
    5,
    7,
    9,
    12,
    14,
    16,
    18,
    20,
    21,
    24,
    26,
    28,
    30,
    32,
    34,
    35,
    38,
    40,
    41,
    43,
    45,
    47,
    49,
  };
  return femalePortraits.contains(number)
      ? AvatarVoice.female
      : AvatarVoice.male;
}

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
  const OnlineAvatarChoice(this.id, this.label, this.index);
  final String id;
  final String label;
  final int index;
}

final onlineAvatarChoices = List<OnlineAvatarChoice>.unmodifiable(
  List.generate(50, (index) {
    final number = index + 1;
    return OnlineAvatarChoice(
      'avatar-${number.toString().padLeft(2, '0')}',
      'Avatar $number',
      index,
    );
  }),
);

OnlineAvatarChoice onlineAvatar(String id) => onlineAvatarChoices.firstWhere(
  (choice) => choice.id == id,
  orElse: () => onlineAvatarChoices.first,
);

class BuiltInComputerOpponent {
  const BuiltInComputerOpponent({
    required this.id,
    required this.name,
    required this.avatarId,
    required this.level,
    required this.botLevel,
  });

  final String id;
  final String name;
  final String avatarId;
  final OnlinePlayerLevel level;
  final int botLevel;
  String get difficultyLabel => '${level.label} · Level $botLevel';
}

/// Fictional computer-controlled profiles available when no person is ready.
const builtInComputerOpponents = <BuiltInComputerOpponent>[
  BuiltInComputerOpponent(
    id: 'amina-diallo',
    botLevel: 1,
    name: 'Amina Diallo',
    avatarId: 'bot_amina',
    level: OnlinePlayerLevel.beginner,
  ),
  BuiltInComputerOpponent(
    id: 'lucas-martin',
    botLevel: 2,
    name: 'Lucas Martin',
    avatarId: 'bot_lucas',
    level: OnlinePlayerLevel.beginner,
  ),
  BuiltInComputerOpponent(
    id: 'mei-lin',
    botLevel: 3,
    name: 'Mei Lin',
    avatarId: 'bot_mei',
    level: OnlinePlayerLevel.beginner,
  ),
  BuiltInComputerOpponent(
    id: 'omar-haddad',
    botLevel: 4,
    name: 'Omar Haddad',
    avatarId: 'bot_omar',
    level: OnlinePlayerLevel.beginner,
  ),
  BuiltInComputerOpponent(
    id: 'sofia-rossi',
    botLevel: 5,
    name: 'Sofia Rossi',
    avatarId: 'bot_sofia',
    level: OnlinePlayerLevel.beginner,
  ),
  BuiltInComputerOpponent(
    id: 'kwame-mensah',
    botLevel: 6,
    name: 'Kwame Mensah',
    avatarId: 'bot_kwame',
    level: OnlinePlayerLevel.beginner,
  ),
  BuiltInComputerOpponent(
    id: 'ana-costa',
    botLevel: 7,
    name: 'Ana Costa',
    avatarId: 'bot_ana',
    level: OnlinePlayerLevel.beginner,
  ),
  BuiltInComputerOpponent(
    id: 'priya-nair',
    botLevel: 8,
    name: 'Priya Nair',
    avatarId: 'bot_priya',
    level: OnlinePlayerLevel.intermediate,
  ),
  BuiltInComputerOpponent(
    id: 'diego-alvarez',
    botLevel: 9,
    name: 'Diego Alvarez',
    avatarId: 'bot_diego',
    level: OnlinePlayerLevel.intermediate,
  ),
  BuiltInComputerOpponent(
    id: 'haruto-sato',
    botLevel: 10,
    name: 'Haruto Sato',
    avatarId: 'bot_haruto',
    level: OnlinePlayerLevel.intermediate,
  ),
  BuiltInComputerOpponent(
    id: 'nadia-petrova',
    botLevel: 11,
    name: 'Nadia Petrova',
    avatarId: 'bot_nadia',
    level: OnlinePlayerLevel.intermediate,
  ),
  BuiltInComputerOpponent(
    id: 'thandi-ndlovu',
    botLevel: 12,
    name: 'Thandi Ndlovu',
    avatarId: 'bot_thandi',
    level: OnlinePlayerLevel.intermediate,
  ),
  BuiltInComputerOpponent(
    id: 'noah-williams',
    botLevel: 13,
    name: 'Noah Williams',
    avatarId: 'bot_noah',
    level: OnlinePlayerLevel.intermediate,
  ),
  BuiltInComputerOpponent(
    id: 'fatima-zahra',
    botLevel: 14,
    name: 'Fatima Zahra',
    avatarId: 'bot_fatima',
    level: OnlinePlayerLevel.intermediate,
  ),
  BuiltInComputerOpponent(
    id: 'arjun-mehta',
    botLevel: 15,
    name: 'Arjun Mehta',
    avatarId: 'bot_arjun',
    level: OnlinePlayerLevel.advanced,
  ),
  BuiltInComputerOpponent(
    id: 'elena-popescu',
    botLevel: 16,
    name: 'Elena Popescu',
    avatarId: 'bot_elena',
    level: OnlinePlayerLevel.advanced,
  ),
  BuiltInComputerOpponent(
    id: 'mateo-silva',
    botLevel: 17,
    name: 'Mateo Silva',
    avatarId: 'bot_mateo',
    level: OnlinePlayerLevel.advanced,
  ),
  BuiltInComputerOpponent(
    id: 'min-jun',
    botLevel: 18,
    name: 'Min Jun',
    avatarId: 'bot_minjun',
    level: OnlinePlayerLevel.advanced,
  ),
  BuiltInComputerOpponent(
    id: 'emma-clarke',
    botLevel: 19,
    name: 'Emma Clarke',
    avatarId: 'bot_emma',
    level: OnlinePlayerLevel.advanced,
  ),
  BuiltInComputerOpponent(
    id: 'ivan-petrov',
    botLevel: 20,
    name: 'Ivan Petrov',
    avatarId: 'bot_ivan',
    level: OnlinePlayerLevel.advanced,
  ),
];

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
