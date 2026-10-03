// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/player_progress.dart';

class PlayerProgressController extends ChangeNotifier {
  static const storageKey = 'player_progress_v1';
  PlayerProgress _progress = const PlayerProgress();
  Future<void> _writes = Future<void>.value();

  PlayerProgress get progress => _progress;

  Future<void> restore() async {
    try {
      final encoded = (await SharedPreferences.getInstance()).getString(
        storageKey,
      );
      if (encoded != null) {
        _progress = PlayerProgress.fromJson(
          (jsonDecode(encoded) as Map).cast<String, dynamic>(),
        );
        notifyListeners();
      }
    } catch (_) {
      // Corrupt local progression should never prevent the game from opening.
    }
  }

  Future<ProgressAward> recordCompletion({
    required String completionId,
    required int moveCount,
    required bool won,
  }) async {
    ProgressAward? result;
    _writes = _writes.then((_) async {
      if (_progress.awardedCompletionIds.contains(completionId)) {
        result = ProgressAward(
          experience: 0,
          trophies: 0,
          badge: _progress.badge,
          alreadyAwarded: true,
        );
        return;
      }
      final oldBadge = _progress.badge;
      final earnedExperience = experienceForCompletedGame(moveCount);
      final next = PlayerProgress(
        experience: _progress.experience + earnedExperience,
        trophies: _progress.trophies + (won ? 1 : 0),
        completedGames: _progress.completedGames + 1,
        wins: _progress.wins + (won ? 1 : 0),
        awardedCompletionIds: List.unmodifiable([
          ..._progress.awardedCompletionIds,
          completionId,
        ]),
      );
      _progress = next;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, jsonEncode(next.toJson()));
      result = ProgressAward(
        experience: earnedExperience,
        trophies: won ? 1 : 0,
        badge: next.badge,
        unlockedBadge: next.badge != oldBadge ? next.badge : null,
      );
    });
    await _writes;
    return result!;
  }
}

class PlayerProgressScope extends InheritedNotifier<PlayerProgressController> {
  const PlayerProgressScope({
    required PlayerProgressController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static PlayerProgressController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<PlayerProgressScope>()
      ?.notifier;
}
