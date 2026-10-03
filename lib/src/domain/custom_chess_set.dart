// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:dartchess/dartchess.dart';

enum CustomBoardSurface { solid, wood, marble, neon }

enum CustomBackground {
  anime,
  indianEpic,
  greek,
  futuristic,
  midnight,
  forest,
  royal,
}

/// The independently selectable parts of one role on one side of the board.
class CustomPieceDesign {
  const CustomPieceDesign({
    int horse = 0,
    int costume = 0,
    int face = 0,
    int crown = 0,
    int weapon = 0,
    int structure = 0,
    double scale = 1,
  }) : horse = horse < 0 ? 0 : (horse > 3 ? 3 : horse),
       costume = costume < 0 ? 0 : (costume > 3 ? 3 : costume),
       face = face < 0 ? 0 : (face > 3 ? 3 : face),
       crown = crown < 0 ? 0 : (crown > 3 ? 3 : crown),
       weapon = weapon < 0 ? 0 : (weapon > 3 ? 3 : weapon),
       structure = structure < 0 ? 0 : (structure > 3 ? 3 : structure),
       scale = scale != scale
           ? 1
           : (scale < .65 ? .65 : (scale > 1.15 ? 1.15 : scale));

  static const minScale = .65;
  static const maxScale = 1.15;
  static const variantCount = 4;

  final int horse;
  final int costume;
  final int face;
  final int crown;
  final int weapon;
  final int structure;
  final double scale;

  CustomPieceDesign copyWith({
    int? horse,
    int? costume,
    int? face,
    int? crown,
    int? weapon,
    int? structure,
    double? scale,
  }) => CustomPieceDesign(
    horse: horse ?? this.horse,
    costume: costume ?? this.costume,
    face: face ?? this.face,
    crown: crown ?? this.crown,
    weapon: weapon ?? this.weapon,
    structure: structure ?? this.structure,
    scale: scale ?? this.scale,
  );

  factory CustomPieceDesign.fromJson(Object? value) {
    final json = value is Map ? value : const <String, Object?>{};
    int index(String key) => json[key] is int ? json[key] as int : 0;
    final scale = json['scale'];
    return CustomPieceDesign(
      horse: index('horse'),
      costume: index('costume'),
      face: index('face'),
      crown: index('crown'),
      weapon: index('weapon'),
      structure: index('structure'),
      scale: scale is num && scale.isFinite ? scale.toDouble() : 1,
    );
  }

  Map<String, Object> toJson() => {
    'horse': horse,
    'costume': costume,
    'face': face,
    'crown': crown,
    'weapon': weapon,
    'structure': structure,
    'scale': scale,
  };

  @override
  bool operator ==(Object other) =>
      other is CustomPieceDesign &&
      horse == other.horse &&
      costume == other.costume &&
      face == other.face &&
      crown == other.crown &&
      weapon == other.weapon &&
      structure == other.structure &&
      scale == other.scale;

  @override
  int get hashCode =>
      Object.hash(horse, costume, face, crown, weapon, structure, scale);
}

/// Device-local appearance only; no piece design can alter chess rules.
class CustomChessSet {
  CustomChessSet({
    required String id,
    required String name,
    required Map<String, CustomPieceDesign> pieces,
    this.lightSquare = 0xFFE9D8BD,
    this.darkSquare = 0xFF6C5C4C,
    this.whiteAccent = 0xFFFFCB78,
    this.blackAccent = 0xFF9CAAFF,
    this.backgroundColor = 0xFF111827,
    this.surface = CustomBoardSurface.wood,
    this.background = CustomBackground.midnight,
  }) : id = id.trim(),
       name = _normalizeName(name),
       pieces = Map.unmodifiable({
         for (final side in Side.values)
           for (final role in Role.values)
             pieceKey(side, role):
                 pieces[pieceKey(side, role)] ?? _defaultDesign(side, role),
       });

  static const maxNameLength = 40;
  static const defaultName = 'My chess set';
  final String id;
  final String name;
  final Map<String, CustomPieceDesign> pieces;
  final int lightSquare;
  final int darkSquare;
  final int whiteAccent;
  final int blackAccent;
  final int backgroundColor;
  final CustomBoardSurface surface;
  final CustomBackground background;

  factory CustomChessSet.create({
    required String id,
    String name = defaultName,
  }) => CustomChessSet(id: id, name: name, pieces: const {});

  static String pieceKey(Side side, Role role) => '${side.name}.${role.name}';

  static CustomPieceDesign _defaultDesign(Side side, Role role) =>
      CustomPieceDesign(
        costume: side == Side.white ? 0 : 1,
        horse: side == Side.white ? 0 : 2,
        structure: side == Side.white ? 0 : 3,
        crown: switch (role) {
          Role.queen => 1,
          Role.knight => 2,
          Role.bishop => 3,
          _ => 0,
        },
        face: switch (role) {
          Role.king => side == Side.white ? 0 : 1,
          Role.queen => side == Side.white ? 2 : 3,
          Role.bishop => 1,
          _ => 0,
        },
        weapon: switch (role) {
          Role.queen || Role.bishop => 1,
          Role.knight || Role.pawn => 2,
          _ => 0,
        },
      );

  static String _normalizeName(String name) {
    final clean = name.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), ' ').trim();
    return clean.isEmpty
        ? defaultName
        : String.fromCharCodes(clean.runes.take(maxNameLength));
  }

  static bool isValidId(String id) =>
      RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,79}$').hasMatch(id);

  CustomPieceDesign designFor(Side side, Role role) =>
      pieces[pieceKey(side, role)]!;

  CustomChessSet withDesign(Side side, Role role, CustomPieceDesign design) =>
      copyWith(pieces: {...pieces, pieceKey(side, role): design});

  CustomChessSet copyWith({
    String? id,
    String? name,
    Map<String, CustomPieceDesign>? pieces,
    int? lightSquare,
    int? darkSquare,
    int? whiteAccent,
    int? blackAccent,
    int? backgroundColor,
    CustomBoardSurface? surface,
    CustomBackground? background,
  }) => CustomChessSet(
    id: id ?? this.id,
    name: name ?? this.name,
    pieces: pieces ?? this.pieces,
    lightSquare: lightSquare ?? this.lightSquare,
    darkSquare: darkSquare ?? this.darkSquare,
    whiteAccent: whiteAccent ?? this.whiteAccent,
    blackAccent: blackAccent ?? this.blackAccent,
    backgroundColor: backgroundColor ?? this.backgroundColor,
    surface: surface ?? this.surface,
    background: background ?? this.background,
  );

  factory CustomChessSet.fromJson(Object? value) {
    final json = value is Map ? value : const <String, Object?>{};
    final id = json['id'];
    final name = json['name'];
    final defaults = CustomChessSet.create(id: id is String ? id : '');
    int color(String key, int fallback) {
      final value = json[key];
      return value is int && value >= 0 && value <= 0xFFFFFFFF
          ? value
          : fallback;
    }

    final pieces = json['pieces'];
    return CustomChessSet(
      id: defaults.id,
      name: name is String ? name : defaultName,
      pieces: {
        if (pieces is Map)
          for (final side in Side.values)
            for (final role in Role.values)
              if (pieces[pieceKey(side, role)] is Map)
                pieceKey(side, role): CustomPieceDesign.fromJson(
                  pieces[pieceKey(side, role)],
                ),
      },
      lightSquare: color('lightSquare', defaults.lightSquare),
      darkSquare: color('darkSquare', defaults.darkSquare),
      whiteAccent: color('whiteAccent', defaults.whiteAccent),
      blackAccent: color('blackAccent', defaults.blackAccent),
      backgroundColor: color('backgroundColor', defaults.backgroundColor),
      surface:
          CustomBoardSurface.values
              .where((v) => v.name == json['surface'])
              .firstOrNull ??
          defaults.surface,
      background:
          CustomBackground.values
              .where((v) => v.name == json['background'])
              .firstOrNull ??
          defaults.background,
    );
  }

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'pieces': {
      for (final entry in pieces.entries) entry.key: entry.value.toJson(),
    },
    'lightSquare': lightSquare,
    'darkSquare': darkSquare,
    'whiteAccent': whiteAccent,
    'blackAccent': blackAccent,
    'backgroundColor': backgroundColor,
    'surface': surface.name,
    'background': background.name,
  };
}
