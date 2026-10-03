// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../domain/online_player_profile.dart';
import '../domain/piece_pack.dart';

enum BackgroundMusic {
  theme,
  rapid,
  zen,
  relaxing,
  inspiring,
  calm,
  focus,
  epic,
}

extension BackgroundMusicDetails on BackgroundMusic {
  String get label => switch (this) {
    BackgroundMusic.theme => 'Chess Set Theme · Default',
    BackgroundMusic.rapid => 'Rapid Chess',
    BackgroundMusic.zen => 'Zen Garden',
    BackgroundMusic.relaxing => 'Relaxing Evening',
    BackgroundMusic.inspiring => 'Inspiring Rise',
    BackgroundMusic.calm => 'Calm Waters',
    BackgroundMusic.focus => 'Deep Focus',
    BackgroundMusic.epic => 'Epic Strategy',
  };
  String assetFor(PiecePackId theme) {
    if (this != BackgroundMusic.theme) return 'audio/mood_$name.wav';
    // Every visual world has its own deterministic, project-original loop.
    // The files contain synthesized oscillators/noise only: no recordings,
    // samples, imported MIDI, or melodies from existing works.
    return 'audio/${theme.name}.wav';
  }
}

BackgroundMusic backgroundMusicFromName(String? name) =>
    BackgroundMusic.values.where((music) => music.name == name).firstOrNull ??
    BackgroundMusic.theme;

enum CinematicSound {
  creditCoin,
  attack,
  lightImpact,
  heavyImpact,
  finalStrike,
  checkMale,
  checkFemale,
  youWon,
  victoryApplause,
}

abstract class MusicOutput {
  Future<void> play(
    PiecePackId theme, {
    BackgroundMusic selection = BackgroundMusic.theme,
  });
  Future<void> playEffect(CinematicSound effect);
  Future<void> pause();
  Future<void> dispose();
}

class AssetMusicOutput implements MusicOutput {
  AudioPlayer? _player;
  AudioPlayer? _effectPlayer;
  String? _loaded;
  @override
  Future<void> play(
    PiecePackId theme, {
    BackgroundMusic selection = BackgroundMusic.theme,
  }) async {
    final player = _player ??= AudioPlayer();
    final asset = selection.assetFor(theme);
    if (_loaded != asset) {
      await player.stop();
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(.3);
      await player.play(AssetSource(asset));
      _loaded = asset;
    } else {
      await player.resume();
    }
  }

  @override
  Future<void> playEffect(CinematicSound effect) async {
    final player = _effectPlayer ??= AudioPlayer();
    await player.stop();
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setVolume(.82);
    await player.play(AssetSource('audio/${effect.name}.wav'));
  }

  @override
  Future<void> pause() async {
    await _player?.pause();
    await _effectPlayer?.stop();
  }

  @override
  Future<void> dispose() async {
    await _player?.dispose();
    await _effectPlayer?.dispose();
  }
}

/// Serializes native operations so rapid theme/mute changes cannot overlap tracks.
class ThemeMusic extends ChangeNotifier {
  ThemeMusic({
    required this.output,
    required this.saveMuted,
    bool muted = false,
    BackgroundMusic selection = BackgroundMusic.theme,
    this.saveSelection,
  }) : _muted = muted,
       _selection = selection;
  static const selectionKey = 'backgroundMusic_v1';
  final Future<void> Function(BackgroundMusic)? saveSelection;
  BackgroundMusic _selection;
  BackgroundMusic get selection => _selection;
  String? saveError;
  final MusicOutput output;
  final Future<void> Function(bool) saveMuted;
  bool _muted;
  bool get muted => _muted;
  bool unavailable = false;
  bool _active = true;
  bool _closed = false;
  PiecePackId? _theme;
  Future<void> _pending = Future.value();
  int _effectSequence = 0;
  Future<void> get settled => _pending;

  void select(PiecePackId theme) {
    if (_theme == theme) return;
    _theme = theme;
    _sync();
  }

  void setActive(bool value) {
    if (_active == value) return;
    _active = value;
    _sync();
  }

  void toggleMuted() {
    setMuted(!_muted);
  }

  void setMuted(bool value) {
    _muted = value;
    saveError = null;
    notifyListeners();
    _pending = _pending.then((_) async {
      try {
        await saveMuted(value);
      } catch (_) {
        if (!_closed) {
          saveError = 'Sound changed, but could not save it. Please try again.';
          notifyListeners();
        }
      }
    });
    _sync();
  }

  void setSelection(BackgroundMusic value) {
    _selection = value;
    saveError = null;
    notifyListeners();
    _pending = _pending.then((_) async {
      try {
        await saveSelection?.call(value);
      } catch (_) {
        if (!_closed) {
          saveError = 'Music changed, but could not save it. Please try again.';
          notifyListeners();
        }
      }
    });
    _sync();
  }

  Future<void> resetToDefaults() {
    setSelection(BackgroundMusic.theme);
    setMuted(false);
    return settled;
  }

  Future<void> playEffect(CinematicSound effect) async {
    _effectSequence++;
    await _playEffect(effect);
  }

  Future<void> _playEffect(CinematicSound effect) async {
    if (_closed || _muted || !_active) return;
    try {
      await output.playEffect(effect);
    } catch (_) {
      if (!_closed) {
        unavailable = true;
        notifyListeners();
      }
    }
  }

  Future<void> announceCheck({AvatarVoice voice = AvatarVoice.male}) =>
      playEffect(
        voice == AvatarVoice.female
            ? CinematicSound.checkFemale
            : CinematicSound.checkMale,
      );

  /// Keeps spoken victory feedback ahead of the applause. A checkmate can
  /// include the character's “Check” call in the same uninterrupted sequence.
  Future<void> announceVictory({
    AvatarVoice voice = AvatarVoice.male,
    bool checkmate = false,
  }) async {
    final sequence = ++_effectSequence;
    if (checkmate) {
      await _playEffect(
        voice == AvatarVoice.female
            ? CinematicSound.checkFemale
            : CinematicSound.checkMale,
      );
      await Future<void>.delayed(const Duration(milliseconds: 720));
      if (_effectSequence != sequence) return;
    }
    await _playEffect(CinematicSound.youWon);
    await Future<void>.delayed(const Duration(milliseconds: 1050));
    if (_effectSequence != sequence) return;
    await _playEffect(CinematicSound.victoryApplause);
  }

  Future<void> announceCheckmateLoss({
    AvatarVoice voice = AvatarVoice.male,
  }) async {
    final sequence = ++_effectSequence;
    await _playEffect(
      voice == AvatarVoice.female
          ? CinematicSound.checkFemale
          : CinematicSound.checkMale,
    );
    await Future<void>.delayed(const Duration(milliseconds: 720));
    if (_effectSequence != sequence) return;
    await _playEffect(CinematicSound.finalStrike);
  }

  /// Restores the selected soundtrack after a platform audio-focus interruption.
  void resumeBackground() => _sync();

  void _sync() {
    _pending = _pending.then((_) async {
      if (_closed) return;
      try {
        if (_muted || !_active || _theme == null) {
          await output.pause();
        } else {
          await output.play(_theme!, selection: _selection);
        }
        if (unavailable && !_closed) {
          unavailable = false;
          notifyListeners();
        }
      } catch (_) {
        if (!_closed) {
          unavailable = true;
          notifyListeners();
        }
      }
    });
  }

  @override
  void dispose() {
    _closed = true;
    unawaited(_pending.then((_) => output.dispose()).catchError((Object _) {}));
    super.dispose();
  }
}

final musicRoutes = RouteObserver<ModalRoute<void>>();

class MusicScope extends InheritedNotifier<ThemeMusic> {
  const MusicScope({
    required ThemeMusic controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);
  static ThemeMusic? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MusicScope>()?.notifier;
}

class MusicButton extends StatelessWidget {
  const MusicButton({this.compact = false, super.key});
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final music = MusicScope.of(context);
    return IconButton(
      tooltip: music?.unavailable == true
          ? 'Music unavailable — tap to mute'
          : music?.muted == true
          ? 'Unmute music'
          : 'Mute music',
      onPressed: music?.toggleMuted,
      padding: compact ? const EdgeInsets.symmetric(horizontal: 2) : null,
      constraints: compact
          ? const BoxConstraints.tightFor(width: 28, height: 40)
          : null,
      style: compact
          ? IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )
          : null,
      icon: Icon(
        music?.muted == true
            ? Icons.volume_off_rounded
            : Icons.volume_up_rounded,
        color: music?.muted == true
            ? const Color(0xFFFF6B6B)
            : const Color(0xFF69F0AE),
      ),
    );
  }
}

/// Restores the visible page's soundtrack when navigating back.
class ThemeSoundtrack extends StatefulWidget {
  const ThemeSoundtrack({required this.theme, required this.child, super.key});
  final PiecePackId theme;
  final Widget child;
  @override
  State<ThemeSoundtrack> createState() => _ThemeSoundtrackState();
}

class _ThemeSoundtrackState extends State<ThemeSoundtrack> with RouteAware {
  ModalRoute<void>? _route;
  ThemeMusic? _music;
  void _select() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && (_route?.isCurrent ?? true)) _music?.select(widget.theme);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _music = MusicScope.of(context);
    final route = ModalRoute.of(context);
    if (route != _route) {
      musicRoutes.unsubscribe(this);
      _route = route;
      if (route != null) musicRoutes.subscribe(this, route);
    }
    _select();
  }

  @override
  void didUpdateWidget(ThemeSoundtrack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.theme != widget.theme) _select();
  }

  @override
  void didPush() => _select();
  @override
  void didPopNext() => _select();
  @override
  void dispose() {
    musicRoutes.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
