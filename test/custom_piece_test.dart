import 'package:battle_chess_arena/src/domain/custom_chess_set.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/play/themed_piece_sprite.dart';
import 'package:battle_chess_arena/src/features/studio/custom_piece.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('studio exposes four complete formations for every chess role', () {
    expect(CustomPieceParts.categories, ['formation']);
    expect(CustomPieceParts.labels('formation'), hasLength(4));
    expect(CustomPieceParts.labels('formation').toSet(), hasLength(4));
    expect(CustomPieceParts.formationPacks.toSet(), hasLength(4));
    for (final role in Role.values) {
      expect(CustomPieceParts.supportedCategories(role), ['formation']);
      expect(CustomPieceParts.formationName(role), isNotEmpty);
    }
    expect(CustomPieceParts.formationName(Role.bishop), contains('Elephant'));
    expect(CustomPieceParts.formationName(Role.knight), contains('Horse'));
    expect(CustomPieceParts.formationName(Role.rook), contains('Chariot'));
  });

  test('formation variants map to stable shipping themed sets', () {
    expect(
      List.generate(4, (index) => CustomPieceParts.packForVariant(index).id),
      [
        PiecePackId.chola,
        PiecePackId.roman,
        PiecePackId.chinese,
        PiecePackId.asgard,
      ],
    );
    expect(CustomPieceParts.packForVariant(-8).id, PiecePackId.chola);
    expect(CustomPieceParts.packForVariant(99).id, PiecePackId.asgard);
  });

  testWidgets(
    'complete elephant, horse and chariot formations render from one sprite each',
    (tester) async {
      for (final role in [Role.bishop, Role.knight, Role.rook]) {
        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox.square(
              dimension: 180,
              child: CustomPiece(
                piece: Piece(color: Side.white, role: role),
                chessSet: CustomChessSet.create(id: 'formations').withDesign(
                  Side.white,
                  role,
                  const CustomPieceDesign(costume: 0),
                ),
                showRole: false,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final sprite = tester.widget<ThemedPieceSprite>(
          find.byType(ThemedPieceSprite),
        );
        expect(sprite.asset, 'assets/characters/kingdoms/chola-v3.png');
        expect(sprite.row, 0);
        expect(
          sprite.column,
          [
            Role.king,
            Role.queen,
            Role.bishop,
            Role.knight,
            Role.rook,
            Role.pawn,
          ].indexOf(role),
        );
        expect(sprite.flipX, isFalse);
        expect(find.byType(ThemedPieceSprite), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('Black mirrors and brightens the entire selected formation', (
    tester,
  ) async {
    final set = CustomChessSet.create(id: 'black').withDesign(
      Side.black,
      Role.knight,
      const CustomPieceDesign(
        horse: 3,
        costume: 1,
        face: 2,
        crown: 3,
        weapon: 2,
        structure: 1,
        scale: .65,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox.square(
            dimension: 180,
            child: CustomPiece(
              piece: const Piece(color: Side.black, role: Role.knight),
              chessSet: set,
              showRole: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final sprite = tester.widget<ThemedPieceSprite>(
      find.byType(ThemedPieceSprite),
    );
    expect(sprite.asset, 'assets/characters/kingdoms/roman-v3.png');
    expect(sprite.row, 1);
    expect(sprite.column, 3);
    expect(sprite.flipX, isTrue);
    expect(sprite.brightenDarkArmy, isTrue);
    final renderedSize = tester.getSize(find.byType(ThemedPieceSprite));
    expect(renderedSize.width, greaterThanOrEqualTo(179));
    expect(renderedSize.height, greaterThanOrEqualTo(179));
  });

  testWidgets('thumbnail previews the selected role, side and formation', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox.square(
          dimension: 160,
          child: CustomPartThumbnail(
            category: 'formation',
            variant: 2,
            role: Role.bishop,
            side: Side.black,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final sprite = tester.widget<ThemedPieceSprite>(
      find.byType(ThemedPieceSprite),
    );
    expect(sprite.asset, 'assets/characters/kingdoms/chinese-v3.png');
    expect(sprite.row, 1);
    expect(sprite.column, 2);
    expect(sprite.flipX, isTrue);
    expect(find.bySemanticsLabel(RegExp('Elephant')), findsOneWidget);
  });

  testWidgets('role badge remains readable without splitting the formation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.square(
          dimension: 100,
          child: CustomPiece(
            piece: const Piece(color: Side.white, role: Role.rook),
            chessSet: CustomChessSet.create(id: 'badge'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('R'), findsOneWidget);
    expect(find.byType(ThemedPieceSprite), findsOneWidget);
  });

  test('every formation atlas is bundled and non-empty', () async {
    for (var variant = 0; variant < 4; variant++) {
      final pack = CustomPieceParts.packForVariant(variant);
      final asset = pack.id.index >= 4
          ? 'assets/characters/kingdoms/${pack.id.name}-v3.png'
          : 'assets/characters/themed-piece-atlas-fantasy-vivid-v5.png';
      final bytes = await rootBundle.load(asset);
      expect(bytes.lengthInBytes, greaterThan(1000), reason: asset);
    }
  });
}
