// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppColorSchemePreset {
  goldenArena(
    label: 'App Icon Gold',
    description: 'Bright gold, amber and warm red from the app icon',
    seed: Color(0xFFD39A2C),
  ),
  royalBlue(
    label: 'Royal Blue',
    description: 'Deep blue and sapphire',
    seed: Color(0xFF3976D2),
  ),
  emerald(
    label: 'Emerald Court',
    description: 'Rich green and jade',
    seed: Color(0xFF2E9B72),
  ),
  crimson(
    label: 'Crimson Crown',
    description: 'Regal red and copper',
    seed: Color(0xFFC9574F),
  ),
  amethyst(
    label: 'Amethyst',
    description: 'Violet and lavender',
    seed: Color(0xFF8B68D5),
  );

  const AppColorSchemePreset({
    required this.label,
    required this.description,
    required this.seed,
  });

  final String label;
  final String description;
  final Color seed;

  List<Color> get backgroundGradient => switch (this) {
    goldenArena => const [
      Color(0xFFFFC42D),
      Color(0xFFC43A20),
      Color(0xFF35120D),
    ],
    royalBlue => const [
      Color(0xFF3178D5),
      Color(0xFF142D62),
      Color(0xFF080D20),
    ],
    emerald => const [Color(0xFF35A77D), Color(0xFF123F36), Color(0xFF071713)],
    crimson => const [Color(0xFFE45E50), Color(0xFF681E28), Color(0xFF200910)],
    amethyst => const [Color(0xFFA778E7), Color(0xFF442269), Color(0xFF140A24)],
  };
}

enum AppBackgroundMode {
  single('Single scheme', 'Keep one background across every chess set'),
  dynamic('Dynamic scheme', 'Match the background to the selected chess set');

  const AppBackgroundMode(this.label, this.description);

  final String label;
  final String description;
}

/// Persists the application-wide colour palette on this device.
class AppColorSchemeController extends ChangeNotifier {
  static const preferenceKey = 'application_colour_scheme_v1';
  static const backgroundModePreferenceKey = 'application_background_mode_v1';
  static const defaultPreset = AppColorSchemePreset.goldenArena;
  static const defaultBackgroundMode = AppBackgroundMode.dynamic;

  AppColorSchemePreset _preset = defaultPreset;
  AppColorSchemePreset get preset => _preset;
  AppBackgroundMode _backgroundMode = defaultBackgroundMode;
  AppBackgroundMode get backgroundMode => _backgroundMode;
  String? error;

  int _revision = 0;
  bool _disposed = false;
  Future<void> _pendingSave = Future.value();

  Future<void> restore() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (_disposed || _revision != 0) return;
      final saved = preferences.getString(preferenceKey);
      _preset = AppColorSchemePreset.values.firstWhere(
        (choice) => choice.name == saved,
        orElse: () => defaultPreset,
      );
      final savedMode = preferences.getString(backgroundModePreferenceKey);
      _backgroundMode = AppBackgroundMode.values.firstWhere(
        (choice) => choice.name == savedMode,
        orElse: () => defaultBackgroundMode,
      );
      error = null;
    } catch (_) {
      if (_disposed) return;
      error = 'Could not load the saved application colours.';
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> setPreset(AppColorSchemePreset value) {
    _preset = value;
    error = null;
    final revision = ++_revision;
    notifyListeners();
    _pendingSave = _pendingSave.then((_) async {
      try {
        final preferences = await SharedPreferences.getInstance();
        if (!await preferences.setString(preferenceKey, value.name)) {
          throw StateError('Preference not saved');
        }
      } catch (_) {
        if (!_disposed && revision == _revision) {
          error = 'Colours changed, but could not be saved for next time.';
          notifyListeners();
        }
      }
    });
    return _pendingSave;
  }

  Future<void> setBackgroundMode(AppBackgroundMode value) {
    _backgroundMode = value;
    error = null;
    final revision = ++_revision;
    notifyListeners();
    _pendingSave = _pendingSave.then((_) async {
      try {
        final preferences = await SharedPreferences.getInstance();
        if (!await preferences.setString(
          backgroundModePreferenceKey,
          value.name,
        )) {
          throw StateError('Preference not saved');
        }
      } catch (_) {
        if (!_disposed && revision == _revision) {
          error = 'Background changed, but could not be saved for next time.';
          notifyListeners();
        }
      }
    });
    return _pendingSave;
  }

  Future<void> resetToDefault() async {
    await setPreset(defaultPreset);
    await setBackgroundMode(defaultBackgroundMode);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class AppColorSchemeScope extends InheritedNotifier<AppColorSchemeController> {
  const AppColorSchemeScope({
    required AppColorSchemeController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static AppColorSchemeController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<AppColorSchemeScope>()
      ?.notifier;
}
