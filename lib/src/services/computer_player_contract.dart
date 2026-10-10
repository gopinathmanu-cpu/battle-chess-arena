// SPDX-License-Identifier: GPL-3.0-or-later

enum ComputerDifficulty { easy, medium, hard }

/// Assistance always uses the strongest profile currently supported by the app,
/// independently of the opponent's selected difficulty or fixed persona.
const assistanceDifficulty = ComputerDifficulty.hard;
const assistanceBotLevel = BotStrength.maximumLevel;

/// Retained for callers that display or inspect the suggestion preset.
const suggestionDifficulty = assistanceDifficulty;

extension ComputerDifficultyDetails on ComputerDifficulty {
  String get label => switch (this) {
    ComputerDifficulty.easy => 'Easy',
    ComputerDifficulty.medium => 'Medium',
    ComputerDifficulty.hard => 'Hard',
  };

  String get description => switch (this) {
    ComputerDifficulty.easy => 'Gentle play for beginners and casual games',
    ComputerDifficulty.medium => 'Consistent positional and tactical play',
    ComputerDifficulty.hard => 'Strong tactical play with deeper calculation',
  };

  Duration get thinkTime => switch (this) {
    ComputerDifficulty.easy => const Duration(milliseconds: 250),
    ComputerDifficulty.medium => const Duration(milliseconds: 650),
    ComputerDifficulty.hard => const Duration(milliseconds: 2500),
  };

  int get stockfishSkill => switch (this) {
    ComputerDifficulty.easy => 0,
    ComputerDifficulty.medium => 6,
    ComputerDifficulty.hard => 20,
  };

  int get stockfishDepth => switch (this) {
    ComputerDifficulty.easy => 2,
    ComputerDifficulty.medium => 7,
    ComputerDifficulty.hard => 18,
  };

  /// Used only when advertised by the engine; otherwise use Skill Level.
  /// Elo limiting overrides Skill Level and is not a measured human rating.
  int get stockfishTargetElo => switch (this) {
    ComputerDifficulty.easy => 800,
    ComputerDifficulty.medium => 1400,
    ComputerDifficulty.hard => 2500,
  };

  int get fallbackDepth => switch (this) {
    ComputerDifficulty.easy => 1,
    ComputerDifficulty.medium => 2,
    ComputerDifficulty.hard => 3,
  };
}

/// A persona's fixed strength, independent of the three user presets.
class BotStrength {
  BotStrength(this.level) {
    RangeError.checkValueInInterval(level, 1, maximumLevel, 'botLevel');
  }

  static const maximumLevel = 20;
  final int level;
  int get stockfishSkill => ((level - 1) * 20 / (maximumLevel - 1)).round();
  int get depth => 2 + ((level - 1) * 16 ~/ (maximumLevel - 1));
  Duration get thinkTime => Duration(milliseconds: 250 + (level - 1) * 125);
  int get fallbackDepth => level <= 7 ? 1 : (level <= 14 ? 2 : 3);
  double get mistakeChance => (maximumLevel - level) / 24;
}

abstract interface class ComputerPlayer {
  Future<String?> bestMove(
    String fen, {
    ComputerDifficulty difficulty = ComputerDifficulty.medium,
    int? botLevel,
  });
  void dispose();
}

extension ComputerPlayerAssistance on ComputerPlayer {
  /// Shares the maximum-strength request between suggestions and automated
  /// human turns. A fixed level avoids the preset's optional Elo cap; native
  /// search still has its ordinary depth/time limits and legal fallback.
  Future<String?> bestAssistanceMove(String fen) => bestMove(
    fen,
    difficulty: assistanceDifficulty,
    botLevel: assistanceBotLevel,
  );
}
