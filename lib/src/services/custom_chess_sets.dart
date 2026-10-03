// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/custom_chess_set.dart';

/// A local collection with transactional, ordered preference writes.
///
/// Listeners see changes only after persistence succeeds. Every mutation waits
/// for the initial restore, so an early editor save cannot overwrite saved sets.
class CustomChessSets extends ChangeNotifier {
  CustomChessSets({
    bool autoLoad = true,
    Future<SharedPreferences> Function()? preferences,
  }) : _preferences = preferences ?? SharedPreferences.getInstance {
    ready = autoLoad ? _load() : Future<void>.value();
    if (!autoLoad) _loaded = true;
  }

  static const storageKey = 'custom_chess_sets_v1';
  static const maxSets = 20;
  static const _version = 1;
  final Future<SharedPreferences> Function() _preferences;
  late final Future<void> ready;
  Future<void> _pending = Future<void>.value();
  List<CustomChessSet> _sets = const [];
  String? _activeId;
  String? _error;
  bool _loaded = false;
  bool _closed = false;
  bool _storageNeedsRecovery = false;

  List<CustomChessSet> get sets => _sets;
  String? get activeId => _activeId;
  CustomChessSet? get active =>
      _sets.where((set) => set.id == _activeId).firstOrNull;
  String? get error => _error;
  bool get loaded => _loaded;

  Future<void> _load() async {
    try {
      final prefs = await _preferences();
      final raw = prefs.get(storageKey);
      if (raw == null) return;
      if (raw is! String) throw const FormatException('Invalid collection');
      final json = jsonDecode(raw);
      if (json is! Map ||
          json['version'] != _version ||
          json['sets'] is! List) {
        throw const FormatException('Unsupported collection');
      }
      final restored = <CustomChessSet>[];
      final ids = <String>{};
      for (final value in json['sets'] as List) {
        final set = CustomChessSet.fromJson(value);
        if (!CustomChessSet.isValidId(set.id) || !ids.add(set.id)) {
          throw const FormatException('Invalid or duplicate set ID');
        }
        restored.add(set);
      }
      // Never truncate a persisted collection; a future version may allow more.
      // Existing sets remain editable even when at or above today's limit.
      _sets = List.unmodifiable(restored);
      final selected = json['activeId'];
      _activeId = selected is String && ids.contains(selected)
          ? selected
          : null;
    } catch (_) {
      // Preserve unreadable data rather than replacing it with an empty library.
      _storageNeedsRecovery = true;
      _error =
          'Your custom sets could not be loaded. Please reopen the app and try again.';
    } finally {
      _loaded = true;
      _notify();
    }
  }

  Future<bool> save(
    CustomChessSet set, {
    bool activate = true,
  }) => _enqueue(() async {
    if (!CustomChessSet.isValidId(set.id)) {
      return _fail(
        'This custom set has an invalid ID. Please create a new set.',
      );
    }
    final existing = _sets.indexWhere((item) => item.id == set.id);
    if (existing < 0 && _sets.length >= maxSets) {
      return _fail(
        'You can save up to $maxSets custom sets. Delete one before adding another.',
      );
    }
    final updated = [..._sets];
    if (existing < 0) {
      updated.add(set);
    } else {
      updated[existing] = set;
    }
    return _persist(updated, activate ? set.id : _activeId);
  });

  Future<bool> activate(String? id) => _enqueue(() async {
    if (id != null && !_sets.any((set) => set.id == id)) {
      return _fail(
        'That custom set is no longer available. Choose another set.',
      );
    }
    return _persist(_sets, id);
  });

  Future<bool> delete(String id) => _enqueue(() async {
    if (!_sets.any((set) => set.id == id)) {
      return _fail('That custom set is no longer available.');
    }
    return _persist(
      _sets.where((set) => set.id != id).toList(),
      id == _activeId ? null : _activeId,
    );
  });

  Future<bool> _enqueue(Future<bool> Function() operation) {
    final result = _pending.then((_) async {
      await ready;
      if (_closed) return false;
      if (_storageNeedsRecovery) return false;
      return operation();
    });
    _pending = result.then<void>((_) {});
    return result;
  }

  Future<bool> _persist(List<CustomChessSet> sets, String? activeId) async {
    SharedPreferences? prefs;
    try {
      final value = jsonEncode({
        'version': _version,
        'sets': sets.map((set) => set.toJson()).toList(),
        'activeId': activeId,
      });
      prefs = await _preferences();
      if (!await prefs.setString(storageKey, value)) {
        throw StateError('The custom set library was not saved');
      }
      _sets = List.unmodifiable(sets);
      _activeId = activeId;
      _error = null;
      _notify();
      return true;
    } catch (_) {
      // Legacy preferences update their cache before writing. Reload it after a
      // failed write so another controller cannot observe uncommitted changes.
      try {
        await prefs?.reload();
      } catch (_) {
        // The user-facing error below still reports the original save failure.
      }
      return _fail(
        'Your custom set changes could not be saved. Please try again.',
      );
    }
  }

  bool _fail(String message) {
    _error = message;
    _notify();
    return false;
  }

  void _notify() {
    if (!_closed) notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }
}

class CustomChessSetScope extends InheritedNotifier<CustomChessSets> {
  const CustomChessSetScope({
    required CustomChessSets controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static CustomChessSets? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<CustomChessSetScope>()
      ?.notifier;

  static CustomChessSets of(BuildContext context) =>
      maybeOf(context) ?? (throw StateError('CustomChessSetScope is missing.'));
}
