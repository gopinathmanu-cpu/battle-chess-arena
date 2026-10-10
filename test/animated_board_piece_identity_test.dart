import 'package:battle_chess_arena/src/domain/animated_army_theme.dart';
import 'package:battle_chess_arena/src/domain/custom_chess_set.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/play/board_appearance.dart';
import 'package:battle_chess_arena/src/features/play/neon_illustrated_stage.dart';
import 'package:battle_chess_arena/src/features/play/themed_piece_sprite.dart';
import 'package:battle_chess_arena/src/features/studio/custom_piece.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _pieces = [
  for (final side in Side.values)
    for (final role in CharacterPiece.roles) Piece(color: side, role: role),
];

String _identity(Piece piece) => '${piece.color.name}-${piece.role.name}';

void main() {
  for (final theme in AnimatedArmyTheme.values) {
    testWidgets(
      '${theme.name} all twelve board figures use the exact stage identities and masks',
      (tester) async {
        final pack = availablePiecePacks.singleWhere(
          (pack) => pack.id == theme.packId,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                width: 576,
                height: 384,
                child: GridView.count(
                  crossAxisCount: 6,
                  childAspectRatio: 1,
                  children: [
                    for (final piece in _pieces) ...[
                      CharacterPiece(
                        key: ValueKey('board-${_identity(piece)}'),
                        piece: piece,
                        pack: pack,
                      ),
                      NeonFigureSprite(
                        key: ValueKey('stage-${_identity(piece)}'),
                        piece: piece,
                        theme: theme,
                        faceRight: piece.color == Side.white,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        for (final piece in _pieces) {
          final board = find.byKey(ValueKey('board-${_identity(piece)}'));
          final stage = find.byKey(ValueKey('stage-${_identity(piece)}'));
          final boardFigure = tester.widget<NeonFigureSprite>(
            find.descendant(of: board, matching: find.byType(NeonFigureSprite)),
          );
          final stageFigure = tester.widget<NeonFigureSprite>(stage);
          expect(boardFigure.piece, stageFigure.piece);
          expect(boardFigure.theme, stageFigure.theme);
          expect(boardFigure.faceRight, stageFigure.faceRight);
          expect(boardFigure.pose, stageFigure.pose);
          expect(boardFigure.pose, NeonFigurePose.rest);
          expect(boardFigure.fromPose, isNull);
          final boardAsset =
              tester
                      .widget<Image>(
                        find.descendant(
                          of: board,
                          matching: find.byType(Image),
                        ),
                      )
                      .image
                  as AssetImage;
          final stageAsset =
              tester
                      .widget<Image>(
                        find.descendant(
                          of: stage,
                          matching: find.byType(Image),
                        ),
                      )
                      .image
                  as AssetImage;
          expect(boardAsset.assetName, stageAsset.assetName);
          expect(boardAsset.assetName, theme.castAsset(piece.color));
          final boardClipper = tester
              .widget<ClipPath>(
                find.descendant(of: board, matching: find.byType(ClipPath)),
              )
              .clipper;
          final stageClipper = tester
              .widget<ClipPath>(
                find.descendant(of: stage, matching: find.byType(ClipPath)),
              )
              .clipper;
          expect(boardClipper.runtimeType, stageClipper.runtimeType);
          if (boardClipper != null && stageClipper != null) {
            expect(
              boardClipper.getClip(const Size(1774, 887)).getBounds(),
              stageClipper.getClip(const Size(1774, 887)).getBounds(),
            );
          }
          final mirror = tester.widget<Transform>(
            find.descendant(
              of: board,
              matching: find.byKey(
                ValueKey('neon-figure-mirror-${_identity(piece)}'),
              ),
            ),
          );
          expect(
            mirror.transform.storage[0],
            piece.color == Side.white ? 1 : -1,
          );
        }
        for (final role in ['K', 'Q', 'B', 'N', 'R', 'P']) {
          expect(find.text(role), findsNWidgets(2));
        }
        expect(find.byType(ThemedPieceSprite), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '${theme.name} each board figure maximizes its square without clipping or distortion',
      (tester) async {
        final pack = availablePiecePacks.singleWhere(
          (pack) => pack.id == theme.packId,
        );
        for (final size in [24.0, 48.0, 72.0]) {
          await tester.pumpWidget(
            MaterialApp(
              home: Center(
                child: SizedBox(
                  width: size * 6,
                  height: size * 2,
                  child: GridView.count(
                    crossAxisCount: 6,
                    children: [
                      for (final piece in _pieces)
                        CharacterPiece(
                          piece: piece,
                          pack: pack,
                          showRole: false,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          final figures = tester
              .widgetList<NeonFigureSprite>(find.byType(NeonFigureSprite))
              .toList();
          expect(figures, hasLength(12));
          expect(
            figures.map((figure) => figure.bodyHeight).toSet().length,
            greaterThan(1),
          );
          for (final figure in figures) {
            final figureFinder = find.byKey(figure.key!);
            final slot = tester.renderObject<RenderBox>(figureFinder);
            final expectedExtent = (size - 1) * .98;
            expect(slot.size.width, closeTo(expectedExtent, .001));
            expect(slot.size.height, closeTo(expectedExtent, .001));
            final crop = tester.renderObject<RenderBox>(
              find.descendant(
                of: figureFinder,
                matching: find.byType(ClipRect),
              ),
            );
            // Both corners are transformed so the Black mirror has the same
            // containment guarantees as the White figure.
            final artwork = Rect.fromPoints(
              crop.localToGlobal(Offset.zero, ancestor: slot),
              crop.localToGlobal(
                crop.size.bottomRight(Offset.zero),
                ancestor: slot,
              ),
            );
            expect(artwork.left, greaterThanOrEqualTo(-.001));
            expect(artwork.top, greaterThanOrEqualTo(-.001));
            expect(artwork.right, lessThanOrEqualTo(slot.size.width + .001));
            expect(artwork.bottom, closeTo(slot.size.height, .001));
            expect(
              (artwork.width - slot.size.width).abs() < .001 ||
                  (artwork.height - slot.size.height).abs() < .001,
              isTrue,
              reason: '${_identity(figure.piece)} should fill one square axis',
            );
            final atlas = tester.widget<Image>(
              find.descendant(of: figureFinder, matching: find.byType(Image)),
            );
            final nativeAspect = theme == AnimatedArmyTheme.neon
                ? figure.piece.color == Side.white
                      ? 2172 / 724
                      : 2167 / 726
                : 1774 / 887;
            expect(
              atlas.width! / atlas.height!,
              closeTo(nativeAspect, .000001),
            );
            final commonBudget = animatedFigureBodyHeight(
              theme: theme,
              space: slot.size,
              poses: const [NeonFigurePose.rest],
            );
            expect(figure.bodyHeight!, greaterThanOrEqualTo(commonBudget));
          }
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  test(
    'rest-only board fitting keeps the measured film and live pose budgets',
    () {
      // Neon now measures the upright Rook commanders in all three poses.
      // Board-only fitting must still leave the shared encounter scale intact.
      const measuredSquareBudgets = {
        AnimatedArmyTheme.neon: 33.70786516853933,
        AnimatedArmyTheme.manga: 41.27764127764128,
        AnimatedArmyTheme.epic: 39.87878787878788,
        AnimatedArmyTheme.olympian: 42.12244897959184,
      };
      for (final theme in AnimatedArmyTheme.values) {
        expect(
          animatedFigureBodyHeight(theme: theme, space: const Size(48, 48)),
          closeTo(measuredSquareBudgets[theme]!, .0000001),
        );
        for (final space in [
          const Size(48, 48),
          const Size(120, 210),
          const Size(200, 150),
        ]) {
          final original = animatedFigureBodyHeight(theme: theme, space: space);
          final allPoses = animatedFigureBodyHeight(
            theme: theme,
            space: space,
            poses: NeonFigurePose.values,
          );
          final rest = animatedFigureBodyHeight(
            theme: theme,
            space: space,
            poses: const [NeonFigurePose.rest],
          );
          expect(original, allPoses);
          expect(rest, greaterThanOrEqualTo(original));
          if (theme != AnimatedArmyTheme.neon) expect(rest, original);
        }
      }
    },
  );

  testWidgets(
    'Classic, historical and custom pieces retain their original renderers',
    (tester) async {
      final fantasy = availablePiecePacks.first;
      for (final style in ClassicPieceStyle.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox.square(
                dimension: 48,
                child: CharacterPiece(
                  piece: const Piece(color: Side.black, role: Role.pawn),
                  pack: fantasy,
                  standard: true,
                  classicStyle: style,
                ),
              ),
            ),
          ),
        );
        expect(find.byType(NeonFigureSprite), findsNothing);
        expect(
          (tester.widget<Image>(find.byType(Image)).image as AssetImage)
              .assetName,
          'assets/characters/classic-piece-variations-atlas.png',
        );
      }
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox.square(
              dimension: 48,
              child: CharacterPiece(
                piece: const Piece(color: Side.black, role: Role.pawn),
                pack: piecePacks[4],
              ),
            ),
          ),
        ),
      );
      expect(find.byType(ThemedPieceSprite), findsOneWidget);
      expect(find.byType(NeonFigureSprite), findsNothing);
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox.square(
              dimension: 48,
              child: CharacterPiece(
                piece: const Piece(color: Side.white, role: Role.king),
                pack: fantasy,
                standard: true,
                customSet: CustomChessSet.create(id: 'retained-custom'),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(CustomPiece), findsOneWidget);
      expect(find.byType(NeonFigureSprite), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
