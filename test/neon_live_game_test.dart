// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/domain/game_time_control.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/play/animation_lab_screen.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:battle_chess_arena/src/features/play/capture_battle_overlay.dart';
import 'package:battle_chess_arena/src/features/play/neon_live_arena.dart';
import 'package:battle_chess_arena/src/features/play/neon_live_game_layout.dart';
import 'package:battle_chess_arena/src/services/computer_player.dart';
import 'package:battle_chess_arena/src/services/game_history_storage.dart';
import 'package:battle_chess_arena/src/services/last_game_storage.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auto_play_test.dart'
    show AutoPlayer, PendingAutoPlayer, TestMoveCommentary;

final _neon = piecePacks.singleWhere((p) => p.id == PiecePackId.futuristic);
Finder _key(String key) => find.byKey(ValueKey(key));
ChessBoard _board(WidgetTester tester) =>
    tester.widget<ChessBoard>(find.byType(ChessBoard));
NeonLiveArena _arena(WidgetTester tester) =>
    tester.widget<NeonLiveArena>(find.byType(NeonLiveArena));

SavedGame _saved(
  List<String> moves, {
  Side side = Side.white,
  PlayerMode mode = PlayerMode.local,
  bool classic = false,
}) => SavedGame(
  mode: mode,
  humanSide: side,
  homePack: PiecePackId.futuristic,
  difficulty: ComputerDifficulty.medium,
  moves: moves,
  whiteMilliseconds: 600000,
  blackMilliseconds: 600000,
  fastBattles: true,
  classicPieces: classic,
  whitePack: PiecePackId.futuristic,
  blackPack: PiecePackId.futuristic,
  boardPack: PiecePackId.futuristic,
  updatedAtEpochMs: 1,
  timeControl: GameTimeControl.practice,
);

void _gameTest(String name, Future<void> Function(WidgetTester) body) =>
    testWidgets(name, (tester) async {
      SharedPreferences.setMockInitialValues({});
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        var drained = false;
        GameHistoryStorage().loadSnapshot().then((_) => drained = true);
        for (var i = 0; !drained && i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 10));
        }
        expect(drained, isTrue);
        await tester.binding.setSurfaceSize(null);
      }
    });

Future<void> _open(
  WidgetTester tester, {
  SavedGame? saved,
  PiecePack? pack,
  bool classic = false,
  Size size = const Size(390, 844),
  double scale = 1,
  ComputerPlayer? computer,
}) async {
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: AnimationLabScreen(
        key: UniqueKey(),
        pack: pack ?? _neon,
        savedGame: saved,
        mode: saved?.mode ?? PlayerMode.local,
        humanSide: saved?.humanSide ?? Side.white,
        computerPlayer: computer ?? PendingAutoPlayer(),
        moveCommentary: TestMoveCommentary(),
        initialClassicPieces: classic,
        initialAnimatedArena: true,
        timeControl: GameTimeControl.practice,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
}

Future<void> _tap(WidgetTester tester, Square square) async {
  await tester.tap(_key('square-${square.name}'));
  await tester.pump();
}

Finder _matchScroll() => _key('portrait-match-scroll').evaluate().isNotEmpty
    ? _key('portrait-match-scroll')
    : _key('landscape-match-scroll');

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  for (var i = 0; i < 12 && target.hitTestable().evaluate().isEmpty; i++) {
    await tester.drag(_matchScroll(), const Offset(0, -200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
  }
  expect(target.hitTestable(), findsOneWidget);
}

Future<void> _returnToBoard(WidgetTester tester) async {
  await tester.drag(_matchScroll(), const Offset(0, 1600));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  _gameTest('selection shows only legal victims without playing the move', (
    tester,
  ) async {
    await _open(tester, saved: _saved(['e2e4', 'd7d5']));
    final before = _board(tester).position.fen;
    await _tap(tester, Square.e4);
    final action = _arena(tester).action!;
    expect(action.isSelection, isTrue);
    expect(action.actorOnLeft, isTrue);
    expect(action.actor, Piece.whitePawn);
    expect(action.threats.map((t) => t.square), [Square.d5]);
    expect(action.threats.single.destinations, {Square.d5});
    expect(_board(tester).position.fen, before);
    expect(_board(tester).legalTargets, contains(Square.d5));
    expect(_board(tester).selected, Square.e4);
    expect(tester.takeException(), isNull);
  });

  _gameTest(
    'opponent move vectors appear on left then own selection replaces them',
    (tester) async {
      await _open(tester);
      for (final uci in ['e2e4', 'e7e5', 'b1c3', 'g8f6']) {
        await _tap(tester, Square.fromName(uci.substring(0, 2)));
        await _tap(tester, Square.fromName(uci.substring(2)));
      }
      final action = _arena(tester).action!;
      expect(action.isSelection, isFalse);
      expect(action.actorOnLeft, isFalse);
      expect(action.actor, Piece.blackKnight);
      expect(action.target, Square.f6);
      expect(
        action.threats.any(
          (t) => t.square == Square.e4 && t.piece == Piece.whitePawn,
        ),
        isTrue,
      );
      await _tap(tester, Square.c3);
      expect(_arena(tester).action!.isSelection, isTrue);
      expect(_arena(tester).action!.actorOnLeft, isTrue);
      expect(_arena(tester).action!.source, Square.c3);
      expect(tester.takeException(), isNull);
    },
  );

  _gameTest(
    'Black player selection stays left while board retains Black orientation',
    (tester) async {
      await _open(
        tester,
        saved: _saved(['e2e4'], side: Side.black, mode: PlayerMode.computer),
      );
      await _tap(tester, Square.e7);
      expect(_arena(tester).viewerSide, Side.black);
      expect(_arena(tester).action!.actor, Piece.blackPawn);
      expect(_arena(tester).action!.actorOnLeft, isTrue);
      expect(_board(tester).orientation, Side.black);
      expect(_board(tester).position.turn, Side.black);
    },
  );

  _gameTest('undo clears stale moved actor and threats', (tester) async {
    await _open(tester, saved: _saved(['e2e4', 'e7e5', 'b1c3', 'g8f6']));
    expect(_arena(tester).action!.actor, Piece.blackKnight);
    await tester.tap(find.byTooltip('Undo'));
    await tester.pump();
    expect(_arena(tester).action, isNull);
    expect(_board(tester).position.board.pieceAt(Square.g8), Piece.blackKnight);
  });

  _gameTest(
    'autoplay updates both live lanes and keeps speed controls accessible',
    (tester) async {
      await _open(
        tester,
        saved: _saved([], mode: PlayerMode.computer),
        computer: AutoPlayer(),
      );
      await tester.tap(_key('auto-play-toggle'));
      await tester.pump();
      expect(_key('auto-play-confirmation'), findsOneWidget);
      expect(_board(tester).position.fen, Chess.initial.fen);
      await tester.tap(_key('confirm-auto-play'));
      await tester.pump();
      for (
        var i = 0;
        i < 100 && _arena(tester).action?.target != Square.e4;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(_arena(tester).action!.actor, Piece.whitePawn);
      expect(_arena(tester).action!.actorOnLeft, isTrue);
      await _scrollTo(tester, _key('auto-play-speed'));
      expect(_key('neon-live-controls-button'), findsNothing);
      expect(_key('neon-live-board-button'), findsNothing);
      for (
        var i = 0;
        i < 100 && _arena(tester).action?.target != Square.e5;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(_arena(tester).action!.actor, Piece.blackPawn);
      expect(_arena(tester).action!.actorOnLeft, isFalse);
      await _scrollTo(tester, _key('auto-play-toggle'));
      await tester.tap(_key('auto-play-toggle'));
      await tester.pump();
      await _returnToBoard(tester);
      expect(_board(tester).position.board.pieceAt(Square.e4), Piece.whitePawn);
      expect(_board(tester).position.board.pieceAt(Square.e5), Piece.blackPawn);
      expect(tester.takeException(), isNull);
    },
  );

  _gameTest(
    'Classic Neon retains the illustrated layout from initial selection',
    (tester) async {
      await _open(tester, classic: true);
      expect(find.byType(NeonLiveArena), findsOneWidget);
      expect(_board(tester).appearance!.standardPieces, isTrue);
      expect(_board(tester).showCoordinates, isTrue);
      await _tap(tester, Square.e2);
      expect(_arena(tester).action!.actor, Piece.whitePawn);
    },
  );

  _gameTest('legacy armies keep their regular layout', (tester) async {
    await _open(
      tester,
      pack: piecePacks.singleWhere((p) => p.id == PiecePackId.japanese),
    );
    expect(find.byType(NeonLiveArena), findsNothing);
    expect(find.byType(NeonLiveGameLayout), findsNothing);
    expect(find.byType(ChessBoard), findsOneWidget);
  });

  _gameTest(
    'both swipe directions toggle board pieces while preserving selection',
    (tester) async {
      await _open(tester, saved: _saved(['e2e4', 'd7d5']));
      await _tap(tester, Square.e4);
      final before = _board(tester).position.fen;
      final action = _arena(tester).action;
      for (final delta in [const Offset(-100, 0), const Offset(100, 0)]) {
        final wasClassic = _board(tester).appearance!.standardPieces;
        await tester.drag(find.byType(ChessBoard), delta);
        await tester.pump();
        expect(_board(tester).appearance!.standardPieces, !wasClassic);
        expect(_board(tester).appearance!.white.id, PiecePackId.futuristic);
        expect(_board(tester).appearance!.black.id, PiecePackId.futuristic);
        expect(_board(tester).position.fen, before);
        expect(_board(tester).selected, Square.e4);
        expect(_arena(tester).action, same(action));
        expect(find.byType(NeonLiveGameLayout), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );

  _gameTest('Classic quick toggle keeps the last opponent illustration', (
    tester,
  ) async {
    await _open(tester, saved: _saved(['e2e4', 'e7e5', 'b1c3', 'g8f6']));
    final action = _arena(tester).action;
    await _scrollTo(tester, _key('quick-piece-style-toggle'));
    await tester.tap(_key('quick-piece-style-toggle'));
    await tester.pump();
    expect(_board(tester).appearance!.standardPieces, isTrue);
    expect(_arena(tester).action, same(action));
    expect(_arena(tester).action!.actor, Piece.blackKnight);
  });

  _gameTest(
    'capture after choosing Classic retains the actual defeated victim',
    (tester) async {
      await _open(tester, saved: _saved(['e2e4', 'd7d5'], classic: true));
      await _tap(tester, Square.e4);
      await _tap(tester, Square.d5);
      expect(_arena(tester).action!.captured, Piece.blackPawn);
      expect(_arena(tester).action!.actor, Piece.whitePawn);
      expect(_board(tester).appearance!.standardPieces, isTrue);
      expect(find.byType(CaptureBattleOverlay), findsOneWidget);
      expect(_board(tester).hiddenPieceSquare, isNull);
      expect(_key('live-capture-skip').hitTestable(), findsOneWidget);
      expect(_key('board-moving-e4-d5'), findsOneWidget);
      final victim = tester.getRect(_key('board-captured-d5'));
      final square = tester.getRect(_key('square-d5'));
      expect((victim.center - square.center).distance, lessThan(.1));
      expect(victim.size, square.size);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(760, 330),
  ]) {
    for (final scale in [1.0, 2.0]) {
      _gameTest('action and interactive board fit $size at text scale $scale', (
        tester,
      ) async {
        await _open(tester, size: size, scale: scale);
        final panel = tester.getRect(find.byType(NeonLiveArena));
        final board = tester.getRect(find.byType(ChessBoard));
        if (size.width > size.height) {
          expect(panel.right, lessThanOrEqualTo(board.left));
          expect(panel.top, board.top);
        } else {
          expect(panel.bottom, lessThanOrEqualTo(board.top));
        }
        expect(board.left, greaterThanOrEqualTo(0));
        expect(board.right, lessThanOrEqualTo(size.width));
        expect(board.bottom, lessThanOrEqualTo(size.height));
        await _tap(tester, Square.e2);
        expect(_arena(tester).action!.source, Square.e2);
        expect(_board(tester).selected, Square.e2);
        expect(tester.takeException(), isNull);
      });
    }
  }

  _gameTest(
    'match controls can scroll while action stays visible and board returns',
    (tester) async {
      await _open(tester);
      final initial = tester.getRect(find.byType(NeonLiveArena));
      await _scrollTo(tester, _key('local-opponent-profile'));
      final list = tester.widget<ListView>(_key('portrait-match-scroll'));
      expect(list.controller!.offset, greaterThan(0));
      expect(tester.getRect(find.byType(NeonLiveArena)), initial);
      await _returnToBoard(tester);
      expect(list.controller!.offset, 0);
      await _tap(tester, Square.d2);
      expect(_board(tester).selected, Square.d2);
      expect(tester.takeException(), isNull);
    },
  );

  _gameTest(
    'landscape places animation left and board right with controls below',
    (tester) async {
      await _open(tester, size: const Size(760, 330));
      await _tap(tester, Square.e2);
      final action = _arena(tester).action;
      final panel = tester.getRect(find.byType(NeonLiveArena));
      final board = tester.getRect(find.byType(ChessBoard));
      expect(panel.right, lessThanOrEqualTo(board.left));
      final list = tester.widget<ListView>(_key('landscape-match-scroll'));
      expect(list.controller!.offset, 0);
      await tester.drag(_key('landscape-match-scroll'), const Offset(0, -170));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(list.controller!.offset, greaterThan(0));
      expect(_arena(tester).action, same(action));
      expect(tester.takeException(), isNull);
    },
  );
}
