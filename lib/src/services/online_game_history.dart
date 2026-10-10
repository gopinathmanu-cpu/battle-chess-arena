// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'package:flutter/foundation.dart';

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

enum OnlinePlayerCircle { family, friends, professionals }

extension OnlinePlayerCircleDetails on OnlinePlayerCircle {
  String get label => switch (this) {
    OnlinePlayerCircle.family => 'Family',
    OnlinePlayerCircle.friends => 'Friends',
    OnlinePlayerCircle.professionals => 'Professionals',
  };
}

/// A saved online connection. The historical type/key names remain stable so
/// existing favourites migrate into Friends without losing anyone.
class OnlineFavorite {
  const OnlineFavorite({
    required this.name,
    required this.avatarId,
    this.circle = OnlinePlayerCircle.friends,
  });
  final String name;
  final String avatarId;
  final OnlinePlayerCircle circle;

  Map<String, String> toJson() => {
    'name': name,
    'avatarId': avatarId,
    'circle': circle.name,
  };
  factory OnlineFavorite.fromJson(Map<String, dynamic> json) => OnlineFavorite(
    name: json['name'] as String,
    avatarId: json['avatarId'] as String,
    circle:
        OnlinePlayerCircle.values
            .where((circle) => circle.name == json['circle'])
            .firstOrNull ??
        OnlinePlayerCircle.friends,
  );
}

/// Device cache of the last balance acknowledged by the online service.
///
/// This is presentation state only: it lets the app show a useful balance while
/// disconnected. The server remains authoritative for every credit mutation.
class CachedArenaCreditBalance {
  const CachedArenaCreditBalance({
    required this.playerToken,
    required this.credits,
    required this.bonusCredits,
    required this.purchasedCredits,
    required this.syncedAt,
    this.seenTransactionIds = const <String>[],
  });

  factory CachedArenaCreditBalance.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unknown Arena Credit cache version');
    }
    final playerToken = json['playerToken'];
    final credits = json['credits'];
    final bonusCredits = json['bonusCredits'];
    final purchasedCredits = json['purchasedCredits'];
    final syncedAt = json['syncedAt'];
    final transactionIds = json['seenTransactionIds'];
    if (playerToken is! String ||
        playerToken.isEmpty ||
        credits is! int ||
        bonusCredits is! int ||
        purchasedCredits is! int ||
        credits < 0 ||
        bonusCredits < 0 ||
        purchasedCredits < 0 ||
        bonusCredits + purchasedCredits != credits ||
        syncedAt is! String ||
        transactionIds is! List ||
        transactionIds.any((id) => id is! String || id.isEmpty)) {
      throw const FormatException('Invalid Arena Credit cache');
    }
    return CachedArenaCreditBalance(
      playerToken: playerToken,
      credits: credits,
      bonusCredits: bonusCredits,
      purchasedCredits: purchasedCredits,
      syncedAt: DateTime.parse(syncedAt).toUtc(),
      seenTransactionIds: List<String>.unmodifiable(
        transactionIds.cast<String>().take(64),
      ),
    );
  }

  final String playerToken;
  final int credits;
  final int bonusCredits;
  final int purchasedCredits;
  final DateTime syncedAt;
  final List<String> seenTransactionIds;

  Map<String, Object> toJson() => {
    'version': 1,
    'playerToken': playerToken,
    'credits': credits,
    'bonusCredits': bonusCredits,
    'purchasedCredits': purchasedCredits,
    'syncedAt': syncedAt.toUtc().toIso8601String(),
    'seenTransactionIds': seenTransactionIds.take(64).toList(),
  };
}

class OnlineGameHistory {
  static final profileChanges = ValueNotifier<OnlinePlayerProfile?>(null);
  static final notificationChanges = ValueNotifier<bool?>(null);
  static const _profileKey = 'online_player_profile_v1';
  static const _gamesKey = 'online_game_history_v1';
  static const _favoritesKey = 'online_favorites_v1';
  static const _remindersKey = 'online_invite_reminders_v1';
  static const _notificationsKey = 'online_mobile_notifications_v1';
  static const _creditBalanceKey = 'arena_credit_balance_v1';

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
    profileChanges.value = profile;
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
    return _saveConnections(favorites);
  }

  static Future<List<OnlineFavorite>> saveConnection(
    OnlineFavorite connection,
  ) async {
    final connections = await loadFavorites();
    connections.removeWhere(
      (item) => item.name.toLowerCase() == connection.name.toLowerCase(),
    );
    connections.add(connection);
    return _saveConnections(connections);
  }

  static Future<List<OnlineFavorite>> removeConnection(String name) async {
    final connections = await loadFavorites();
    connections.removeWhere(
      (item) => item.name.toLowerCase() == name.toLowerCase(),
    );
    return _saveConnections(connections);
  }

  static Future<List<OnlineFavorite>> _saveConnections(
    List<OnlineFavorite> connections,
  ) async {
    connections.sort((a, b) {
      final group = a.circle.index.compareTo(b.circle.index);
      return group != 0
          ? group
          : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _favoritesKey,
      jsonEncode(connections.map((item) => item.toJson()).toList()),
    );
    return connections;
  }

  static Future<Set<String>> loadReminders() async {
    final preferences = await SharedPreferences.getInstance();
    return (preferences.getStringList(_remindersKey) ?? []).toSet();
  }

  static Future<void> saveReminders(Set<String> inviteIds) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(_remindersKey, inviteIds.toList());
  }

  static Future<bool> loadMobileNotificationsEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_notificationsKey) ?? false;
  }

  static Future<void> saveMobileNotificationsEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_notificationsKey, enabled);
    notificationChanges.value = enabled;
  }

  static Future<CachedArenaCreditBalance?> loadCreditBalance(
    String? playerToken,
  ) async {
    if (playerToken == null || playerToken.isEmpty) return null;
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_creditBalanceKey);
    if (value == null) return null;
    try {
      final cached = CachedArenaCreditBalance.fromJson(
        (jsonDecode(value) as Map).cast<String, dynamic>(),
      );
      return cached.playerToken == playerToken ? cached : null;
    } catch (_) {
      await preferences.remove(_creditBalanceKey);
      return null;
    }
  }

  static Future<void> saveCreditBalance(
    CachedArenaCreditBalance balance,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _creditBalanceKey,
      jsonEncode(balance.toJson()),
    );
  }

  static Future<void> clearHistoricalData() async {
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.remove(_gamesKey),
      preferences.remove(_remindersKey),
    ]);
  }
}
