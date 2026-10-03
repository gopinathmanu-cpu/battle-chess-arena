// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class BetaAppInfo {
  const BetaAppInfo({
    required this.version,
    required this.build,
    required this.platform,
    required this.device,
    required this.architecture,
  });
  final String version;
  final String build;
  final String platform;
  final String device;
  final String architecture;
  static const channel = MethodChannel('battle_chess_arena/beta_info');
  static const sourceUrl =
      'https://github.com/gopinathmanu-cpu/battle-chess-arena';

  static Future<BetaAppInfo> load() async {
    try {
      final info = await channel
          .invokeMapMethod<String, Object?>('getAppInfo')
          .timeout(const Duration(seconds: 2));
      if (info != null) {
        return BetaAppInfo(
          version: info['version'] as String,
          build: info['build'] as String,
          platform: info['platform'] as String,
          device: info['device'] as String,
          architecture: info['architecture'] as String,
        );
      }
    } catch (_) {
      // Android metadata comes from the installed APK, not a duplicated version
      // constant. Other targets remain usable and explicitly report unavailable.
    }
    return BetaAppInfo(
      version: 'Unavailable',
      build: 'Unavailable',
      platform: kIsWeb ? 'Web' : defaultTargetPlatform.name,
      device: 'Unavailable',
      architecture: 'Unavailable',
    );
  }

  String get summary =>
      'Battle Chess Arena $version ($build)\nPlatform: $platform\nDevice: $device\nArchitecture: $architecture';
}
