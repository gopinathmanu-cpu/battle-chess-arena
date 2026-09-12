// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/online_player_profile.dart';

class OnlineGameRecord {
  const OnlineGameRecord({
    required this.gameId,
    required this.seat,
    required this.seatToken,
    required this.opponentName,
    required this.opponentAvatarId,
    required this.status,
    required this.moveCount,
    required this.updatedAt,
  });

  final String gameId;
  final String seat;
  final String seatToken;
  final String opponentName;
  final String opponentAvatarId;
  final String status;
  final int moveCount;
  final DateTime updatedAt;

  bool get isOpen => status != 'complete';

  Map<String, Object?> toJson() => {
    'gameId': gameId,
    'seat': seat,
    'seatToken': seatToken,
    'opponentName': opponentName,
    'opponentAvatarId': opponentAvatarId,
    'status': status,
    'moveCount': moveCount,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory OnlineGameRecord.fromJson(Map<String, dynamic> json) =>
      OnlineGameRecord(
        gameId: json['gameId'] as String,
        seat: json['seat'] as String,
        seatToken: json['seatToken'] as String,
        opponentName: json['opponentName'] as String? ?? 'Waiting opponent',
        opponentAvatarId: json['opponentAvatarId'] as String? ?? 'crown',
        status: json['status'] as String,
        moveCount: json['moveCount'] as int? ?? 0,
        updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
      );
}

class OnlineFavorite {
  const OnlineFavorite({required this.name, required this.avatarId});
  final String name;
  final String avatarId;

  Map<String, String> toJson() => {'name': name, 'avatarId': avatarId};
  factory OnlineFavorite.fromJson(Map<String, dynamic> json) => OnlineFavorite(
    name: json['name'] as String,
    avatarId: json['avatarId'] as String,
  );
}

class OnlineGameHistory {
  static const _profileKey = 'online_player_profile_v1';
  static const _gamesKey = 'online_game_history_v1';
  static const _favoritesKey = 'online_favorites_v1';
  static const _remindersKey = 'online_invite_reminders_v1';

  static Future<OnlinePlayerProfile?> loadProfile() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_profileKey);
    if (value == null) return null;
    try {
      return OnlinePlayerProfile.fromJson(
        (jsonDecode(value) as Map).cast<String, dynamic>(),
      );
    } catch (_) {
      await preferences.remove(_profileKey);
      return null;
    }
  }

  static Future<void> saveProfile(OnlinePlayerProfile profile) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_profileKey, jsonEncode(profile.toJson()));
  }

  static Future<List<OnlineGameRecord>> loadGames() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_gamesKey);
    if (value == null) return [];
    try {
      final decoded = jsonDecode(value) as List;
      final records = decoded
          .map(
            (item) => OnlineGameRecord.fromJson(
              (item as Map).cast<String, dynamic>(),
            ),
          )
          .toList();
      records.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return records;
    } catch (_) {
      await preferences.remove(_gamesKey);
      return [];
    }
  }

  static Future<List<OnlineGameRecord>> upsert(OnlineGameRecord record) async {
    final records = await loadGames();
    records.removeWhere((item) => item.gameId == record.gameId);
    records.insert(0, record);
    if (records.length > 50) records.removeRange(50, records.length);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _gamesKey,
      jsonEncode(records.map((item) => item.toJson()).toList()),
    );
    return records;
  }

  static Future<List<OnlineGameRecord>> deleteGame(String gameId) async {
    final records = await loadGames()
      ..removeWhere((item) => item.gameId == gameId);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _gamesKey,
      jsonEncode(records.map((item) => item.toJson()).toList()),
    );
    return records;
  }

  static Future<List<OnlineFavorite>> loadFavorites() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_favoritesKey);
    if (value == null) return [];
    try {
      return (jsonDecode(value) as List)
          .map(
            (item) =>
                OnlineFavorite.fromJson((item as Map).cast<String, dynamic>()),
          )
          .toList();
    } catch (_) {
      await preferences.remove(_favoritesKey);
      return [];
    }
  }

  static Future<List<OnlineFavorite>> toggleFavorite(
    OnlineFavorite favorite,
  ) async {
    final favorites = await loadFavorites();
    final index = favorites.indexWhere(
      (item) => item.name.toLowerCase() == favorite.name.toLowerCase(),
    );
    if (index < 0) {
      favorites.add(favorite);
    } else {
      favorites.removeAt(index);
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _favoritesKey,
      jsonEncode(favorites.map((item) => item.toJson()).toList()),
    );
    return favorites;
  }

  static Future<Set<String>> loadReminders() async {
    final preferences = await SharedPreferences.getInstance();
    return (preferences.getStringList(_remindersKey) ?? []).toSet();
  }

  static Future<void> saveReminders(Set<String> inviteIds) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(_remindersKey, inviteIds.toList());
  }
}
