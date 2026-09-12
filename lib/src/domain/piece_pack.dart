import 'package:flutter/material.dart';

enum PiecePackId { anime, indianEpic, greek, futuristic, classic }

class PiecePack {
  const PiecePack({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.accent,
    required this.icon,
  });

  final PiecePackId id;
  final String name;
  final String subtitle;
  final Color accent;
  final IconData icon;
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
    id: PiecePackId.classic,
    name: 'Royal Classic',
    subtitle: 'Timeless carved tournament pieces',
    accent: Color(0xFFE6D4AF),
    icon: Icons.castle,
  ),
];
