// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/game_session.dart';
import '../domain/piece_pack.dart';
import 'computer_player.dart';

class SavedGame {
  const SavedGame({
    required this.mode,
    required this.homePack,
    required this.difficulty,
    required this.moves,
    required this.whiteMilliseconds,
    required this.blackMilliseconds,
    required this.fastBattles,
    required this.whitePack,
    required this.blackPack,
    required this.boardPack,
    required this.updatedAtEpochMs,
  });

  final PlayerMode mode;
  final PiecePackId homePack;
  final ComputerDifficulty difficulty;
  final List<String> moves;
  final int whiteMilliseconds;
  final int blackMilliseconds;
  final bool fastBattles;
  final PiecePackId whitePack;
  final PiecePackId blackPack;
  final PiecePackId boardPack;
  final int updatedAtEpochMs;

  Map<String, Object> toJson() => {
    'version': 1,
    'mode': mode.name,
    'homePack': homePack.name,
    'difficulty': difficulty.name,
    'moves': moves,
    'whiteMilliseconds': whiteMilliseconds,
    'blackMilliseconds': blackMilliseconds,
    'fastBattles': fastBattles,
    'whitePack': whitePack.name,
    'blackPack': blackPack.name,
    'boardPack': boardPack.name,
    'updatedAtEpochMs': updatedAtEpochMs,
  };

  factory SavedGame.fromJson(Map<String, Object?> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unknown save version');
    }
    final moves = (json['moves'] as List).cast<String>();
    return SavedGame(
      mode: PlayerMode.values.byName(json['mode'] as String),
      homePack: PiecePackId.values.byName(json['homePack'] as String),
      difficulty: ComputerDifficulty.values.byName(
        json['difficulty'] as String,
      ),
      moves: List.unmodifiable(moves),
      whiteMilliseconds: json['whiteMilliseconds'] as int,
      blackMilliseconds: json['blackMilliseconds'] as int,
      fastBattles: json['fastBattles'] as bool,
      whitePack: PiecePackId.values.byName(json['whitePack'] as String),
      blackPack: PiecePackId.values.byName(json['blackPack'] as String),
      boardPack: PiecePackId.values.byName(json['boardPack'] as String),
      updatedAtEpochMs: json['updatedAtEpochMs'] as int,
    );
  }
}

class LastGameStorage {
  static const _key = 'lastOpenGameV1';
  static int _revision = 0;
  static SavedGame? _memory;

  static Future<SavedGame?> load() async {
    try {
      if (_memory != null) return _memory;
      final preferences = await SharedPreferences.getInstance();
      final encoded = preferences.getString(_key);
      if (encoded == null) return null;
      final saved = SavedGame.fromJson(
        (jsonDecode(encoded) as Map).cast<String, Object?>(),
      );
      if (saved.moves.isEmpty ||
          saved.whiteMilliseconds <= 0 ||
          saved.blackMilliseconds <= 0) {
        await clear();
        return null;
      }
      GameSession.fromMoves(mode: saved.mode, moves: saved.moves);
      _memory = saved;
      return saved;
    } catch (_) {
      await clear();
      return null;
    }
  }

  static Future<void> save(SavedGame game) async {
    final revision = ++_revision;
    _memory = game;
    final encoded = jsonEncode(game.toJson());
    final preferences = await SharedPreferences.getInstance();
    if (revision == _revision) await preferences.setString(_key, encoded);
  }

  static Future<void> clear() async {
    ++_revision;
    _memory = null;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key);
  }
}
