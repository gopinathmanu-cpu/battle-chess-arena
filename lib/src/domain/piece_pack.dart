import 'package:flutter/material.dart';

// Append new packs so existing atlas indices and saved selections stay stable.
enum PiecePackId {
  anime,
  indianEpic,
  greek,
  futuristic,
  japanese,
  chinese,
  mongolian,
  egyptian,
  arab,
  persian,
  english,
  french,
  sparta,
  macedonian,
  roman,
  achaemenid,
  ottoman,
  chola,
  maratha,
  zulu,
  aztec,
  inca,
  mewar,
  lanka,
  ayodhya,
  hastinapura,
  kishkindha,
  asgard,
  camelot,
  atlantis,
  troy,
}

enum PiecePackGroup { original, historical, legendary }

enum ClassicPieceStyle { magneticTeaching, wood, plastic, metal }

extension ClassicPieceStyleDetails on ClassicPieceStyle {
  String get label => switch (this) {
    ClassicPieceStyle.magneticTeaching => 'Magnetic 3D',
    ClassicPieceStyle.wood => 'Wooden 3D',
    ClassicPieceStyle.plastic => 'Flat Club',
    ClassicPieceStyle.metal => 'Flat Teaching',
  };

  String get subtitle => switch (this) {
    ClassicPieceStyle.magneticTeaching => 'Teaching-board style',
    ClassicPieceStyle.wood => 'Maple and walnut',
    ClassicPieceStyle.plastic => 'Bold black & white icons',
    ClassicPieceStyle.metal => 'Rounded teaching icons',
  };

  IconData get icon => switch (this) {
    ClassicPieceStyle.magneticTeaching => Icons.school_outlined,
    ClassicPieceStyle.wood => Icons.forest_outlined,
    ClassicPieceStyle.plastic => Icons.contrast_outlined,
    ClassicPieceStyle.metal => Icons.school_outlined,
  };
}

class PiecePack {
  const PiecePack({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.accent,
    required this.icon,
    this.group = PiecePackGroup.original,
  });

  final PiecePackId id;
  final String name;
  final String subtitle;
  final Color accent;
  final IconData icon;
  final PiecePackGroup group;
}

const piecePacks = <PiecePack>[
  PiecePack(
    id: PiecePackId.anime,
    name: 'Manga Vanguard',
    subtitle: 'Expressive fantasy champions',
    accent: Color(0xFFFF5A87),
    icon: Icons.auto_awesome,
  ),
  PiecePack(
    id: PiecePackId.indianEpic,
    name: 'Epic Guardians',
    subtitle: 'Original heroes inspired by Indian epics',
    accent: Color(0xFFFFB02E),
    icon: Icons.local_fire_department,
  ),
  PiecePack(
    id: PiecePackId.greek,
    name: 'Olympian Legion',
    subtitle: 'Marble, bronze and mythic power',
    accent: Color(0xFF63A8FF),
    icon: Icons.account_balance,
  ),
  PiecePack(
    id: PiecePackId.futuristic,
    name: 'Neon Dominion',
    subtitle: 'Androids, mechs and energy weapons',
    accent: Color(0xFF5CF2E7),
    icon: Icons.memory,
  ),
  PiecePack(
    id: PiecePackId.japanese,
    group: PiecePackGroup.historical,
    name: 'Japanese Shogunate',
    subtitle: 'Samurai-era robes and layered armour',
    accent: Color(0xFFEB7283),
    icon: Icons.temple_buddhist_outlined,
  ),
  PiecePack(
    id: PiecePackId.chinese,
    group: PiecePackGroup.historical,
    name: 'Chinese Imperial Court',
    subtitle: 'Imperial-inspired robes and ceremonial armour',
    accent: Color(0xFF8DE3B0),
    icon: Icons.account_balance_outlined,
  ),
  PiecePack(
    id: PiecePackId.mongolian,
    group: PiecePackGroup.historical,
    name: 'Mongolian Khans',
    subtitle: 'Steppe-inspired coats and mounted warriors',
    accent: Color(0xFFE2B46B),
    icon: Icons.terrain_outlined,
  ),
  PiecePack(
    id: PiecePackId.egyptian,
    group: PiecePackGroup.historical,
    name: 'Egyptian Pharaohs',
    subtitle: 'Ancient-inspired linen and royal headdresses',
    accent: Color(0xFF75C7DE),
    icon: Icons.wb_sunny_outlined,
  ),
  PiecePack(
    id: PiecePackId.arab,
    group: PiecePackGroup.historical,
    name: 'Arab Caliphate',
    subtitle: 'Caliphate-inspired robes and ceremonial dress',
    accent: Color(0xFFE5C78C),
    icon: Icons.auto_awesome_outlined,
  ),
  PiecePack(
    id: PiecePackId.persian,
    group: PiecePackGroup.historical,
    name: 'Persian Royal Court',
    subtitle: 'Safavid-inspired robes and patterned armour',
    accent: Color(0xFFC6A7F4),
    icon: Icons.diamond_outlined,
  ),
  PiecePack(
    id: PiecePackId.english,
    group: PiecePackGroup.historical,
    name: 'English Crown',
    subtitle: 'Medieval-inspired crowns and heraldic armour',
    accent: Color(0xFFE58699),
    icon: Icons.shield_outlined,
  ),
  PiecePack(
    id: PiecePackId.french,
    group: PiecePackGroup.historical,
    name: 'French Court',
    subtitle: 'Court-inspired attire and ornate armour',
    accent: Color(0xFF96BFFF),
    icon: Icons.castle_outlined,
  ),
  PiecePack(
    id: PiecePackId.sparta,
    group: PiecePackGroup.historical,
    name: 'Spartan Warriors',
    subtitle: 'Spartan-inspired crimson cloaks and bronze armour',
    accent: Color(0xFFDD7975),
    icon: Icons.shield_outlined,
  ),
  PiecePack(
    id: PiecePackId.macedonian,
    group: PiecePackGroup.historical,
    name: 'Macedonian Kingdom',
    subtitle: 'Macedonian-inspired helmets and royal cavalry',
    accent: Color(0xFF99BEDC),
    icon: Icons.account_balance_outlined,
  ),
  PiecePack(
    id: PiecePackId.roman,
    group: PiecePackGroup.historical,
    name: 'Roman Empire',
    subtitle: 'Roman-inspired crests and legionary armour',
    accent: Color(0xFFE49A74),
    icon: Icons.account_balance_outlined,
  ),
  PiecePack(
    id: PiecePackId.achaemenid,
    group: PiecePackGroup.historical,
    name: 'Achaemenid Empire',
    subtitle: 'Ancient Persian-inspired robes and royal guards',
    accent: Color(0xFFCEA5E4),
    icon: Icons.diamond_outlined,
  ),
  PiecePack(
    id: PiecePackId.ottoman,
    group: PiecePackGroup.historical,
    name: 'Ottoman Court',
    subtitle: 'Ottoman-inspired kaftans and ceremonial armour',
    accent: Color(0xFF91CCB4),
    icon: Icons.auto_awesome_outlined,
  ),
  PiecePack(
    id: PiecePackId.chola,
    group: PiecePackGroup.historical,
    name: 'Chola Empire',
    subtitle: 'Chola-inspired crowns and ornamental armour',
    accent: Color(0xFFF3BC70),
    icon: Icons.temple_hindu_outlined,
  ),
  PiecePack(
    id: PiecePackId.maratha,
    group: PiecePackGroup.historical,
    name: 'Maratha Empire',
    subtitle: 'Maratha-inspired turbans and warrior attire',
    accent: Color(0xFFEFAB7A),
    icon: Icons.flag_outlined,
  ),
  PiecePack(
    id: PiecePackId.zulu,
    group: PiecePackGroup.historical,
    name: 'Zulu Kingdom',
    subtitle: 'Zulu-inspired shields and ceremonial dress',
    accent: Color(0xFFE4B581),
    icon: Icons.shield_outlined,
  ),
  PiecePack(
    id: PiecePackId.aztec,
    group: PiecePackGroup.historical,
    name: 'Aztec Empire',
    subtitle: 'Aztec-inspired featherwork and warrior regalia',
    accent: Color(0xFF79D0BD),
    icon: Icons.wb_sunny_outlined,
  ),
  PiecePack(
    id: PiecePackId.inca,
    group: PiecePackGroup.historical,
    name: 'Inca Empire',
    subtitle: 'Inca-inspired woven tunics and golden ornaments',
    accent: Color(0xFFE4CD7B),
    icon: Icons.terrain_outlined,
  ),
  PiecePack(
    id: PiecePackId.mewar,
    group: PiecePackGroup.historical,
    name: 'Kingdom of Mewar',
    subtitle: 'Mewar-inspired turbans and Rajput armour',
    accent: Color(0xFFF0A979),
    icon: Icons.castle_outlined,
  ),
  PiecePack(
    id: PiecePackId.lanka,
    group: PiecePackGroup.legendary,
    name: 'Legendary Lanka',
    subtitle: 'Epic-inspired island court and ornate crowns',
    accent: Color(0xFFE9959F),
    icon: Icons.local_fire_department_outlined,
  ),
  PiecePack(
    id: PiecePackId.ayodhya,
    group: PiecePackGroup.legendary,
    name: 'Ayodhya Kingdom',
    subtitle: 'Epic-inspired royal attire and noble guardians',
    accent: Color(0xFFFFCC7F),
    icon: Icons.temple_hindu_outlined,
  ),
  PiecePack(
    id: PiecePackId.hastinapura,
    group: PiecePackGroup.legendary,
    name: 'Hastinapura Court',
    subtitle: 'Epic-inspired royal armour and chariot warriors',
    accent: Color(0xFFABBDF2),
    icon: Icons.account_balance_outlined,
  ),
  PiecePack(
    id: PiecePackId.kishkindha,
    group: PiecePackGroup.legendary,
    name: 'Kishkindha Kingdom',
    subtitle: 'Epic-inspired forest champions and royal ornaments',
    accent: Color(0xFFA8D598),
    icon: Icons.forest_outlined,
  ),
  PiecePack(
    id: PiecePackId.asgard,
    group: PiecePackGroup.legendary,
    name: 'Asgard',
    subtitle: 'Norse-myth-inspired cloaks and radiant armour',
    accent: Color(0xFFB2D7ED),
    icon: Icons.bolt_outlined,
  ),
  PiecePack(
    id: PiecePackId.camelot,
    group: PiecePackGroup.legendary,
    name: 'Camelot',
    subtitle: 'Arthurian-inspired crowns and knightly armour',
    accent: Color(0xFFB8ABED),
    icon: Icons.castle_outlined,
  ),
  PiecePack(
    id: PiecePackId.atlantis,
    group: PiecePackGroup.legendary,
    name: 'Atlantis',
    subtitle: 'Myth-inspired ocean court and pearlescent armour',
    accent: Color(0xFF7DD9D2),
    icon: Icons.waves_outlined,
  ),
  PiecePack(
    id: PiecePackId.troy,
    group: PiecePackGroup.legendary,
    name: 'Troy',
    subtitle: 'Epic-inspired bronze armour and royal defenders',
    accent: Color(0xFFEBC399),
    icon: Icons.shield_outlined,
  ),
];
