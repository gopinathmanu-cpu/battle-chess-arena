// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:battle_chess_arena/src/services/audio_preference_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Exercise the same delayed reads and failed writes as the native store.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/types.dart';

class _ControlledAudioStore extends InMemorySharedPreferencesStore {
  _ControlledAudioStore(super.data) : super.withData();
  final writes = <(String, Object)>[];
  Completer<void>? writeGate;
  bool readFails = false, nextWriteFails = false, nextWriteThrows = false;

  @override
  Future<Map<String, Object>> getAllWithParameters(
    GetAllParameters parameters,
  ) async {
    if (readFails) throw PlatformException(code: 'read-failed');
    return super.getAllWithParameters(parameters);
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    writes.add((key, value));
    await writeGate?.future;
    if (nextWriteFails) {
      nextWriteFails = false;
      return false;
    }
    if (nextWriteThrows) {
      nextWriteThrows = false;
      throw PlatformException(code: 'write-failed');
    }
    return super.setValue(valueType, key, value);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('first use enables commentary and leaves music unmuted', () async {
    expect(await AudioPreferenceStorage.loadCommentaryEnabled(), isTrue);
    expect(await AudioPreferenceStorage.loadMusicMuted(), isFalse);
  });

  test(
    'stored off choices restore without changing unrelated settings',
    () async {
      SharedPreferences.setMockInitialValues({
        AudioPreferenceStorage.commentaryEnabledKey: false,
        AudioPreferenceStorage.musicMutedKey: true,
        'saved-game': 'keep',
      });
      expect(await AudioPreferenceStorage.loadCommentaryEnabled(), isFalse);
      expect(await AudioPreferenceStorage.loadMusicMuted(), isTrue);
      expect(
        (await SharedPreferences.getInstance()).getString('saved-game'),
        'keep',
      );
    },
  );

  test('rapid changes serialize and reads wait for the final choice', () async {
    SharedPreferences.resetStatic();
    final store = _ControlledAudioStore({})..writeGate = Completer<void>();
    SharedPreferencesStorePlatform.instance = store;
    final writes = [
      AudioPreferenceStorage.saveCommentaryEnabled(false),
      AudioPreferenceStorage.saveMusicMuted(true),
      AudioPreferenceStorage.saveCommentaryEnabled(true),
      AudioPreferenceStorage.saveMusicMuted(false),
    ];
    final commentary = AudioPreferenceStorage.loadCommentaryEnabled();
    final music = AudioPreferenceStorage.loadMusicMuted();
    store.writeGate!.complete();
    await Future.wait(writes);
    expect(await commentary, isTrue);
    expect(await music, isFalse);
    expect(store.writes, [
      ('flutter.${AudioPreferenceStorage.commentaryEnabledKey}', false),
      ('flutter.${AudioPreferenceStorage.musicMutedKey}', true),
      ('flutter.${AudioPreferenceStorage.commentaryEnabledKey}', true),
      ('flutter.${AudioPreferenceStorage.musicMutedKey}', false),
    ]);
  });

  for (final thrown in [false, true]) {
    test(
      'failed write $thrown is reported and does not poison later saves',
      () async {
        SharedPreferences.resetStatic();
        final store = _ControlledAudioStore({})
          ..nextWriteFails = !thrown
          ..nextWriteThrows = thrown;
        SharedPreferencesStorePlatform.instance = store;
        await expectLater(
          AudioPreferenceStorage.saveCommentaryEnabled(false),
          thrown ? throwsA(isA<PlatformException>()) : throwsStateError,
        );
        await AudioPreferenceStorage.saveMusicMuted(true);
        await AudioPreferenceStorage.saveCommentaryEnabled(false);
        expect(await AudioPreferenceStorage.loadCommentaryEnabled(), isFalse);
        expect(await AudioPreferenceStorage.loadMusicMuted(), isTrue);
      },
    );
  }

  test('read failure preserves the defaults', () async {
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = _ControlledAudioStore({})
      ..readFails = true;
    expect(await AudioPreferenceStorage.loadCommentaryEnabled(), isTrue);
    expect(await AudioPreferenceStorage.loadMusicMuted(), isFalse);
  });

  test('malformed saved values preserve the defaults', () async {
    SharedPreferences.setMockInitialValues({
      AudioPreferenceStorage.commentaryEnabledKey: 'off',
      AudioPreferenceStorage.musicMutedKey: 1,
    });
    expect(await AudioPreferenceStorage.loadCommentaryEnabled(), isTrue);
    expect(await AudioPreferenceStorage.loadMusicMuted(), isFalse);
  });
}
