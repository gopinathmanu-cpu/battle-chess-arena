// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/piece_pack.dart';
import '../features/play/board_appearance.dart';

/// Device-local appearance per room and seat; never changes the other player.
class MatchAppearanceStorage {
  static Future<void>? _pending;
  static String key(String gameId, String seat) =>
      'match_appearance_v1_${Uri.encodeComponent(gameId)}_$seat';

  static Future<BoardAppearance?> load(String gameId, String seat) async {
    final pending = _pending;
    if (pending != null) await pending;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(key(gameId, seat));
    if (saved == null || (saved.length != 5 && saved.length != 6)) return null;
    if (saved.length == 6 && saved[5] != 'animated' && saved[5] != 'classic') {
      return null;
    }
    try {
      PiecePack pack(String id) =>
          piecePacks.firstWhere((p) => p.id.name == id);
      return BoardAppearance(
        white: pack(saved[0]),
        black: pack(saved[1]),
        board: pack(saved[2]),
        standardPieces: saved[3] == 'classic',
        classicStyle: ClassicPieceStyle.values.byName(saved[4]),
        // Older rooms used the Animated world even with Classic board icons.
        animatedArena: saved.length == 5 || saved[5] == 'animated',
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(String gameId, String seat, BoardAppearance value) {
    final data = [
      value.white.id.name,
      value.black.id.name,
      value.board.id.name,
      value.standardPieces ? 'classic' : 'themed',
      value.classicStyle.name,
      value.animatedArena ? 'animated' : 'classic',
    ];
    Future<void> write() async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setStringList(key(gameId, seat), data)) {
        throw StateError('Match appearance could not be saved');
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
    // Do not retain an idle queue's originating zone. A newer write may have
    // installed another tail while this one was settling.
    tail.then((_) {
      if (identical(_pending, tail)) _pending = null;
    });
    return result;
  }
}
