// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:battle_chess_arena/src/domain/animated_army_theme.dart';
import 'package:battle_chess_arena/src/domain/custom_chess_set.dart';
import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/domain/game_time_control.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/play/animation_lab_screen.dart';
import 'package:battle_chess_arena/src/features/play/animated_move_timing.dart';
import 'package:battle_chess_arena/src/features/play/capture_battle_overlay.dart';
import 'package:battle_chess_arena/src/features/play/checkmate_dialog.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:battle_chess_arena/src/features/play/neon_cinematic_screen.dart';
import 'package:battle_chess_arena/src/features/play/neon_illustrated_stage.dart';
import 'package:battle_chess_arena/src/features/play/neon_live_arena.dart';
import 'package:battle_chess_arena/src/features/play/neon_live_game_layout.dart';
import 'package:battle_chess_arena/src/services/computer_player.dart';
import 'package:battle_chess_arena/src/services/custom_chess_sets.dart';
import 'package:battle_chess_arena/src/services/game_history_storage.dart';
import 'package:battle_chess_arena/src/services/last_game_storage.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auto_play_test.dart' show PendingAutoPlayer, TestMoveCommentary;

Finder _key(String key) => find.byKey(ValueKey(key));
ChessBoard _board(WidgetTester tester) =>
    tester.widget<ChessBoard>(find.byType(ChessBoard));
NeonLiveArena _arena(WidgetTester tester) =>
    tester.widget<NeonLiveArena>(find.byType(NeonLiveArena));
PiecePack _pack(PiecePackId id) =>
    piecePacks.singleWhere((pack) => pack.id == id);

SavedGame _saved(
  PiecePackId pack,
  List<String> moves, {
  bool classic = false,
}) => SavedGame(
  mode: PlayerMode.local,
  homePack: pack,
  difficulty: ComputerDifficulty.medium,
  moves: moves,
  whiteMilliseconds: 600000,
  blackMilliseconds: 600000,
  fastBattles: true,
  whitePack: pack,
  blackPack: pack,
  boardPack: pack,
  classicPieces: classic,
  updatedAtEpochMs: 1,
  timeControl: GameTimeControl.practice,
);

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  var drained = false;
  Object? error;
  GameHistoryStorage().loadSnapshot().then(
    (_) => drained = true,
    onError: (Object failure) {
      error = failure;
      drained = true;
    },
  );
  for (var frame = 0; !drained && frame < 50; frame++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(drained, isTrue);
  expect(error, isNull);
}

void _gameTest(String name, Future<void> Function(WidgetTester) body) =>
    testWidgets(name, (tester) async {
      SharedPreferences.setMockInitialValues({});
      addTearDown(() => tester.binding.setSurfaceSize(null));
      try {
        await body(tester);
      } finally {
        await _close(tester);
      }
    });

Future<void> _open(
  WidgetTester tester, {
  required PiecePackId pack,
  SavedGame? saved,
  Size size = const Size(390, 844),
  double scale = 1,
  PlayerMode mode = PlayerMode.local,
  CustomChessSets? custom,
  NavigatorObserver? observer,
}) async {
  await tester.binding.setSurfaceSize(size);
  Widget app = MaterialApp(
    navigatorObservers: [if (observer != null) observer],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: AnimationLabScreen(
      key: UniqueKey(),
      pack: _pack(pack),
      savedGame: saved,
      mode: mode,
      computerPlayer: PendingAutoPlayer(),
      moveCommentary: TestMoveCommentary(),
      timeControl: GameTimeControl.practice,
    ),
  );
  if (custom != null) app = CustomChessSetScope(controller: custom, child: app);
  await tester.pumpWidget(app);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
}

Future<void> _tap(WidgetTester tester, Square square) async {
  await tester.tap(_key('square-${square.name}'));
  await tester.pump();
}

class _MovieRoutes extends NavigatorObserver {
  MaterialPageRoute<dynamic>? movie;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is MaterialPageRoute && route.fullscreenDialog) movie = route;
  }
}

void main() {
  _gameTest(
    'shared-device Black keeps its lane and facing when a fast selection becomes a move',
    (tester) async {
      for (final theme in AnimatedArmyTheme.values) {
        await _open(
          tester,
          pack: theme.packId,
          saved: _saved(theme.packId, ['e2e4']),
        );
        await _tap(tester, Square.e7);
        await tester.pump(const Duration(milliseconds: 45));
        expect(_arena(tester).action!.actorOnLeft, isFalse);
        final figure = _key('neon-live-right-figure');
        final selectedRect = tester.getRect(figure);
        expect(tester.widget<NeonFigureSprite>(figure).faceRight, isFalse);
        await _tap(tester, Square.e5);
        expect(_arena(tester).action!.actorOnLeft, isFalse);
        expect(tester.widget<NeonFigureSprite>(figure).faceRight, isFalse);
        expect(tester.getRect(figure), selectedRect);
        expect(_board(tester).animateMoves, isTrue);
        expect(_board(tester).animatedMove!.from, Square.e7);
        expect(_board(tester).animatedMove!.to, Square.e5);
        expect(
          _board(tester).position.board.pieceAt(Square.e5),
          Piece.blackPawn,
        );
        await tester.pump(animatedMoveDuration);
        expect(_arena(tester).action!.actorOnLeft, isFalse);
        expect(tester.takeException(), isNull);
        await _close(tester);
      }
    },
  );
  _gameTest(
    'all four armies restore the last move after inherited scopes initialize',
    (tester) async {
      for (final theme in AnimatedArmyTheme.values) {
        final custom = CustomChessSets();
        await custom.ready;
        try {
          final saved = _saved(theme.packId, ['e2e4', 'd7d5'], classic: true);
          await _open(tester, pack: theme.packId, saved: saved, custom: custom);
          expect(tester.takeException(), isNull);
          expect(_arena(tester).theme, theme);
          expect(_arena(tester).action!.isSelection, isFalse);
          expect(_arena(tester).action!.source, Square.d7);
          expect(_arena(tester).action!.target, Square.d5);
          expect(
            _board(tester).position.fen,
            GameSession.fromMoves(moves: saved.moves).position.fen,
          );
          expect(_board(tester).appearance!.standardPieces, isTrue);
        } finally {
          await _close(tester);
          custom.dispose();
        }
      }
    },
  );

  _gameTest(
    'all four armies keep selection pose and actual victim when committing a Classic capture',
    (tester) async {
      for (final theme in AnimatedArmyTheme.values) {
        final initial = _saved(theme.packId, ['e2e4', 'd7d5']);
        await _open(tester, pack: theme.packId, saved: initial);
        expect(_arena(tester).theme, theme);
        expect(_board(tester).showCoordinates, isTrue);
        await _tap(tester, Square.e4);
        await tester.pump(const Duration(milliseconds: 210));
        final selection = _arena(tester).action!;
        expect(selection.isSelection, isTrue);
        expect(selection.threats.single.piece, Piece.blackPawn);
        expect(selection.threats.single.square, Square.d5);
        expect(_board(tester).legalTargets, contains(Square.d5));
        expect(
          tester.widget<NeonFigureSprite>(_key('neon-live-left-figure')).theme,
          theme,
        );
        await tester.drag(find.byType(ChessBoard), const Offset(-100, 0));
        await tester.pump();
        expect(_board(tester).appearance!.standardPieces, isTrue);
        expect(_board(tester).appearance!.white.id, theme.packId);
        expect(_board(tester).appearance!.black.id, theme.packId);
        expect(
          _board(tester).position.fen,
          GameSession.fromMoves(moves: initial.moves).position.fen,
        );
        expect(_arena(tester).theme, theme);
        expect(_arena(tester).action, same(selection));
        final pose = [
          for (final key in [
            'neon-live-actor-lean',
            'neon-live-actor-pose',
            'neon-live-actor-scale',
          ])
            tester.widget<Transform>(_key(key)).transform.clone(),
        ];
        await _tap(tester, Square.d5);
        final moved = _arena(tester).action!;
        expect(moved.isSelection, isFalse);
        expect(moved.actor, Piece.whitePawn);
        expect(moved.captured, Piece.blackPawn);
        expect(moved.source, Square.e4);
        expect(moved.target, Square.d5);
        expect(
          _board(tester).position.board.pieceAt(Square.d5),
          Piece.whitePawn,
        );
        for (final (index, key) in [
          'neon-live-actor-lean',
          'neon-live-actor-pose',
          'neon-live-actor-scale',
        ].indexed) {
          expect(tester.widget<Transform>(_key(key)).transform, pose[index]);
        }
        final defeated = tester.widget<NeonFigureSprite>(
          _key('neon-live-right-figure'),
        );
        expect(defeated.piece, Piece.blackPawn);
        expect(defeated.theme, theme);
        expect(defeated.faceRight, isFalse);
        expect(_key('neon-live-capture-defeated'), findsNothing);
        await tester.pump(
          Duration(
            milliseconds:
                (animatedMoveDuration.inMilliseconds *
                        animatedMoveImpactFraction)
                    .ceil() +
                1,
          ),
        );
        expect(
          tester.widget<Text>(_key('neon-live-right-label')).data,
          allOf(contains('DEFEATED'), contains('BLACK PAWN')),
        );
        expect(find.byType(CaptureBattleOverlay), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _close(tester);
      }
    },
  );

  for (final (size, theme) in [
    (const Size(320, 568), AnimatedArmyTheme.manga),
    (const Size(650, 360), AnimatedArmyTheme.olympian),
  ]) {
    _gameTest(
      'Animated board and quick action fit $size at enlarged text and retain swap after rotation',
      (tester) async {
        await _open(
          tester,
          pack: theme.packId,
          size: size,
          scale: 2,
          mode: PlayerMode.computer,
        );
        final board = tester.getRect(find.byType(ChessBoard));
        final scan = _key('analyse-threats');
        final suggest = _key('use-computer-lifeline');
        expect(scan.hitTestable(), findsOneWidget);
        expect(suggest.hitTestable(), findsOneWidget);
        expect(board.width, closeTo(board.height, .1));
        expect(board.left, greaterThanOrEqualTo(0));
        expect(board.right, lessThanOrEqualTo(size.width));
        expect(board.bottom, lessThanOrEqualTo(size.height));
        expect(_board(tester).showCoordinates, isTrue);
        if (size.width < size.height) {
          expect(tester.getRect(scan).top, greaterThanOrEqualTo(board.bottom));
          expect(tester.getRect(scan).bottom, lessThanOrEqualTo(size.height));
          expect(
            tester.getRect(suggest).top,
            greaterThanOrEqualTo(board.bottom),
          );
          expect(
            tester.getRect(suggest).bottom,
            lessThanOrEqualTo(size.height),
          );
        } else {
          expect(
            tester.getRect(find.byType(NeonLiveArena)).right,
            lessThan(board.left),
          );
          await tester.tap(_key('neon-live-swap-panels'));
          await tester.pump();
          final swapped = tester.getRect(find.byType(ChessBoard));
          expect(
            swapped.right,
            lessThan(tester.getRect(find.byType(NeonLiveArena)).left),
          );
          expect(scan.hitTestable(), findsOneWidget);
          expect(suggest.hitTestable(), findsOneWidget);
          await tester.binding.setSurfaceSize(const Size(360, 650));
          await tester.pump();
          await tester.binding.setSurfaceSize(size);
          await tester.pump();
          expect(
            tester.getRect(find.byType(ChessBoard)).right,
            lessThan(tester.getRect(find.byType(NeonLiveArena)).left),
          );
          expect(_arena(tester).theme, theme);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  _gameTest('legacy and custom armies keep their regular board presentation', (
    tester,
  ) async {
    await _open(tester, pack: PiecePackId.japanese);
    expect(find.byType(NeonLiveArena), findsNothing);
    expect(find.byType(NeonLiveGameLayout), findsNothing);
    expect(_board(tester).showCoordinates, isFalse);
    await _tap(tester, Square.e2);
    expect(_board(tester).legalTargets, contains(Square.e4));
    await _close(tester);

    final custom = CustomChessSets(autoLoad: false);
    addTearDown(custom.dispose);
    expect(
      await custom.save(CustomChessSet.create(id: 'custom-fantasy')),
      isTrue,
    );
    await _open(tester, pack: PiecePackId.indianEpic, custom: custom);
    expect(find.byType(NeonLiveArena), findsNothing);
    expect(_board(tester).appearance!.customSet?.id, 'custom-fantasy');
    expect(_board(tester).showCoordinates, isFalse);
    await _tap(tester, Square.e2);
    expect(_board(tester).legalTargets, contains(Square.e4));
    expect(tester.takeException(), isNull);
  });

  _gameTest(
    'finished Classic games pass their selected world and recorded moves to the movie route',
    (tester) async {
      const moves = ['f2f3', 'e7e5', 'g2g4', 'd8h4'];
      for (final theme in AnimatedArmyTheme.values) {
        final routes = _MovieRoutes();
        await _open(
          tester,
          pack: theme.packId,
          saved: _saved(theme.packId, moves, classic: true),
          observer: routes,
        );
        expect(_board(tester).position.isCheckmate, isTrue);
        final movieButton = _key('finished-match-cinematic');
        for (
          var frame = 0;
          movieButton.evaluate().isEmpty && frame < 12;
          frame++
        ) {
          await tester.drag(
            _key('portrait-match-scroll'),
            const Offset(0, -200),
          );
          await tester.pump(const Duration(milliseconds: 180));
        }
        expect(movieButton, findsOneWidget);
        final source = tester.element(find.byType(AnimationLabScreen));
        final opened = tester
            .widget<CinematicSummaryButton>(movieButton)
            .onPressed();
        final route = routes.movie!;
        // Inspect the actual route's constructor without starting native sound.
        final movie = route.builder(source) as NeonCinematicScreen;
        expect(movie.theme, theme);
        expect(movie.moves, moves);
        expect(movie.winnerSide, Side.black);
        expect(movie.resultTitle, 'Black Wins! · Checkmate');
        route.navigator!.removeRoute(route);
        await opened;
        await tester.pump();
        await tester.drag(_key('portrait-match-scroll'), const Offset(0, 1800));
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          _board(tester).position.fen,
          GameSession.fromMoves(moves: moves).position.fen,
        );
        expect(_board(tester).appearance!.standardPieces, isTrue);
        expect(tester.takeException(), isNull);
        await _close(tester);
      }
    },
  );
}
