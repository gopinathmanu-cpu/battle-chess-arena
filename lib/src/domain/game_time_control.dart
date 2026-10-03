// SPDX-License-Identifier: GPL-3.0-or-later
/// Persist rules, not preset indexes: existing games keep their original clock.
class GameTimeControl {
  const GameTimeControl({
    this.baseMs = 900000,
    this.incrementMs = 10000,
    this.timed = true,
  });
  static const rapid = GameTimeControl();
  static const practice = GameTimeControl(timed: false, incrementMs: 0);
  static const legacy = GameTimeControl(baseMs: 600000, incrementMs: 0);
  final int baseMs;
  final int incrementMs;
  final bool timed;
  Map<String, Object> toJson() => {
    'baseMs': baseMs,
    'incrementMs': incrementMs,
    'timed': timed,
  };
  factory GameTimeControl.fromJson(Map<String, Object?> json) {
    final base = json['baseMs'] as int;
    final increment = json['incrementMs'] as int;
    if (base <= 0 || increment < 0 || increment > 60000) {
      throw const FormatException('Invalid saved clock');
    }
    return GameTimeControl(
      baseMs: base,
      incrementMs: increment,
      timed: json['timed'] as bool,
    );
  }
}
