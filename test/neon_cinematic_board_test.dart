import 'package:battle_chess_arena/src/domain/animated_army_theme.dart';
import 'package:battle_chess_arena/src/domain/cinematic_replay.dart';
import 'package:battle_chess_arena/src/features/play/board_appearance.dart';
import 'package:battle_chess_arena/src/features/play/neon_cinematic_board.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder cell(String name) => find.byKey(ValueKey('cinematic-board-main-$name'));
Finder pieceIn(String name) =>
    find.descendant(of: cell(name), matching: find.byType(CharacterPiece));
Finder movingPiece = find.byKey(
  const ValueKey('cinematic-board-main-moving-piece'),
);

Future<void> render(
  WidgetTester tester, {
  CinematicReplayScene? scene,
  Position? position,
  AnimatedArmyTheme theme = AnimatedArmyTheme.neon,
  double progress = .38,
  bool reduced = false,
  bool intro = false,
  bool finale = false,
  Set<Square> threats = const {},
  Size size = const Size(350, 350),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: NeonCinematicBoard(
            theme: theme,
            position: position ?? Chess.initial,
            scene: scene,
            progress: progress,
            reducedMotion: reduced,
            intro: intro,
            finale: finale,
            threatSquares: threats,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

CinematicReplayScene last(List<String> moves) =>
    CinematicReplay.fromMoves(moves: moves).scenes.last;

void main() {
  for (final theme in AnimatedArmyTheme.values) {
    testWidgets(
      '${theme.name} main, travelling actor and overview use its army',
      (tester) async {
        final scene = last(['e2e4', 'd7d5', 'e4d5']);
        await render(tester, theme: theme, scene: scene, progress: .38);
        expect(
          find.byKey(const ValueKey('cinematic-board-context')),
          findsOneWidget,
        );
        final figures = tester.widgetList<CharacterPiece>(
          find.byType(CharacterPiece),
        );
        expect(figures, isNotEmpty);
        expect(
          figures.every((figure) => figure.pack.id == theme.packId),
          isTrue,
        );
        final moving = tester.widget<CharacterPiece>(
          find.descendant(
            of: movingPiece,
            matching: find.byType(CharacterPiece),
          ),
        );
        expect(moving.piece, Piece.whitePawn);
        expect(moving.pack.id, theme.packId);
        expect(
          tester.widget<CharacterPiece>(pieceIn('d5')).piece,
          Piece.blackPawn,
        );
        await render(tester, theme: theme, scene: scene, progress: .56);
        expect(movingPiece, findsNothing);
        expect(pieceIn('e4'), findsNothing);
        final landed = tester.widget<CharacterPiece>(pieceIn('d5'));
        expect(landed.piece, Piece.whitePawn);
        expect(landed.pack.id, theme.packId);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'overview remains clear of a move into h8 throughout the chapter',
    (tester) async {
      final scene = last([
        'h2h4',
        'a7a5',
        'h4h5',
        'a5a4',
        'h5h6',
        'a4a3',
        'h6g7',
        'a3b2',
        'g7h8q',
      ]);
      Offset? corner;
      for (final progress in [.1, .21, .29, .38, .47, .55, .56, .75, .9]) {
        await render(tester, scene: scene, progress: progress);
        final overview = tester.getRect(
          find.byKey(const ValueKey('cinematic-board-context')),
        );
        corner ??= overview.topLeft;
        expect(
          overview.topLeft,
          corner,
          reason: 'Inset must stay in one corner per scene',
        );
        expect(
          overview.overlaps(tester.getRect(cell('g7'))),
          isFalse,
          reason: 'Inset must not cover the move source',
        );
        expect(
          overview.overlaps(tester.getRect(cell('h8'))),
          isFalse,
          reason: 'Inset must not cover the landing square',
        );
        if (movingPiece.evaluate().isNotEmpty) {
          expect(
            overview.overlaps(tester.getRect(movingPiece)),
            isFalse,
            reason: 'Inset must not cover the travelling piece',
          );
        }
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('mover travels exactly between the recorded source and target', (
    tester,
  ) async {
    final scene = last(['e2e4']);
    final fen = scene.before.fen;
    await render(tester, scene: scene);
    expect(pieceIn('e2'), findsNothing);
    expect(pieceIn('e4'), findsNothing);
    expect(movingPiece, findsOneWidget);
    final midpoint = Offset.lerp(
      tester.getCenter(cell('e2')),
      tester.getCenter(cell('e4')),
      .5,
    )!;
    expect((tester.getCenter(movingPiece) - midpoint).distance, lessThan(.01));
    expect(
      find.byKey(const ValueKey('cinematic-board-context')),
      findsOneWidget,
    );
    expect(scene.before.fen, fen);
    expect(scene.after.board.pieceAt(Square.e4), Piece.whitePawn);
    await render(tester, scene: scene, progress: cinematicBoardMoveEnd);
    expect(movingPiece, findsNothing);
    expect(pieceIn('e2'), findsNothing);
    expect(tester.widget<CharacterPiece>(pieceIn('e4')).piece, Piece.whitePawn);
    expect(tester.takeException(), isNull);
  });

  testWidgets('overview accompanies zoom before, during and after the move', (
    tester,
  ) async {
    final scene = last(['d2d4']);
    for (final progress in [.1, .38, .75]) {
      await render(tester, scene: scene, progress: progress);
      expect(
        find.byKey(const ValueKey('cinematic-board-context')),
        findsOneWidget,
      );
      final camera = tester.widget<Transform>(
        find.byKey(const ValueKey('cinematic-board-camera')),
      );
      expect(camera.transform.entry(0, 0), greaterThan(1));
    }
    await render(tester, scene: scene, progress: 1);
    expect(find.byKey(const ValueKey('cinematic-board-context')), findsNothing);
    expect(find.text('a'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'captured piece remains until landing then the attacker replaces it',
    (tester) async {
      final scene = last(['e2e4', 'd7d5', 'e4d5']);
      await render(tester, scene: scene);
      expect(
        tester.widget<CharacterPiece>(pieceIn('d5')).piece,
        Piece.blackPawn,
      );
      await render(tester, scene: scene, progress: .56);
      expect(
        tester.widget<CharacterPiece>(pieceIn('d5')).piece,
        Piece.whitePawn,
      );
      expect(pieceIn('e4'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'castling moves the correct king and allied rook simultaneously',
    (tester) async {
      final scene = last([
        'e2e4',
        'e7e5',
        'g1f3',
        'b8c6',
        'f1e2',
        'g8f6',
        'e1g1',
      ]);
      await render(tester, scene: scene);
      final rook = find.byKey(
        const ValueKey('cinematic-board-main-moving-rook'),
      );
      expect(movingPiece, findsOneWidget);
      expect(rook, findsOneWidget);
      expect(pieceIn('e1'), findsNothing);
      expect(pieceIn('h1'), findsNothing);
      final rookMid = Offset.lerp(
        tester.getCenter(cell('h1')),
        tester.getCenter(cell('f1')),
        .5,
      )!;
      expect((tester.getCenter(rook) - rookMid).distance, lessThan(.01));
      await render(tester, scene: scene, progress: .56);
      expect(
        tester.widget<CharacterPiece>(pieceIn('g1')).piece,
        Piece.whiteKing,
      );
      expect(
        tester.widget<CharacterPiece>(pieceIn('f1')).piece,
        Piece.whiteRook,
      );
      expect(pieceIn('h1'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('en passant removes the off-destination victim only at landing', (
    tester,
  ) async {
    final scene = last(['e2e4', 'a7a6', 'e4e5', 'd7d5', 'e5d6']);
    await render(tester, scene: scene);
    expect(tester.widget<CharacterPiece>(pieceIn('d5')).piece, Piece.blackPawn);
    expect(pieceIn('d6'), findsNothing);
    await render(tester, scene: scene, progress: .56);
    expect(pieceIn('d5'), findsNothing);
    expect(tester.widget<CharacterPiece>(pieceIn('d6')).piece, Piece.whitePawn);
    expect(tester.takeException(), isNull);
  });

  testWidgets('underpromotion lands as the recorded knight, not a queen', (
    tester,
  ) async {
    final scene = last([
      'a2a4',
      'h7h5',
      'a4a5',
      'h5h4',
      'a5a6',
      'h4h3',
      'a6b7',
      'h3g2',
      'b7a8n',
    ]);
    await render(tester, scene: scene);
    final travelling = find.descendant(
      of: movingPiece,
      matching: find.byType(CharacterPiece),
    );
    expect(tester.widget<CharacterPiece>(travelling).piece, Piece.whitePawn);
    expect(tester.widget<CharacterPiece>(pieceIn('a8')).piece, Piece.blackRook);
    await render(tester, scene: scene, progress: .56);
    expect(
      tester.widget<CharacterPiece>(pieceIn('a8')).piece,
      Piece.whiteKnight,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reduced motion retains highlights without zoom or travelling overlays',
    (tester) async {
      final scene = last(['g1f3']);
      await render(tester, scene: scene, progress: .38, reduced: true);
      expect(movingPiece, findsNothing);
      expect(
        find.byKey(const ValueKey('cinematic-board-context')),
        findsNothing,
      );
      expect(
        tester.widget<CharacterPiece>(pieceIn('g1')).piece,
        Piece.whiteKnight,
      );
      await render(tester, scene: scene, progress: .7, reduced: true);
      expect(
        tester.widget<CharacterPiece>(pieceIn('f3')).piece,
        Piece.whiteKnight,
      );
      final camera = tester.widget<Transform>(
        find.byKey(const ValueKey('cinematic-board-camera')),
      );
      expect(camera.transform.entry(0, 0), 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'initial/final snapshots and threat cells remain visible in compact layout',
    (tester) async {
      final replay = CinematicReplay.fromMoves(
        moves: ['f2f3', 'e7e5', 'g2g4', 'd8h4'],
      );
      await render(
        tester,
        intro: true,
        position: replay.initialPosition,
        size: const Size(780, 115),
      );
      expect(
        tester.widget<CharacterPiece>(pieceIn('e2')).piece,
        Piece.whitePawn,
      );
      await render(
        tester,
        finale: true,
        position: replay.finalPosition,
        threats: {Square.e1},
        size: const Size(780, 115),
      );
      expect(
        tester.widget<CharacterPiece>(pieceIn('h4')).piece,
        Piece.blackQueen,
      );
      expect(
        find.byKey(const ValueKey('cinematic-board-main-threat-e1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('cinematic-board-context')),
        findsNothing,
      );
      expect(find.byType(GestureDetector), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
