// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:battle_chess_arena/src/domain/animated_army_theme.dart';
import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/domain/online_game_session.dart';
import 'package:battle_chess_arena/src/domain/online_game_state.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/play/animated_move_timing.dart';
import 'package:battle_chess_arena/src/features/play/board_appearance.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/online_fixtures.dart';

Finder _key(String value) => find.byKey(ValueKey(value));
Finder _square(Square square) => _key('square-${square.name}');
Finder _flight(Square source, Square target) =>
    _key('board-moving-${source.name}-${target.name}');

Position _position(String fen) => Chess.fromSetup(Setup.parseFen(fen));

BoardAppearance _appearance(AnimatedArmyTheme theme) => BoardAppearance.forPack(
  piecePacks.firstWhere((pack) => pack.id == theme.packId),
);

Future<void> _board(
  WidgetTester tester, {
  required Position position,
  NormalMove? move,
  Square? selected,
  Side orientation = Side.white,
  BoardAppearance? appearance,
  bool animate = true,
  bool reduced = false,
  bool systemReduced = false,
  bool coordinates = true,
  Square? hidden,
  EdgeInsets padding = EdgeInsets.zero,
  double extent = 320,
  double textScale = 1,
  ValueChanged<Square>? onTap,
  ValueChanged<int>? onSwipe,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          padding: padding,
          disableAnimations: systemReduced,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: Center(
            child: SizedBox.square(
              dimension: extent,
              child: ChessBoard(
                position: position,
                selected: selected,
                legalTargets: const {},
                accent: Colors.cyan,
                appearance: appearance ?? _appearance(AnimatedArmyTheme.neon),
                orientation: orientation,
                animateMoves: animate,
                animatedMove: move,
                reducedMotion: reduced,
                showCoordinates: coordinates,
                hiddenPieceSquare: hidden,
                onSquareTap: onTap ?? (_) {},
                onSetSwipe: onSwipe,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

String? _label(WidgetTester tester, Square square) => tester
    .widget<Semantics>(
      find
          .ancestor(of: _square(square), matching: find.byType(Semantics))
          .first,
    )
    .properties
    .label;

Iterable<CharacterPiece> _piecesIn(WidgetTester tester, Finder finder) =>
    tester.widgetList<CharacterPiece>(
      find.descendant(of: finder, matching: find.byType(CharacterPiece)),
    );

void _at(Offset actual, Offset expected) {
  expect(actual.dx, closeTo(expected.dx, .01));
  expect(actual.dy, closeTo(expected.dy, .01));
}

void main() {
  for (final theme in AnimatedArmyTheme.values) {
    for (final orientation in Side.values) {
      testWidgets(
        '${theme.name} ${orientation.name} capture travels through coordinate grid while committed taps stay active',
        (tester) async {
          final game = GameSession(
            position: _position('4k3/8/8/8/8/3p4/4P3/4K3 w - - 0 1'),
          );
          final before = game.position;
          final tapped = <Square>[];
          final swipes = <int>[];
          final appearance = _appearance(theme);
          await _board(
            tester,
            position: before,
            selected: Square.e2,
            appearance: appearance,
            orientation: orientation,
          );
          await tester.pump(animatedSelectionDuration);
          final source = tester.getCenter(_square(Square.e2));
          final target = tester.getCenter(_square(Square.d3));
          final resolution = game.play(Square.e2, Square.d3)!;
          await _board(
            tester,
            position: game.position,
            move: resolution.move,
            appearance: appearance,
            orientation: orientation,
            onTap: tapped.add,
            onSwipe: swipes.add,
          );
          final flight = _flight(Square.e2, Square.d3);
          expect(flight, findsOneWidget);
          _at(tester.getCenter(flight), source);
          expect(_label(tester, Square.e2), 'e2 empty');
          expect(_label(tester, Square.d3), 'd3 white pawn');
          expect(_key('board-captured-d3'), findsOneWidget);
          expect(_piecesIn(tester, flight).single.pack.id, theme.packId);
          expect(_piecesIn(tester, _square(Square.d3)), isEmpty);
          await tester.tap(_square(Square.d3));
          expect(tapped, [Square.d3]);

          await tester.pump(const Duration(milliseconds: 230));
          final midpoint = tester.getCenter(flight);
          expect((midpoint - source).distance, greaterThan(0));
          expect(
            (midpoint - source).distance,
            lessThan((target - source).distance),
          );
          await tester.pump(const Duration(milliseconds: 240));
          _at(tester.getCenter(flight), target);
          expect(
            tester.widget<Opacity>(_key('board-captured-d3')).opacity,
            lessThan(1),
          );
          for (final transform in tester.widgetList<Transform>(
            find.descendant(
              of: _key('board-captured-d3'),
              matching: find.byType(Transform),
            ),
          )) {
            expect(
              transform.transform.getMaxScaleOnAxis(),
              closeTo(1, .001),
              reason: 'Defeat fades the victim without changing its body size.',
            );
          }
          await tester.drag(_square(Square.a4), const Offset(-90, 0));
          expect(swipes, [1]);
          await tester.pump(animatedMoveDuration);
          expect(flight, findsNothing);
          expect(_key('board-captured-d3'), findsNothing);
          expect(
            _piecesIn(tester, _square(Square.d3)).single.piece,
            Piece.whitePawn,
          );
          expect(
            game.position.fen,
            tester.widget<ChessBoard>(find.byType(ChessBoard)).position.fen,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'clock rebuilds, a cleared move event and Classic style preserve flight progress',
    (tester) async {
      final game = GameSession();
      final before = game.position;
      await _board(tester, position: before);
      final move = game.play(Square.e2, Square.e4)!.move;
      await _board(tester, position: game.position, move: move);
      await tester.pump(const Duration(milliseconds: 200));
      final flight = _flight(Square.e2, Square.e4);
      final current = tester.getCenter(flight);
      await _board(
        tester,
        position: game.position,
        selected: Square.d7,
        appearance: _appearance(
          AnimatedArmyTheme.neon,
        ).withStandardPieces(ClassicPieceStyle.magneticTeaching),
      );
      _at(tester.getCenter(flight), current);
      expect(_piecesIn(tester, flight).single.standard, isTrue);
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.getCenter(flight).dy, lessThan(current.dy));
      await tester.pump(animatedMoveDuration);
      expect(flight, findsNothing);
      expect(game.position.turn, Side.black);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a rapid selection commit continues from the scale actually painted',
    (tester) async {
      final game = GameSession();
      await _board(tester, position: game.position);
      await _board(tester, position: game.position, selected: Square.e2);
      await tester.pump(const Duration(milliseconds: 60));
      final transition = tester.widget<ScaleTransition>(
        find
            .descendant(
              of: _square(Square.e2),
              matching: find.byType(ScaleTransition),
            )
            .first,
      );
      final selectedScale = transition.scale.value;
      expect(selectedScale, greaterThan(1));
      expect(selectedScale, lessThan(1.12));
      final move = game.play(Square.e2, Square.e4)!.move;
      await _board(tester, position: game.position, move: move);
      expect(
        tester
            .widget<Transform>(_key('board-flight-scale-e2'))
            .transform
            .getMaxScaleOnAxis(),
        closeTo(selectedScale, .001),
      );
      await tester.pump(animatedMoveDuration + const Duration(milliseconds: 1));
      expect(_flight(Square.e2, Square.e4), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'online requests and reconnect snapshots snap; only an accepted event animates while clocks advance',
    (tester) async {
      var now = 0;
      final session = OnlineGameSession(nowMs: () => now);
      session.apply(OnlineGameState.fromJson(stateJson()));
      await _board(
        tester,
        position: session.state!.position,
        selected: Square.e2,
      );
      session.moveRequest(Square.e2, Square.e4, 'w');
      await _board(tester, position: session.state!.position);
      expect(_flight(Square.e2, Square.e4), findsNothing);
      expect(session.state!.position.board.pieceAt(Square.e2), Piece.whitePawn);

      final game = GameSession()..play(Square.e2, Square.e4);
      session.apply(
        OnlineGameState.fromJson(stateJson(sequence: 2, game: game)),
      );
      await _board(
        tester,
        position: session.state!.position,
        move: session.committedMove!.move,
      );
      expect(_flight(Square.e2, Square.e4), findsOneWidget);
      now = 175;
      await tester.pump(const Duration(milliseconds: 175));
      expect(session.clockMs('b'), 59825);
      expect(session.state!.position.fen, game.position.fen);

      game.play(Square.e7, Square.e5);
      session.apply(
        OnlineGameState.fromJson(stateJson(sequence: 3, game: game)),
        animate: false,
      );
      expect(session.committedMove, isNull);
      await _board(tester, position: session.state!.position);
      expect(_flight(Square.e2, Square.e4), findsNothing);
      expect(_flight(Square.e7, Square.e5), findsNothing);
      expect(_label(tester, Square.e5), 'e5 black pawn');
      expect(tester.takeException(), isNull);
    },
  );

  for (final kingside in [true, false]) {
    testWidgets(
      'castling moves both pieces to their actual ${kingside ? 'king' : 'queen'} side squares',
      (tester) async {
        final game = GameSession(
          position: _position(
            kingside
                ? '4k3/8/8/8/8/8/8/4K2R w K - 0 1'
                : '4k3/8/8/8/8/8/8/R3K3 w Q - 0 1',
          ),
        );
        await _board(tester, position: game.position, orientation: Side.black);
        final target = kingside ? Square.g1 : Square.c1;
        final rookFrom = kingside ? Square.h1 : Square.a1;
        final rookTo = kingside ? Square.f1 : Square.d1;
        final move = game.play(Square.e1, target)!.move;
        expect(move.to, rookFrom);
        await _board(
          tester,
          position: game.position,
          move: move,
          orientation: Side.black,
        );
        expect(_flight(Square.e1, target), findsOneWidget);
        expect(_flight(rookFrom, rookTo), findsOneWidget);
        expect(_key('board-captured-${rookFrom.name}'), findsNothing);
        expect(_piecesIn(tester, _square(target)), isEmpty);
        expect(_piecesIn(tester, _square(rookTo)), isEmpty);
        await tester.pump(const Duration(milliseconds: 500));
        _at(
          tester.getCenter(_flight(Square.e1, target)),
          tester.getCenter(_square(target)),
        );
        _at(
          tester.getCenter(_flight(rookFrom, rookTo)),
          tester.getCenter(_square(rookTo)),
        );
        await tester.pump(animatedMoveDuration);
        expect(
          _piecesIn(tester, _square(target)).single.piece,
          Piece.whiteKing,
        );
        expect(
          _piecesIn(tester, _square(rookTo)).single.piece,
          Piece.whiteRook,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'en passant keeps the defeated pawn on its victim square until impact',
    (tester) async {
      final game = GameSession(
        position: _position('4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 2'),
      );
      await _board(tester, position: game.position);
      final victim = tester.getCenter(_square(Square.d5));
      final move = game.play(Square.e5, Square.d6)!.move;
      await _board(tester, position: game.position, move: move);
      expect(_flight(Square.e5, Square.d6), findsOneWidget);
      expect(_key('board-captured-d5'), findsOneWidget);
      expect(_key('board-captured-d6'), findsNothing);
      _at(tester.getCenter(_key('board-captured-d5')), victim);
      expect(
        _piecesIn(tester, _key('board-captured-d5')).single.piece,
        Piece.blackPawn,
      );
      expect(_label(tester, Square.d5), 'd5 empty');
      expect(_label(tester, Square.d6), 'd6 white pawn');
      await tester.pump(animatedMoveDuration);
      expect(_key('board-captured-d5'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'capture underpromotion changes pawn to the accepted role upon arrival',
    (tester) async {
      final game = GameSession(
        position: _position('r6k/1P6/8/8/8/8/8/7K w - - 0 1'),
      );
      await _board(tester, position: game.position);
      final move = game
          .play(Square.b7, Square.a8, promotion: Role.knight)!
          .move;
      await _board(tester, position: game.position, move: move);
      final flight = _flight(Square.b7, Square.a8);
      expect(_piecesIn(tester, flight).single.piece, Piece.whitePawn);
      expect(_label(tester, Square.a8), 'a8 white knight');
      expect(
        _piecesIn(tester, _key('board-captured-a8')).single.piece,
        Piece.blackRook,
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(_piecesIn(tester, flight).single.piece, Piece.whiteKnight);
      await tester.pump(animatedMoveDuration);
      expect(
        _piecesIn(tester, _square(Square.a8)).single.piece,
        Piece.whiteKnight,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'missing, illegal, mismatched and multi-ply move events never animate',
    (tester) async {
      final game = GameSession();
      final initial = game.position;
      final move = game.play(Square.e2, Square.e4)!.move;
      for (final event in <NormalMove?>[
        null,
        const NormalMove(from: Square.e2, to: Square.e5),
        const NormalMove(from: Square.e2, to: Square.e3),
      ]) {
        await _board(tester, position: initial);
        await _board(tester, position: game.position, move: event);
        expect(_flight(Square.e2, Square.e4), findsNothing);
        expect(
          _piecesIn(tester, _square(Square.e4)).single.piece,
          Piece.whitePawn,
        );
      }
      final next = game.play(Square.e7, Square.e5)!.move;
      await _board(tester, position: initial);
      await _board(tester, position: game.position, move: next);
      expect(_flight(Square.e7, Square.e5), findsNothing);
      await _board(tester, position: initial, move: move);
      expect(_flight(Square.e2, Square.e4), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a second accepted move replaces flight without changing the committed board',
    (tester) async {
      final game = GameSession();
      await _board(tester, position: game.position);
      final white = game.play(Square.e2, Square.e4)!.move;
      await _board(tester, position: game.position, move: white);
      await tester.pump(const Duration(milliseconds: 150));
      final black = game.play(Square.e7, Square.e5)!.move;
      await _board(tester, position: game.position, move: black);
      expect(_flight(Square.e2, Square.e4), findsNothing);
      expect(_flight(Square.e7, Square.e5), findsOneWidget);
      _at(
        tester.getCenter(_flight(Square.e7, Square.e5)),
        tester.getCenter(_square(Square.e7)),
      );
      expect(
        _piecesIn(tester, _square(Square.e4)).single.piece,
        Piece.whitePawn,
      );
      expect(game.position.turn, Side.white);
      await tester.pump(animatedMoveDuration + const Duration(milliseconds: 1));
      expect(
        _piecesIn(tester, _square(Square.e5)).single.piece,
        Piece.blackPawn,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final systemReduced in [true, false]) {
    testWidgets(
      '${systemReduced ? 'system' : 'preference'} reduced motion displays the accepted piece immediately',
      (tester) async {
        final game = GameSession();
        await _board(
          tester,
          position: game.position,
          systemReduced: systemReduced,
          reduced: !systemReduced,
        );
        final move = game.play(Square.e2, Square.e4)!.move;
        await _board(
          tester,
          position: game.position,
          move: move,
          systemReduced: systemReduced,
          reduced: !systemReduced,
        );
        expect(_flight(Square.e2, Square.e4), findsNothing);
        expect(
          _piecesIn(tester, _square(Square.e4)).single.piece,
          Piece.whitePawn,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'turning reduced motion on finishes an active flight without replay on re-enable',
    (tester) async {
      final game = GameSession();
      await _board(tester, position: game.position);
      final move = game.play(Square.e2, Square.e4)!.move;
      await _board(tester, position: game.position, move: move);
      await tester.pump(const Duration(milliseconds: 100));
      await _board(
        tester,
        position: game.position,
        move: move,
        systemReduced: true,
      );
      expect(_flight(Square.e2, Square.e4), findsNothing);
      expect(
        _piecesIn(tester, _square(Square.e4)).single.piece,
        Piece.whitePawn,
      );
      await _board(tester, position: game.position, move: move);
      expect(_flight(Square.e2, Square.e4), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'legacy guard and capture overlay ownership preserve immediate pieces',
    (tester) async {
      final game = GameSession();
      final before = game.position;
      final move = game.play(Square.e2, Square.e4)!.move;
      await _board(tester, position: before, animate: false);
      await _board(tester, position: game.position, move: move, animate: false);
      expect(_flight(Square.e2, Square.e4), findsNothing);
      expect(
        _piecesIn(tester, _square(Square.e4)).single.piece,
        Piece.whitePawn,
      );
      await _board(tester, position: before);
      await _board(
        tester,
        position: game.position,
        move: move,
        hidden: Square.e4,
      );
      expect(_flight(Square.e2, Square.e4), findsNothing);
      expect(_piecesIn(tester, _square(Square.e4)), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rotation and coordinate gutter resize retain movement progress',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final game = GameSession();
      await _board(tester, position: game.position, extent: 280);
      final move = game.play(Square.e2, Square.e4)!.move;
      await _board(tester, position: game.position, move: move, extent: 280);
      await tester.pump(const Duration(milliseconds: 200));
      final flight = _flight(Square.e2, Square.e4);
      double fraction() =>
          (tester.getCenter(flight).dy -
              tester.getCenter(_square(Square.e2)).dy) /
          (tester.getCenter(_square(Square.e4)).dy -
              tester.getCenter(_square(Square.e2)).dy);
      final progress = fraction();
      await tester.binding.setSurfaceSize(const Size(650, 360));
      await _board(
        tester,
        position: game.position,
        move: move,
        extent: 300,
        orientation: Side.black,
        textScale: 2,
      );
      expect(fraction(), closeTo(progress, .001));
      expect(
        tester.getSize(flight).width,
        closeTo((300 - 2 * ChessBoard.coordinateInset(300)) / 8, .001),
      );
      await tester.pump(animatedMoveDuration);
      expect(flight, findsNothing);
      expect(
        _piecesIn(tester, _square(Square.e4)).single.piece,
        Piece.whitePawn,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'flight pauses in background, resumes remaining time and disposes safely',
    (tester) async {
      final game = GameSession();
      await _board(tester, position: game.position);
      final move = game.play(Square.e2, Square.e4)!.move;
      await _board(tester, position: game.position, move: move);
      await tester.pump(const Duration(milliseconds: 180));
      final flight = _flight(Square.e2, Square.e4);
      final point = tester.getCenter(flight);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 1));
      _at(tester.getCenter(flight), point);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getCenter(flight).dy, lessThan(point.dy));
      expect(game.position.turn, Side.black);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(animatedMoveDuration);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unlabelled grid safe-area padding also aligns source and target',
    (tester) async {
      final game = GameSession();
      const padding = EdgeInsets.only(top: 24, bottom: 12);
      await _board(
        tester,
        position: game.position,
        coordinates: false,
        padding: padding,
      );
      final source = tester.getCenter(_square(Square.e2));
      final target = tester.getCenter(_square(Square.e4));
      final move = game.play(Square.e2, Square.e4)!.move;
      await _board(
        tester,
        position: game.position,
        move: move,
        coordinates: false,
        padding: padding,
      );
      _at(tester.getCenter(_flight(Square.e2, Square.e4)), source);
      await tester.pump(const Duration(milliseconds: 500));
      _at(tester.getCenter(_flight(Square.e2, Square.e4)), target);
      await tester.pump(animatedMoveDuration);
      expect(tester.takeException(), isNull);
    },
  );
}
