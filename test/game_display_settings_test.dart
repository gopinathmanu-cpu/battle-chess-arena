import 'package:battle_chess_arena/src/services/game_display_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'visible by default, hide choice persists on a new controller',
    () async {
      final settings = GameDisplaySettings();
      expect(settings.showCapturedPieces, isTrue);
      await settings.setShowCapturedPieces(false);
      expect(settings.error, isNull);
      settings.dispose();
      final reopened = GameDisplaySettings();
      await Future<void>.delayed(Duration.zero);
      expect(reopened.showCapturedPieces, isFalse);
      reopened.dispose();
    },
  );

  test('rapid choices win over late load and writes finish in order', () async {
    final settings = GameDisplaySettings();
    final writes = [
      settings.setShowCapturedPieces(false),
      settings.setShowCapturedPieces(true),
      settings.setShowCapturedPieces(false),
    ];
    await Future.wait(writes);
    expect(settings.showCapturedPieces, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(GameDisplaySettings.capturedPiecesKey), isFalse);
    settings.dispose();
  });

  test('board colours and their enabled state persist independently', () async {
    final settings = GameDisplaySettings();
    await settings.setBoardColors(
      const Color(0xFFFFE0EA),
      const Color(0xFF70406F),
    );
    expect(settings.customBoardColorsEnabled, isTrue);
    await settings.toggleBoardColors();
    expect(settings.customBoardColorsEnabled, isFalse);
    settings.dispose();

    final reopened = GameDisplaySettings();
    await Future<void>.delayed(Duration.zero);
    expect(reopened.boardLightSquare, const Color(0xFFFFE0EA));
    expect(reopened.boardDarkSquare, const Color(0xFF70406F));
    expect(reopened.customBoardColorsEnabled, isFalse);
    await reopened.toggleBoardColors();
    expect(reopened.customBoardColorsEnabled, isTrue);
    reopened.dispose();
  });

  test('reset restores the bright default palette and disables it', () async {
    final settings = GameDisplaySettings();
    await settings.setBoardColors(Colors.grey, Colors.black);
    await settings.resetBoardColors();
    expect(settings.customBoardColorsEnabled, isFalse);
    expect(settings.boardLightSquare, GameDisplaySettings.defaultLightSquare);
    expect(settings.boardDarkSquare, GameDisplaySettings.defaultDarkSquare);
    settings.dispose();
  });

  test(
    'disposing while loading or saving causes no late notification',
    () async {
      var notifications = 0;
      final settings = GameDisplaySettings()
        ..addListener(() => notifications++);
      settings.dispose();
      await Future<void>.delayed(Duration.zero);
      final saving = GameDisplaySettings();
      final write = saving.setShowCapturedPieces(false);
      saving.dispose();
      await write;
      expect(notifications, 0);
    },
  );
}
