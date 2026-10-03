import 'package:battle_chess_arena/src/domain/custom_chess_set.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/play/board_appearance.dart';
import 'package:battle_chess_arena/src/services/theme_music.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('custom colours apply without discarding the built-in selection', () {
    final set = CustomChessSet.create(
      id: 'test',
    ).copyWith(lightSquare: 0xFFF0EEEE, darkSquare: 0xFF153933);
    final base = BoardAppearance.forPack(
      piecePacks.last,
    ).withStandardPieces(ClassicPieceStyle.wood);
    final custom = base.withCustomSet(set);
    expect(custom.lightSquare, const Color(0xFFF0EEEE));
    expect(custom.darkSquare, const Color(0xFF153933));
    expect(custom.classicStyle, ClassicPieceStyle.wood);
    expect(custom.withCustomSet(null).board.id, base.board.id);
    expect(custom.withStandardPieces().customSet, isNull);
  });

  test('board-only colours survive piece and custom-set changes', () {
    final base = BoardAppearance.forPack(
      piecePacks.first,
    ).withBoardColors(const Color(0xFFFFE0EA), const Color(0xFF70406F));
    final custom = base.withCustomSet(CustomChessSet.create(id: 'override'));
    final classic = custom.withStandardPieces(ClassicPieceStyle.wood);
    expect(custom.lightSquare, const Color(0xFFFFE0EA));
    expect(custom.darkSquare, const Color(0xFF70406F));
    expect(classic.lightSquare, const Color(0xFFFFE0EA));
    expect(classic.darkSquare, const Color(0xFF70406F));
  });

  testWidgets('studio backgrounds do not change music and honor tint', (
    tester,
  ) async {
    for (final background in CustomBackground.values) {
      final set = CustomChessSet.create(
        id: 'test',
      ).copyWith(background: background, backgroundColor: 0xFF3B1954);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorldBackdrop(
              pack: piecePacks.first,
              customSet: set,
              playSoundtrack: false,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ThemeSoundtrack), findsNothing);
      final gradients = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .map((decoration) => decoration.gradient)
          .whereType<LinearGradient>();
      expect(
        gradients.any(
          (gradient) => gradient.colors.any(
            (colour) => colour.toARGB32() & 0xFFFFFF == 0x3B1954,
          ),
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    }
  });
}
