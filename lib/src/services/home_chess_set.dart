// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/piece_pack.dart';

/// Remembers both families' last selections without changing saved games.
class HomeChessSet {
  const HomeChessSet({
    this.pack = PiecePackId.anime,
    this.classic = true,
    this.style = ClassicPieceStyle.magneticTeaching,
  });

  static const preferenceKey = 'home_chess_set_v1';
  final PiecePackId pack;
  final bool classic;
  final ClassicPieceStyle style;

  static Future<HomeChessSet> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.get(preferenceKey);
    if (value is! List<String> || value.length != 3) {
      return const HomeChessSet();
    }
    return HomeChessSet(
      pack:
          PiecePackId.values
              .where((item) => item.name == value[0])
              .firstOrNull ??
          PiecePackId.anime,
      classic: switch (value[1]) {
        'classic' => true,
        'themed' => false,
        _ => true,
      },
      style:
          ClassicPieceStyle.values
              .where((item) => item.name == value[2])
              .firstOrNull ??
          ClassicPieceStyle.magneticTeaching,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setStringList(preferenceKey, [
      pack.name,
      classic ? 'classic' : 'themed',
      style.name,
    ])) {
      throw StateError('Chess set preference was not saved');
    }
  }
}
