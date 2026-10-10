// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:shared_preferences/shared_preferences.dart';

/// Shared audio choices for live play, saved games and cinematic replays.
class AudioPreferenceStorage {
  static const commentaryEnabledKey = 'moveCommentaryEnabledV1';
  static const musicMutedKey = 'musicMuted';
  static Future<void>? _pending;

  static Future<bool> loadCommentaryEnabled() =>
      _load(commentaryEnabledKey, fallback: true);

  static Future<void> saveCommentaryEnabled(bool enabled) =>
      _save(commentaryEnabledKey, enabled);

  static Future<bool> loadMusicMuted() => _load(musicMutedKey, fallback: false);

  static Future<void> saveMusicMuted(bool muted) => _save(musicMutedKey, muted);

  static Future<bool> _load(String key, {required bool fallback}) async {
    try {
      final pending = _pending;
      if (pending != null) await pending;
      final preferences = await SharedPreferences.getInstance();
      return preferences.getBool(key) ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  static Future<void> _save(String key, bool value) {
    Future<void> write() async {
      final preferences = await SharedPreferences.getInstance();
      if (!await preferences.setBool(key, value)) {
        throw StateError('Could not save audio preference: $key');
      }
    }

    final pending = _pending;
    final result = pending == null
        ? Future<void>.sync(write)
        : pending.then((_) => write());
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    _pending = tail;
    tail.then((_) {
      if (identical(_pending, tail)) _pending = null;
    });
    return result;
  }
}
