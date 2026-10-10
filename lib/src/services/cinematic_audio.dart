// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/animated_army_theme.dart';

/// A scene can wait for its narration while pause/seek cancels that wait.
abstract interface class CinematicNarrator {
  bool get supported;
  Future<void> narrate(String text, {double rate = 1});
  Future<void> stop();
  Future<void> dispose();
}

class NativeCinematicNarrator implements CinematicNarrator {
  NativeCinematicNarrator({MethodChannel? channel, TargetPlatform? platform})
    : _channel = channel ?? const MethodChannel(_channelName),
      _platform = platform ?? defaultTargetPlatform;

  static const _channelName = 'battle_chess_arena/cinematic_narration';
  static int _ownerSequence = 0;
  final String _owner = 'film-voice-${++_ownerSequence}';
  final MethodChannel _channel;
  final TargetPlatform _platform;
  Completer<void>? _speech;
  bool _disposed = false;

  @override
  bool get supported => !kIsWeb && _platform == TargetPlatform.android;

  @override
  Future<void> narrate(String text, {double rate = 1}) {
    final narration = text.trim();
    if (_disposed || !supported || narration.isEmpty) return Future.value();
    _finishSpeech();
    final speech = _speech = Completer<void>();
    unawaited(
      _invoke('narrate', {
        'text': narration,
        'rate': rate.isFinite ? rate.clamp(.65, 1.8) : 1.0,
      }).whenComplete(() {
        if (identical(_speech, speech)) _finishSpeech();
      }),
    );
    return speech.future;
  }

  void _finishSpeech() {
    final speech = _speech;
    _speech = null;
    if (speech != null && !speech.isCompleted) speech.complete();
  }

  @override
  Future<void> stop() {
    if (_disposed) return Future.value();
    _finishSpeech();
    return _invoke('stop');
  }

  @override
  Future<void> dispose() {
    if (_disposed) return Future.value();
    _disposed = true;
    _finishSpeech();
    return _invoke('dispose');
  }

  Future<void> _invoke(String method, [Map<String, Object>? arguments]) async {
    if (!supported) return;
    try {
      // Native narrate completes only on onDone/onError/onStop, or cancellation.
      await _channel.invokeMethod<void>(method, {
        ...?arguments,
        'owner': _owner,
      });
    } on MissingPluginException {
      // Captions and timed scenes remain available without a speech plugin.
    } on PlatformException {
      // An unavailable English voice must never prevent the next scene.
    }
  }
}

abstract interface class CinematicScore {
  Future<void> play({bool ducked = false});
  Future<void> pause();
  Future<void> impact({bool finale = false});
  Future<void> dispose();
}

/// Small injectable boundary for verifying ordering without native audio.
abstract interface class CinematicAudioPlayer {
  Future<void> configure({required bool looping});
  Future<void> setVolume(double volume);
  Future<void> playAsset(String asset);
  Future<void> resume();
  Future<void> pause();
  Future<void> stop();
  Future<void> dispose();
}

class _AssetCinematicPlayer implements CinematicAudioPlayer {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> configure({required bool looping}) async {
    // App narration and score deliberately share the output. Effects must not
    // take audio focus away from the installed speech engine.
    await _player.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(audioFocus: AndroidAudioFocus.none),
        iOS: AudioContextIOS(
          options: const {AVAudioSessionOptions.mixWithOthers},
        ),
      ),
    );
    await _player.setReleaseMode(looping ? ReleaseMode.loop : ReleaseMode.stop);
  }

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);
  @override
  Future<void> playAsset(String asset) => _player.play(AssetSource(asset));
  @override
  Future<void> resume() => _player.resume();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> dispose() => _player.dispose();
}

/// Keeps the original film score separate from the app's normal theme music.
/// Commands observe the latest intent, so queued work cannot revive muted audio.
class AssetCinematicScore implements CinematicScore {
  AssetCinematicScore({
    this.theme = AnimatedArmyTheme.neon,
    CinematicAudioPlayer Function()? playerFactory,
  }) : _playerFactory = playerFactory ?? _AssetCinematicPlayer.new;

  static const scoreAsset = 'audio/neon_film_score.wav';
  static const musicVolume = .24;
  static const narrationVolume = .075;
  final AnimatedArmyTheme theme;
  final CinematicAudioPlayer Function() _playerFactory;
  CinematicAudioPlayer? _music;
  CinematicAudioPlayer? _effect;
  Future<void> _pending = Future.value();
  Future<void>? _closing;
  bool _musicLoaded = false;
  bool _wanted = false;
  bool _ducked = false;
  bool _closed = false;
  int _effectSequence = 0;

  Future<void> _enqueue(Future<void> Function() operation) {
    // A decoder error degrades to a silent film and does not poison the queue.
    return _pending = _pending
        .then((_) => operation())
        .catchError((Object _) {});
  }

  @override
  Future<void> play({bool ducked = false}) {
    if (_closed) return Future.value();
    _wanted = true;
    _ducked = ducked;
    return _enqueue(() async {
      if (_closed || !_wanted) return;
      final music = _music ??= _playerFactory();
      if (!_musicLoaded) {
        await music.configure(looping: true);
        if (_closed || !_wanted) return;
        await music.setVolume(_ducked ? narrationVolume : musicVolume);
        if (_closed || !_wanted) return;
        await music.playAsset(theme.scoreAsset);
        _musicLoaded = true;
      } else {
        await music.setVolume(_ducked ? narrationVolume : musicVolume);
        if (_closed || !_wanted) return;
        await music.resume();
      }
    });
  }

  @override
  Future<void> pause() {
    if (_closed) return Future.value();
    _wanted = false;
    _effectSequence++;
    return _enqueue(() async {
      // Always stop effects; they should never spill into a paused scene.
      await _effect?.stop();
      if (_closed || _wanted) return;
      await _music?.pause();
    });
  }

  @override
  Future<void> impact({bool finale = false}) {
    if (_closed || !_wanted) return Future.value();
    final sequence = ++_effectSequence;
    return _enqueue(() async {
      bool valid() => !_closed && _wanted && sequence == _effectSequence;
      if (!valid()) return;
      final effect = _effect ??= _playerFactory();
      await effect.configure(looping: false);
      if (!valid()) return;
      await effect.stop();
      await effect.setVolume(_ducked ? .2 : .38);
      if (!valid()) return;
      await effect.playAsset(
        finale ? 'audio/finalStrike.wav' : 'audio/lightImpact.wav',
      );
    });
  }

  @override
  Future<void> dispose() {
    if (_closing != null) return _closing!;
    _closed = true;
    _wanted = false;
    _effectSequence++;
    return _closing = _enqueue(() async {
      // Release each player independently even when a native dispose fails.
      try {
        await _music?.dispose();
      } finally {
        await _effect?.dispose();
        _music = null;
        _effect = null;
      }
    });
  }
}
