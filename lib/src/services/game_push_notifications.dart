// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Optional Firebase configuration; an unconfigured build retains local alerts.
class GamePushNotifications {
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const senderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static bool get configured =>
      [apiKey, appId, senderId, projectId].every((v) => v.isNotEmpty);
  StreamSubscription<String>? _tokens;
  StreamSubscription<RemoteMessage>? _opens;
  bool _disposed = false;
  String? deviceId;
  String? token;
  bool ready = false;
  Future<void> start({
    required VoidCallback onToken,
    required void Function(String) openGame,
  }) async {
    if (kIsWeb ||
        ![
          TargetPlatform.android,
          TargetPlatform.iOS,
        ].contains(defaultTargetPlatform)) {
      return;
    }
    try {
      await Firebase.initializeApp(
        options: configured
            ? const FirebaseOptions(
                apiKey: apiKey,
                appId: appId,
                messagingSenderId: senderId,
                projectId: projectId,
              )
            : null,
      );
      if (_disposed) return;
      final preferences = await SharedPreferences.getInstance();
      deviceId =
          preferences.getString('game_push_device_v1') ??
          List.generate(
            16,
            (_) =>
                Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
          ).join();
      await preferences.setString('game_push_device_v1', deviceId!);
      if (_disposed) return;
      ready = true;
      _tokens = FirebaseMessaging.instance.onTokenRefresh.listen((value) {
        if (!_disposed) {
          token = value;
          onToken();
        }
      });
      _opens = FirebaseMessaging.onMessageOpenedApp.listen((message) {
        final id = message.data['gameId'];
        if (!_disposed && id != null) openGame(id);
      });
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (_disposed) return;
      if (initial?.data['gameId'] case final String id) openGame(id);
      // Permission remains opt-in through the existing Mobile notifications setting.
      token = await FirebaseMessaging.instance.getToken();
      if (!_disposed) onToken();
    } catch (_) {
      // Missing configuration or unavailable Play services cannot interrupt games.
      ready = false;
    }
  }

  void dispose() {
    _disposed = true;
    _tokens?.cancel();
    _opens?.cancel();
  }
}
