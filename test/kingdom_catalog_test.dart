// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/services/computer_player.dart';
import 'package:battle_chess_arena/src/services/home_chess_set.dart';
import 'package:battle_chess_arena/src/services/last_game_storage.dart';
import 'package:battle_chess_arena/src/services/theme_music.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _KingdomMusicOutput implements MusicOutput {
  PiecePackId? current;
  BackgroundMusic? selection;

  @override
  Future<void> play(
    PiecePackId theme, {
    BackgroundMusic selection = BackgroundMusic.theme,
  }) async {
    current = theme;
    this.selection = selection;
  }

  @override
  Future<void> playEffect(CinematicSound effect) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'thirty-one themed packs append realms without changing saved indices',
    () {
      expect(PiecePackId.values.take(4), [
        PiecePackId.anime,
        PiecePackId.indianEpic,
        PiecePackId.greek,
        PiecePackId.futuristic,
      ]);
      expect(PiecePackId.values.take(4).map((id) => id.index), [0, 1, 2, 3]);
      expect(piecePacks.map((pack) => pack.id), PiecePackId.values);
      expect(piecePacks, hasLength(31));
      expect(piecePacks.map((pack) => pack.id.name).toSet(), hasLength(31));
      expect(piecePacks.map((pack) => pack.name).toSet(), hasLength(31));
      expect(piecePacks.skip(4).take(8).map((pack) => pack.name), [
        'Japanese Shogunate',
        'Chinese Imperial Court',
        'Mongolian Khans',
        'Egyptian Pharaohs',
        'Arab Caliphate',
        'Persian Royal Court',
        'English Crown',
        'French Court',
      ]);
      expect(
        piecePacks.take(12).map((pack) => pack.id.index),
        List.generate(12, (index) => index),
      );
      expect(piecePacks.skip(12).map((pack) => pack.id.name), [
        'sparta',
        'macedonian',
        'roman',
        'achaemenid',
        'ottoman',
        'chola',
        'maratha',
        'zulu',
        'aztec',
        'inca',
        'mewar',
        'lanka',
        'ayodhya',
        'hastinapura',
        'kishkindha',
        'asgard',
        'camelot',
        'atlantis',
        'troy',
      ]);
      expect(piecePacks.every((pack) => pack.subtitle.isNotEmpty), isTrue);
    },
  );

  test(
    'realm groups distinguish historical, legendary and original worlds',
    () {
      final original = piecePacks.where(
        (pack) => pack.group == PiecePackGroup.original,
      );
      final historical = piecePacks.where(
        (pack) => pack.group == PiecePackGroup.historical,
      );
      final legendary = piecePacks.where(
        (pack) => pack.group == PiecePackGroup.legendary,
      );
      expect(original.map((pack) => pack.id), PiecePackId.values.take(4));
      expect(historical, hasLength(19));
      expect(legendary, hasLength(8));
      expect(
        historical.map((pack) => pack.id),
        containsAll([
          PiecePackId.persian,
          PiecePackId.achaemenid,
          PiecePackId.sparta,
          PiecePackId.macedonian,
        ]),
      );
      expect(legendary.map((pack) => pack.id), PiecePackId.values.skip(23));
      expect(
        piecePacks
            .firstWhere((pack) => pack.id == PiecePackId.persian)
            .subtitle,
        contains('Safavid'),
      );
      expect(
        piecePacks
            .firstWhere((pack) => pack.id == PiecePackId.achaemenid)
            .subtitle,
        contains('Ancient Persian'),
      );
    },
  );

  test('all four classic styles retain their names, indices and labels', () {
    expect(ClassicPieceStyle.values.map((style) => style.name), [
      'magneticTeaching',
      'wood',
      'plastic',
      'metal',
    ]);
    expect(ClassicPieceStyle.values.map((style) => style.index), [0, 1, 2, 3]);
    expect(ClassicPieceStyle.values.map((style) => style.label), [
      'Magnetic 3D',
      'Wooden 3D',
      'Flat Club',
      'Flat Teaching',
    ]);
  });

  test(
    'all thirty-one home selections survive restore in either piece family',
    () async {
      SharedPreferences.setMockInitialValues({
        ThemeMusic.selectionKey: BackgroundMusic.zen.name,
        'musicMuted': true,
      });
      for (final pack in piecePacks) {
        for (final classic in [false, true]) {
          final style = ClassicPieceStyle
              .values[pack.id.index % ClassicPieceStyle.values.length];
          await HomeChessSet(
            pack: pack.id,
            classic: classic,
            style: style,
          ).save();
          final restored = await HomeChessSet.load();
          expect(restored.pack, pack.id);
          expect(restored.classic, classic);
          expect(restored.style, style);
        }
      }
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getString(ThemeMusic.selectionKey),
        BackgroundMusic.zen.name,
      );
      expect(preferences.getBool('musicMuted'), isTrue);
    },
  );

  test(
    'old home preferences continue to resolve their original sets',
    () async {
      for (final pack in piecePacks.take(4)) {
        SharedPreferences.setMockInitialValues({
          HomeChessSet.preferenceKey: [
            pack.id.name,
            'themed',
            'magneticTeaching',
          ],
        });
        expect((await HomeChessSet.load()).pack, pack.id);
      }
    },
  );

  test(
    'saved games round trip every kingdom independently for armies and board',
    () {
      for (final pack in piecePacks) {
        final black = piecePacks[(pack.id.index + 1) % piecePacks.length].id;
        final board = piecePacks[(pack.id.index + 2) % piecePacks.length].id;
        final saved = SavedGame(
          mode: PlayerMode.computer,
          homePack: pack.id,
          difficulty: ComputerDifficulty.medium,
          moves: const ['e2e4', 'e7e5'],
          whiteMilliseconds: 590000,
          blackMilliseconds: 591000,
          fastBattles: false,
          whitePack: pack.id,
          blackPack: black,
          boardPack: board,
          updatedAtEpochMs: 123456789,
        );
        final restored = SavedGame.fromJson(saved.toJson());
        expect(restored.homePack, pack.id);
        expect(restored.whitePack, pack.id);
        expect(restored.blackPack, black);
        expect(restored.boardPack, board);
        expect(restored.moves, saved.moves);
      }
    },
  );

  test('every world has its own compact original soundtrack', () {
    final themeAssets = <String>{};
    for (final pack in piecePacks) {
      for (final music in BackgroundMusic.values) {
        final asset = music.assetFor(pack.id);
        final file = File('assets/$asset');
        expect(file.existsSync(), isTrue, reason: asset);
        if (music == BackgroundMusic.theme) {
          expect(asset, 'audio/${pack.id.name}.wav');
          expect(file.lengthSync(), inInclusiveRange(180000, 750000));
          themeAssets.add(asset);
        } else {
          expect(asset, 'audio/mood_${music.name}.wav');
        }
      }
    }
    expect(themeAssets, hasLength(piecePacks.length));
  });

  test(
    'switching kingdoms preserves the chosen music instead of resetting it',
    () async {
      final output = _KingdomMusicOutput();
      final savedMusic = <BackgroundMusic>[];
      final savedMute = <bool>[];
      final music = ThemeMusic(
        output: output,
        selection: BackgroundMusic.calm,
        saveSelection: (selection) async => savedMusic.add(selection),
        saveMuted: (muted) async => savedMute.add(muted),
      );
      addTearDown(music.dispose);
      for (final pack in piecePacks) {
        music.select(pack.id);
        await music.settled;
        expect(music.selection, BackgroundMusic.calm);
        expect(output.current, pack.id);
        expect(output.selection, BackgroundMusic.calm);
      }
      expect(savedMusic, isEmpty);
      expect(savedMute, isEmpty);
    },
  );
}
