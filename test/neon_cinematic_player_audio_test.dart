import 'dart:async';

import 'package:battle_chess_arena/src/app.dart';
import 'package:battle_chess_arena/src/domain/animated_army_theme.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/home/home_screen.dart';
import 'package:battle_chess_arena/src/domain/cinematic_replay.dart';
import 'package:battle_chess_arena/src/domain/neon_cinematic_story.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:battle_chess_arena/src/features/play/neon_cinematic_screen.dart';
import 'package:battle_chess_arena/src/features/play/neon_cinematic_board.dart';
import 'package:battle_chess_arena/src/features/play/neon_illustrated_stage.dart';
import 'package:battle_chess_arena/src/services/cinematic_audio.dart';
import 'package:battle_chess_arena/src/services/audio_preference_storage.dart';
import 'package:battle_chess_arena/src/services/theme_music.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/types.dart';

import 'theme_music_test.dart' show FakeMusicOutput;

const _moves = ['e2e4', 'd7d5', 'e4d5'];
Finder _control(String name) => find.byKey(ValueKey('cinematic-$name'));
NeonIllustratedStage _stage(WidgetTester tester) =>
    tester.widget<NeonIllustratedStage>(find.byType(NeonIllustratedStage));

class _Speech {
  _Speech(this.text, this.rate);
  final String text;
  final double rate;
  final done = Completer<void>();
  void complete() {
    if (!done.isCompleted) done.complete();
  }
}

class _Narrator implements CinematicNarrator {
  final speeches = <_Speech>[];
  int stops = 0;
  int disposals = 0;
  @override
  bool get supported => true;
  @override
  Future<void> narrate(String text, {double rate = 1}) {
    final speech = _Speech(text, rate);
    speeches.add(speech);
    return speech.done.future;
  }

  // Retaining cancelled futures lets tests model a late native completion.
  @override
  Future<void> stop() async => stops++;
  @override
  Future<void> dispose() async {
    disposals++;
    for (final speech in speeches) {
      speech.complete();
    }
  }
}

class _Score implements CinematicScore {
  final plays = <bool>[];
  final impacts = <bool>[];
  int pauses = 0;
  int disposals = 0;
  bool playing = false;
  @override
  Future<void> play({bool ducked = false}) async {
    playing = true;
    plays.add(ducked);
  }

  @override
  Future<void> pause() async {
    playing = false;
    pauses++;
  }

  @override
  Future<void> impact({bool finale = false}) async => impacts.add(finale);
  @override
  Future<void> dispose() async {
    playing = false;
    disposals++;
  }
}

Future<void> _open(
  WidgetTester tester,
  _Narrator narrator,
  _Score score, {
  AnimatedArmyTheme theme = AnimatedArmyTheme.neon,
  bool observeRoutes = false,
  ThemeMusic? music,
  ClassicPieceStyle classicStyle = ClassicPieceStyle.magneticTeaching,
  List<String> moves = _moves,
  String resultTitle = 'Game complete',
  Side? playerSide,
  Side? winnerSide,
}) async {
  await tester.binding.setSurfaceSize(const Size(900, 650));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final film = NeonCinematicScreen(
    theme: theme,
    moves: moves,
    resultTitle: resultTitle,
    playerSide: playerSide,
    winnerSide: winnerSide,
    classicStyle: classicStyle,
    narrator: narrator,
    score: score,
  );
  await tester.pumpWidget(
    MaterialApp(
      navigatorObservers: observeRoutes ? [musicRoutes] : [],
      home: music == null ? film : MusicScope(controller: music, child: film),
    ),
  );
  for (var frame = 0; frame < 60; frame++) {
    await tester.pump();
    if (tester.widget<IconButton>(_control('narration-toggle')).onPressed !=
        null) {
      return;
    }
  }
  fail('Cinematic audio preferences did not finish loading');
}

Future<void> _controls(WidgetTester tester) async {
  if (_control('timeline').evaluate().isEmpty) {
    await tester.tap(_control('stage'));
    await tester.pump();
  }
}

class _DelayedAudioRead extends InMemorySharedPreferencesStore {
  _DelayedAudioRead(super.data) : super.withData();
  final ready = Completer<void>();
  @override
  Future<Map<String, Object>> getAllWithParameters(
    GetAllParameters parameters,
  ) async {
    await ready.future;
    return super.getAllWithParameters(parameters);
  }
}

class _CountingMusicOutput extends FakeMusicOutput {
  int plays = 0;
  @override
  Future<void> play(
    PiecePackId theme, {
    BackgroundMusic selection = BackgroundMusic.theme,
  }) async {
    plays++;
    await super.play(theme, selection: selection);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final theme in AnimatedArmyTheme.values.where(
    (t) => t != AnimatedArmyTheme.neon,
  )) {
    testWidgets(
      '${theme.name} narration gates chapters and rejects cancelled completion',
      (tester) async {
        final voice = _Narrator();
        final score = _Score();
        await _open(tester, voice, score, theme: theme);
        final intro = voice.speeches.single;
        expect(intro.text, contains(theme.whiteFaction));
        expect(intro.text, contains(theme.blackFaction));
        expect(_stage(tester).theme, theme);
        await tester.pump(const Duration(seconds: 30));
        await tester.pump();
        expect(_stage(tester).intro, isTrue);
        expect(_stage(tester).progress, 1);
        expect(score.plays.last, isTrue);
        await _controls(tester);
        tester.widget<Slider>(_control('timeline')).onChanged!(3);
        await tester.pump();
        final capture = voice.speeches.last;
        expect(capture.text, contains("capturing Black's pawn on d5"));
        expect(capture.text, tester.widget<Text>(_control('narration')).data);
        intro.complete();
        await tester.pump();
        expect(_stage(tester).scene!.san, 'exd5');
        expect(score.plays.last, isTrue);
        await tester.pump(const Duration(seconds: 30));
        await tester.pump();
        expect(_stage(tester).scene!.san, 'exd5');
        expect(_stage(tester).progress, 1);
        expect(score.impacts, [false]);
        capture.complete();
        await tester.pump();
        expect(_stage(tester).finale, isTrue);
        expect(voice.speeches.last.text, contains('The recording ends here.'));
        expect(voice.speeches.last.text, isNot(contains('fight another day')));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        expect(voice.disposals, 1);
        expect(score.disposals, 1);
      },
    );
  }

  testWidgets(
    'a player loss is spoken exactly as captioned and awaits completion',
    (tester) async {
      const moves = ['f2f3', 'e7e5', 'g2g4', 'd8h4'];
      const result = 'Black wins by checkmate';
      final replay = CinematicReplay.fromMoves(
        moves: moves,
        resultTitle: result,
      );
      final voice = _Narrator();
      final score = _Score();
      await _open(
        tester,
        voice,
        score,
        moves: moves,
        resultTitle: result,
        playerSide: Side.white,
        winnerSide: Side.black,
      );
      final intro = voice.speeches.single;
      tester.widget<Slider>(_control('timeline')).onChanged!(5);
      await tester.pump();
      final finale = voice.speeches.last;
      expect(finale.text, tester.widget<Text>(_control('narration')).data);
      expect(
        finale.text,
        contains('Learn from this game and fight another day.'),
      );
      expect(score.plays.last, isTrue);
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      expect(_stage(tester).finale, isTrue);
      expect(_stage(tester).progress, 1);
      expect(_stage(tester).resultTitle, result);
      expect(_stage(tester).winnerSide, Side.black);
      expect(score.impacts, [true]);
      expect(score.playing, isTrue);
      intro.complete();
      await tester.pump();
      expect(score.plays.last, isTrue);
      expect(score.playing, isTrue);
      expect(voice.speeches, hasLength(2));
      await _controls(tester);
      await tester.tap(_control('board'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester.widget<ChessBoard>(find.byType(ChessBoard)).position.fen,
        replay.finalPosition.fen,
      );
      await tester.tap(_control('close-board'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(voice.speeches.last.text, finale.text);
      finale.complete();
      await tester.pump();
      expect(score.playing, isTrue);
      voice.speeches.last.complete();
      await tester.pump();
      await tester.pump();
      expect(find.byTooltip('Play film'), findsOneWidget);
      expect(score.playing, isFalse);
      expect(score.impacts, [true]);
      expect(_stage(tester).resultTitle, result);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  for (final (result, winner, muted, emitsVictory) in [
    ('Black wins on time', Side.black, false, true),
    ('Game drawn by agreement', Side.black, false, false),
    ('Game unfinished', Side.black, false, false),
    ('Match cancelled', Side.black, false, false),
    ('Black wins on time', Side.black, true, false),
  ]) {
    testWidgets('finale sound follows the result and mute: $result / $muted', (
      tester,
    ) async {
      final voice = _Narrator();
      final score = _Score();
      await _open(
        tester,
        voice,
        score,
        resultTitle: result,
        playerSide: Side.white,
        winnerSide: winner,
      );
      if (muted) {
        await tester.tap(_control('music'));
        await tester.pump();
      }
      tester.widget<Slider>(_control('timeline')).onChanged!(4);
      await tester.pump();
      expect(score.impacts, isEmpty);
      await tester.pump(const Duration(milliseconds: 500));
      expect(score.impacts, isEmpty);
      await tester.pump(const Duration(seconds: 20));
      await tester.pump();
      expect(score.impacts, emitsVictory ? [true] : isEmpty);
      final spoken = voice.speeches.last.text;
      expect(spoken, tester.widget<Text>(_control('narration')).data);
      expect(
        spoken.contains('Learn from this game and fight another day.'),
        result == 'Black wins on time',
      );
      await tester.pump(const Duration(seconds: 20));
      expect(score.impacts, emitsVictory ? [true] : isEmpty);
      expect(_stage(tester).resultTitle, result);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }

  testWidgets('capture sound lands with the visible capture and its stamps', (
    tester,
  ) async {
    final voice = _Narrator();
    final score = _Score();
    await _open(tester, voice, score);
    tester.widget<Slider>(_control('timeline')).onChanged!(3);
    await tester.pump();
    for (var i = 0; i < 500 && _stage(tester).progress < .52; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(_stage(tester).progress, greaterThanOrEqualTo(.52));
    expect(_stage(tester).progress, lessThan(.56));
    expect(score.impacts, isEmpty);
    expect(find.byKey(const ValueKey('neon-capture-winner')), findsNothing);
    for (var i = 0; i < 500 && _stage(tester).progress < .57; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(_stage(tester).progress, greaterThanOrEqualTo(.57));
    expect(score.impacts, [false]);
    expect(find.byKey(const ValueKey('neon-capture-winner')), findsOneWidget);
    expect(find.byKey(const ValueKey('neon-capture-defeated')), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
    expect(score.impacts, [false]);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
    'chapter waits for actual narration completion before advancing',
    (tester) async {
      final voice = _Narrator();
      final score = _Score();
      final story = NeonCinematicStory(
        CinematicReplay.fromMoves(moves: _moves),
      );
      await _open(tester, voice, score);
      expect(voice.speeches.single.text, story.intro().narration);
      expect(score.plays.last, isTrue);
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      expect(_stage(tester).intro, isTrue);
      expect(_stage(tester).progress, 1);
      await tester.pump(const Duration(seconds: 20));
      expect(voice.speeches, hasLength(1));
      voice.speeches.single.complete();
      await tester.pump();
      await tester.pump();
      expect(_stage(tester).scene?.san, 'e4');
      expect(voice.speeches.last.text, story.move(0).narration);
      expect(score.plays.last, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets(
    'a cancelled narration completion cannot advance a sought scene',
    (tester) async {
      final voice = _Narrator();
      final score = _Score();
      await _open(tester, voice, score);
      final oldSpeech = voice.speeches.single;
      tester.widget<Slider>(_control('timeline')).onChanged!(3);
      await tester.pump();
      expect(_stage(tester).scene?.san, 'exd5');
      expect(voice.stops, greaterThan(0));
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      expect(_stage(tester).progress, 1);
      oldSpeech.complete();
      await tester.pump();
      expect(_stage(tester).scene?.san, 'exd5');
      expect(score.impacts, [false]);
      voice.speeches.last.complete();
      await tester.pump();
      expect(_stage(tester).finale, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets(
    'pause stops voice and score and resume restarts current narration',
    (tester) async {
      final voice = _Narrator();
      final score = _Score();
      await _open(tester, voice, score);
      await tester.pump(const Duration(seconds: 1));
      final progress = _stage(tester).progress;
      final narration = voice.speeches.single.text;
      await tester.tap(_control('play-pause'));
      await tester.pump();
      expect(voice.stops, 1);
      expect(score.playing, isFalse);
      await tester.pump(const Duration(seconds: 20));
      expect(_stage(tester).progress, progress);
      voice.speeches.single.complete();
      await tester.pump();
      expect(_stage(tester).intro, isTrue);
      await tester.tap(_control('play-pause'));
      await tester.pump();
      expect(voice.speeches, hasLength(2));
      expect(voice.speeches.last.text, narration);
      expect(score.playing, isTrue);
      expect(score.plays.last, isTrue);
      await tester.pump(const Duration(milliseconds: 500));
      expect(_stage(tester).progress, greaterThan(progress));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets(
    'voice and music toggles are independent and music ducks for speech',
    (tester) async {
      final voice = _Narrator();
      final score = _Score();
      await _open(tester, voice, score);
      expect(score.plays.last, isTrue);
      await tester.tap(_control('music'));
      await tester.pump();
      expect(score.playing, isFalse);
      expect(voice.stops, 0);
      expect(voice.speeches, hasLength(1));
      expect(find.byTooltip('Enable soundtrack'), findsOneWidget);
      await tester.tap(_control('narration-toggle'));
      await tester.pump();
      expect(voice.stops, 1);
      expect(score.playing, isFalse);
      expect(find.byTooltip('Enable narration'), findsOneWidget);
      await tester.tap(_control('music'));
      await tester.pump();
      expect(score.playing, isTrue);
      expect(score.plays.last, isFalse);
      expect(voice.speeches, hasLength(1));
      await tester.tap(_control('narration-toggle'));
      await tester.pump();
      expect(voice.speeches, hasLength(2));
      expect(score.plays.last, isTrue);
      voice.speeches.last.complete();
      await tester.pump();
      expect(score.plays.last, isFalse);
      expect(_control('narration'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets('background and board inspection pause both audio and motion', (
    tester,
  ) async {
    final voice = _Narrator();
    final score = _Score();
    await _open(tester, voice, score);
    await tester.pump(const Duration(seconds: 1));
    final progress = _stage(tester).progress;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(score.playing, isFalse);
    expect(voice.stops, 1);
    await tester.pump(const Duration(seconds: 10));
    expect(_stage(tester).progress, progress);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(voice.speeches, hasLength(2));
    expect(score.playing, isTrue);
    await tester.tap(_control('board'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ChessBoard), findsOneWidget);
    expect(voice.stops, 2);
    expect(score.playing, isFalse);
    final boardProgress = _stage(tester).progress;
    await tester.pump(const Duration(seconds: 10));
    expect(_stage(tester).progress, boardProgress);
    await tester.tap(_control('close-board'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ChessBoard), findsNothing);
    expect(voice.speeches, hasLength(3));
    expect(score.playing, isTrue);
    await tester.pump(const Duration(milliseconds: 500));
    expect(_stage(tester).progress, greaterThan(boardProgress));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
    'faster visual playback preserves speech and rejects stale completion',
    (tester) async {
      final voice = _Narrator();
      final score = _Score();
      await _open(tester, voice, score);
      final first = voice.speeches.single;
      await tester.tap(_control('speed'));
      await tester.pump();
      await tester.tap(_control('speed'));
      await tester.pump();
      expect(find.text('4×'), findsOneWidget);
      expect(voice.speeches, hasLength(3));
      expect(voice.speeches.last.rate, lessThanOrEqualTo(1.6));
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      expect(_stage(tester).intro, isTrue);
      expect(_stage(tester).progress, 1);
      first.complete();
      await tester.pump();
      expect(_stage(tester).intro, isTrue);
      voice.speeches.last.complete();
      await tester.pump();
      expect(_stage(tester).scene?.san, 'e4');
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets('disposal releases narrator and score even with pending speech', (
    tester,
  ) async {
    final voice = _Narrator();
    final score = _Score();
    await _open(tester, voice, score);
    await tester.pump(const Duration(seconds: 5));
    await _controls(tester);
    final count = voice.speeches.length;
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(voice.disposals, 1);
    expect(score.disposals, 1);
    expect(score.playing, isFalse);
    await tester.pump(const Duration(seconds: 10));
    expect(voice.speeches, hasLength(count));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('covering routes silence the film and preserve a manual pause', (
    tester,
  ) async {
    final voice = _Narrator();
    final score = _Score();
    await _open(tester, voice, score, observeRoutes: true);
    await tester.pump(const Duration(seconds: 1));
    final progress = _stage(tester).progress;
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push<void>(
      MaterialPageRoute(builder: (_) => const Scaffold(body: Text('Covered'))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(score.playing, isFalse);
    expect(voice.stops, greaterThan(0));
    await tester.pump(const Duration(seconds: 10));
    final covered = tester.widget<NeonIllustratedStage>(
      find.byType(NeonIllustratedStage, skipOffstage: false),
    );
    expect(covered.progress, progress);
    voice.speeches.first.complete();
    await tester.pump();
    navigator.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(score.playing, isTrue);
    expect(voice.speeches, hasLength(2));
    expect(_stage(tester).intro, isTrue);
    await tester.pump(const Duration(milliseconds: 500));
    expect(_stage(tester).progress, greaterThan(progress));
    await _controls(tester);
    await tester.tap(_control('play-pause'));
    await tester.pump();
    final paused = _stage(tester).progress;
    final speeches = voice.speeches.length;
    navigator.push<void>(
      MaterialPageRoute(builder: (_) => const Scaffold(body: Text('Covered'))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    navigator.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 10));
    expect(_stage(tester).progress, paused);
    expect(voice.speeches, hasLength(speeches));
    expect(score.playing, isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
  for (final theme in AnimatedArmyTheme.values) {
    testWidgets('${theme.name} reopens with commentary and music still off', (
      tester,
    ) async {
      final firstVoice = _Narrator(), secondVoice = _Narrator();
      final firstScore = _Score(), secondScore = _Score();
      await _open(tester, firstVoice, firstScore, theme: theme);
      await tester.tap(_control('narration-toggle'));
      await tester.pump();
      await tester.tap(_control('music'));
      await tester.pump();
      expect(await AudioPreferenceStorage.loadCommentaryEnabled(), isFalse);
      expect(await AudioPreferenceStorage.loadMusicMuted(), isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await _open(tester, secondVoice, secondScore, theme: theme);
      expect(secondVoice.speeches, isEmpty);
      expect(secondScore.plays, isEmpty);
      expect(find.byTooltip('Enable narration'), findsOneWidget);
      expect(find.byTooltip('Enable soundtrack'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(_stage(tester).progress, greaterThan(0));
      expect(secondVoice.speeches, isEmpty);
      expect(secondScore.plays, isEmpty);
      await tester.tap(_control('narration-toggle'));
      await tester.pump();
      expect(secondVoice.speeches, hasLength(1));
      expect(secondScore.plays, isEmpty);
      expect(await AudioPreferenceStorage.loadCommentaryEnabled(), isTrue);
      await tester.tap(_control('music'));
      await tester.pump();
      expect(secondScore.playing, isTrue);
      expect(await AudioPreferenceStorage.loadMusicMuted(), isFalse);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }

  testWidgets(
    'delayed muted preference restore starts neither voice nor score early',
    (tester) async {
      SharedPreferences.resetStatic();
      final store = _DelayedAudioRead({
        'flutter.${AudioPreferenceStorage.commentaryEnabledKey}': false,
        'flutter.${AudioPreferenceStorage.musicMutedKey}': true,
      });
      SharedPreferencesStorePlatform.instance = store;
      final voice = _Narrator();
      final score = _Score();
      await tester.pumpWidget(
        MaterialApp(
          home: NeonCinematicScreen(
            moves: _moves,
            resultTitle: 'Game complete',
            narrator: voice,
            score: score,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(_stage(tester).progress, 0);
      expect(voice.speeches, isEmpty);
      expect(score.plays, isEmpty);
      expect(
        tester.widget<IconButton>(_control('narration-toggle')).onPressed,
        isNull,
      );
      store.ready.complete();
      for (
        var frame = 0;
        frame < 60 &&
            tester.widget<IconButton>(_control('narration-toggle')).onPressed ==
                null;
        frame++
      ) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(find.byTooltip('Enable narration'), findsOneWidget);
      expect(find.byTooltip('Enable soundtrack'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(_stage(tester).progress, greaterThan(0));
      expect(voice.speeches, isEmpty);
      expect(score.plays, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets(
    'pause and seek during preference loading keep the requested chapter silent',
    (tester) async {
      SharedPreferences.resetStatic();
      final store = _DelayedAudioRead({});
      SharedPreferencesStorePlatform.instance = store;
      final voice = _Narrator();
      final score = _Score();
      await tester.pumpWidget(
        MaterialApp(
          home: NeonCinematicScreen(
            moves: _moves,
            resultTitle: 'Game complete',
            narrator: voice,
            score: score,
          ),
        ),
      );
      await tester.tap(_control('play-pause'));
      tester.widget<Slider>(_control('timeline')).onChanged!(3);
      await tester.pump();
      expect(_stage(tester).scene!.san, 'exd5');
      expect(_stage(tester).progress, 0);
      store.ready.complete();
      for (
        var frame = 0;
        frame < 60 &&
            tester.widget<IconButton>(_control('narration-toggle')).onPressed ==
                null;
        frame++
      ) {
        await tester.pump();
      }
      await tester.pump(const Duration(seconds: 1));
      expect(_stage(tester).scene!.san, 'exd5');
      expect(_stage(tester).progress, 0);
      expect(voice.speeches, isEmpty);
      expect(score.plays, isEmpty);
      await tester.tap(_control('play-pause'));
      await tester.pump();
      expect(voice.speeches.single.text, contains("capturing Black's pawn"));
      expect(score.playing, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets(
    'film music toggle persists through the shared controller and app restart',
    (tester) async {
      final output = _CountingMusicOutput();
      final music = ThemeMusic(
        output: output,
        saveMuted: AudioPreferenceStorage.saveMusicMuted,
      );
      addTearDown(music.dispose);
      music.select(PiecePackId.futuristic);
      await music.settled;
      final voice = _Narrator();
      final score = _Score();
      await _open(tester, voice, score, music: music);
      expect(output.playing, isFalse);
      await tester.tap(_control('music'));
      await tester.pump();
      await music.settled;
      expect(music.muted, isTrue);
      expect(await AudioPreferenceStorage.loadMusicMuted(), isTrue);
      expect(score.playing, isFalse);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await music.settled;
      expect(output.playing, isFalse);
      final restartedOutput = _CountingMusicOutput();
      await tester.pumpWidget(
        BattleChessArenaApp(
          musicOutput: restartedOutput,
          incomingLinks: const Stream.empty(),
        ),
      );
      await tester.pumpAndSettle();
      final restoredMusic = MusicScope.of(
        tester.element(find.byType(HomeScreen)),
      )!;
      expect(restoredMusic.muted, isTrue);
      expect(restartedOutput.plays, 0);
      expect(find.byTooltip('Unmute music'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'Classic replay toggle preserves chapter, progress, speech and Animated stage',
    (tester) async {
      final voice = _Narrator();
      final score = _Score();
      await _open(tester, voice, score, classicStyle: ClassicPieceStyle.wood);
      tester.widget<Slider>(_control('timeline')).onChanged!(3);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      final before = _stage(tester);
      final speechCount = voice.speeches.length;
      final stops = voice.stops;
      final plays = score.plays.length;
      await tester.tap(_control('piece-toggle'));
      await tester.pump();
      final after = _stage(tester);
      expect(after.theme, before.theme);
      expect(
        after.scene!.resolution.move.uci,
        before.scene!.resolution.move.uci,
      );
      expect(after.progress, before.progress);
      expect(voice.speeches, hasLength(speechCount));
      expect(voice.stops, stops);
      expect(score.plays, hasLength(plays));
      final battlefield = tester.widget<NeonCinematicBoard>(
        find.byType(NeonCinematicBoard),
      );
      expect(battlefield.classicPieces, isTrue);
      expect(battlefield.classicStyle, ClassicPieceStyle.wood);
      expect(find.byTooltip('Use Animated replay pieces'), findsOneWidget);
      await tester.tap(_control('board'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final enlarged = tester.widget<ChessBoard>(find.byType(ChessBoard));
      expect(enlarged.appearance!.standardPieces, isTrue);
      expect(enlarged.appearance!.classicStyle, ClassicPieceStyle.wood);
      await tester.tap(_control('close-board'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final continued = _stage(tester);
      final continuedSpeeches = voice.speeches.length;
      await tester.tap(_control('piece-toggle'));
      await tester.pump();
      expect(
        tester
            .widget<NeonCinematicBoard>(find.byType(NeonCinematicBoard))
            .classicPieces,
        isFalse,
      );
      expect(_stage(tester).progress, continued.progress);
      expect(voice.speeches, hasLength(continuedSpeeches));
      expect(_stage(tester).theme, AnimatedArmyTheme.neon);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
