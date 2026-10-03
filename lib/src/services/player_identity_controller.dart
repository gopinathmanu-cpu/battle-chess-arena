// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/avatar_name_policy.dart';

class PlayerIdentityController extends ChangeNotifier {
  static const nicknameKey = 'preferred_player_name_v1';
  static const promptHandledKey = 'preferred_player_name_prompt_handled_v1';

  String? _nickname;
  bool _promptHandled = false;
  bool _loaded = false;

  String? get nickname => _nickname;
  bool get loaded => _loaded;
  bool get shouldPrompt => _loaded && !_promptHandled;

  Future<void> restore() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = preferences.getString(nicknameKey);
      _nickname = saved == null || saved.trim().isEmpty ? null : saved.trim();
      _promptHandled = preferences.getBool(promptHandledKey) ?? false;
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> saveNickname(String value) async {
    final normalized = normalizedAvatarName(value);
    final error = preferredNameValidationError(normalized);
    if (error != null) throw ArgumentError(error);
    _nickname = normalized;
    _promptHandled = true;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(nicknameKey, normalized);
    await preferences.setBool(promptHandledKey, true);
  }

  Future<void> continueWithoutNickname() async {
    _nickname = null;
    _promptHandled = true;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(nicknameKey);
    await preferences.setBool(promptHandledKey, true);
  }
}

class PlayerIdentityScope extends InheritedNotifier<PlayerIdentityController> {
  const PlayerIdentityScope({
    required PlayerIdentityController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static PlayerIdentityController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<PlayerIdentityScope>()
      ?.notifier;
}
