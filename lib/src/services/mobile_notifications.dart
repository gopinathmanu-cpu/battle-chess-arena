// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Small native bridge for Android/iOS notifications without a third-party SDK.
class MobileNotificationService {
  MobileNotificationService({MethodChannel? channel, TargetPlatform? platform})
    : _channel = channel ?? const MethodChannel(_channelName),
      _platform = platform ?? defaultTargetPlatform;

  static const _channelName = 'battle_chess_arena/mobile_notifications';
  final MethodChannel _channel;
  final TargetPlatform _platform;

  bool get isSupported =>
      !kIsWeb &&
      (_platform == TargetPlatform.android || _platform == TargetPlatform.iOS);

  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> show({
    required String id,
    required String title,
    required String body,
  }) => _invoke('show', {'id': id, 'title': title, 'body': body});

  Future<void> schedule({
    required String id,
    required String title,
    required String body,
    required DateTime at,
  }) => _invoke('schedule', {
    'id': id,
    'title': title,
    'body': body,
    'at': at.millisecondsSinceEpoch,
  });

  Future<void> cancel(String id) => _invoke('cancel', {'id': id});

  Future<void> cancelAll() => _invoke('cancelAll');

  Future<void> _invoke(String method, [Map<String, Object>? arguments]) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on PlatformException {
      // Notifications are best-effort and must never interrupt online play.
    } on MissingPluginException {
      // Desktop and older builds do not install the mobile bridge.
    }
  }
}
