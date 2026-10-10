// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:battle_chess_arena/src/domain/custom_chess_set.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/play/board_appearance.dart';
import 'package:battle_chess_arena/src/features/studio/custom_piece.dart';
import 'package:battle_chess_arena/src/features/play/themed_piece_sprite.dart';
import 'package:battle_chess_arena/src/services/home_chess_set.dart';
import 'package:battle_chess_arena/src/services/match_appearance_storage.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('four available Fantasy sets leave the full saved catalog intact', () {
    expect(availablePiecePacks.map((pack) => pack.name), [
      'Manga Vanguard',
      'Epic Guardians',
      'Olympian Legion',
      'Neon Dominion',
    ]);
    expect(
      availablePiecePacks.every(
        (pack) => pack.group == PiecePackGroup.original,
      ),
      isTrue,
    );
    expect(piecePacks.map((pack) => pack.id), PiecePackId.values);
    expect(piecePacks.take(4), availablePiecePacks);
    expect(ClassicPieceStyle.values, hasLength(4));
    expect(() => availablePiecePacks.clear(), throwsUnsupportedError);
    expect(() => piecePacks.clear(), throwsUnsupportedError);
  });

  test(
    'stored unavailable preferences and match armies still decode exactly',
    () async {
      SharedPreferences.setMockInitialValues({});
      const preference = HomeChessSet(
        pack: PiecePackId.japanese,
        classic: false,
      );
      await preference.save();
      expect((await HomeChessSet.load()).pack, PiecePackId.japanese);
      final old = BoardAppearance(
        white: piecePacks.singleWhere((pack) => pack.id == PiecePackId.chola),
        black: piecePacks.singleWhere((pack) => pack.id == PiecePackId.asgard),
        board: piecePacks.singleWhere((pack) => pack.id == PiecePackId.troy),
      );
      await MatchAppearanceStorage.save('legacy-room', 'w', old);
      final restored = (await MatchAppearanceStorage.load('legacy-room', 'w'))!;
      expect(restored.white.id, PiecePackId.chola);
      expect(restored.black.id, PiecePackId.asgard);
      expect(restored.board.id, PiecePackId.troy);
      expect(restored.standardPieces, isFalse);
    },
  );

  test('legacy custom JSON keeps its exact design and formation mapping', () {
    const designJson = <String, Object>{
      'horse': 3,
      'costume': 2,
      'face': 1,
      'crown': 3,
      'weapon': 2,
      'structure': 1,
      'scale': .85,
    };
    final design = CustomPieceDesign.fromJson(designJson);
    expect(design.formationPack, isNull);
    expect(design.toJson(), designJson);
    expect(CustomPieceParts.packForDesign(design).id, PiecePackId.chinese);
    final original = CustomChessSet(
      id: 'old-set',
      name: 'Legacy set',
      pieces: {
        for (final side in Side.values)
          for (final role in Role.values)
            CustomChessSet.pieceKey(side, role): design,
      },
    );
    final restored = CustomChessSet.fromJson(original.toJson());
    expect(restored.toJson(), original.toJson());
    for (final side in Side.values) {
      for (final role in Role.values) {
        expect(restored.designFor(side, role), design);
      }
    }
    expect(CustomPieceParts.formationPacks, [
      PiecePackId.chola,
      PiecePackId.roman,
      PiecePackId.chinese,
      PiecePackId.asgard,
    ]);
  });

  test('new Studio pack field round trips and survives role copies', () {
    expect(CustomPieceParts.availableFormationPacks, availablePiecePacks);
    final set = CustomChessSet.create(id: 'new-set');
    for (final side in Side.values) {
      for (final role in Role.values) {
        final initial = set.designFor(side, role);
        expect(
          initial.formationPack,
          side == Side.white ? PiecePackId.anime : PiecePackId.indianEpic,
        );
        for (final pack in availablePiecePacks) {
          final design = initial.copyWith(formationPack: pack.id, scale: .9);
          final restored = CustomPieceDesign.fromJson(design.toJson());
          expect(restored, design);
          expect(restored.hashCode, design.hashCode);
          expect(restored.copyWith(crown: 3).formationPack, pack.id);
          expect(CustomPieceParts.packForDesign(restored), pack);
        }
      }
    }
    final unknown = CustomPieceDesign.fromJson({
      'costume': 3,
      'formationPack': 'unknown-army',
    });
    expect(unknown.formationPack, isNull);
    expect(CustomPieceParts.packForDesign(unknown).id, PiecePackId.asgard);
  });

  testWidgets('new Fantasy formations render every role and side accurately', (
    tester,
  ) async {
    const roles = [
      Role.king,
      Role.queen,
      Role.bishop,
      Role.knight,
      Role.rook,
      Role.pawn,
    ];
    for (final pack in availablePiecePacks) {
      for (final side in Side.values) {
        for (final role in roles) {
          final set = CustomChessSet.create(
            id: 'new-set',
          ).withDesign(side, role, CustomPieceDesign(formationPack: pack.id));
          await tester.pumpWidget(
            MaterialApp(
              home: Center(
                child: SizedBox.square(
                  dimension: 160,
                  child: CustomPiece(
                    piece: Piece(color: side, role: role),
                    chessSet: set,
                    showRole: false,
                  ),
                ),
              ),
            ),
          );
          final sprite = tester.widget<ThemedPieceSprite>(
            find.byType(ThemedPieceSprite),
          );
          expect(
            sprite.asset,
            'assets/characters/themed-piece-atlas-fantasy-vivid-v5.png',
          );
          expect(sprite.row, pack.id.index * 2 + (side == Side.white ? 0 : 1));
          expect(sprite.column, roles.indexOf(role));
          expect(sprite.flipX, side == Side.black);
          expect(tester.takeException(), isNull);
        }
      }
    }
  });
}
