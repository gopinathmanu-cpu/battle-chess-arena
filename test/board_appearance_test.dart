import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/play/board_appearance.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:battle_chess_arena/src/features/play/themed_piece_sprite.dart';
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
          cells.add(
            '${piece.atlasAsset}:${piece.atlasRow}:${piece.atlasColumn}',
          );
          expect(piece.atlasRow, lessThan(piece.atlasRows));
        }
      }
    }
    expect(cells.length, piecePacks.length * 12);
  });

  test('standard piece mode keeps the selected armies and board world', () {
    final appearance = BoardAppearance(
      white: piecePacks[0],
      black: piecePacks[1],
      board: piecePacks[2],
    ).withStandardPieces();

    expect(appearance.white.id, PiecePackId.anime);
    expect(appearance.black.id, PiecePackId.indianEpic);
    expect(appearance.board.id, PiecePackId.greek);
    expect(appearance.standardPieces, isTrue);
  });

  testWidgets('last opponent move marks its origin and destination', (
    tester,
  ) async {
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
              lastMoveFrom: Square.e7,
              lastMoveTo: Square.e5,
              onSquareTap: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('last-move-e7')), findsOneWidget);
    expect(find.byKey(const ValueKey('last-move-e5')), findsOneWidget);
  });

  testWidgets('best move uses markers distinct from the last move', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.square(
          dimension: 400,
          child: ChessBoard(
            position: Chess.initial,
            selected: null,
            legalTargets: const {},
            accent: Colors.blue,
            suggestedFrom: Square.g8,
            suggestedTo: Square.f6,
            lastMoveFrom: Square.e7,
            lastMoveTo: Square.e5,
            onSquareTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('best-move-origin-icon')), findsOneWidget);
    expect(find.byKey(const ValueKey('best-move-target-icon')), findsOneWidget);
    expect(find.byKey(const ValueKey('last-move-e7')), findsOneWidget);
    expect(find.byKey(const ValueKey('last-move-e5')), findsOneWidget);
  });

  testWidgets('checked king alert remains until the check is removed', (
    tester,
  ) async {
    Widget board(Position position) => MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: SizedBox.square(
          dimension: 400,
          child: ChessBoard(
            position: position,
            selected: null,
            legalTargets: const {},
            accent: Colors.blue,
            onSquareTap: (_) {},
          ),
        ),
      ),
    );

    final checked = Chess.fromSetup(
      Setup.parseFen('7k/7R/8/8/8/8/8/K7 b - - 0 1'),
    );
    expect(checked.isCheck, isTrue);
    await tester.pumpWidget(board(checked));
    expect(find.byKey(const ValueKey('checked-king-h8')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('checked-king-warning-icon')),
      findsOneWidget,
    );

    await tester.pumpWidget(board(Chess.initial));
    expect(find.byKey(const ValueKey('checked-king-h8')), findsNothing);
  });

  testWidgets('Classic set uses the bundled four-variation image atlas', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.square(
          dimension: 80,
          child: CharacterPiece(
            piece: const Piece(color: Side.white, role: Role.bishop),
            pack: piecePacks.first,
            standard: true,
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as AssetImage).assetName,
      'assets/characters/classic-piece-variations-atlas.png',
    );
  });

  testWidgets('themed set uses the Bishop walking atlas', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.square(
          dimension: 80,
          child: CharacterPiece(
            piece: const Piece(color: Side.black, role: Role.rook),
            pack: piecePacks.first,
          ),
        ),
      ),
    );

    final image = tester.widget<ThemedPieceSprite>(
      find.byType(ThemedPieceSprite),
    );
    expect(
      image.asset,
      'assets/characters/themed-piece-atlas-fantasy-vivid-v5.png',
    );
    expect(find.byType(OverflowBox), findsNothing);
    expect(CharacterPiece.atlasWidth / 6, CharacterPiece.atlasCellSize);
    expect(CharacterPiece.atlasHeight / 8, CharacterPiece.atlasCellSize);
  });

  testWidgets(
    'appearance dialog switches between every themed and classic set',
    (tester) async {
      BoardAppearance? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                selected = await chooseBoardAppearance(
                  context,
                  BoardAppearance.forPack(piecePacks.first),
                );
              },
              child: const Text('Customize'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Customize'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('chess-set-family-selector')), findsOne);
      expect(find.text('White army'), findsOne);
      expect(find.text('Black army'), findsOne);

      await tester.tap(find.text('Classic'));
      await tester.pumpAndSettle();
      expect(find.text('White army'), findsNothing);
      expect(
        find.byKey(const ValueKey('dialog-classic-piece-style-selector')),
        findsOne,
      );
      await tester.tap(find.text('Magnetic 3D · Teaching-board style'));
      await tester.pumpAndSettle();
      for (final style in ClassicPieceStyle.values) {
        expect(find.text('${style.label} · ${style.subtitle}'), findsWidgets);
      }
      await tester.tap(
        find.text('Flat Teaching · Rounded teaching icons').last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(selected?.standardPieces, isTrue);
      expect(selected?.classicStyle, ClassicPieceStyle.metal);
    },
  );

  testWidgets('appearance dialog keeps a conquest opponent locked', (
    tester,
  ) async {
    BoardAppearance? selected;
    final opponent = piecePacks.firstWhere(
      (pack) => pack.id == PiecePackId.chola,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              selected = await chooseBoardAppearance(
                context,
                BoardAppearance(
                  white: piecePacks.first,
                  black: piecePacks[1],
                  board: opponent,
                ),
                lockedBlack: opponent,
                lockedBlackReason: 'Locked to this conquest opponent.',
              );
            },
            child: const Text('Conquest appearance'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Conquest appearance'));
    await tester.pumpAndSettle();
    expect(find.text('Opponent army'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('locked-opponent-army-message')),
      findsOneWidget,
    );
    final opponentField = tester
        .widgetList<DropdownButtonFormField<PiecePack>>(
          find.byType(DropdownButtonFormField<PiecePack>),
        )
        .firstWhere((field) => field.decoration.labelText == 'Opponent army');
    expect(opponentField.onChanged, isNull);
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(selected!.black.id, PiecePackId.chola);
  });

  testWidgets('black themed characters mirror toward their opponents', (
    tester,
  ) async {
    Future<bool> flipsHorizontally(Side side) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox.square(
            dimension: 80,
            child: CharacterPiece(
              piece: Piece(color: side, role: Role.knight),
              pack: piecePacks.first,
            ),
          ),
        ),
      );
      return tester
          .widget<ThemedPieceSprite>(find.byType(ThemedPieceSprite))
          .flipX;
    }

    expect(await flipsHorizontally(Side.white), isFalse);
    expect(await flipsHorizontally(Side.black), isTrue);
  });

  test(
    'kingdom packs use separate two-army assets and readable board colours',
    () {
      for (final pack in piecePacks.skip(4)) {
        final sprite = CharacterPiece(
          piece: const Piece(color: Side.black, role: Role.pawn),
          pack: pack,
        );
        expect(
          sprite.atlasAsset,
          'assets/characters/kingdoms/${pack.id.name}-v3.png',
        );
        expect(sprite.atlasRows, 2);
        expect(sprite.atlasRow, 1);
        expect(sprite.atlasColumn, 5);
        expect(
          pack.lightSquare.computeLuminance(),
          greaterThan(pack.darkSquare.computeLuminance()),
        );
        expect(pack.armyName(Side.white), isNot(pack.armyName(Side.black)));
      }
    },
  );

  test('every chess set has a distinct, high-contrast board palette', () {
    final palettes = <String>{};
    for (final pack in piecePacks) {
      final light = pack.lightSquare.computeLuminance();
      final dark = pack.darkSquare.computeLuminance();
      expect(light - dark, greaterThan(.22), reason: pack.name);
      expect(light, greaterThan(.48), reason: pack.name);
      expect(dark, lessThan(.24), reason: pack.name);
      palettes.add(
        '${pack.lightSquare.toARGB32()}:${pack.darkSquare.toARGB32()}',
      );
    }
    expect(palettes, hasLength(piecePacks.length));
  });

  testWidgets('new kingdom backgrounds never index the original scene atlas', (
    tester,
  ) async {
    for (final pack in piecePacks.skip(4)) {
      await tester.pumpWidget(
        MaterialApp(
          home: WorldBackdrop(
            pack: pack,
            playSoundtrack: false,
            child: const Text('Kingdom'),
          ),
        ),
      );
      expect(find.byType(OverflowBox), findsNothing);
      expect(find.byType(Image), findsNothing);
      expect(find.text('Kingdom'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('move history is shown as a white and black table', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MoveStrip(moves: ['e4', 'e5', 'Nf3'], accent: Colors.amber),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('move-history-table')), findsOneWidget);
    expect(find.text('Move'), findsOneWidget);
    expect(find.text('White'), findsOneWidget);
    expect(find.text('Black'), findsOneWidget);
    expect(find.text('Nf3'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    final table = tester.widget<Table>(find.byType(Table));
    expect(table.columnWidths?[0], const FixedColumnWidth(72));
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
