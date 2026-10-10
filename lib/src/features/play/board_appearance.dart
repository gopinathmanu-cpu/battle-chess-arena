// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../../domain/piece_pack.dart';
import '../../domain/custom_chess_set.dart';
import '../../domain/animated_army_theme.dart';
import '../../services/theme_music.dart';
import '../../services/app_color_scheme_controller.dart';
import '../studio/custom_piece.dart';
import 'themed_piece_sprite.dart';

class BoardAppearance {
  const BoardAppearance({
    required this.white,
    required this.black,
    required this.board,
    this.standardPieces = false,
    this.animatedArena = true,
    this.classicStyle = ClassicPieceStyle.magneticTeaching,
    this.customSet,
    this.lightSquareOverride,
    this.darkSquareOverride,
  });
  factory BoardAppearance.forPack(PiecePack pack) =>
      BoardAppearance(white: pack, black: pack, board: pack);
  final PiecePack white;
  final PiecePack black;
  final PiecePack board;
  final bool standardPieces;

  /// Page presentation is independent of swiping the board's piece artwork.
  final bool animatedArena;
  final ClassicPieceStyle classicStyle;
  final CustomChessSet? customSet;
  final Color? lightSquareOverride;
  final Color? darkSquareOverride;
  Color get lightSquare =>
      lightSquareOverride ??
      (customSet != null
          ? Color(customSet!.lightSquare)
          : _animatedBoardTheme != null
          ? Color(_animatedBoardTheme!.lightSquareArgb)
          : board.lightSquare);
  Color get darkSquare =>
      darkSquareOverride ??
      (customSet != null
          ? Color(customSet!.darkSquare)
          : _animatedBoardTheme != null
          ? Color(_animatedBoardTheme!.darkSquareArgb)
          : board.darkSquare);
  AnimatedArmyTheme? get _animatedBoardTheme =>
      animatedArena ? AnimatedArmyTheme.forPack(board.id) : null;
  PiecePack army(Side side) => side == Side.white ? white : black;

  BoardAppearance withCustomSet(CustomChessSet? set) => BoardAppearance(
    white: white,
    black: black,
    board: board,
    standardPieces: standardPieces,
    animatedArena: animatedArena,
    classicStyle: classicStyle,
    customSet: set,
    lightSquareOverride: lightSquareOverride,
    darkSquareOverride: darkSquareOverride,
  );

  BoardAppearance withBoardColors(Color light, Color dark) => BoardAppearance(
    white: white,
    black: black,
    board: board,
    standardPieces: standardPieces,
    animatedArena: animatedArena,
    classicStyle: classicStyle,
    customSet: customSet,
    lightSquareOverride: light,
    darkSquareOverride: dark,
  );

  BoardAppearance withStandardPieces([
    ClassicPieceStyle style = ClassicPieceStyle.magneticTeaching,
  ]) {
    return BoardAppearance(
      white: white,
      black: black,
      board: board,
      standardPieces: true,
      animatedArena: animatedArena,
      classicStyle: style,
      lightSquareOverride: lightSquareOverride,
      darkSquareOverride: darkSquareOverride,
    );
  }
}

extension PieceWorld on PiecePack {
  Color get lightSquare => switch (id) {
    PiecePackId.anime => const Color(0xFFD6E3E8),
    PiecePackId.indianEpic => const Color(0xFFD8E3CF),
    PiecePackId.greek => const Color(0xFFE0C99F),
    PiecePackId.futuristic => const Color(0xFFBFC8CC),
    PiecePackId.japanese => const Color(0xFFC9D8DB),
    PiecePackId.chinese => const Color(0xFFCDD9D2),
    PiecePackId.mongolian => const Color(0xFFC9D9E2),
    PiecePackId.egyptian => const Color(0xFFC8DDE0),
    PiecePackId.arab => const Color(0xFFD8D2E2),
    PiecePackId.persian => const Color(0xFFDED1B8),
    PiecePackId.english => const Color(0xFFD0DDCF),
    PiecePackId.french => const Color(0xFFE0CFC4),
    PiecePackId.sparta => const Color(0xFFC9DBDF),
    PiecePackId.macedonian => const Color(0xFFDDCFD2),
    PiecePackId.roman => const Color(0xFFCCDCE2),
    PiecePackId.achaemenid => const Color(0xFFD4DEC8),
    PiecePackId.ottoman => const Color(0xFFDAD1E1),
    PiecePackId.chola => const Color(0xFFCCD9E0),
    PiecePackId.maratha => const Color(0xFFD2DFC9),
    PiecePackId.zulu => const Color(0xFFC9D9E0),
    PiecePackId.aztec => const Color(0xFFDED5C9),
    PiecePackId.inca => const Color(0xFFCADAE2),
    PiecePackId.mewar => const Color(0xFFD0DEC9),
    PiecePackId.lanka => const Color(0xFFCADCE0),
    PiecePackId.ayodhya => const Color(0xFFDDD0D6),
    PiecePackId.hastinapura => const Color(0xFFDDCEB5),
    PiecePackId.kishkindha => const Color(0xFFD8D1E2),
    PiecePackId.asgard => const Color(0xFFDDCBAE),
    PiecePackId.camelot => const Color(0xFFE1CDC8),
    PiecePackId.atlantis => const Color(0xFFE0D0AF),
    PiecePackId.troy => const Color(0xFFCCD9DF),
  };
  Color get darkSquare => switch (id) {
    PiecePackId.anime => const Color(0xFF41606B),
    PiecePackId.indianEpic => const Color(0xFF3E625C),
    PiecePackId.greek => const Color(0xFF76543B),
    PiecePackId.futuristic => const Color(0xFF36434A),
    PiecePackId.japanese => const Color(0xFF6B3E4A),
    PiecePackId.chinese => const Color(0xFF405E6B),
    PiecePackId.mongolian => const Color(0xFF48566F),
    PiecePackId.egyptian => const Color(0xFF7B5045),
    PiecePackId.arab => const Color(0xFF456A68),
    PiecePackId.persian => const Color(0xFF3F6870),
    PiecePackId.english => const Color(0xFF485F70),
    PiecePackId.french => const Color(0xFF66475E),
    PiecePackId.sparta => const Color(0xFF3C6266),
    PiecePackId.macedonian => const Color(0xFF624B67),
    PiecePackId.roman => const Color(0xFF40586D),
    PiecePackId.achaemenid => const Color(0xFF42675F),
    PiecePackId.ottoman => const Color(0xFF60485F),
    PiecePackId.chola => const Color(0xFF465A70),
    PiecePackId.maratha => const Color(0xFF40645E),
    PiecePackId.zulu => const Color(0xFF465969),
    PiecePackId.aztec => const Color(0xFF60495F),
    PiecePackId.inca => const Color(0xFF405871),
    PiecePackId.mewar => const Color(0xFF41645E),
    PiecePackId.lanka => const Color(0xFF3E6268),
    PiecePackId.ayodhya => const Color(0xFF614A64),
    PiecePackId.hastinapura => const Color(0xFF6B513D),
    PiecePackId.kishkindha => const Color(0xFF4B526E),
    PiecePackId.asgard => const Color(0xFF6A523E),
    PiecePackId.camelot => const Color(0xFF684650),
    PiecePackId.atlantis => const Color(0xFF614A65),
    PiecePackId.troy => const Color(0xFF405A6C),
  };
  Color get backdrop => Color.lerp(darkSquare, Colors.black, .78)!;
  String armyName(Side side) {
    const names = [
      ['Dawn Guard', 'Dusk Raiders'],
      ['Solar Guardians', 'Moon Sentinels'],
      ['Olympian Court', 'Underworld Legion'],
      ['Aurora Command', 'Void Command'],
      ['Ivory Shogunate', 'Crimson Shogunate'],
      ['Jade Dynasty', 'Vermilion Dynasty'],
      ['Sky Riders', 'Steppe Guardians'],
      ['Sun Court', 'Obsidian Court'],
      ['Pearl Court', 'Emerald Court'],
      ['Ivory Immortals', 'Violet Immortals'],
      ['Ivory Crown', 'Crimson Crown'],
      ['Azure Court', 'Royal Garnet'],
    ];
    if (id.index < names.length) {
      return names[id.index][side == Side.white ? 0 : 1];
    }
    return '${side == Side.white ? 'Ivory' : 'Obsidian'} $name';
  }
}

/// Each themed atlas is decoded once and only its isolated sprite is painted.
class CharacterPiece extends StatelessWidget {
  const CharacterPiece({
    required this.piece,
    required this.pack,
    this.showRole = true,
    this.standard = false,
    this.classicStyle = ClassicPieceStyle.magneticTeaching,
    this.customSet,
    super.key,
  });
  static const atlas =
      'assets/characters/themed-piece-atlas-fantasy-vivid-v5.png';
  static const atlasWidth = 1536.0;
  static const atlasHeight = 2048.0;
  static const atlasCellSize = 256.0;
  static const roles = [
    Role.king,
    Role.queen,
    Role.bishop,
    Role.knight,
    Role.rook,
    Role.pawn,
  ];
  final Piece piece;
  final PiecePack pack;
  final bool showRole;
  final bool standard;
  final ClassicPieceStyle classicStyle;
  final CustomChessSet? customSet;
  bool get usesKingdomAtlas => pack.id.index >= 4;
  String get atlasAsset => usesKingdomAtlas
      ? 'assets/characters/kingdoms/${pack.id.name}-v3.png'
      : atlas;
  int get atlasRows => usesKingdomAtlas ? 2 : 8;
  int get atlasRow =>
      (usesKingdomAtlas ? 0 : pack.id.index * 2) +
      (piece.color == Side.white ? 0 : 1);
  int get atlasColumn => roles.indexOf(piece.role);
  double get roleScale => ThemedPieceMetrics.scaleFor(piece.role);
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest.shortestSide;
      if (customSet != null) {
        return CustomPiece(
          piece: piece,
          chessSet: customSet!,
          showRole: showRole,
        );
      }
      if (standard) {
        return SizedBox.square(
          dimension: size,
          child: _ClassicChessPiece(piece: piece, style: classicStyle),
        );
      }
      final animatedTheme = AnimatedArmyTheme.forPack(pack.id);
      return SizedBox.square(
        dimension: size,
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(.5),
                child: ExcludeSemantics(
                  child: animatedTheme != null
                      ? AnimatedArmyBoardSprite(
                          piece: piece,
                          theme: animatedTheme,
                        )
                      : ThemedPieceSprite(
                          asset: atlasAsset,
                          row: atlasRow,
                          column: atlasColumn,
                          rows: atlasRows,
                          role: piece.role,
                          flipX: piece.color == Side.black,
                          brightenDarkArmy: piece.color == Side.black,
                        ),
                ),
              ),
            ),
            if (showRole)
              Positioned(
                right: 1,
                bottom: 1,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: size * .35,
                    maxHeight: size * .35,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: piece.color == Side.white
                            ? const Color(0xFFF8F0DD)
                            : const Color(0xFF161525),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: pack.accent.withValues(alpha: .7),
                          width: .6,
                        ),
                      ),
                      child: Text(
                        switch (piece.role) {
                          Role.king => 'K',
                          Role.queen => 'Q',
                          Role.rook => 'R',
                          Role.bishop => 'B',
                          Role.knight => 'N',
                          Role.pawn => 'P',
                        },
                        style: TextStyle(
                          fontSize: 8,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          color: piece.color == Side.white
                              ? Colors.black87
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class PieceStyleToggleButton extends StatelessWidget {
  const PieceStyleToggleButton({
    required this.classic,
    required this.themedPack,
    required this.onPressed,
    this.compact = false,
    this.cycleClassicSets = false,
    this.classicStyle = ClassicPieceStyle.magneticTeaching,
    super.key,
  });

  final bool classic;
  final PiecePack themedPack;
  final VoidCallback onPressed;
  final bool compact;
  final bool cycleClassicSets;
  final ClassicPieceStyle classicStyle;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: cycleClassicSets
        ? 'Next Classic set'
        : classic
        ? 'Use animated character pieces'
        : 'Use classic chess pieces',
    padding: compact ? const EdgeInsets.all(1) : null,
    constraints: compact
        ? const BoxConstraints.tightFor(width: 34, height: 48)
        : null,
    style: compact
        ? IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap)
        : null,
    onPressed: onPressed,
    icon: Container(
      key: const ValueKey('piece-style-toggle-icon'),
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (cycleClassicSets)
            SizedBox.square(
              dimension: 27,
              child: CharacterPiece(
                piece: const Piece(color: Side.white, role: Role.knight),
                pack: themedPack,
                standard: true,
                classicStyle:
                    ClassicPieceStyle.values[(classicStyle.index + 1) %
                        ClassicPieceStyle.values.length],
              ),
            )
          else if (classic)
            SizedBox.square(
              key: const ValueKey('switch-to-themed-icon'),
              dimension: 27,
              child: CharacterPiece(
                piece: const Piece(color: Side.white, role: Role.knight),
                pack: themedPack,
                showRole: false,
              ),
            )
          else
            Text(
              '♞',
              key: const ValueKey('switch-to-classic-icon'),
              style: TextStyle(
                fontSize: 25,
                height: 1,
                color: themedPack.accent,
                fontWeight: FontWeight.w900,
              ),
            ),
          Positioned(
            right: -4,
            bottom: -4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: Icon(
                Icons.change_circle_rounded,
                size: 15,
                color: themedPack.accent,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Traditional Staunton pieces used by the Classic Chess Set toggle.
class _ClassicChessPiece extends StatelessWidget {
  const _ClassicChessPiece({required this.piece, required this.style});

  static const atlas = 'assets/characters/classic-piece-variations-atlas.png';
  static const atlasWidth = 1536.0;
  static const atlasHeight = 2048.0;
  static const cellSize = 256.0;
  final Piece piece;
  final ClassicPieceStyle style;

  @override
  Widget build(BuildContext context) {
    final column = CharacterPiece.roles.indexOf(piece.role);
    final row = style.index * 2 + (piece.color == Side.white ? 0 : 1);
    return Padding(
      padding: const EdgeInsets.all(1.5),
      child: ExcludeSemantics(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox.square(
            dimension: cellSize,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment(-1 + 2 * column / 5, -1 + 2 * row / 7),
                minWidth: atlasWidth,
                maxWidth: atlasWidth,
                minHeight: atlasHeight,
                maxHeight: atlasHeight,
                child: Image.asset(
                  atlas,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high,
                  isAntiAlias: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<BoardAppearance?> chooseBoardAppearance(
  BuildContext context,
  BoardAppearance current, {
  PiecePack? lockedBlack,
  String? lockedBlackReason,
}) {
  var white = current.white;
  var black = lockedBlack ?? current.black;
  var board = current.board;
  var classic = current.standardPieces;
  var classicStyle = current.classicStyle;
  return showDialog<BoardAppearance>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, refresh) {
        Widget field(
          String label,
          PiecePack value,
          ValueChanged<PiecePack> changed, {
          bool enabled = true,
        }) => DropdownButtonFormField<PiecePack>(
          initialValue: availablePiecePacks.contains(value) ? value : null,
          hint: Text(value.name),
          disabledHint: Text(value.name),
          isExpanded: true,
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: enabled ? null : const Icon(Icons.lock_outline),
          ),
          items: availablePiecePacks
              .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
              .toList(),
          onChanged: enabled
              ? (p) {
                  if (p != null) refresh(() => changed(p));
                }
              : null,
        );
        return AlertDialog(
          title: const Text('Chess set & theme'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<bool>(
                  key: const ValueKey('chess-set-family-selector'),
                  segments: const [
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.groups_2_outlined),
                      label: Text('Animated'),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.castle_outlined),
                      label: Text('Classic'),
                    ),
                  ],
                  selected: {classic},
                  onSelectionChanged: (value) =>
                      refresh(() => classic = value.first),
                ),
                const SizedBox(height: 12),
                if (!classic) ...[
                  field('White army', white, (p) => white = p),
                  const SizedBox(height: 12),
                  field(
                    lockedBlack == null ? 'Black army' : 'Opponent army',
                    black,
                    (p) => black = p,
                    enabled: lockedBlack == null,
                  ),
                  if (lockedBlack != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      lockedBlackReason ??
                          'This opponent army is fixed for the current round.',
                      key: const ValueKey('locked-opponent-army-message'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 12),
                ] else
                  DropdownButtonFormField<ClassicPieceStyle>(
                    key: const ValueKey('dialog-classic-piece-style-selector'),
                    initialValue: classicStyle,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Classic set'),
                    items: [
                      for (final style in ClassicPieceStyle.values)
                        DropdownMenuItem(
                          value: style,
                          child: Text('${style.label} · ${style.subtitle}'),
                        ),
                    ],
                    onChanged: (style) {
                      if (style != null) {
                        refresh(() => classicStyle = style);
                      }
                    },
                  ),
                const SizedBox(height: 12),
                field('Board world', board, (p) => board = p),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    SizedBox.square(
                      dimension: 76,
                      child: CharacterPiece(
                        piece: const Piece(color: Side.white, role: Role.king),
                        pack: white,
                        standard: classic,
                        classicStyle: classicStyle,
                      ),
                    ),
                    SizedBox.square(
                      dimension: 76,
                      child: CharacterPiece(
                        piece: const Piece(color: Side.black, role: Role.king),
                        pack: black,
                        standard: classic,
                        classicStyle: classicStyle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'You can change the set during a game. Chess roles and turns stay the same.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                BoardAppearance(
                  white: white,
                  black: lockedBlack ?? black,
                  board: board,
                  standardPieces: classic,
                  classicStyle: classicStyle,
                ),
              ),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    ),
  );
}

class WorldBackdrop extends StatelessWidget {
  const WorldBackdrop({
    required this.pack,
    required this.child,
    this.customSet,
    this.playSoundtrack = true,
    super.key,
  });
  final PiecePack pack;
  final Widget child;
  final bool playSoundtrack;
  final CustomChessSet? customSet;
  PiecePack get _scenePack =>
      customSet != null && customSet!.background.index < 4
      ? piecePacks[customSet!.background.index]
      : pack;
  Color get _overlayTint => customSet == null
      ? _scenePack.backdrop
      : Color(customSet!.backgroundColor);
  @override
  Widget build(BuildContext context) {
    final appBackground = AppColorSchemeScope.maybeOf(context);
    if (appBackground?.backgroundMode == AppBackgroundMode.single) {
      final colors = appBackground!.preset.backgroundGradient;
      final backdrop = Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              key: const ValueKey('single-application-background'),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-.65, -.85),
                  radius: 1.55,
                  colors: colors,
                  stops: const [0, .48, 1],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: .12),
                    Colors.black.withValues(alpha: .68),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(child: child),
        ],
      );
      return playSoundtrack
          ? ThemeSoundtrack(theme: _scenePack.id, child: backdrop)
          : backdrop;
    }
    final backdrop = Stack(
      children: [
        if ((customSet == null || customSet!.background.index < 4) &&
            _scenePack.id.index < 4)
          Positioned.fill(
            child: ExcludeSemantics(
              child: ClipRect(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: 256,
                    height: 204.8,
                    child: ClipRect(
                      child: OverflowBox(
                        minWidth: 1536,
                        maxWidth: 1536,
                        minHeight: 1024,
                        maxHeight: 1024,
                        alignment: Alignment(1, -1 + _scenePack.id.index * .5),
                        child: Image.asset(
                          'assets/concepts/piece-families.png',
                          fit: BoxFit.fill,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (customSet == null && _scenePack.id.index >= 4)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-.65, -.8),
                  radius: 1.55,
                  colors: [
                    Color.lerp(_scenePack.darkSquare, _scenePack.accent, .16)!,
                    _scenePack.backdrop,
                    Color.lerp(_scenePack.backdrop, Colors.black, .35)!,
                  ],
                  stops: const [0, .65, 1],
                ),
              ),
            ),
          ),
        if (customSet != null && customSet!.background.index >= 4)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-.6, -.8),
                  radius: 1.6,
                  colors: [
                    Color(customSet!.backgroundColor),
                    switch (customSet!.background) {
                      CustomBackground.forest => const Color(0xFF061E18),
                      CustomBackground.royal => const Color(0xFF211031),
                      _ => const Color(0xFF060B18),
                    },
                  ],
                ),
              ),
            ),
          ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _overlayTint.withValues(
                    alpha: customSet != null && customSet!.background.index >= 4
                        ? .12
                        : .48,
                  ),
                  _overlayTint.withValues(
                    alpha: customSet != null && customSet!.background.index >= 4
                        ? .3
                        : .78,
                  ),
                ],
              ),
            ),
          ),
        ),
        SafeArea(child: child),
      ],
    );
    return playSoundtrack
        ? ThemeSoundtrack(theme: _scenePack.id, child: backdrop)
        : backdrop;
  }
}
