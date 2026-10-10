import 'dart:async';

import 'package:battle_chess_arena/src/domain/animated_army_theme.dart';
import 'package:battle_chess_arena/src/services/cinematic_audio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePlayer implements CinematicAudioPlayer {
  final events = <String>[];
  Completer<void>? configureGate;
  bool failConfiguration = false;

  @override
  Future<void> configure({required bool looping}) async {
    events.add('configure:$looping');
    if (failConfiguration) {
      failConfiguration = false;
      throw PlatformException(code: 'decoder_unavailable');
    }
    await configureGate?.future;
  }

  @override
  Future<void> setVolume(double volume) async => events.add('volume:$volume');
  @override
  Future<void> playAsset(String asset) async => events.add('play:$asset');
  @override
  Future<void> resume() async => events.add('resume');
  @override
  Future<void> pause() async => events.add('pause');
  @override
  Future<void> stop() async => events.add('stop');
  @override
  Future<void> dispose() async => events.add('dispose');
}

Future<void> _flush() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.value();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('film narrator', () {
    const channel = MethodChannel('test/cinematic_narration');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('holds the scene until native speech actually completes', () async {
      final speechDone = Completer<void>();
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'narrate') await speechDone.future;
        return null;
      });
      final narrator = NativeCinematicNarrator(
        channel: channel,
        platform: TargetPlatform.android,
      );
      var finished = false;
      final speech = narrator.narrate('  The city waits.  ', rate: 1.25)
        ..then((_) => finished = true);
      await _flush();
      expect(narrator.supported, isTrue);
      expect(finished, isFalse);
      final arguments = calls.single.arguments as Map;
      expect(arguments['text'], 'The city waits.');
      expect(arguments['rate'], 1.25);
      expect(arguments['owner'], isA<String>());
      speechDone.complete();
      await speech;
      expect(finished, isTrue);
      await narrator.dispose();
    });

    test('stop releases speech immediately even before native reply', () async {
      final nativeDone = Completer<void>();
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        if (call.method == 'narrate') await nativeDone.future;
        return null;
      });
      final narrator = NativeCinematicNarrator(
        channel: channel,
        platform: TargetPlatform.android,
      );
      final speech = narrator.narrate('A knight breaks the silence.');
      await _flush();
      await narrator.stop();
      await expectLater(speech, completes);
      expect(calls, ['narrate', 'stop']);
      nativeDone.complete();
      await narrator.dispose();
    });

    test('a stale reply cannot finish the replacement narration', () async {
      final firstDone = Completer<void>();
      final secondDone = Completer<void>();
      var count = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'narrate') {
          await (count++ == 0 ? firstDone.future : secondDone.future);
        }
        return null;
      });
      final narrator = NativeCinematicNarrator(
        channel: channel,
        platform: TargetPlatform.android,
      );
      final first = narrator.narrate('Opening scene.');
      await _flush();
      var secondFinished = false;
      final second = narrator.narrate('A new scene.')
        ..then((_) => secondFinished = true);
      await expectLater(first, completes);
      firstDone.complete();
      await _flush();
      expect(secondFinished, isFalse);
      secondDone.complete();
      await second;
      expect(secondFinished, isTrue);
      await narrator.dispose();
    });

    test('dispose cancels pending speech and blocks later calls', () async {
      final nativeDone = Completer<void>();
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        if (call.method == 'narrate') await nativeDone.future;
        return null;
      });
      final narrator = NativeCinematicNarrator(
        channel: channel,
        platform: TargetPlatform.android,
      );
      final pending = narrator.narrate('The final stand.');
      await _flush();
      await narrator.dispose();
      await expectLater(pending, completes);
      await narrator.narrate('No more scenes.');
      await narrator.stop();
      await narrator.dispose();
      expect(calls, ['narrate', 'dispose']);
      nativeDone.complete();
    });

    test(
      'unsupported platforms and empty captions complete silently',
      () async {
        var calls = 0;
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls++;
          return null;
        });
        for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
          final narrator = NativeCinematicNarrator(
            channel: channel,
            platform: platform,
          );
          expect(narrator.supported, isFalse);
          await narrator.narrate('A silent city.');
          await narrator.stop();
          await narrator.dispose();
        }
        final android = NativeCinematicNarrator(
          channel: channel,
          platform: TargetPlatform.android,
        );
        await android.narrate('  ');
        expect(calls, 0);
      },
    );

    test('missing plugins and missing voices release scene waits', () async {
      for (final missingPlugin in [true, false]) {
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (missingPlugin) throw MissingPluginException();
          throw PlatformException(code: 'english_voice_unavailable');
        });
        final narrator = NativeCinematicNarrator(
          channel: channel,
          platform: TargetPlatform.android,
        );
        await expectLater(narrator.narrate('The gates open.'), completes);
        await expectLater(narrator.stop(), completes);
        await expectLater(narrator.dispose(), completes);
      }
    });

    test('speech rates stay within the supported dramatic range', () async {
      final rates = <Object?>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'narrate') {
          rates.add((call.arguments as Map)['rate']);
        }
        return null;
      });
      final narrator = NativeCinematicNarrator(
        channel: channel,
        platform: TargetPlatform.android,
      );
      await narrator.narrate('One.', rate: .1);
      await narrator.narrate('Two.', rate: 8);
      await narrator.narrate('Three.', rate: double.nan);
      expect(rates, [.65, 1.8, 1.0]);
      await narrator.dispose();
    });

    test(
      'route instances send separate ownership on narration and cleanup',
      () async {
        final newSpeechDone = Completer<void>();
        final calls = <MethodCall>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'narrate' &&
              (call.arguments as Map)['text'] == 'New film.') {
            await newSpeechDone.future;
          }
          return null;
        });
        final oldNarrator = NativeCinematicNarrator(
          channel: channel,
          platform: TargetPlatform.android,
        );
        final newNarrator = NativeCinematicNarrator(
          channel: channel,
          platform: TargetPlatform.android,
        );
        await oldNarrator.narrate('Old film.');
        var newFinished = false;
        final newSpeech = newNarrator.narrate('New film.')
          ..then((_) => newFinished = true);
        await _flush();
        await oldNarrator.stop();
        await oldNarrator.dispose();
        await _flush();
        expect(newFinished, isFalse);
        final oldOwner = (calls.first.arguments as Map)['owner'];
        final newOwner = (calls[1].arguments as Map)['owner'];
        expect(newOwner, isNot(oldOwner));
        expect((calls[2].arguments as Map)['owner'], oldOwner);
        expect((calls[3].arguments as Map)['owner'], oldOwner);
        newSpeechDone.complete();
        await newSpeech;
        await newNarrator.stop();
        await newNarrator.dispose();
        expect((calls[4].arguments as Map)['owner'], newOwner);
        expect((calls[5].arguments as Map)['owner'], newOwner);
      },
    );
  });

  group('film score', () {
    for (final theme in AnimatedArmyTheme.values) {
      test(
        '${theme.name} score loads once, ducks and cannot revive after dispose',
        () async {
          final music = _FakePlayer();
          final score = AssetCinematicScore(
            theme: theme,
            playerFactory: () => music,
          );
          await score.play(ducked: true);
          await score.play();
          await score.pause();
          await score.play(ducked: true);
          await score.dispose();
          await score.play();
          await score.impact(finale: true);
          await score.dispose();
          expect(music.events, [
            'configure:true',
            'volume:0.075',
            'play:${theme.scoreAsset}',
            'volume:0.24',
            'resume',
            'pause',
            'volume:0.075',
            'resume',
            'dispose',
          ]);
        },
      );
    }

    test(
      'loops its own asset and ducks the score under the narrator',
      () async {
        final music = _FakePlayer();
        final score = AssetCinematicScore(playerFactory: () => music);
        await score.play();
        await score.play(ducked: true);
        await score.play();
        await score.pause();
        await score.play();
        await score.dispose();
        expect(music.events, [
          'configure:true',
          'volume:0.24',
          'play:audio/neon_film_score.wav',
          'volume:0.075',
          'resume',
          'volume:0.24',
          'resume',
          'pause',
          'volume:0.24',
          'resume',
          'dispose',
        ]);
      },
    );

    test('mute during preparation cannot start a stale score', () async {
      final gate = Completer<void>();
      final music = _FakePlayer()..configureGate = gate;
      final score = AssetCinematicScore(playerFactory: () => music);
      final playing = score.play();
      await _flush();
      expect(music.events, ['configure:true']);
      final paused = score.pause();
      gate.complete();
      await Future.wait([playing, paused]);
      expect(music.events, ['configure:true', 'pause']);
      await score.dispose();
    });

    test('dispose wins over queued play and is idempotent', () async {
      final gate = Completer<void>();
      final music = _FakePlayer()..configureGate = gate;
      final score = AssetCinematicScore(playerFactory: () => music);
      final playing = score.play();
      await _flush();
      final closing = score.dispose();
      await score.play();
      await score.pause();
      await score.impact(finale: true);
      gate.complete();
      await Future.wait([playing, closing, score.dispose()]);
      expect(music.events, ['configure:true', 'dispose']);
    });

    test('a decoder error does not poison later playback or cleanup', () async {
      final music = _FakePlayer()..failConfiguration = true;
      final score = AssetCinematicScore(playerFactory: () => music);
      await expectLater(score.play(), completes);
      await score.play();
      await score.dispose();
      expect(music.events, [
        'configure:true',
        'configure:true',
        'volume:0.24',
        'play:audio/neon_film_score.wav',
        'dispose',
      ]);
    });

    test('impacts use a separate softer player and pause stops them', () async {
      final music = _FakePlayer();
      final effect = _FakePlayer();
      var created = 0;
      final score = AssetCinematicScore(
        playerFactory: () => created++ == 0 ? music : effect,
      );
      await score.play(ducked: true);
      await score.impact();
      await score.play();
      await score.impact(finale: true);
      await score.pause();
      await score.impact();
      await score.dispose();
      expect(effect.events, [
        'configure:false',
        'stop',
        'volume:0.2',
        'play:audio/lightImpact.wav',
        'configure:false',
        'stop',
        'volume:0.38',
        'play:audio/finalStrike.wav',
        'stop',
        'dispose',
      ]);
      expect(created, 2);
    });

    test('pause invalidates an impact that is still loading', () async {
      final music = _FakePlayer();
      final gate = Completer<void>();
      final effect = _FakePlayer()..configureGate = gate;
      var created = 0;
      final score = AssetCinematicScore(
        playerFactory: () => created++ == 0 ? music : effect,
      );
      await score.play();
      final impact = score.impact(finale: true);
      await _flush();
      final pause = score.pause();
      gate.complete();
      await Future.wait([impact, pause]);
      expect(effect.events, ['configure:false', 'stop']);
      await score.dispose();
    });
  });
}
