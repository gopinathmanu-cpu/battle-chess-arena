// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DiagnosticMode { home, computer, local, online, tournament }

enum DiagnosticSource {
  framework,
  asynchronous,
  startup,
  engineFallback,
  tournamentSave,
}

/// A deliberately small, local-only error log. Never stores exception messages,
/// game positions, player names, network payloads, URLs, or authentication tokens.
class AppDiagnostics extends ChangeNotifier {
  static final instance = AppDiagnostics();
  static const storageKey = 'beta_diagnostics_v1';
  static const enabledKey = 'beta_diagnostics_enabled_v1';
  static const maxEvents = 30;

  final List<Map<String, Object>> _events = [];
  SharedPreferences? _preferences;
  Future<void>? _pending;
  bool _enabled = true;
  bool _initialized = false;
  bool _storageAvailable = false;
  DiagnosticMode mode = DiagnosticMode.home;

  bool get enabled => _enabled;
  bool get storageAvailable => _storageAvailable;
  int get eventCount => _events.length;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _preferences = prefs;
      _enabled = prefs.getBool(enabledKey) ?? true;
      if (_enabled) {
        final saved = prefs.getString(storageKey);
        if (saved != null) {
          try {
            final entries = jsonDecode(saved) as List;
            final restored = entries
                .take(maxEvents)
                .map((entry) => _readEvent(entry as Map))
                .toList();
            _events.insertAll(0, restored);
            _trim();
          } catch (_) {
            // Invalid diagnostics are expendable; game saves are never touched.
            await prefs.remove(storageKey);
          }
        }
      } else {
        _events.clear();
        await prefs.remove(storageKey);
      }
      _storageAvailable = true;
    } catch (_) {
      _storageAvailable = false;
    }
    notifyListeners();
    await _persist();
  }

  static String _safeType(String value) =>
      RegExp(r'^[A-Za-z][A-Za-z0-9_]{0,79}$').hasMatch(value) ? value : 'Error';

  // Keep source coordinates, not arbitrary stack text or absolute device paths.
  static List<String> _frames(String stack) => RegExp(
    r'(?:package:[a-zA-Z0-9_]+/[a-zA-Z0-9_/.-]+\.dart|dart:[a-zA-Z0-9_/.-]+):[0-9]+:[0-9]+',
  ).allMatches(stack).take(8).map((match) => match.group(0)!).toList();

  static Map<String, Object> _readEvent(Map entry) => {
    'time': DateTime.parse(entry['time'] as String).toUtc().toIso8601String(),
    'source': DiagnosticSource.values.byName(entry['source'] as String).name,
    'mode': DiagnosticMode.values.byName(entry['mode'] as String).name,
    'type': _safeType(entry['type'] as String),
    'frames': _frames((entry['frames'] as List).join('\n')),
  };

  void record(DiagnosticSource source, Object error, [StackTrace? stack]) {
    if (!_enabled) return;
    _events.add({
      'time': DateTime.now().toUtc().toIso8601String(),
      'source': source.name,
      'mode': mode.name,
      'type': _safeType(error.runtimeType.toString()),
      'frames': _frames(stack?.toString() ?? ''),
    });
    _trim();
    // Error callbacks can occur during build. Do not trigger widget rebuilds
    // from that stack; the About screen refreshes when opened or explicitly.
    unawaited(_persist());
  }

  void _trim() {
    if (_events.length > maxEvents) {
      _events.removeRange(0, _events.length - maxEvents);
    }
  }

  Future<void> _persist() {
    final prefs = _preferences;
    if (prefs == null) return Future<void>.value();
    Future<void> write() async {
      try {
        final preferenceSaved = await prefs.setBool(enabledKey, _enabled);
        final logSaved = _enabled && _events.isNotEmpty
            ? await prefs.setString(storageKey, jsonEncode(_events))
            : await prefs.remove(storageKey);
        _storageAvailable = preferenceSaved && logSaved;
      } catch (_) {
        _storageAvailable = false;
      }
    }

    final result = _pending == null ? write() : _pending!.then((_) => write());
    _pending = result;
    result.then((_) {
      if (identical(_pending, result)) _pending = null;
    });
    return result;
  }

  Future<void> flush() async {
    await _pending;
  }

  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    if (!enabled) _events.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> clear() async {
    _events.clear();
    await _persist();
    notifyListeners();
  }

  String export() {
    if (!_enabled) return 'Local diagnostics disabled.';
    if (_events.isEmpty) return 'No locally captured errors.';
    return _events
        .map(
          (entry) =>
              '${entry['time']} | ${entry['source']} | ${entry['mode']} | ${entry['type']}\n${(entry['frames'] as List).join('\n')}',
        )
        .join('\n\n');
  }

  /// Called only by the application entrypoint, not by widgets or tests. Returns
  /// a restoration callback so handler wiring can be verified without leakage.
  VoidCallback installErrorHandlers() {
    final previousFlutter = FlutterError.onError;
    final previousAsync = PlatformDispatcher.instance.onError;
    void flutterHandler(FlutterErrorDetails details) {
      record(DiagnosticSource.framework, details.exception, details.stack);
      if (!kReleaseMode) previousFlutter?.call(details);
    }

    bool asyncHandler(Object error, StackTrace stack) {
      record(DiagnosticSource.asynchronous, error, stack);
      if (!kReleaseMode && previousAsync != null) {
        return previousAsync(error, stack);
      }
      return true;
    }

    FlutterError.onError = flutterHandler;
    PlatformDispatcher.instance.onError = asyncHandler;
    return () {
      if (FlutterError.onError == flutterHandler) {
        FlutterError.onError = previousFlutter;
      }
      if (PlatformDispatcher.instance.onError == asyncHandler) {
        PlatformDispatcher.instance.onError = previousAsync;
      }
    };
  }
}

/// Only allowlisted mode names enter diagnostics; never serialize route args.
class DiagnosticNavigationObserver extends NavigatorObserver {
  DiagnosticNavigationObserver(this.diagnostics);
  final AppDiagnostics diagnostics;
  final List<Route<dynamic>> _routes = [];
  void _update() {
    diagnostics.mode = DiagnosticMode.home;
    for (final route in _routes) {
      for (final mode in DiagnosticMode.values) {
        if (route.settings.name == '/${mode.name}') diagnostics.mode = mode;
      }
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    _update();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _update();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _update();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index >= 0) {
      if (newRoute == null) {
        _routes.removeAt(index);
      } else {
        _routes[index] = newRoute;
      }
    } else if (newRoute != null) {
      _routes.add(newRoute);
    }
    _update();
  }
}
