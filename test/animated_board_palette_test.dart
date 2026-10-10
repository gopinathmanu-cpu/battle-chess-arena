// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:battle_chess_arena/src/domain/animated_army_theme.dart';
import 'package:battle_chess_arena/src/domain/cinematic_replay.dart';
import 'package:battle_chess_arena/src/domain/custom_chess_set.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/play/board_appearance.dart';
import 'package:battle_chess_arena/src/features/play/neon_cinematic_board.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PiecePack _pack(PiecePackId id) =>
    piecePacks.singleWhere((pack) => pack.id == id);

double _contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return (first > second ? first + .05 : second + .05) /
      (first > second ? second + .05 : first + .05);
}

void main() {
  for (final theme in AnimatedArmyTheme.values) {
    test('${theme.name} world palette remains readable with Classic icons', () {
      final pack = _pack(theme.packId);
      final look = BoardAppearance.forPack(pack);
      final classic = look.withStandardPieces(ClassicPieceStyle.wood);
      expect(look.lightSquare, Color(theme.lightSquareArgb));
      expect(look.darkSquare, Color(theme.darkSquareArgb));
      expect(classic.lightSquare, look.lightSquare);
      expect(classic.darkSquare, look.darkSquare);
      expect(classic.animatedArena, isTrue);
      expect(
        _contrast(look.lightSquare, look.darkSquare),
        greaterThanOrEqualTo(3),
      );
      expect(look.darkSquare.computeLuminance(), greaterThan(.2));
      // Pale pieces retain their built-in dark edges on the light squares.
      // On darker squares, both light bodies and dark bodies remain distinct.
      for (final ink in [const Color(0xFFF8F6EE), const Color(0xFF20232B)]) {
        expect(_contrast(ink, look.darkSquare), greaterThanOrEqualTo(3));
      }
    });

    test('${theme.name} traditional page keeps its original board colors', () {
      final pack = _pack(theme.packId);
      final look = BoardAppearance(
        white: pack,
        black: pack,
        board: pack,
        animatedArena: false,
        standardPieces: true,
      );
      expect(look.lightSquare, pack.lightSquare);
      expect(look.darkSquare, pack.darkSquare);
      expect(look.lightSquare, isNot(Color(theme.lightSquareArgb)));
      expect(look.darkSquare, isNot(Color(theme.darkSquareArgb)));
    });

    for (final classic in [false, true]) {
      testWidgets(
        '${theme.name} replay main and overview retain palette with ${classic ? 'Classic' : 'Animated'} pieces',
        (tester) async {
          final scene = CinematicReplay.fromMoves(
            moves: ['e2e4'],
          ).scenes.single;
          await tester.pumpWidget(
            MaterialApp(
              home: Center(
                child: SizedBox.square(
                  dimension: 350,
                  child: NeonCinematicBoard(
                    position: Chess.initial,
                    scene: scene,
                    progress: .38,
                    reducedMotion: false,
                    theme: theme,
                    classicPieces: classic,
                    classicStyle: ClassicPieceStyle.wood,
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          for (final view in ['main', 'context']) {
            for (final (square, expected) in [
              ('a8', Color(theme.lightSquareArgb)),
              ('b8', Color(theme.darkSquareArgb)),
            ]) {
              final tile = find.byKey(
                ValueKey('cinematic-board-$view-$square'),
              );
              final surface = tester.widget<DecoratedBox>(
                find
                    .descendant(of: tile, matching: find.byType(DecoratedBox))
                    .first,
              );
              expect((surface.decoration as BoxDecoration).color, expected);
            }
          }
          final pieces = tester.widgetList<CharacterPiece>(
            find.byType(CharacterPiece),
          );
          expect(pieces, isNotEmpty);
          expect(pieces.every((piece) => piece.standard == classic), isTrue);
          expect(
            pieces.every(
              (piece) => piece.classicStyle == ClassicPieceStyle.wood,
            ),
            isTrue,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  test('explicit board colors and saved custom sets take priority', () {
    final pack = _pack(PiecePackId.futuristic);
    final saved = CustomChessSet.create(
      id: 'palette-saved-set',
    ).copyWith(lightSquare: 0xFFFFE8D9, darkSquare: 0xFF805C73);
    final custom = BoardAppearance.forPack(pack).withCustomSet(saved);
    expect(custom.lightSquare, const Color(0xFFFFE8D9));
    expect(custom.darkSquare, const Color(0xFF805C73));
    final overrides = custom.withBoardColors(Colors.blue, Colors.green);
    expect(overrides.lightSquare, Colors.blue);
    expect(overrides.darkSquare, Colors.green);
    expect(overrides.customSet, same(saved));
    final classic = BoardAppearance.forPack(
      pack,
    ).withBoardColors(Colors.blue, Colors.green).withStandardPieces();
    expect(classic.lightSquare, Colors.blue);
    expect(classic.darkSquare, Colors.green);
  });

  test('palette follows the independently chosen board world', () {
    final army = _pack(PiecePackId.futuristic);
    final board = _pack(PiecePackId.greek);
    final look = BoardAppearance(white: army, black: army, board: board);
    expect(look.lightSquare, Color(AnimatedArmyTheme.olympian.lightSquareArgb));
    expect(look.darkSquare, Color(AnimatedArmyTheme.olympian.darkSquareArgb));
  });

  test('legacy worlds keep their saved palettes in either page mode', () {
    for (final pack in piecePacks.skip(4)) {
      for (final animated in [false, true]) {
        final look = BoardAppearance(
          white: pack,
          black: pack,
          board: pack,
          animatedArena: animated,
        );
        expect(look.lightSquare, pack.lightSquare);
        expect(look.darkSquare, pack.darkSquare);
      }
    }
  });
}
