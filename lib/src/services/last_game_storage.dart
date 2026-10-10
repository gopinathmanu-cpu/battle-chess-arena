// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'package:dartchess/dartchess.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/game_session.dart';
import '../domain/game_time_control.dart';
import '../domain/piece_pack.dart';
import 'computer_player.dart';

PiecePackId _piecePackFromSavedName(Object? value) {
  final name = value as String;
  // Royal Classic was removed. Preserve resumable games by moving its visual
  // selections to the default themed pack; game state is unaffected.
  if (name == 'classic') return PiecePackId.anime;
  return PiecePackId.values.byName(name);
}

class SavedGame {
  const SavedGame({
    required this.mode,
    this.humanSide = Side.white,
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
    this.lifelinesRemaining = 3,
    this.classicPieces = false,
    this.animatedArena,
    this.classicStyle = ClassicPieceStyle.magneticTeaching,
    this.timeControl = GameTimeControl.legacy,
    this.progressGameId,
    this.historyGameId,
    this.historyResultTitle,
  });

  final PlayerMode mode;
  final Side humanSide;
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
  final int lifelinesRemaining;
  final bool classicPieces;

  /// Missing in older saves, whose existing army presentation is retained.
  final bool? animatedArena;
  final ClassicPieceStyle classicStyle;
  final GameTimeControl timeControl;
  final String? progressGameId;
  final String? historyGameId;

  /// Retains a completed recording until the full history archive is durable.
  final String? historyResultTitle;

  bool get canResume =>
      historyResultTitle == null &&
      moves.isNotEmpty &&
      (!timeControl.timed || (whiteMilliseconds > 0 && blackMilliseconds > 0));

  Map<String, Object> toJson() => {
    'version': 1,
    'mode': mode.name,
    'humanSide': humanSide.name,
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
    'lifelinesRemaining': lifelinesRemaining,
    'classicPieces': classicPieces,
    if (animatedArena != null) 'animatedArena': animatedArena!,
    'classicStyle': classicStyle.name,
    'timeControl': timeControl.toJson(),
    if (progressGameId != null) 'progressGameId': progressGameId!,
    if (historyGameId != null) 'historyGameId': historyGameId!,
    if (historyResultTitle != null) 'historyResultTitle': historyResultTitle!,
  };

  factory SavedGame.fromJson(Map<String, Object?> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unknown save version');
    }
    final moves = (json['moves'] as List).cast<String>();
    return SavedGame(
      mode: PlayerMode.values.byName(json['mode'] as String),
      humanSide: Side.values.byName(json['humanSide'] as String? ?? 'white'),
      homePack: _piecePackFromSavedName(json['homePack']),
      difficulty: ComputerDifficulty.values.byName(
        json['difficulty'] as String,
      ),
      moves: List.unmodifiable(moves),
      timeControl: json['timeControl'] is Map
          ? GameTimeControl.fromJson(
              (json['timeControl'] as Map).cast<String, Object?>(),
            )
          : GameTimeControl.legacy,
      whiteMilliseconds: json['whiteMilliseconds'] as int,
      blackMilliseconds: json['blackMilliseconds'] as int,
      fastBattles: json['fastBattles'] as bool,
      whitePack: _piecePackFromSavedName(json['whitePack']),
      blackPack: _piecePackFromSavedName(json['blackPack']),
      boardPack: _piecePackFromSavedName(json['boardPack']),
      updatedAtEpochMs: json['updatedAtEpochMs'] as int,
      lifelinesRemaining: json['lifelinesRemaining'] as int? ?? 3,
      classicPieces: json['classicPieces'] as bool? ?? false,
      animatedArena: json['animatedArena'] as bool?,
      classicStyle: ClassicPieceStyle.values.byName(
        json['classicStyle'] as String? ??
            ClassicPieceStyle.magneticTeaching.name,
      ),
      progressGameId: json['progressGameId'] as String?,
      historyGameId: json['historyGameId'] as String?,
      historyResultTitle: json['historyResultTitle'] as String?,
    );
  }
}

class LastGameStorage {
  static const _key = 'lastOpenGameV1';
  static int _revision = 0;
  static SavedGame? _memory;

  static Future<SavedGame?> load() async {
    final revision = _revision;
    try {
      if (_memory case final cached?) {
        if (!cached.canResume) {
          if (cached.historyResultTitle == null) await clear();
          return null;
        }
        return cached;
      }
      final preferences = await SharedPreferences.getInstance();
      if (revision != _revision) {
        return _memory?.canResume == true ? _memory : null;
      }
      final encoded = preferences.getString(_key);
      if (encoded == null) return null;
      final saved = SavedGame.fromJson(
        (jsonDecode(encoded) as Map).cast<String, Object?>(),
      );
      if (!saved.canResume) {
        if (saved.historyResultTitle == null) await clear();
        return null;
      }
      GameSession.fromMoves(
        mode: saved.mode,
        humanSide: saved.humanSide,
        moves: saved.moves,
      );
      _memory = saved;
      return saved;
    } catch (_) {
      if (revision != _revision) {
        return _memory?.canResume == true ? _memory : null;
      }
      await clear();
      return null;
    }
  }

  static Future<void> save(SavedGame game) async {
    if (!game.canResume) {
      await clear();
      return;
    }
    final revision = ++_revision;
    _memory = game;
    final encoded = jsonEncode(game.toJson());
    final preferences = await SharedPreferences.getInstance();
    if (revision == _revision) await preferences.setString(_key, encoded);
  }

  /// Stage a terminal game's source before archiving. The ticket prevents a
  /// delayed archive from clearing a newer game's resume slot.
  static Future<int> saveHistorySource(SavedGame game) async {
    final revision = ++_revision;
    final previous = _memory;
    _memory = game;
    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
      if (revision != _revision) return revision;
      final encoded = jsonEncode(game.toJson());
      if (!await preferences.setString(_key, encoded)) {
        throw StateError('Completed game source could not be saved');
      }
      return revision;
    } catch (_) {
      if (revision == _revision) {
        _memory = previous;
        // Reload rolls back SharedPreferences' optimistic failed write.
        if (preferences != null) await preferences.reload();
      }
      rethrow;
    }
  }

  static Future<void> clear({int? expectedRevision}) async {
    if (expectedRevision != null && expectedRevision != _revision) return;
    final revision = ++_revision;
    _memory = null;
    final preferences = await SharedPreferences.getInstance();
    if (revision == _revision) await preferences.remove(_key);
  }
}
