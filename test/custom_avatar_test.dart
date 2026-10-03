// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';

import 'package:battle_chess_arena/src/domain/custom_avatar.dart';
import 'package:battle_chess_arena/src/domain/online_game_state.dart';
import 'package:battle_chess_arena/src/domain/online_player_profile.dart';
import 'package:battle_chess_arena/src/services/online_game_history.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const defaults = CustomAvatarDesign();
  const maximumId = 'custom-v1-1337b9455577';
  const maxima = [1, 3, 3, 7, 11, 9, 4, 5, 5, 5, 7, 7];

  test('default custom avatar has a stable compact wire identity', () {
    expect(defaults.avatarId, 'custom-v1-020321000000');
    expect(defaults.avatarId.length, 22);
    expect(CustomAvatarDesign.tryParse(defaults.avatarId), defaults);
    expect(
      CustomAvatarDesign.tryParse(defaults.avatarId).hashCode,
      defaults.hashCode,
    );
    expect(defaults.copyWith(), defaults);
  });

  test('every category and option round trips in its fixed wire position', () {
    final labels = [
      CustomAvatarDesign.presentationLabels,
      CustomAvatarDesign.ageLabels,
      CustomAvatarDesign.faceLabels,
      CustomAvatarDesign.skinToneLabels,
      CustomAvatarDesign.hairStyleLabels,
      CustomAvatarDesign.hairColorLabels,
      CustomAvatarDesign.moustacheLabels,
      CustomAvatarDesign.beardLabels,
      CustomAvatarDesign.eyewearLabels,
      CustomAvatarDesign.outfitLabels,
      CustomAvatarDesign.outfitColorLabels,
      CustomAvatarDesign.backgroundLabels,
    ];
    for (var field = 0; field < maxima.length; field++) {
      expect(labels[field].length, maxima[field] + 1);
      expect(labels[field].toSet().length, labels[field].length);
      for (var option = 0; option <= maxima[field]; option++) {
        final digits = List<String>.filled(12, '0');
        digits[field] = option.toRadixString(36);
        final id = '${CustomAvatarDesign.prefix}${digits.join()}';
        final parsed = CustomAvatarDesign.tryParse(id);
        expect(parsed, isNotNull, reason: 'Field $field option $option');
        expect(parsed!.avatarId, id);
      }
    }
  });

  test('copyWith can modify all fields without changing the original', () {
    final changed = defaults.copyWith(
      presentation: 1,
      age: 3,
      face: 3,
      skinTone: 7,
      hairStyle: 11,
      hairColor: 9,
      moustache: 4,
      beard: 5,
      eyewear: 5,
      outfit: 5,
      outfitColor: 7,
      background: 7,
    );
    expect(changed.avatarId, maximumId);
    expect(changed, CustomAvatarDesign.tryParse(maximumId));
    expect(changed, isNot(defaults));
    expect(defaults.avatarId, 'custom-v1-020321000000');
  });

  test(
    'constructors clamp values but untrusted wire values are never clamped',
    () {
      const maximum = CustomAvatarDesign(
        presentation: 99,
        age: 99,
        face: 99,
        skinTone: 99,
        hairStyle: 99,
        hairColor: 99,
        moustache: 99,
        beard: 99,
        eyewear: 99,
        outfit: 99,
        outfitColor: 99,
        background: 99,
      );
      const minimum = CustomAvatarDesign(
        presentation: -1,
        age: -1,
        face: -1,
        skinTone: -1,
        hairStyle: -1,
        hairColor: -1,
        moustache: -1,
        beard: -1,
        eyewear: -1,
        outfit: -1,
        outfitColor: -1,
        background: -1,
      );
      expect(maximum.avatarId, maximumId);
      expect(minimum.avatarId, 'custom-v1-000000000000');
      for (var field = 0; field < maxima.length; field++) {
        for (var invalid = maxima[field] + 1; invalid < 36; invalid++) {
          final digits = List<String>.filled(12, '0');
          digits[field] = invalid.toRadixString(36);
          expect(
            CustomAvatarDesign.tryParse(
              '${CustomAvatarDesign.prefix}${digits.join()}',
            ),
            isNull,
          );
        }
      }
    },
  );

  test('malformed, foreign and future avatar IDs fail safely', () {
    for (final id in [
      '',
      'avatar-01',
      'crown',
      'bot_amina',
      'custom-v2-020321000000',
      'CUSTOM-v1-020321000000',
      'custom-v1-1337B9455577',
      'custom-v1-02032100000',
      'custom-v1-0203210000000',
      ' custom-v1-020321000000',
      'custom-v1-020321000000 ',
      'custom-v1-020321000000\n',
      'custom-v1-020321000000\r\n',
      'custom-v1-02032100000\u0000',
      'custom-v1-02032100000/',
      'custom-v1-02032100000é',
      'custom-v1-02032100000😀',
      'custom-v1-${'0' * 10000}',
    ]) {
      expect(CustomAvatarDesign.tryParse(id), isNull, reason: id);
    }
  });

  test(
    'profile JSON and local storage retain custom appearance and identity',
    () async {
      SharedPreferences.setMockInitialValues({});
      const profile = OnlinePlayerProfile(
        name: 'Custom Champion',
        avatarId: maximumId,
        level: OnlinePlayerLevel.advanced,
        playerToken: 'existing-player-token',
      );
      final jsonProfile = OnlinePlayerProfile.fromJson(
        jsonDecode(jsonEncode(profile.toJson())) as Map<String, dynamic>,
      );
      expect(jsonProfile.toJson(), profile.toJson());
      await OnlineGameHistory.saveProfile(jsonProfile);
      final loaded = await OnlineGameHistory.loadProfile();
      expect(loaded?.toJson(), profile.toJson());
      expect(CustomAvatarDesign.tryParse(loaded!.avatarId)?.hairStyle, 11);
      expect(
        loaded.copyWith(playerToken: 'reconnected-token').avatarId,
        maximumId,
      );
    },
  );

  test(
    'opponent summaries and saved match records preserve portable IDs',
    () async {
      SharedPreferences.setMockInitialValues({});
      final summary = OnlinePlayerSummary.fromJson({
        'name': 'Custom Friend',
        'avatarId': maximumId,
        'level': 'beginner',
      }, fallbackName: 'Opponent');
      expect(summary.avatarId, maximumId);
      expect(summary.computer, isFalse);
      final record = OnlineGameRecord(
        gameId: 'custom-match',
        seat: 'w',
        seatToken: 'private-seat-token',
        opponentName: summary.name,
        opponentAvatarId: summary.avatarId,
        status: 'active',
        moveCount: 4,
        updatedAt: DateTime.utc(2026, 9, 26),
      );
      await OnlineGameHistory.upsert(record);
      final restored = (await OnlineGameHistory.loadGames()).single;
      expect(restored.opponentAvatarId, maximumId);
      expect(CustomAvatarDesign.tryParse(restored.opponentAvatarId), isNotNull);
      final favorite = OnlineFavorite.fromJson(
        OnlineFavorite(name: summary.name, avatarId: summary.avatarId).toJson(),
      );
      expect(favorite.avatarId, maximumId);
    },
  );
}
