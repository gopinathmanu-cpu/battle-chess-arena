// SPDX-License-Identifier: GPL-3.0-or-later

enum ComputerDifficulty { easy, medium, hard }

extension ComputerDifficultyDetails on ComputerDifficulty {
  String get label => switch (this) {
    ComputerDifficulty.easy => 'Easy',
    ComputerDifficulty.medium => 'Medium',
    ComputerDifficulty.hard => 'Hard',
  };

  String get description => switch (this) {
    ComputerDifficulty.easy => 'Quick moves for learning and relaxed games',
    ComputerDifficulty.medium => 'Balanced strength and response time',
    ComputerDifficulty.hard => 'Deeper search for a stronger challenge',
  };

  Duration get thinkTime => switch (this) {
    ComputerDifficulty.easy => const Duration(milliseconds: 250),
    ComputerDifficulty.medium => const Duration(milliseconds: 650),
    ComputerDifficulty.hard => const Duration(milliseconds: 1400),
  };

  int get stockfishSkill => switch (this) {
    ComputerDifficulty.easy => 2,
    ComputerDifficulty.medium => 10,
    ComputerDifficulty.hard => 18,
  };

  int get fallbackDepth => switch (this) {
    ComputerDifficulty.easy => 0,
    ComputerDifficulty.medium => 1,
    ComputerDifficulty.hard => 2,
  };
}

abstract interface class ComputerPlayer {
  Future<String?> bestMove(
    String fen, {
    ComputerDifficulty difficulty = ComputerDifficulty.medium,
  });
  void dispose();
}
