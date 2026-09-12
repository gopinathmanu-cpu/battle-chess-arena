import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/play/board_appearance.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every theme, side and role has a distinct atlas cell', () {
    final cells = <String>{};
    for (final pack in piecePacks) {
      for (final side in Side.values) {
        for (final role in CharacterPiece.roles) {
          final piece = CharacterPiece(
            piece: Piece(color: side, role: role),
            pack: pack,
          );
          cells.add('${piece.atlasRow}:${piece.atlasColumn}');
        }
      }
    }
    expect(cells.length, 60);
  });
  testWidgets('mixed armies retain their identity with black orientation', (
    tester,
  ) async {
    final appearance = BoardAppearance(
      white: piecePacks[1],
      black: piecePacks[3],
      board: piecePacks[2],
    );
    Square? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox.square(
            dimension: 400,
            child: ChessBoard(
              position: Chess.initial,
              selected: null,
              legalTargets: const {},
              accent: Colors.blue,
              orientation: Side.black,
              appearance: appearance,
              onSquareTap: (s) => tapped = s,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final sprites = tester.widgetList<CharacterPiece>(
      find.byType(CharacterPiece),
    );
    expect(sprites.length, 32);
    expect(
      sprites
          .where((p) => p.piece.color == Side.white)
          .every((p) => p.pack.id == PiecePackId.indianEpic),
      true,
    );
    expect(
      sprites
          .where((p) => p.piece.color == Side.black)
          .every((p) => p.pack.id == PiecePackId.futuristic),
      true,
    );
    await tester.tap(find.byKey(const ValueKey('square-e7')));
    expect(tapped, Square.e7);
    expect(tester.takeException(), isNull);
  });
}
