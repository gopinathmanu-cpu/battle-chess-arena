// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local display preference shared by offline and online game screens.
class GameDisplaySettings extends ChangeNotifier {
  GameDisplaySettings() {
    unawaited(_load());
  }

  static const capturedPiecesKey = 'show_captured_pieces_v1';
  static const boardColorsKey = 'board_square_colours_v1';
  static const customBoardColorsEnabledKey = 'custom_board_colours_enabled_v1';
  static const defaultLightSquare = Color(0xFFF3E6C7);
  static const defaultDarkSquare = Color(0xFF39736B);
  bool showCapturedPieces = true;
  bool customBoardColorsEnabled = false;
  Color boardLightSquare = defaultLightSquare;
  Color boardDarkSquare = defaultDarkSquare;
  String? error;
  int _capturedRevision = 0;
  int _boardRevision = 0;
  bool _disposed = false;
  Future<void> _pendingSave = Future.value();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_disposed) return;
      if (_capturedRevision == 0) {
        showCapturedPieces = prefs.getBool(capturedPiecesKey) ?? true;
      }
      if (_boardRevision == 0) {
        customBoardColorsEnabled =
            prefs.getBool(customBoardColorsEnabledKey) ?? false;
        final saved = prefs.getStringList(boardColorsKey);
        if (saved != null && saved.length == 2) {
          final light = int.tryParse(saved[0]);
          final dark = int.tryParse(saved[1]);
          if (light != null && dark != null) {
            boardLightSquare = Color(_opaque(light));
            boardDarkSquare = Color(_opaque(dark));
          }
        }
      }
    } catch (_) {
      if (_disposed) return;
      error = 'Could not load the saved display preference.';
    }
    notifyListeners();
  }

  Future<void> setShowCapturedPieces(bool value) {
    showCapturedPieces = value;
    error = null;
    final revision = ++_capturedRevision;
    notifyListeners();
    // Serialize rapid toggles so an older write cannot overwrite the last choice.
    _pendingSave = _pendingSave.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (!await prefs.setBool(capturedPiecesKey, value)) {
          throw StateError('Preference not saved');
        }
      } catch (_) {
        if (!_disposed && revision == _capturedRevision) {
          error = 'Applies now, but could not save for next time. Try again.';
          notifyListeners();
        }
      }
    });
    return _pendingSave;
  }

  Future<void> setBoardColors(Color light, Color dark) {
    boardLightSquare = Color(_opaque(light.toARGB32()));
    boardDarkSquare = Color(_opaque(dark.toARGB32()));
    customBoardColorsEnabled = true;
    error = null;
    final revision = ++_boardRevision;
    notifyListeners();
    return _saveBoardColors(revision);
  }

  Future<void> toggleBoardColors() {
    customBoardColorsEnabled = !customBoardColorsEnabled;
    error = null;
    final revision = ++_boardRevision;
    notifyListeners();
    return _saveBoardColors(revision);
  }

  Future<void> resetBoardColors() {
    boardLightSquare = defaultLightSquare;
    boardDarkSquare = defaultDarkSquare;
    customBoardColorsEnabled = false;
    error = null;
    final revision = ++_boardRevision;
    notifyListeners();
    return _saveBoardColors(revision);
  }

  Future<void> _saveBoardColors(int revision) {
    final enabled = customBoardColorsEnabled;
    final colors = <String>[
      boardLightSquare.toARGB32().toString(),
      boardDarkSquare.toARGB32().toString(),
    ];
    _pendingSave = _pendingSave.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final colorsSaved = await prefs.setStringList(boardColorsKey, colors);
        final enabledSaved = await prefs.setBool(
          customBoardColorsEnabledKey,
          enabled,
        );
        if (!colorsSaved || !enabledSaved) {
          throw StateError('Board colours not saved');
        }
      } catch (_) {
        if (!_disposed && revision == _boardRevision) {
          error = 'Applies now, but could not save for next time. Try again.';
          notifyListeners();
        }
      }
    });
    return _pendingSave;
  }

  static int _opaque(int value) => 0xFF000000 | (value & 0x00FFFFFF);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
