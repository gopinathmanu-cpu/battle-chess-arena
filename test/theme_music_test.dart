import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/services/theme_music.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeMusicOutput implements MusicOutput {
  PiecePackId? current;
  bool playing = false;
  bool fail = false;
  bool disposed = false;
  final effects = <CinematicSound>[];
  @override
  Future<void> play(PiecePackId theme) async {
    if (fail) throw StateError('audio unavailable');
    current = theme;
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

void main() {
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
    music.select(PiecePackId.classic);
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
}
