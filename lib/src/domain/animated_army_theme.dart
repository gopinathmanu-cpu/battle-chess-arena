// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:dartchess/dartchess.dart';

import 'piece_pack.dart';

const neonReadyCastAsset =
    'assets/cinematics/neon/ready-cast-bright-rook-v1.png';
const neonAttackCastAsset =
    'assets/cinematics/neon/attack-cast-bright-rook-v1.png';
const neonOtherReadyCastAsset =
    'assets/cinematics/neon/ready-cast-bright-v1.png';
const neonOtherAttackCastAsset =
    'assets/cinematics/neon/attack-cast-bright-v1.png';

String neonReadyAsset(Role role) =>
    role == Role.rook ? neonReadyCastAsset : neonOtherReadyCastAsset;
String neonAttackAsset(Role role) =>
    role == Role.rook ? neonAttackCastAsset : neonOtherAttackCastAsset;

/// The visual world belongs to the selected army, independently of board icons.
/// Legacy and custom sets deliberately keep their existing presentation.
enum AnimatedArmyTheme {
  neon,
  manga,
  epic,
  olympian;

  static AnimatedArmyTheme? forPack(PiecePackId pack) => switch (pack) {
    PiecePackId.futuristic => neon,
    PiecePackId.anime => manga,
    PiecePackId.indianEpic => epic,
    PiecePackId.greek => olympian,
    _ => null,
  };

  PiecePackId get packId => switch (this) {
    neon => PiecePackId.futuristic,
    manga => PiecePackId.anime,
    epic => PiecePackId.indianEpic,
    olympian => PiecePackId.greek,
  };

  String get displayName => switch (this) {
    neon => 'Neon Dominion',
    manga => 'Manga Vanguard',
    epic => 'Epic Guardians',
    olympian => 'Olympian Legion',
  };

  String get assetDirectory => switch (this) {
    neon => 'assets/cinematics/neon',
    manga => 'assets/cinematics/manga',
    epic => 'assets/cinematics/epic',
    olympian => 'assets/cinematics/olympian',
  };

  String get worldAsset =>
      '$assetDirectory/${this == neon ? 'city' : 'world'}.png';

  /// New worlds share a two-row atlas: White above Black, six roles per row.
  /// All source characters face right; the renderer mirrors inward as needed.
  String castAsset(Side side) => switch (this) {
    neon =>
      '$assetDirectory/${side == Side.white ? 'white-cast-rook-v1' : 'black-cast-bright-rook-v1'}.png',
    olympian => '$assetDirectory/cast-bright-hair-v1.png',
    _ => '$assetDirectory/cast-bright-v1.png',
  };

  String get scoreAsset => switch (this) {
    neon => 'audio/neon_film_score.wav',
    manga => 'audio/manga_film_score.wav',
    epic => 'audio/epic_film_score.wav',
    olympian => 'audio/olympian_film_score.wav',
  };

  String get whiteFaction => switch (this) {
    neon => 'Aurora',
    manga => 'Star Vanguard',
    epic => 'Sun Guardians',
    olympian => 'Dawn Legion',
  };

  String get blackFaction => switch (this) {
    neon => 'Void',
    manga => 'Eclipse Vanguard',
    epic => 'Moon Guardians',
    olympian => 'Dusk Legion',
  };

  int get whiteColorArgb => switch (this) {
    neon => 0xFF83F8EF,
    manga => 0xFF83BDFF,
    epic => 0xFFFFD382,
    olympian => 0xFF99D8FF,
  };

  int get blackColorArgb => switch (this) {
    neon => 0xFFFF6ACB,
    manga => 0xFFFF6A9C,
    epic => 0xFFC39AFF,
    olympian => 0xFFFFB36B,
  };

  int get accentColorArgb => whiteColorArgb;

  /// World colors remain readable behind either army and Classic board icons.
  int get lightSquareArgb => switch (this) {
    neon => 0xFFCDEEEB,
    manga => 0xFFD6E8F7,
    epic => 0xFFF1E5C7,
    olympian => 0xFFE8E3DB,
  };

  int get darkSquareArgb => switch (this) {
    neon => 0xFF957BA5,
    manga => 0xFFA5758C,
    epic => 0xFF6E8971,
    olympian => 0xFF9A7B5A,
  };

  int get baseColorArgb => switch (this) {
    neon => 0xFF070B19,
    manga => 0xFF101529,
    epic => 0xFF19120D,
    olympian => 0xFF0D1723,
  };
}
