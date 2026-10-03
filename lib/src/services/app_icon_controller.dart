// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppIconChoice {
  classicGold(
    id: 'classic_gold',
    label: 'Classic Gold',
    asset: 'assets/branding/battle_chess_arena_icon_v7.png',
  ),
  lightPurple(
    id: 'light_purple',
    label: 'Light Purple',
    asset: 'assets/branding/icon-options/battle-chess-arena-light-purple.png',
  );

  const AppIconChoice({
    required this.id,
    required this.label,
    required this.asset,
  });

  final String id;
  final String label;
  final String asset;
}

class AppIconController extends ChangeNotifier {
  AppIconController({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName) {
    _load();
  }

  static const _channelName = 'battle_chess_arena/app_icon';
  static const _preferenceKey = 'selected_app_icon';
  final MethodChannel _channel;

  AppIconChoice _choice = AppIconChoice.lightPurple;
  bool _loading = true;
  bool _changing = false;
  bool _disposed = false;
  String? _error;

  AppIconChoice get choice => _choice;
  bool get loading => _loading;
  bool get changing => _changing;
  String? get error => _error;
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _load() async {
    final saved = (await SharedPreferences.getInstance()).getString(
      _preferenceKey,
    );
    _choice = AppIconChoice.values.firstWhere(
      (candidate) => candidate.id == saved,
      orElse: () => AppIconChoice.lightPurple,
    );
    _loading = false;
    if (!_disposed) notifyListeners();
  }

  Future<bool> select(AppIconChoice next) async {
    if (_changing || next == _choice) return true;
    if (!supported) {
      _error = 'Selectable launcher icons are currently available on Android.';
      if (!_disposed) notifyListeners();
      return false;
    }
    _changing = true;
    _error = null;
    if (!_disposed) notifyListeners();
    try {
      await _channel.invokeMethod<void>('setAppIcon', {'icon': next.id});
      await (await SharedPreferences.getInstance()).setString(
        _preferenceKey,
        next.id,
      );
      _choice = next;
      return true;
    } on PlatformException catch (exception) {
      _error = exception.message ?? 'The launcher icon could not be changed.';
      return false;
    } finally {
      _changing = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> resetToDefault() => select(AppIconChoice.lightPurple);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
