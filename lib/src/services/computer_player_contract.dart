// SPDX-License-Identifier: GPL-3.0-or-later

enum ComputerDifficulty { easy, medium, hard }

extension ComputerDifficultyDetails on ComputerDifficulty {
  String get label => switch (this) {
    ComputerDifficulty.easy => 'Easy',
    ComputerDifficulty.medium => 'Medium',
    ComputerDifficulty.hard => 'Hard',
  };

  String get description => switch (this) {
    ComputerDifficulty.easy => 'Safe, sensible play with fewer attacking ideas',
    ComputerDifficulty.medium => 'Consistent positional and tactical play',
    ComputerDifficulty.hard => 'Maximum Stockfish skill with deepest search',
  };

  Duration get thinkTime => switch (this) {
    ComputerDifficulty.easy => const Duration(milliseconds: 250),
    ComputerDifficulty.medium => const Duration(milliseconds: 650),
    ComputerDifficulty.hard => const Duration(milliseconds: 2500),
  };

  int get stockfishSkill => switch (this) {
    ComputerDifficulty.easy => 0,
    ComputerDifficulty.medium => 5,
    ComputerDifficulty.hard => 20,
  };

  int get fallbackDepth => switch (this) {
    ComputerDifficulty.easy => 1,
    ComputerDifficulty.medium => 2,
    ComputerDifficulty.hard => 3,
  };
}

abstract interface class ComputerPlayer {
  Future<String?> bestMove(
    String fen, {
    ComputerDifficulty difficulty = ComputerDifficulty.medium,
  });
  void dispose();
}
