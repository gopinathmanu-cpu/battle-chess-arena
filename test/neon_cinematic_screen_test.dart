// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:ui' as ui;

import 'package:battle_chess_arena/src/domain/animated_army_theme.dart';
import 'package:battle_chess_arena/src/domain/cinematic_replay.dart';
import 'package:battle_chess_arena/src/domain/cinematic_threats.dart';
import 'package:battle_chess_arena/src/domain/neon_cinematic_story.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:battle_chess_arena/src/features/play/neon_cinematic_screen.dart';
import 'package:battle_chess_arena/src/features/play/neon_cinematic_board.dart';
import 'package:battle_chess_arena/src/features/play/neon_illustrated_stage.dart';
import 'package:battle_chess_arena/src/services/cinematic_audio.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _mateMoves = ['f2f3', 'e7e5', 'g2g4', 'd8h4'];
const _captureMoves = ['e2e4', 'd7d5', 'e4d5', 'd8d5', 'g1f3'];
const _result = 'Black wins by checkmate';
final _previewKey = GlobalKey();

Finder _control(String name) => find.byKey(ValueKey('cinematic-$name'));

Future<void> _openFilm(
  WidgetTester tester, {
  AnimatedArmyTheme theme = AnimatedArmyTheme.neon,
  List<String> moves = _mateMoves,
  Size size = const Size(1200, 900),
  double textScale = 1,
  bool reducedMotion = false,
  EdgeInsets insets = EdgeInsets.zero,
  String resultTitle = _result,
  Side? playerSide,
  Side? winnerSide,
  CinematicNarrator? narrator,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reducedMotion,
          padding: insets,
          viewPadding: insets,
        ),
        child: child!,
      ),
      home: RepaintBoundary(
        key: _previewKey,
        child: NeonCinematicScreen(
          theme: theme,
          moves: moves,
          resultTitle: resultTitle,
          playerSide: playerSide,
          winnerSide: winnerSide,
          narrator: narrator ?? _SilentNarrator(),
          score: _SilentScore(),
        ),
      ),
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

ChessBoard _board(WidgetTester tester) =>
    tester.widget<ChessBoard>(find.byType(ChessBoard));

NeonIllustratedStage _stage(WidgetTester tester) =>
    tester.widget<NeonIllustratedStage>(find.byType(NeonIllustratedStage));

double _progress(WidgetTester tester) => _stage(tester).progress;

Future<void> _showControls(WidgetTester tester) async {
  if (_control('timeline').evaluate().isEmpty) {
    await tester.tap(_control('stage'));
    await tester.pump();
  }
}

Future<void> _openBoard(WidgetTester tester) async {
  await _showControls(tester);
  await tester.tap(_control('board'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _closeBoard(WidgetTester tester) async {
  await tester.tap(_control('close-board'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

String _sceneLabel(WidgetTester tester) =>
    tester.widget<Text>(_control('scene-label')).data!;

Future<void> _next(WidgetTester tester) async {
  await _showControls(tester);
  await tester.tap(_control('next'));
  await tester.pump();
}

class _SilentNarrator implements CinematicNarrator {
  @override
  bool get supported => false;
  @override
  Future<void> narrate(String text, {double rate = 1}) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

class _SilentScore implements CinematicScore {
  @override
  Future<void> play({bool ducked = false}) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> impact({bool finale = false}) async {}
  @override
  Future<void> dispose() async {}
}

class _PreviewHeldNarrator implements CinematicNarrator {
  Completer<void>? _pending;
  @override
  bool get supported => true;
  @override
  Future<void> narrate(String text, {double rate = 1}) =>
      (_pending = Completer<void>()).future;
  @override
  Future<void> stop() async {
    if (_pending?.isCompleted == false) _pending!.complete();
    _pending = null;
  }

  @override
  Future<void> dispose() => stop();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final theme in AnimatedArmyTheme.values) {
    testWidgets(
      '${theme.name} film keeps its world and army through move and board inspection',
      (tester) async {
        await _openFilm(
          tester,
          theme: theme,
          moves: _captureMoves,
          resultTitle: 'Game unfinished',
          size: const Size(390, 844),
        );
        expect(
          tester.widget<Text>(_control('theme-title')).data,
          theme.displayName,
        );
        expect(_stage(tester).theme, theme);
        expect(
          tester
              .widget<NeonCinematicBoard>(find.byType(NeonCinematicBoard))
              .theme,
          theme,
        );
        expect(
          tester.widget<Text>(_control('narration')).data,
          contains(theme.whiteFaction),
        );
        tester.widget<Slider>(_control('timeline')).onChanged!(3);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 2300));
        expect(_stage(tester).scene!.san, 'exd5');
        expect(_stage(tester).progress, greaterThanOrEqualTo(.56));
        expect(
          tester.widget<Text>(_control('narration')).data,
          contains("capturing Black's pawn on d5"),
        );
        await _openBoard(tester);
        final board = _board(tester);
        expect(board.appearance!.white.id, theme.packId);
        expect(board.appearance!.black.id, theme.packId);
        expect(board.position.board.pieceAt(Square.d5), Piece.whitePawn);
        expect(board.position.board.pieceAt(Square.e4), isNull);
        await _closeBoard(tester);
        expect(_stage(tester).theme, theme);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }

  for (final (
        name,
        result,
        moves,
        player,
        explicitWinner,
        resolvedWinner,
        encourages,
      )
      in [
        (
          'canonical loss',
          _result,
          _mateMoves,
          Side.white,
          null,
          Side.black,
          true,
        ),
        (
          'opposite perspective',
          _result,
          _mateMoves,
          Side.black,
          null,
          Side.black,
          false,
        ),
        (
          'local spectator',
          _result,
          _mateMoves,
          null,
          Side.black,
          Side.black,
          false,
        ),
        (
          'You Win',
          'You Win!',
          _captureMoves,
          Side.black,
          Side.black,
          Side.black,
          false,
        ),
        (
          'Computer Wins',
          'Computer Wins',
          _captureMoves,
          Side.black,
          Side.white,
          Side.white,
          true,
        ),
        (
          'named opponent',
          'Storm Engine Wins!',
          _captureMoves,
          Side.white,
          Side.black,
          Side.black,
          true,
        ),
        (
          'draw',
          'Game drawn by agreement',
          _mateMoves,
          Side.white,
          Side.black,
          null,
          false,
        ),
        (
          'unfinished',
          'Game unfinished',
          _mateMoves,
          Side.white,
          Side.black,
          null,
          false,
        ),
        (
          'cancelled',
          'Match cancelled',
          _mateMoves,
          Side.white,
          Side.black,
          null,
          false,
        ),
      ]) {
    testWidgets('finale preserves the recorded result for $name', (
      tester,
    ) async {
      final replay = CinematicReplay.fromMoves(
        moves: moves,
        resultTitle: result,
      );
      await _openFilm(
        tester,
        moves: moves,
        resultTitle: result,
        playerSide: player,
        winnerSide: explicitWinner,
      );
      tester.widget<Slider>(_control('timeline')).onChanged!(
        moves.length + 1.0,
      );
      await tester.pump();
      expect(_stage(tester).finale, isTrue);
      expect(_stage(tester).winnerSide, resolvedWinner);
      expect(_stage(tester).resultTitle, result);
      expect(tester.widget<Text>(_control('headline')).data, result);
      final narration = tester.widget<Text>(_control('narration')).data!;
      expect(
        narration.contains('Learn from this game and fight another day.'),
        encourages,
      );
      expect(
        tester
            .widget<NeonCinematicBoard>(find.byType(NeonCinematicBoard))
            .position
            .fen,
        replay.finalPosition.fen,
      );
      expect(
        find.byKey(const ValueKey('neon-victory-white')),
        resolvedWinner == Side.white ? findsOneWidget : findsNothing,
      );
      expect(
        find.byKey(const ValueKey('neon-victory-black')),
        resolvedWinner == Side.black ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }

  testWidgets('action and battlefield remain visible throughout playback', (
    tester,
  ) async {
    final replay = CinematicReplay.fromMoves(moves: _captureMoves);
    await _openFilm(tester, moves: _captureMoves, size: const Size(390, 844));
    final action = tester.getRect(_control('action-pane'));
    final battlefield = tester.getRect(_control('battlefield-pane'));
    expect(action.bottom, lessThanOrEqualTo(battlefield.top));
    expect(action.height, closeTo(battlefield.height, 1));
    expect(
      tester
          .widget<NeonCinematicBoard>(find.byType(NeonCinematicBoard))
          .position
          .fen,
      Chess.initial.fen,
    );
    tester.widget<Slider>(_control('timeline')).onChanged!(3);
    await tester.pump();
    var board = tester.widget<NeonCinematicBoard>(
      find.byType(NeonCinematicBoard),
    );
    expect(board.scene?.source, Square.e4);
    expect(board.scene?.target, Square.d5);
    expect(board.position.fen, replay.scenes[2].before.fen);
    expect(board.progress, _progress(tester));
    expect(find.byKey(const ValueKey('neon-capture-winner')), findsNothing);
    expect(find.byKey(const ValueKey('neon-capture-defeated')), findsNothing);
    await tester.pump(const Duration(milliseconds: 2400));
    board = tester.widget<NeonCinematicBoard>(find.byType(NeonCinematicBoard));
    expect(board.position.fen, replay.scenes[2].after.fen);
    expect(board.progress, _progress(tester));
    expect(find.byKey(const ValueKey('neon-capture-winner')), findsOneWidget);
    expect(find.byKey(const ValueKey('neon-capture-defeated')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1601));
    expect(_control('timeline'), findsNothing);
    expect(find.byType(NeonCinematicBoard), findsOneWidget);
    expect(find.byType(NeonIllustratedStage), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'threat portraits and board highlights use the same after position',
    (tester) async {
      const moves = ['e2e4', 'e7e5', 'f1c4', 'b8c6', 'd1h5'];
      final replay = CinematicReplay.fromMoves(moves: moves);
      final threats = cinematicThreatsAfter(replay.scenes.last);
      await _openFilm(tester, moves: moves, size: const Size(390, 844));
      tester.widget<Slider>(_control('timeline')).onChanged!(5);
      await tester.pump();
      expect(
        _stage(tester).threats.map((t) => t.square),
        threats.map((t) => t.square),
      );
      expect(
        tester
            .widget<NeonCinematicBoard>(find.byType(NeonCinematicBoard))
            .threatSquares,
        isEmpty,
      );
      expect(find.byKey(const ValueKey('neon-threat-bubbles')), findsNothing);
      await tester.pump(const Duration(milliseconds: 1400));
      final board = tester.widget<NeonCinematicBoard>(
        find.byType(NeonCinematicBoard),
      );
      expect(board.threatSquares, threats.map((t) => t.square).toSet());
      expect(board.threatSquares, contains(Square.f7));
      expect(board.position.fen, replay.scenes.last.after.fen);
      expect(
        find.byKey(const ValueKey('neon-threat-black-pawn-f7')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'short landscape with large text retains the full captured figure',
    (tester) async {
      const moves = ['e2e4', 'e7e5', 'f1c4', 'b8c6', 'd1h5', 'g8f6', 'h5f7'];
      await _openFilm(
        tester,
        moves: moves,
        size: const Size(650, 360),
        textScale: 1.5,
        insets: const EdgeInsets.symmetric(vertical: 24),
      );
      tester.widget<Slider>(_control('timeline')).onChanged!(7);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 3600));
      final victim = find.byKey(const ValueKey('film-victim-black-pawn'));
      expect(victim, findsOneWidget);
      expect(tester.getSize(victim).height, greaterThan(20));
      expect(tester.getSize(victim).width, greaterThan(0));
      expect(find.byKey(const ValueKey('neon-capture-winner')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('neon-capture-defeated')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('neon-threat-black-king-e8')),
        findsOneWidget,
      );
      expect(find.byType(NeonCinematicBoard), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('illustrates every recorded move in order and stops on finale', (
    tester,
  ) async {
    final replay = CinematicReplay.fromMoves(moves: _mateMoves);
    final story = NeonCinematicStory(replay);
    await _openFilm(tester);
    expect(_sceneLabel(tester), 'PROLOGUE');
    expect(_stage(tester).intro, isTrue);
    expect(find.byType(ChessBoard), findsNothing);
    await tester.pump(
      story.intro().visualDuration + const Duration(milliseconds: 1),
    );
    await tester.pump();

    for (var index = 0; index < replay.scenes.length; index++) {
      final scene = replay.scenes[index];
      expect(
        _sceneLabel(tester),
        'MOVE ${scene.moveNumber} · ${scene.side == Side.white ? 'WHITE' : 'BLACK'} · ${scene.san}',
      );
      expect(_stage(tester).scene?.before.fen, scene.before.fen);
      expect(_stage(tester).scene?.after.fen, scene.after.fen);
      expect(_stage(tester).scene?.source, scene.source);
      expect(_stage(tester).scene?.target, scene.target);
      expect(
        tester.widget<Text>(_control('headline')).data,
        story.move(index).title,
      );
      final duration = story.move(index).visualDuration.inMilliseconds;
      final landingTime = (duration * .6).round();
      await tester.pump();
      await tester.pump(Duration(milliseconds: landingTime));
      expect(_progress(tester), greaterThanOrEqualTo(.6));
      await tester.pump(Duration(milliseconds: duration - landingTime + 1));
      await tester.pump();
    }

    expect(_sceneLabel(tester), 'FINAL TRANSMISSION');
    expect(_stage(tester).finale, isTrue);
    expect(_stage(tester).resultTitle, _result);
    await _showControls(tester);
    expect(tester.widget<IconButton>(_control('next')).onPressed, isNull);
    await tester.pump(
      story.finale().visualDuration + const Duration(milliseconds: 1),
    );
    await tester.pump();
    expect(find.byTooltip('Play film'), findsOneWidget);
    final finalProgress = _progress(tester);
    await tester.pump(const Duration(seconds: 20));
    expect(_progress(tester), finalProgress);
    await tester.pumpWidget(const SizedBox());
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'pause, previous and timeline seek preserve the recorded history',
    (tester) async {
      final replay = CinematicReplay.fromMoves(moves: _captureMoves);
      await _openFilm(tester, moves: _captureMoves);
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.tap(_control('play-pause'));
      await tester.pump();
      final pausedProgress = _progress(tester);
      await tester.pump(const Duration(seconds: 20));
      expect(_progress(tester), pausedProgress);
      expect(find.byTooltip('Play film'), findsOneWidget);
      await _next(tester);
      expect(_stage(tester).scene?.before.fen, replay.scenes.first.before.fen);
      await _next(tester);
      await _next(tester);
      expect(_sceneLabel(tester), 'MOVE 2 · WHITE · exd5');
      expect(_stage(tester).scene?.before.fen, replay.scenes[2].before.fen);
      expect(_progress(tester), 0);
      await tester.pump(const Duration(seconds: 10));
      expect(_progress(tester), 0);
      await tester.tap(_control('previous'));
      await tester.pump();
      expect(_sceneLabel(tester), 'MOVE 1 · BLACK · d5');
      tester.widget<Slider>(_control('timeline')).onChanged!(4);
      await tester.pump();
      expect(_sceneLabel(tester), 'MOVE 2 · BLACK · Qxd5');
      expect(_stage(tester).scene?.before.fen, replay.scenes[3].before.fen);
      await tester.tap(_control('play-pause'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2640));
      expect(_progress(tester), greaterThan(.56));
      expect(
        _stage(tester).scene?.after.board.pieceAt(Square.d5)?.role,
        Role.queen,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('speed changes affect remaining scene time and replay restarts', (
    tester,
  ) async {
    await _openFilm(tester);
    await tester.tap(_control('speed'));
    await tester.pump();
    expect(find.text('2×'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2501));
    await tester.pump();
    expect(_sceneLabel(tester), 'MOVE 1 · WHITE · f3');
    await tester.tap(_control('speed'));
    await tester.pump();
    expect(find.text('4×'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 551));
    await tester.pump();
    expect(_sceneLabel(tester), 'MOVE 1 · BLACK · e5');
    await tester.tap(_control('speed'));
    await tester.pump();
    expect(find.text('1×'), findsOneWidget);
    tester.widget<Slider>(_control('timeline')).onChanged!(5);
    await tester.pump();
    expect(_sceneLabel(tester), 'FINAL TRANSMISSION');
    await tester.pump(const Duration(seconds: 6));
    await _showControls(tester);
    await tester.tap(_control('replay'));
    await tester.pump();
    expect(_sceneLabel(tester), 'PROLOGUE');
    expect(_stage(tester).intro, isTrue);
    expect(find.byTooltip('Pause film'), findsOneWidget);
    expect(_progress(tester), 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('background pauses playback and a paused film stays paused', (
    tester,
  ) async {
    await _openFilm(tester);
    await tester.pump(const Duration(seconds: 1));
    final firstProgress = _progress(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 10));
    expect(_progress(tester), firstProgress);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(_progress(tester), greaterThan(firstProgress));
    final foregroundProgress = _progress(tester);
    // Some lifecycle providers deliver paused without an inactive event.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 5));
    expect(_progress(tester), foregroundProgress);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(_progress(tester), greaterThan(foregroundProgress));
    await tester.tap(_control('play-pause'));
    await tester.pump();
    final pausedProgress = _progress(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 10));
    expect(_progress(tester), pausedProgress);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion retains readable captions and correct board', (
    tester,
  ) async {
    await _openFilm(tester, moves: _captureMoves, reducedMotion: true);
    await tester.tap(_control('play-pause'));
    await tester.pump();
    await _next(tester);
    await _next(tester);
    await _next(tester);
    expect(_sceneLabel(tester), 'MOVE 2 · WHITE · exd5');
    expect(find.text('White captures a pawn'), findsOneWidget);
    expect(
      tester.widget<Text>(_control('narration')).data,
      contains("White's pawn moves e4 to d5, capturing Black's pawn on d5."),
    );
    expect(
      _stage(tester).scene?.before.board.pieceAt(Square.e4)?.role,
      Role.pawn,
    );
    final progress = _progress(tester);
    await tester.pump(const Duration(seconds: 10));
    expect(_progress(tester), progress);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'board inspection shows opening, pre-move, post-move and finale',
    (tester) async {
      final replay = CinematicReplay.fromMoves(moves: _mateMoves);
      await _openFilm(tester);
      await tester.tap(_control('play-pause'));
      await tester.pump();
      await _openBoard(tester);
      expect(_board(tester).position.fen, Chess.initial.fen);
      await _closeBoard(tester);
      expect(find.byType(ChessBoard), findsNothing);

      await _next(tester);
      await _openBoard(tester);
      expect(_board(tester).position.fen, replay.scenes.first.before.fen);
      expect(_board(tester).lastMoveFrom, Square.f2);
      expect(_board(tester).lastMoveTo, Square.f3);
      await _closeBoard(tester);

      await tester.tap(_control('play-pause'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1400));
      await tester.tap(_control('play-pause'));
      await tester.pump();
      await _openBoard(tester);
      expect(_board(tester).position.fen, replay.scenes.first.after.fen);
      expect(_board(tester).position.board.pieceAt(Square.f3), Piece.whitePawn);
      await _closeBoard(tester);

      tester.widget<Slider>(_control('timeline')).onChanged!(5);
      await tester.pump();
      await _openBoard(tester);
      expect(_board(tester).position.fen, replay.finalPosition.fen);
      expect(_board(tester).position.isCheckmate, isTrue);
      await _closeBoard(tester);
      expect(_sceneLabel(tester), 'FINAL TRANSMISSION');
      expect(_progress(tester), 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('film hides transport after four seconds and stage restores it', (
    tester,
  ) async {
    await _openFilm(tester);
    expect(_control('timeline'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 3999));
    expect(_control('timeline'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2));
    expect(_control('timeline'), findsNothing);
    expect(_control('narration'), findsOneWidget);
    await tester.tap(_control('stage'));
    await tester.pump();
    expect(_control('timeline'), findsOneWidget);
    await tester.tap(_control('play-pause'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    expect(_control('timeline'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  for (final (size, textScale) in [
    (const Size(320, 568), 1.0),
    (const Size(320, 568), 1.5),
    (const Size(650, 360), 1.0),
    (const Size(844, 390), 1.5),
  ]) {
    testWidgets('controls stay reachable at $size with text scale $textScale', (
      tester,
    ) async {
      await _openFilm(tester, size: size, textScale: textScale);
      await tester.tap(_control('play-pause'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      for (final name in [
        'timeline',
        'next',
        'previous',
        'play-pause',
        'speed',
        'narration-toggle',
        'music',
        'piece-toggle',
        'board',
      ]) {
        final bounds = tester.getRect(_control(name));
        expect(bounds.left, greaterThanOrEqualTo(0));
        expect(bounds.top, greaterThanOrEqualTo(0));
        expect(bounds.right, lessThanOrEqualTo(size.width));
        expect(bounds.bottom, lessThanOrEqualTo(size.height));
      }
      tester.widget<Slider>(_control('timeline')).onChanged!(5);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(_control('replay'));
      await tester.tap(_control('replay'));
      await tester.pump();
      expect(_sceneLabel(tester), 'PROLOGUE');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  if (const bool.fromEnvironment('CAPTURE_CINEMATIC_PREVIEWS')) {
    testWidgets('capture actual Black action and result review frames', (
      tester,
    ) async {
      await _loadPreviewFonts(tester);
      const blackKnight = ['e2e4', 'd7d5', 'e4d5', 'g8f6'];
      const blackQueen = ['e2e4', 'd7d5', 'e4d5', 'd8d5'];
      const blackPawn = ['e2e4', 'd7d5', 'e4d5', 'e7e6', 'd5e6', 'f7e6'];
      const whiteThreats = ['e2e4', 'e7e5', 'f1c4', 'b8c6', 'd1h5'];
      const fourThreats = ['b1c3', 'f7f6', 'c3d5', 'g7g5', 'h2h4'];
      await _captureReviewFrame(
        tester,
        'intro-portrait',
        moves: _mateMoves,
        chapter: 0,
      );
      await _captureReviewFrame(
        tester,
        'black-knight-portrait',
        moves: blackKnight,
        chapter: 4,
      );
      await _captureReviewFrame(
        tester,
        'black-queen-capture-strike-portrait',
        moves: blackQueen,
        chapter: 4,
        progress: .47,
      );
      await _captureReviewFrame(
        tester,
        'black-queen-capture-portrait',
        moves: blackQueen,
        chapter: 4,
        progress: .61,
      );
      await _captureReviewFrame(
        tester,
        'black-pawn-capture-portrait',
        moves: blackPawn,
        chapter: 6,
        progress: .61,
      );
      await _captureReviewFrame(
        tester,
        'black-checkmate-portrait',
        moves: _mateMoves,
        chapter: 4,
        resultTitle: _result,
      );
      await _captureReviewFrame(
        tester,
        'white-multiple-threats-portrait',
        moves: whiteThreats,
        chapter: 5,
      );
      await _captureReviewFrame(
        tester,
        'white-four-threats-first-page',
        moves: fourThreats,
        chapter: 5,
      );
      await _captureReviewFrame(
        tester,
        'white-four-threats-second-page',
        moves: fourThreats,
        chapter: 5,
        nextThreatPage: true,
      );
      await _captureReviewFrame(
        tester,
        'black-queen-capture-small-portrait',
        moves: blackQueen,
        chapter: 4,
        size: const Size(320, 568),
        progress: .61,
      );
      await _captureReviewFrame(
        tester,
        'player-loss-finale-portrait',
        moves: _mateMoves,
        chapter: 5,
        resultTitle: _result,
        playerSide: Side.white,
        winnerSide: Side.black,
      );
      await _captureReviewFrame(
        tester,
        'black-win-finale-portrait',
        moves: _mateMoves,
        chapter: 5,
        resultTitle: _result,
        playerSide: Side.black,
        winnerSide: Side.black,
      );
      await _captureReviewFrame(
        tester,
        'white-win-finale-portrait',
        moves: const ['e2e4', 'e7e5', 'f1c4', 'b8c6', 'd1h5', 'g8f6', 'h5f7'],
        chapter: 8,
        resultTitle: 'White wins by checkmate',
        playerSide: Side.white,
        winnerSide: Side.white,
      );
      await _captureReviewFrame(
        tester,
        'unfinished-finale-portrait',
        moves: blackQueen,
        chapter: 5,
      );
      await _captureReviewFrame(
        tester,
        'black-queen-capture-landscape',
        moves: blackQueen,
        chapter: 4,
        size: const Size(650, 360),
        progress: .61,
      );
      await _captureReviewFrame(
        tester,
        'black-queen-capture-landscape-large-text',
        moves: blackQueen,
        chapter: 4,
        size: const Size(650, 360),
        textScale: 1.5,
        insets: const EdgeInsets.symmetric(vertical: 24),
        progress: .61,
      );
      await _captureReviewFrame(
        tester,
        'black-queen-capture-landscape-controls-hidden',
        moves: blackQueen,
        chapter: 4,
        size: const Size(650, 360),
        hideControls: true,
      );
      await _captureReviewFrame(
        tester,
        'black-queen-capture-reduced-motion',
        moves: blackQueen,
        chapter: 4,
        reducedMotion: true,
        progress: .61,
      );
    });

    testWidgets('capture optional cinematic review frames', (tester) async {
      await _loadPreviewFonts(tester);
      const moves = ['e2e4', 'e7e5', 'f1c4', 'b8c6', 'd1h5', 'g8f6', 'h5f7'];
      await _openFilm(
        tester,
        moves: moves,
        resultTitle: 'White wins by checkmate',
      );
      await tester.pump(const Duration(milliseconds: 800));
      await _saveFrame(tester, 'intro-landscape');
      await tester.tap(_control('play-pause'));
      await tester.pump();
      tester.widget<Slider>(_control('timeline')).onChanged!(3);
      await tester.pump();
      await tester.tap(_control('play-pause'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));
      await _saveFrame(tester, 'middle-landscape');
      tester.widget<Slider>(_control('timeline')).onChanged!(7);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 3600));
      await _saveFrame(tester, 'capture-landscape');
      tester.widget<Slider>(_control('timeline')).onChanged!(8);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      await _saveFrame(tester, 'finale-landscape');
      await tester.pumpWidget(const SizedBox());
      await _openFilm(
        tester,
        moves: moves,
        size: const Size(390, 844),
        resultTitle: 'White wins by checkmate',
      );
      await tester.pump(const Duration(milliseconds: 1000));
      await _saveFrame(tester, 'intro-portrait');
      tester.widget<Slider>(_control('timeline')).onChanged!(5);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 880));
      await _saveFrame(tester, 'movement-portrait');
      await tester.pump(const Duration(milliseconds: 550));
      await _saveFrame(tester, 'threats-portrait');
      tester.widget<Slider>(_control('timeline')).onChanged!(7);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 3600));
      await _saveFrame(tester, 'capture-portrait');
      await _showControls(tester);
      tester.widget<Slider>(_control('timeline')).onChanged!(8);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      await _saveFrame(tester, 'finale-portrait');
      await tester.pumpWidget(const SizedBox());
      await _openFilm(
        tester,
        moves: moves,
        size: const Size(650, 360),
        resultTitle: 'White wins by checkmate',
      );
      tester.widget<Slider>(_control('timeline')).onChanged!(7);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 3600));
      await _saveFrame(tester, 'capture-phone-landscape');
      await tester.pumpWidget(const SizedBox());
      await _openFilm(
        tester,
        moves: moves,
        size: const Size(650, 360),
        textScale: 1.5,
        insets: const EdgeInsets.symmetric(vertical: 24),
        resultTitle: 'White wins by checkmate',
      );
      tester.widget<Slider>(_control('timeline')).onChanged!(7);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 3600));
      await _saveFrame(tester, 'capture-landscape-large-text');
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 251));
      await _saveFrame(tester, 'capture-landscape-controls-hidden');
      await tester.pumpWidget(const SizedBox());
      await _openFilm(
        tester,
        moves: const ['e2e4', 'd7d5', 'e4d5', 'd8d5'],
        size: const Size(390, 844),
        resultTitle: 'Game unfinished',
      );
      tester.widget<Slider>(_control('timeline')).onChanged!(4);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 3600));
      await _saveFrame(tester, 'black-capture-portrait');
      await tester.pumpWidget(const SizedBox());
      await _openFilm(
        tester,
        moves: const ['e2e4', 'd7d5', 'e4d5', 'd8d5'],
        size: const Size(650, 360),
        resultTitle: 'Game unfinished',
      );
      tester.widget<Slider>(_control('timeline')).onChanged!(4);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 3600));
      await _saveFrame(tester, 'black-capture-landscape');

      await tester.pumpWidget(const SizedBox());
    });
  }
}

Future<void> _captureReviewFrame(
  WidgetTester tester,
  String name, {
  required List<String> moves,
  required int chapter,
  String resultTitle = 'Game unfinished',
  Side? playerSide,
  Side? winnerSide,
  Size size = const Size(390, 844),
  double textScale = 1,
  EdgeInsets insets = EdgeInsets.zero,
  double progress = .76,
  bool nextThreatPage = false,
  bool hideControls = false,
  bool reducedMotion = false,
}) async {
  await _openFilm(
    tester,
    moves: moves,
    resultTitle: resultTitle,
    playerSide: playerSide,
    winnerSide: winnerSide,
    size: size,
    textScale: textScale,
    insets: insets,
    reducedMotion: reducedMotion,
    narrator: hideControls ? _PreviewHeldNarrator() : null,
  );
  await tester.runAsync(() async {
    await Future.wait([
      for (final name in ['city', 'white-cast', 'black-cast'])
        precacheImage(
          AssetImage('assets/cinematics/neon/$name.png'),
          _previewKey.currentContext!,
        ),
    ]);
  });
  tester.widget<Slider>(_control('timeline')).onChanged!(chapter.toDouble());
  await tester.pump();
  for (var i = 0; i < 1000 && _progress(tester) < progress; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(_progress(tester), greaterThanOrEqualTo(progress));
  expect(_progress(tester), lessThan(progress + .03));
  if (hideControls) {
    for (
      var i = 0;
      i < 500 && _control('timeline').evaluate().isNotEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pump(const Duration(milliseconds: 251));
    expect(_control('timeline'), findsNothing);
    expect(_stage(tester).scene?.ply, chapter);
  } else {
    if (_control('timeline').evaluate().isEmpty) {
      await _showControls(tester);
      // Controls expand into the layout before their buttons become reachable.
      await tester.pump(const Duration(milliseconds: 251));
    }
    await tester.tap(_control('play-pause'));
    await tester.pump();
  }
  if (nextThreatPage) {
    await tester.tap(find.byKey(const ValueKey('neon-threat-page-next')));
    await tester.pump();
    expect(find.text('2 / 2'), findsOneWidget);
  }
  await _saveFrame(tester, name, directoryName: 'build/cinematic-preview-v5');
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

Future<void> _loadPreviewFonts(WidgetTester tester) async {
  await tester.runAsync(() async {
    final packageConfig = io.File('.dart_tool/package_config.json').absolute;
    final data =
        jsonDecode(await packageConfig.readAsString()) as Map<String, dynamic>;
    final flutter = (data['packages'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((package) => package['name'] == 'flutter');
    final flutterPackage = packageConfig.uri.resolve('${flutter['rootUri']}/');
    final fontDirectory = flutterPackage.resolve(
      '../../bin/cache/artifacts/material_fonts/',
    );
    final text = FontLoader('Roboto');
    for (final name in [
      'Roboto-Regular.ttf',
      'Roboto-Bold.ttf',
      'Roboto-Black.ttf',
    ]) {
      text.addFont(
        io.File.fromUri(
          fontDirectory.resolve(name),
        ).readAsBytes().then(ByteData.sublistView),
      );
    }
    await text.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
}

Future<void> _saveFrame(
  WidgetTester tester,
  String name, {
  String directoryName = 'build/cinematic-preview-v4',
}) async {
  // Image assets decode in the real event loop; this opt-in helper keeps
  // screenshots for manual review without maintaining platform-specific goldens.
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
  });
  await tester.pump();
  final boundary =
      _previewKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = io.Directory(directoryName);
    await directory.create(recursive: true);
    await io.File('${directory.path}/$name.png').writeAsBytes(
      bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
    image.dispose();
  });
}
