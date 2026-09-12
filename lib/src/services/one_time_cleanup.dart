// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:shared_preferences/shared_preferences.dart';

import 'last_game_storage.dart';
import 'online_game_history.dart';

class OneTimeCleanup {
  static const markerKey = 'clean_slate_beta_1_complete';

  static Future<void> run() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(markerKey) == true) return;
    await Future.wait([
      LastGameStorage.clear(),
      OnlineGameHistory.clearHistoricalData(),
    ]);
    await preferences.setBool(markerKey, true);
  }
}
