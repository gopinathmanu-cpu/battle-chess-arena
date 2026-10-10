import 'dart:async';

import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/play/animation_lab_screen.dart';
import 'package:battle_chess_arena/src/features/play/capture_battle_overlay.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:battle_chess_arena/src/services/arena_credit_controller.dart';
import 'package:battle_chess_arena/src/services/computer_player.dart';
import 'package:battle_chess_arena/src/services/last_game_storage.dart';
import 'package:battle_chess_arena/src/services/move_commentary.dart';
import 'package:battle_chess_arena/src/services/audio_preference_storage.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/autoplay.dart';

class AutoPlayer implements ComputerPlayer {
  AutoPlayer({this.moves = const ['e2e4', 'e7e5', 'g1f3', 'b8c6']});

  final List<String> moves;
  int calls = 0;

  @override
  Future<String?> bestMove(
    String fen, {
    ComputerDifficulty difficulty = ComputerDifficulty.medium,
    int? botLevel,
  }) async => moves[calls++ % moves.length];

  @override
  void dispose() {}
}

class PendingAutoPlayer implements ComputerPlayer {
  final requests = <Completer<String?>>[];
  int activeRequests = 0;
  int maximumActiveRequests = 0;

  @override
  Future<String?> bestMove(
    String fen, {
    ComputerDifficulty difficulty = ComputerDifficulty.medium,
    int? botLevel,
  }) async {
    final request = Completer<String?>();
    requests.add(request);
    activeRequests++;
    if (activeRequests > maximumActiveRequests) {
      maximumActiveRequests = activeRequests;
    }
    try {
      return await request.future;
    } finally {
      activeRequests--;
    }
  }

  @override
  void dispose() {
    for (final request in requests) {
      if (!request.isCompleted) request.complete(null);
    }
  }
}

class TestMoveCommentary implements MoveCommentary {
  final spoken = <String>[];
  int stops = 0;
  bool disposed = false;

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> dispose() async => disposed = true;
}

void main() {
  Future<void> openGame(
    WidgetTester tester,
    ComputerPlayer player, {
    Size size = const Size(1200, 1000),
    MoveCommentary? commentary,
    SavedGame? savedGame,
    bool resetPreferences = true,
  }) async {
    if (resetPreferences) SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final credits = ArenaCreditController();
    addTearDown(credits.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ArenaCreditScope(
          controller: credits,
          child: AnimationLabScreen(
            pack: piecePacks.first,
            mode: PlayerMode.computer,
            computerPlayer: player,
            moveCommentary: commentary ?? TestMoveCommentary(),
            savedGame: savedGame,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ChessBoard board(WidgetTester tester) =>
      tester.widget<ChessBoard>(find.byType(ChessBoard).first);

  Future<void> enableAutoPlay(WidgetTester tester) => toggleAutoPlay(tester);

  Future<void> setSpeed(WidgetTester tester, double speed) async {
    final slider = tester.widget<Slider>(
      find.byKey(const ValueKey('auto-play-speed')),
    );
    slider.onChanged!(speed);
    await tester.pump();
  }

  Future<void> expectSourceBlinks(
    WidgetTester tester, {
    required Square from,
    required Square to,
  }) async {
    final piece = board(tester).position.board.pieceAt(from);
    expect(piece, isNotNull);
    expect(board(tester).previewFrom, from);
    expect(board(tester).previewTo, to);
    expect(board(tester).blinkingSquare, from);
    expect(board(tester).previewLit, isTrue);
    await tester.pump();
    for (var halfCycle = 0; halfCycle < 6; halfCycle++) {
      await tester.pump(const Duration(microseconds: 200001));
      if (halfCycle < 5) {
        expect(board(tester).blinkingSquare, from);
        expect(board(tester).previewLit, halfCycle.isOdd);
        expect(board(tester).position.board.pieceAt(from), piece);
        expect(board(tester).position.board.pieceAt(to), isNull);
      }
    }
    expect(board(tester).position.board.pieceAt(from), isNull);
    expect(board(tester).position.board.pieceAt(to), piece);
    expect(board(tester).blinkingSquare, to);
    expect(board(tester).previewLit, isTrue);
  }

  Future<void> expectTargetBlinks(
    WidgetTester tester, {
    required Square from,
    required Square to,
  }) async {
    final piece = board(tester).position.board.pieceAt(to);
    expect(piece, isNotNull);
    await tester.pump();
    for (var halfCycle = 0; halfCycle < 6; halfCycle++) {
      await tester.pump(const Duration(microseconds: 200001));
      expect(board(tester).position.board.pieceAt(from), isNull);
      expect(board(tester).position.board.pieceAt(to), piece);
      if (halfCycle < 5) {
        expect(board(tester).previewFrom, from);
        expect(board(tester).previewTo, to);
        expect(board(tester).blinkingSquare, to);
        expect(board(tester).previewLit, halfCycle.isOdd);
      }
    }
    expect(board(tester).previewFrom, isNull);
    expect(board(tester).blinkingSquare, isNull);
    expect(board(tester).lastMoveFrom, from);
    expect(board(tester).lastMoveTo, to);
    await tester.pump();
  }

  testWidgets(
    'both automated sides wait two seconds, blink source three times, then move and blink target three times',
    (tester) async {
      final player = AutoPlayer();
      await openGame(tester, player);
      await enableAutoPlay(tester);
      await tester.pump(const Duration(milliseconds: 1999));
      expect(player.calls, 0);
      await tester.pump(const Duration(microseconds: 1001));
      expect(player.calls, 1);
      await expectSourceBlinks(tester, from: Square.e2, to: Square.e4);
      await expectTargetBlinks(tester, from: Square.e2, to: Square.e4);

      await tester.pump(const Duration(milliseconds: 1999));
      expect(player.calls, 1);
      expect(board(tester).lastMoveFrom, Square.e2);
      expect(board(tester).lastMoveTo, Square.e4);
      await tester.pump(const Duration(microseconds: 1001));
      expect(player.calls, 2);
      expect(board(tester).lastMoveFrom, Square.e2);
      expect(board(tester).lastMoveTo, Square.e4);
      await expectSourceBlinks(tester, from: Square.e7, to: Square.e5);
      await expectTargetBlinks(tester, from: Square.e7, to: Square.e5);
      await toggleAutoPlay(tester);
      await tester.pump(const Duration(seconds: 12));
      expect(player.calls, 2);
      expect(board(tester).position.board.pieceAt(Square.g1), isNotNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('stopping during source preview cancels the pending move', (
    tester,
  ) async {
    final player = AutoPlayer();
    await openGame(tester, player);
    await enableAutoPlay(tester);
    await tester.pump(const Duration(microseconds: 2000001));
    expect(board(tester).previewFrom, Square.e2);
    await tester.pump(const Duration(milliseconds: 400));
    await toggleAutoPlay(tester);
    await tester.pump(const Duration(seconds: 10));
    expect(board(tester).previewFrom, isNull);
    expect(board(tester).position.board.pieceAt(Square.e2), isNotNull);
    expect(board(tester).position.board.pieceAt(Square.e4), isNull);
    expect(player.calls, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'stopping after commit preserves the move and finishes the normal computer reply',
    (tester) async {
      final player = AutoPlayer();
      await openGame(tester, player);
      await enableAutoPlay(tester);
      await tester.pump(const Duration(microseconds: 2000001));
      await expectSourceBlinks(tester, from: Square.e2, to: Square.e4);
      await toggleAutoPlay(tester);
      await tester.pump();
      expect(board(tester).position.board.pieceAt(Square.e2), isNull);
      expect(board(tester).position.board.pieceAt(Square.e4), isNotNull);
      await tester.pump(const Duration(microseconds: 1200001));
      await tester.pump();
      expect(player.calls, 1);
      await tester.pump(const Duration(milliseconds: 1999));
      expect(player.calls, 1);
      await tester.pump(const Duration(milliseconds: 1));
      expect(player.calls, 2);
      expect(board(tester).previewFrom, Square.e7);
      await expectSourceBlinks(tester, from: Square.e7, to: Square.e5);
      await expectTargetBlinks(tester, from: Square.e7, to: Square.e5);
      await tester.pump(const Duration(seconds: 10));
      expect(player.calls, 2);
      expect(board(tester).position.board.pieceAt(Square.e4), isNotNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'auto speed control appears beneath the board on a narrow phone',
    (tester) async {
      await openGame(tester, AutoPlayer(), size: const Size(390, 844));
      final control = find.byKey(const ValueKey('auto-play-speed-control'));
      expect(control, findsNothing);
      await enableAutoPlay(tester);
      expect(control, findsOneWidget);
      final slider = tester.widget<Slider>(
        find.byKey(const ValueKey('auto-play-speed')),
      );
      expect(slider.value, 1);
      expect(slider.min, 0.5);
      expect(slider.max, 3);
      expect(
        tester.getRect(control).top,
        greaterThanOrEqualTo(tester.getRect(find.byType(ChessBoard)).bottom),
      );
      expect(tester.takeException(), isNull);
      await toggleAutoPlay(tester);
      await tester.pump();
      expect(control, findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final speed in [0.5, 3.0]) {
    testWidgets('$speed× scales both turn gaps and both blink phases', (
      tester,
    ) async {
      final player = AutoPlayer();
      await openGame(tester, player);
      await enableAutoPlay(tester);
      await setSpeed(tester, speed);
      final gap = Duration(microseconds: (2000000 / speed).ceil());
      final blinkPhase = Duration(microseconds: (1200000 / speed).ceil());
      await tester.pump(gap - const Duration(milliseconds: 1));
      expect(player.calls, 0);
      await tester.pump(const Duration(milliseconds: 2));
      expect(player.calls, 1);
      expect(board(tester).blinkingSquare, Square.e2);
      expect(board(tester).position.board.pieceAt(Square.e4), isNull);
      await tester.pump();
      await tester.pump(blinkPhase + const Duration(milliseconds: 1));
      expect(board(tester).blinkingSquare, Square.e4);
      expect(board(tester).position.board.pieceAt(Square.e4), isNotNull);
      await tester.pump();
      await tester.pump(blinkPhase + const Duration(milliseconds: 1));
      expect(board(tester).previewFrom, isNull);
      await tester.pump();
      // Faster target blinks can finish before the accepted Manga animation.
      // The next paced gap begins after both have finished.
      final liveRemainder =
          const Duration(milliseconds: 850) -
          blinkPhase -
          const Duration(milliseconds: 1);
      if (liveRemainder > Duration.zero) {
        await tester.pump(liveRemainder - const Duration(milliseconds: 1));
        expect(player.calls, 1);
        await tester.pump(const Duration(milliseconds: 1));
      }
      await tester.pump(gap - const Duration(milliseconds: 1));
      expect(player.calls, 1);
      await tester.pump(const Duration(milliseconds: 2));
      expect(player.calls, 2);
      expect(board(tester).blinkingSquare, Square.e7);
      await tester.pump();
      await tester.pump(blinkPhase + const Duration(milliseconds: 1));
      expect(board(tester).blinkingSquare, Square.e5);
      expect(board(tester).position.board.pieceAt(Square.e5), isNotNull);
      await tester.pump();
      await tester.pump(blinkPhase + const Duration(milliseconds: 1));
      expect(board(tester).previewFrom, isNull);
      await toggleAutoPlay(tester);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('changing speed adjusts a running gap and source preview', (
    tester,
  ) async {
    final player = AutoPlayer();
    await openGame(tester, player);
    await enableAutoPlay(tester);
    await tester.pump(const Duration(seconds: 1));
    await setSpeed(tester, 3);
    await tester.pump(const Duration(milliseconds: 332));
    expect(player.calls, 0);
    await tester.pump(const Duration(milliseconds: 2));
    expect(player.calls, 1);
    expect(board(tester).blinkingSquare, Square.e2);
    await setSpeed(tester, 1);
    await tester.pump(const Duration(milliseconds: 200));
    await setSpeed(tester, 0.5);
    await tester.pump(const Duration(milliseconds: 1999));
    expect(board(tester).position.board.pieceAt(Square.e4), isNull);
    await tester.pump(const Duration(milliseconds: 2));
    expect(board(tester).position.board.pieceAt(Square.e4), isNotNull);
    expect(board(tester).blinkingSquare, Square.e4);
    expect(player.calls, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('toggles and speed changes do not overlap an engine request', (
    tester,
  ) async {
    final player = PendingAutoPlayer();
    await openGame(tester, player);
    await enableAutoPlay(tester);
    await tester.pump(const Duration(microseconds: 2000001));
    expect(player.requests, hasLength(1));
    await toggleAutoPlay(tester);
    await tester.pump();
    await toggleAutoPlay(tester);
    await tester.pump();
    await setSpeed(tester, 3);
    await tester.pump(const Duration(seconds: 3));
    expect(player.requests, hasLength(1));
    expect(player.maximumActiveRequests, 1);
    player.requests.first.complete('e2e4');
    await tester.pump();
    expect(board(tester).position.board.pieceAt(Square.e4), isNull);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(player.requests, hasLength(2));
    expect(player.maximumActiveRequests, 1);
    await toggleAutoPlay(tester);
    await tester.pump();
    player.requests.last.complete('e2e4');
    await tester.pump(const Duration(seconds: 3));
    expect(board(tester).position.board.pieceAt(Square.e4), isNull);
    expect(player.requests, hasLength(2));
    await tester.pumpWidget(const SizedBox());
  });

  for (final phase in ['gap', 'source', 'target']) {
    testWidgets('disposing during the $phase phase cancels pending work', (
      tester,
    ) async {
      final player = AutoPlayer();
      final commentary = TestMoveCommentary();
      await openGame(tester, player, commentary: commentary);
      await enableAutoPlay(tester);
      if (phase != 'gap') {
        await tester.pump(const Duration(microseconds: 2000001));
        if (phase == 'target') {
          await expectSourceBlinks(tester, from: Square.e2, to: Square.e4);
        }
      }
      final calls = player.calls;
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
      expect(player.calls, calls);
      expect(commentary.disposed, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'backgrounding pauses the source preview and resumes its remainder',
    (tester) async {
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      final player = AutoPlayer();
      await openGame(tester, player);
      await enableAutoPlay(tester);
      await tester.pump(const Duration(microseconds: 2000001));
      await tester.pump();
      await tester.pump(const Duration(microseconds: 200001));
      expect(board(tester).previewLit, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 10));
      expect(board(tester).previewFrom, Square.e2);
      expect(board(tester).previewLit, isFalse);
      expect(board(tester).position.board.pieceAt(Square.e2), isNotNull);
      expect(board(tester).position.board.pieceAt(Square.e4), isNull);
      expect(player.calls, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 999));
      expect(board(tester).position.board.pieceAt(Square.e4), isNull);
      await tester.pump(const Duration(milliseconds: 2));
      expect(board(tester).position.board.pieceAt(Square.e4), isNotNull);
      expect(board(tester).blinkingSquare, Square.e4);
      expect(player.calls, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'move commentary can be toggled and speaks only committed moves',
    (tester) async {
      final commentary = TestMoveCommentary();
      await openGame(tester, AutoPlayer(), commentary: commentary);
      final toggle = find.byKey(const ValueKey('auto-play-commentary-toggle'));
      final caption = find.byKey(
        const ValueKey('auto-play-commentary-caption'),
      );
      expect(toggle, findsNothing);
      await enableAutoPlay(tester);
      expect(toggle, findsOneWidget);
      await tester.pump(const Duration(microseconds: 2000001));
      expect(commentary.spoken, isEmpty);
      expect(caption, findsNothing);
      await expectSourceBlinks(tester, from: Square.e2, to: Square.e4);
      expect(commentary.spoken, ['White pawn moves from e2 to e4.']);
      expect(caption, findsOneWidget);
      expect(find.text('White pawn moves from e2 to e4.'), findsOneWidget);
      await toggleAutoPlay(tester);
      await tester.pump();
      expect(commentary.stops, greaterThan(0));
      expect(caption, findsNothing);
      await expectTargetBlinks(tester, from: Square.e2, to: Square.e4);
      await tester.pump(const Duration(microseconds: 2000001));
      await expectSourceBlinks(tester, from: Square.e7, to: Square.e5);
      expect(commentary.spoken, hasLength(1));
      expect(caption, findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'commentary choice is restored before a new autoplay game speaks',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        AudioPreferenceStorage.commentaryEnabledKey: false,
      });
      final muted = TestMoveCommentary();
      await openGame(
        tester,
        AutoPlayer(),
        commentary: muted,
        resetPreferences: false,
      );
      await enableAutoPlay(tester);
      expect(find.byTooltip('Enable move commentary'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 650));
      expect(muted.spoken, isEmpty);
      await tester.tap(
        find.byKey(const ValueKey('auto-play-commentary-toggle')),
      );
      await tester.pump();
      expect(await AudioPreferenceStorage.loadCommentaryEnabled(), isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      final enabled = TestMoveCommentary();
      await openGame(
        tester,
        AutoPlayer(),
        commentary: enabled,
        resetPreferences: false,
      );
      await enableAutoPlay(tester);
      expect(find.byTooltip('Disable move commentary'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(muted.disposed, isTrue);
      expect(enabled.disposed, isTrue);
    },
  );

  testWidgets(
    'a capture completed in the background retains target blinks before the next turn',
    (tester) async {
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      const saved = SavedGame(
        mode: PlayerMode.computer,
        homePack: PiecePackId.greek,
        difficulty: ComputerDifficulty.easy,
        moves: ['e2e4', 'd7d5'],
        whiteMilliseconds: 600000,
        blackMilliseconds: 600000,
        fastBattles: false,
        whitePack: PiecePackId.greek,
        blackPack: PiecePackId.greek,
        boardPack: PiecePackId.greek,
        updatedAtEpochMs: 1,
      );
      final player = AutoPlayer(moves: ['e4d5', 'd8d5']);
      await openGame(tester, player, savedGame: saved);
      await enableAutoPlay(tester);
      await tester.pump(const Duration(microseconds: 2000001));
      expect(board(tester).previewFrom, Square.e4);
      expect(board(tester).previewTo, Square.d5);
      await tester.pump();
      for (var halfCycle = 0; halfCycle < 6; halfCycle++) {
        await tester.pump(const Duration(microseconds: 200001));
      }
      expect(find.byType(CaptureBattleOverlay), findsOneWidget);
      expect(board(tester).position.board.pieceAt(Square.e4), isNull);
      expect(
        board(tester).position.board.pieceAt(Square.d5)?.color,
        Side.white,
      );
      expect(board(tester).blinkingSquare, isNull);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(CaptureBattleOverlay), findsNothing);
      expect(board(tester).previewFrom, Square.e4);
      expect(board(tester).previewTo, Square.d5);
      expect(board(tester).blinkingSquare, Square.d5);
      expect(board(tester).previewLit, isTrue);
      expect(player.calls, 1);
      await tester.pump(const Duration(seconds: 2));
      expect(board(tester).previewFrom, Square.e4);
      expect(board(tester).blinkingSquare, Square.d5);
      expect(board(tester).previewLit, isTrue);
      expect(player.calls, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await expectTargetBlinks(tester, from: Square.e4, to: Square.d5);
      await tester.pump(const Duration(milliseconds: 1999));
      expect(player.calls, 1);
      await tester.pump(const Duration(microseconds: 1001));
      expect(player.calls, 2);
      expect(board(tester).previewFrom, Square.d8);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('normal computer replies remain silent outside auto-play', (
    tester,
  ) async {
    final commentary = TestMoveCommentary();
    final player = AutoPlayer()..calls = 1;
    await openGame(tester, player, commentary: commentary);
    await tester.tap(find.byKey(const ValueKey('square-e2')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('square-e4')));
    await tester.pump();
    expect(board(tester).previewFrom, isNull);
    // Manga completes its accepted move before the normal reply gap begins.
    await tester.pump(const Duration(milliseconds: 850));
    expect(player.calls, 1);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    await expectSourceBlinks(tester, from: Square.e7, to: Square.e5);
    await expectTargetBlinks(tester, from: Square.e7, to: Square.e5);
    expect(commentary.spoken, isEmpty);
    expect(
      find.byKey(const ValueKey('auto-play-commentary-caption')),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('castling previews, blinks and retains the king destination', (
    tester,
  ) async {
    const saved = SavedGame(
      mode: PlayerMode.computer,
      homePack: PiecePackId.greek,
      difficulty: ComputerDifficulty.easy,
      moves: ['g1f3', 'g8f6', 'e2e4', 'e7e5', 'f1e2', 'f8e7'],
      whiteMilliseconds: 600000,
      blackMilliseconds: 600000,
      fastBattles: false,
      whitePack: PiecePackId.greek,
      blackPack: PiecePackId.greek,
      boardPack: PiecePackId.greek,
      updatedAtEpochMs: 1,
    );
    await openGame(tester, AutoPlayer(moves: ['e1h1']), savedGame: saved);
    await enableAutoPlay(tester);
    await tester.pump(const Duration(microseconds: 2000001));
    await expectSourceBlinks(tester, from: Square.e1, to: Square.g1);
    expect(board(tester).position.board.pieceAt(Square.f1)?.role, Role.rook);
    expect(board(tester).position.board.pieceAt(Square.h1), isNull);
    await expectTargetBlinks(tester, from: Square.e1, to: Square.g1);
    await tester.pumpWidget(const SizedBox());
  });
}
