// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../domain/piece_pack.dart';

enum CinematicSound {
  attack,
  lightImpact,
  heavyImpact,
  finalStrike,
  victoryApplause,
}

abstract class MusicOutput {
  Future<void> play(PiecePackId theme);
  Future<void> playEffect(CinematicSound effect);
  Future<void> pause();
  Future<void> dispose();
}

class AssetMusicOutput implements MusicOutput {
  AudioPlayer? _player;
  AudioPlayer? _effectPlayer;
  PiecePackId? _loaded;
  @override
  Future<void> play(PiecePackId theme) async {
    final player = _player ??= AudioPlayer();
    if (_loaded != theme) {
      await player.stop();
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(.3);
      await player.play(AssetSource('audio/${theme.name}.wav'));
      _loaded = theme;
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
  }) : _muted = muted;
  final MusicOutput output;
  final Future<void> Function(bool) saveMuted;
  bool _muted;
  bool get muted => _muted;
  bool unavailable = false;
  bool _active = true;
  bool _closed = false;
  PiecePackId? _theme;
  Future<void> _pending = Future.value();
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
    _muted = !_muted;
    notifyListeners();
    final value = _muted;
    _pending = _pending.then((_) async {
      try {
        await saveMuted(value);
      } catch (_) {
        /* Playback still works. */
      }
    });
    _sync();
  }

  Future<void> playEffect(CinematicSound effect) async {
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

  /// Restores the selected soundtrack after a platform audio-focus interruption.
  void resumeBackground() => _sync();

  void _sync() {
    _pending = _pending.then((_) async {
      if (_closed) return;
      try {
        if (_muted || !_active || _theme == null) {
          await output.pause();
        } else {
          await output.play(_theme!);
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
  const MusicButton({super.key});
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
      icon: Icon(music?.muted == true ? Icons.volume_off : Icons.volume_up),
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
