import 'package:battle_chess_arena/src/app.dart';
import 'package:battle_chess_arena/src/features/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/domain/online_player_profile.dart';
import 'package:battle_chess_arena/src/services/theme_music.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeMusicOutput implements MusicOutput {
  PiecePackId? current;
  BackgroundMusic? selection;
  bool playing = false;
  bool fail = false;
  bool disposed = false;
  final effects = <CinematicSound>[];
  @override
  Future<void> play(
    PiecePackId theme, {
    BackgroundMusic selection = BackgroundMusic.theme,
  }) async {
    if (fail) throw StateError('audio unavailable');
    current = theme;
    this.selection = selection;
    playing = true;
  }

  @override
  Future<void> playEffect(CinematicSound effect) async {
    if (fail) throw StateError('audio unavailable');
    effects.add(effect);
  }

  @override
  Future<void> pause() async {
    playing = false;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    playing = false;
  }
}

class _LeaseMusicOutput extends FakeMusicOutput {
  int playCalls = 0;
  int disposeCalls = 0;

  @override
  Future<void> play(
    PiecePackId theme, {
    BackgroundMusic selection = BackgroundMusic.theme,
  }) async {
    playCalls++;
    await super.play(theme, selection: selection);
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    await super.dispose();
  }
}

void main() {
  testWidgets(
    'music selection persists across app restart and reset keeps unrelated data',
    (tester) async {
      SharedPreferences.setMockInitialValues({'unrelated_game': 'keep'});
      final first = FakeMusicOutput();
      await tester.pumpWidget(
        BattleChessArenaApp(
          musicOutput: first,
          incomingLinks: const Stream.empty(),
        ),
      );
      await tester.pumpAndSettle();
      var music = MusicScope.of(tester.element(find.byType(HomeScreen)))!;
      expect(music.selection, BackgroundMusic.theme);
      music.setSelection(BackgroundMusic.zen);
      await tester.pumpAndSettle();
      expect(first.selection, BackgroundMusic.zen);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      final second = FakeMusicOutput();
      await tester.pumpWidget(
        BattleChessArenaApp(
          musicOutput: second,
          incomingLinks: const Stream.empty(),
        ),
      );
      await tester.pumpAndSettle();
      music = MusicScope.of(tester.element(find.byType(HomeScreen)))!;
      expect(music.selection, BackgroundMusic.zen);
      expect(second.selection, BackgroundMusic.zen);
      music.toggleMuted();
      music.setSelection(BackgroundMusic.rapid);
      music.select(PiecePackId.greek);
      await tester.pumpAndSettle();
      expect(second.playing, false);
      music.resetToDefaults();
      await tester.pumpAndSettle();
      expect(music.selection, BackgroundMusic.theme);
      expect(music.muted, false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ThemeMusic.selectionKey), 'theme');
      expect(prefs.getBool('musicMuted'), false);
      expect(prefs.getString('unrelated_game'), 'keep');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  test('latest mood survives theme changes and rapid writes', () async {
    final output = FakeMusicOutput();
    final saved = <BackgroundMusic>[];
    final music = ThemeMusic(
      output: output,
      saveMuted: (_) async {},
      saveSelection: (value) async {
        saved.add(value);
      },
    );
    music.select(PiecePackId.anime);
    music.setSelection(BackgroundMusic.rapid);
    music.setSelection(BackgroundMusic.calm);
    music.select(PiecePackId.futuristic);
    await music.settled;
    expect(output.selection, BackgroundMusic.calm);
    expect(saved.last, BackgroundMusic.calm);
    expect(backgroundMusicFromName('unknown'), BackgroundMusic.theme);
    music.dispose();
  });
  test(
    'mute survives theme changes and resumes only the latest theme',
    () async {
      final output = FakeMusicOutput();
      final saved = <bool>[];
      final music = ThemeMusic(
        output: output,
        saveMuted: (v) async {
          saved.add(v);
        },
      );
      music.select(PiecePackId.anime);
      await music.settled;
      expect(output.playing, isTrue);
      music.toggleMuted();
      music.select(PiecePackId.greek);
      music.select(PiecePackId.futuristic);
      await music.settled;
      expect(output.playing, isFalse);
      expect(saved, [true]);
      music.toggleMuted();
      await music.settled;
      expect(output.current, PiecePackId.futuristic);
      expect(output.playing, isTrue);
      expect(saved, [true, false]);
      music.dispose();
    },
  );
  test(
    'background pauses and foreground respects saved mute preference',
    () async {
      final output = FakeMusicOutput();
      final music = ThemeMusic(
        output: output,
        saveMuted: (_) async {},
        muted: true,
      );
      music.select(PiecePackId.indianEpic);
      music.setActive(false);
      music.setActive(true);
      await music.settled;
      expect(output.playing, isFalse);
      music.toggleMuted();
      await music.settled;
      expect(output.playing, isTrue);
      music.setActive(false);
      await music.settled;
      expect(output.playing, isFalse);
      music.setActive(true);
      await music.settled;
      expect(output.current, PiecePackId.indianEpic);
      expect(output.playing, isTrue);
      music.dispose();
    },
  );
  test('audio failure is contained and can recover', () async {
    final output = FakeMusicOutput()..fail = true;
    final music = ThemeMusic(output: output, saveMuted: (_) async {});
    music.select(PiecePackId.futuristic);
    await music.settled;
    expect(music.unavailable, isTrue);
    output.fail = false;
    music.toggleMuted();
    music.toggleMuted();
    await music.settled;
    expect(music.unavailable, isFalse);
    expect(output.playing, isTrue);
    music.dispose();
  });
  test('cinematic effects follow the global mute setting', () async {
    final output = FakeMusicOutput();
    final music = ThemeMusic(output: output, saveMuted: (_) async {});
    await music.playEffect(CinematicSound.attack);
    music.toggleMuted();
    await music.playEffect(CinematicSound.heavyImpact);
    expect(output.effects, [CinematicSound.attack]);
    music.toggleMuted();
    await music.settled;
    await music.playEffect(CinematicSound.finalStrike);
    await music.playEffect(CinematicSound.victoryApplause);
    expect(output.effects, [
      CinematicSound.attack,
      CinematicSound.finalStrike,
      CinematicSound.victoryApplause,
    ]);
    music.dispose();
  });
  test('avatar check voice and victory cue precede applause', () async {
    final output = FakeMusicOutput();
    final music = ThemeMusic(output: output, saveMuted: (_) async {});

    await music.announceCheck(voice: AvatarVoice.female);
    expect(output.effects, [CinematicSound.checkFemale]);

    await music.announceVictory();
    expect(output.effects, [
      CinematicSound.checkFemale,
      CinematicSound.youWon,
      CinematicSound.victoryApplause,
    ]);
    music.dispose();
  });
  test('background resumes after a cinematic audio interruption', () async {
    final output = FakeMusicOutput();
    final music = ThemeMusic(output: output, saveMuted: (_) async {});
    music.select(PiecePackId.greek);
    await music.settled;
    expect(output.playing, isTrue);

    await music.playEffect(CinematicSound.attack);
    output.playing = false;
    music.resumeBackground();
    await music.settled;

    expect(output.playing, isTrue);
    expect(output.current, PiecePackId.greek);
    music.dispose();
  });

  group('temporary cinematic audio ownership', () {
    test(
      'two leases restore only after the last release and keep settings',
      () async {
        final output = _LeaseMusicOutput();
        final savedMute = <bool>[];
        final savedSelection = <BackgroundMusic>[];
        final music = ThemeMusic(
          output: output,
          saveMuted: (value) async => savedMute.add(value),
          saveSelection: (value) async => savedSelection.add(value),
        );
        music.select(PiecePackId.anime);
        await music.settled;
        final firstRelease = music.suspendBackground();
        final secondRelease = music.suspendBackground();
        await music.settled;
        expect(output.playing, isFalse);

        music.select(PiecePackId.futuristic);
        music.setSelection(BackgroundMusic.epic);
        firstRelease();
        await music.settled;
        expect(output.playing, isFalse);
        expect(output.playCalls, 1);
        expect(music.muted, isFalse);
        expect(savedMute, isEmpty);
        expect(savedSelection, [BackgroundMusic.epic]);

        secondRelease();
        await music.settled;
        expect(output.playing, isTrue);
        expect(output.current, PiecePackId.futuristic);
        expect(output.selection, BackgroundMusic.epic);
        expect(output.playCalls, 2);
        music.dispose();
      },
    );

    test(
      'lifecycle and focus resumes stay silent while a lease is held',
      () async {
        final output = _LeaseMusicOutput();
        final music = ThemeMusic(output: output, saveMuted: (_) async {});
        music.select(PiecePackId.futuristic);
        await music.settled;
        final release = music.suspendBackground();
        await music.settled;
        music.setActive(false);
        music.setActive(true);
        music.resumeBackground();
        await music.settled;
        expect(output.playing, isFalse);
        expect(output.playCalls, 1);

        music.setActive(false);
        release();
        await music.settled;
        expect(output.playing, isFalse);
        expect(output.playCalls, 1);
        music.setActive(true);
        await music.settled;
        expect(output.playing, isTrue);
        expect(output.playCalls, 2);
        music.dispose();
      },
    );

    test(
      'release is idempotent and cannot clear another route lease',
      () async {
        final output = _LeaseMusicOutput();
        final music = ThemeMusic(output: output, saveMuted: (_) async {});
        music.select(PiecePackId.greek);
        await music.settled;
        final firstRelease = music.suspendBackground();
        await music.settled;
        firstRelease();
        await music.settled;
        final secondRelease = music.suspendBackground();
        await music.settled;
        final callsBeforeDuplicate = output.playCalls;
        firstRelease();
        music.resumeBackground();
        await music.settled;
        expect(output.playing, isFalse);
        expect(output.playCalls, callsBeforeDuplicate);
        secondRelease();
        secondRelease();
        await music.settled;
        expect(output.playing, isTrue);
        expect(output.playCalls, callsBeforeDuplicate + 1);
        music.dispose();
      },
    );

    test('release respects the user mute preference', () async {
      final output = _LeaseMusicOutput();
      final saved = <bool>[];
      final music = ThemeMusic(
        output: output,
        saveMuted: (value) async => saved.add(value),
      );
      music.select(PiecePackId.futuristic);
      await music.settled;
      final release = music.suspendBackground();
      music.setMuted(true);
      await music.settled;
      release();
      await music.settled;
      expect(output.playing, isFalse);
      expect(saved, [true]);
      music.setMuted(false);
      await music.settled;
      expect(output.playing, isTrue);
      expect(saved, [true, false]);
      music.dispose();
    });

    test(
      'leased routes suppress underlying effects until every release',
      () async {
        final output = _LeaseMusicOutput();
        final music = ThemeMusic(output: output, saveMuted: (_) async {});
        final firstRelease = music.suspendBackground();
        final secondRelease = music.suspendBackground();
        await music.settled;
        await music.playEffect(CinematicSound.attack);
        await music.announceCheck(voice: AvatarVoice.female);
        firstRelease();
        await music.playEffect(CinematicSound.finalStrike);
        expect(output.effects, isEmpty);
        secondRelease();
        await music.settled;
        await music.playEffect(CinematicSound.lightImpact);
        expect(output.effects, [CinematicSound.lightImpact]);
        music.dispose();
      },
    );

    test(
      'disposal while leased cannot revive playback on late release',
      () async {
        final output = _LeaseMusicOutput();
        final music = ThemeMusic(output: output, saveMuted: (_) async {});
        music.select(PiecePackId.futuristic);
        await music.settled;
        final release = music.suspendBackground();
        await music.settled;
        music.dispose();
        release();
        release();
        await music.settled;
        await music.playEffect(CinematicSound.attack);
        expect(output.disposed, isTrue);
        expect(output.playing, isFalse);
        expect(output.playCalls, 1);
        expect(output.disposeCalls, 1);
        expect(output.effects, isEmpty);
      },
    );

    testWidgets('taking film ownership cancels an older victory sequence', (
      tester,
    ) async {
      final output = _LeaseMusicOutput();
      final music = ThemeMusic(output: output, saveMuted: (_) async {});
      final victory = music.announceVictory(checkmate: true);
      await tester.pump();
      expect(output.effects, [CinematicSound.checkMale]);
      final release = music.suspendBackground();
      await tester.pump();
      release();
      await tester.pump(const Duration(milliseconds: 721));
      await tester.pump(const Duration(milliseconds: 1051));
      await victory;
      expect(output.effects, [CinematicSound.checkMale]);
      music.dispose();
      await tester.pump();
    });
  });
}
