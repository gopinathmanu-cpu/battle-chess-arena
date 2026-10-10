// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/domain/neon_live_action.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/play/animated_accepted_capture_cues.dart';
import 'package:battle_chess_arena/src/services/theme_music.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _MusicOutput implements MusicOutput {
  final effects = <CinematicSound>[];

  @override
  Future<void> play(
    PiecePackId theme, {
    BackgroundMusic selection = BackgroundMusic.theme,
  }) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> playEffect(CinematicSound effect) async => effects.add(effect);
  @override
  Future<void> dispose() async {}
}

class _Capture {
  _Capture({
    String fen = '7k/8/8/3p4/4P3/8/8/K7 w - - 0 1',
    String move = 'e4d5',
  }) {
    final game = GameSession(position: Chess.fromSetup(Setup.parseFen(fen)));
    before = game.position;
    final resolution = game.playUci(move)!;
    after = game.position;
    action = NeonLiveAction.move(
      before: before,
      after: after,
      resolution: resolution,
      viewerSide: Side.white,
    )!;
  }

  late final Position before, after;
  late final NeonLiveAction action;
}

class _Frame {
  const _Frame(
    this.position, {
    this.action,
    this.enabled = true,
    this.reduced = false,
  });
  final Position position;
  final NeonLiveAction? action;
  final bool enabled, reduced;
}

void main() {
  Future<void> mount(
    WidgetTester tester,
    ThemeMusic music,
    ValueNotifier<_Frame> frame,
  ) async {
    await tester.pumpWidget(
      MusicScope(
        controller: music,
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<_Frame>(
              valueListenable: frame,
              builder: (context, value, _) => AnimatedAcceptedCaptureCues(
                position: value.position,
                action: value.action,
                enabled: value.enabled,
                reducedMotion: value.reduced,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> close(
    WidgetTester tester,
    ThemeMusic music,
    ValueNotifier<_Frame> frame,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    frame.dispose();
    music.dispose();
    await tester.pump();
  }

  testWidgets('restored capture and fresh selection remain silent', (
    tester,
  ) async {
    final capture = _Capture();
    final output = _MusicOutput();
    final music = ThemeMusic(output: output, saveMuted: (_) async {});
    final frame = ValueNotifier(_Frame(capture.after, action: capture.action));
    await mount(tester, music, frame);
    await tester.pump(const Duration(seconds: 1));
    frame.value = _Frame(
      capture.after,
      action: NeonLiveAction.selection(
        position: capture.after,
        source: Square.h8,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    frame.value = _Frame(capture.after, action: capture.action);
    await tester.pump(const Duration(seconds: 1));
    expect(output.effects, isEmpty);
    expect(tester.takeException(), isNull);
    await close(tester, music, frame);
  });

  testWidgets(
    'accepted capture lands at391ms through duplicate and cleared action',
    (tester) async {
      final capture = _Capture();
      final output = _MusicOutput();
      final music = ThemeMusic(output: output, saveMuted: (_) async {});
      final frame = ValueNotifier(_Frame(capture.before));
      await mount(tester, music, frame);
      frame.value = _Frame(capture.after, action: capture.action);
      await tester.pump();
      expect(output.effects, [CinematicSound.attack]);
      await tester.pump(const Duration(milliseconds: 100));
      frame.value = _Frame(
        Chess.fromSetup(Setup.parseFen(capture.after.fen)),
        action: capture.action,
      );
      await tester.pump();
      // Overlay Skip, a clock revision or a later selection can clear the event.
      frame.value = _Frame(capture.after);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 290));
      expect(output.effects, [CinematicSound.attack]);
      await tester.pump(const Duration(milliseconds: 1));
      expect(output.effects, [
        CinematicSound.attack,
        CinematicSound.lightImpact,
      ]);
      frame.value = _Frame(capture.after, action: capture.action);
      await tester.pump(const Duration(seconds: 2));
      expect(output.effects, [
        CinematicSound.attack,
        CinematicSound.lightImpact,
      ]);
      expect(
        tester.getSize(find.byType(AnimatedAcceptedCaptureCues)),
        Size.zero,
      );
      expect(tester.takeException(), isNull);
      await close(tester, music, frame);
    },
  );

  testWidgets('reduced motion immediately sounds one accepted capture', (
    tester,
  ) async {
    final capture = _Capture();
    final output = _MusicOutput();
    final music = ThemeMusic(output: output, saveMuted: (_) async {});
    final frame = ValueNotifier(_Frame(capture.before, reduced: true));
    await mount(tester, music, frame);
    frame.value = _Frame(capture.after, action: capture.action, reduced: true);
    await tester.pump();
    expect(output.effects, [CinematicSound.attack, CinematicSound.lightImpact]);
    await tester.pump(const Duration(seconds: 1));
    expect(output.effects, [CinematicSound.attack, CinematicSound.lightImpact]);
    await close(tester, music, frame);
  });

  testWidgets(
    'background pauses impact and resumes its remaining board clock',
    (tester) async {
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      final capture = _Capture();
      final output = _MusicOutput();
      final music = ThemeMusic(output: output, saveMuted: (_) async {});
      final frame = ValueNotifier(_Frame(capture.before));
      await mount(tester, music, frame);
      frame.value = _Frame(capture.after, action: capture.action);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      music.setActive(false);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 3));
      expect(output.effects, [CinematicSound.attack]);
      music.setActive(true);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 290));
      expect(output.effects, [CinematicSound.attack]);
      await tester.pump(const Duration(milliseconds: 2));
      expect(output.effects, [
        CinematicSound.attack,
        CinematicSound.lightImpact,
      ]);
      await close(tester, music, frame);
    },
  );

  testWidgets(
    'capture accepted in background waits for resumed board movement',
    (tester) async {
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      final capture = _Capture();
      final output = _MusicOutput();
      final music = ThemeMusic(output: output, saveMuted: (_) async {});
      final frame = ValueNotifier(_Frame(capture.before));
      await mount(tester, music, frame);
      music.setActive(false);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      frame.value = _Frame(capture.after, action: capture.action);
      await tester.pump(const Duration(seconds: 1));
      expect(output.effects, isEmpty);
      music.setActive(true);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(output.effects, [CinematicSound.attack]);
      await tester.pump(const Duration(milliseconds: 391));
      expect(output.effects, [
        CinematicSound.attack,
        CinematicSound.lightImpact,
      ]);
      await close(tester, music, frame);
    },
  );

  testWidgets(
    'disabled legacy owner and re-enabling a snapshot do not duplicate cues',
    (tester) async {
      final capture = _Capture();
      final output = _MusicOutput();
      final music = ThemeMusic(output: output, saveMuted: (_) async {});
      final frame = ValueNotifier(_Frame(capture.before, enabled: false));
      await mount(tester, music, frame);
      frame.value = _Frame(
        capture.after,
        action: capture.action,
        enabled: false,
      );
      await tester.pump();
      frame.value = _Frame(capture.after, action: capture.action);
      await tester.pump(const Duration(seconds: 1));
      expect(output.effects, isEmpty);
      await close(tester, music, frame);
    },
  );

  for (final (fen, move) in [
    ('7k/8/8/8/4P3/8/8/K7 w - - 0 1', 'e4e5'),
    ('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1', 'e1g1'),
  ]) {
    testWidgets('accepted $move has no capture cue', (tester) async {
      final moveFixture = _Capture(fen: fen, move: move);
      final output = _MusicOutput();
      final music = ThemeMusic(output: output, saveMuted: (_) async {});
      final frame = ValueNotifier(_Frame(moveFixture.before));
      await mount(tester, music, frame);
      frame.value = _Frame(moveFixture.after, action: moveFixture.action);
      await tester.pump(const Duration(seconds: 1));
      expect(output.effects, isEmpty);
      await close(tester, music, frame);
    });
  }

  for (final (fen, move, effect) in [
    ('7k/8/8/3p4/4Q3/8/8/K7 w - - 0 1', 'e4d5', CinematicSound.heavyImpact),
    ('7k/8/8/3p4/3R4/8/8/K7 w - - 0 1', 'd4d5', CinematicSound.heavyImpact),
    ('7k/8/8/3p4/4K3/8/8/8 w - - 0 1', 'e4d5', CinematicSound.heavyImpact),
    ('7k/8/8/3p4/2B5/8/8/K7 w - - 0 1', 'c4d5', CinematicSound.lightImpact),
    ('7k/8/8/3p4/5N2/8/8/K7 w - - 0 1', 'f4d5', CinematicSound.lightImpact),
    ('7k/6r1/5KQ1/8/8/8/8/8 w - - 0 1', 'g6g7', CinematicSound.finalStrike),
  ]) {
    testWidgets('$move uses its accepted role or checkmate impact', (
      tester,
    ) async {
      final capture = _Capture(fen: fen, move: move);
      final output = _MusicOutput();
      final music = ThemeMusic(output: output, saveMuted: (_) async {});
      final frame = ValueNotifier(_Frame(capture.before));
      await mount(tester, music, frame);
      frame.value = _Frame(capture.after, action: capture.action);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 391));
      expect(output.effects, [CinematicSound.attack, effect]);
      expect(tester.takeException(), isNull);
      await close(tester, music, frame);
    });
  }
}
