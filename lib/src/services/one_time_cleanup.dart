// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:shared_preferences/shared_preferences.dart';

class OneTimeCleanup {
  static const markerKey = 'clean_slate_beta_1_complete';

  static Future<void> run() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(markerKey) == true) return;
    // Retired in beta 2: upgrading an older installation must never erase its
    // saved match or online history, even if it skipped the beta-1 cleanup.
    await preferences.setBool(markerKey, true);
  }
}
