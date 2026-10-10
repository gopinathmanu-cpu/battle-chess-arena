// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';

import 'package:dartchess/dartchess.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/bot_tournament.dart';
import '../domain/cinematic_replay.dart';
import '../domain/game_session.dart';
import '../domain/piece_pack.dart';
import 'computer_player_contract.dart';
import 'last_game_storage.dart';

enum GameHistoryMode { local, computer, tournament, online }

enum GameHistoryStatus { completed, unfinished }

/// A legacy resumable snapshot has no start timestamp. Its retained timestamp
/// and content supply a deterministic ID until the resumed session persists it.
/// Existing progress IDs always take precedence.
String legacySavedGameId(SavedGame saved) {
  final historyId = saved.historyGameId;
  if (historyId != null && historyId.trim().isNotEmpty) return historyId.trim();
  final existing = saved.progressGameId;
  if (existing != null && existing.trim().isNotEmpty) return existing.trim();
  final signature = jsonEncode([
    saved.mode.name,
    saved.humanSide.name,
    saved.updatedAtEpochMs,
    saved.moves,
  ]);
  var hash = 0x811c9dc5;
  for (final unit in signature.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return 'legacy-${saved.mode.name}-${saved.updatedAtEpochMs}-'
      '${hash.toRadixString(16).padLeft(8, '0')}';
}

/// A validated, immutable recording, independent of the resumable save slot.
/// Appearance metadata preserves the recorded Animated army world; legacy and
/// custom recordings retain a Neon interpretation without changing their moves.
class GameHistoryRecord {
  static String idForSavedGame(SavedGame saved) => legacySavedGameId(saved);

  factory GameHistoryRecord({
    required String id,
    required DateTime completedAt,
    required String resultTitle,
    required GameHistoryMode mode,
    required Iterable<String> moves,
    String? finalFen,
    GameHistoryStatus status = GameHistoryStatus.completed,
    String whiteName = 'White',
    String blackName = 'Black',
    Side? humanSide,
    String? opponentLabel,
    PiecePackId whitePackId = PiecePackId.anime,
    PiecePackId blackPackId = PiecePackId.anime,
    PiecePackId boardPackId = PiecePackId.anime,
    bool classicPieces = false,
    ClassicPieceStyle classicStyle = ClassicPieceStyle.magneticTeaching,
    String? whiteCustomSetId,
    String? blackCustomSetId,
    String? whiteCustomName,
    String? blackCustomName,
    String? tournamentTitle,
    ComputerDifficulty? difficulty,
  }) {
    final recordedAt = completedAt.toUtc();
    if (id.trim().isEmpty ||
        resultTitle.trim().isEmpty ||
        whiteName.trim().isEmpty ||
        blackName.trim().isEmpty ||
        recordedAt.millisecondsSinceEpoch < 0) {
      throw const FormatException('Invalid game history metadata');
    }
    final replay = CinematicReplay.fromMoves(
      moves: moves,
      resultTitle: resultTitle,
    );
    if (finalFen != null && finalFen != replay.finalPosition.fen) {
      throw const FormatException(
        'Game history does not match its final board',
      );
    }
    final opponent = opponentLabel?.trim();
    return GameHistoryRecord._(
      id: id.trim(),
      completedAt: recordedAt,
      resultTitle: resultTitle.trim(),
      mode: mode,
      status: status,
      moves: replay.uciMoves,
      finalFen: replay.finalPosition.fen,
      whiteName: whiteName.trim(),
      blackName: blackName.trim(),
      humanSide: humanSide,
      opponentLabel: opponent?.isNotEmpty == true
          ? opponent!
          : humanSide == Side.white
          ? blackName.trim()
          : humanSide == Side.black
          ? whiteName.trim()
          : '${whiteName.trim()} vs ${blackName.trim()}',
      whitePackId: whitePackId,
      blackPackId: blackPackId,
      boardPackId: boardPackId,
      classicPieces: classicPieces,
      classicStyle: classicStyle,
      whiteCustomSetId: _optionalText(whiteCustomSetId),
      blackCustomSetId: _optionalText(blackCustomSetId),
      whiteCustomName: _optionalText(whiteCustomName),
      blackCustomName: _optionalText(blackCustomName),
      tournamentTitle: _optionalText(tournamentTitle),
      difficulty: difficulty,
    );
  }

  const GameHistoryRecord._({
    required this.id,
    required this.completedAt,
    required this.resultTitle,
    required this.mode,
    required this.status,
    required this.moves,
    required this.finalFen,
    required this.whiteName,
    required this.blackName,
    required this.humanSide,
    required this.opponentLabel,
    required this.whitePackId,
    required this.blackPackId,
    required this.boardPackId,
    required this.classicPieces,
    required this.classicStyle,
    required this.whiteCustomSetId,
    required this.blackCustomSetId,
    required this.whiteCustomName,
    required this.blackCustomName,
    required this.tournamentTitle,
    required this.difficulty,
  });

  factory GameHistoryRecord.fromSavedGame(
    SavedGame saved, {
    String? id,
    GameHistoryMode? mode,
    GameHistoryStatus? status,
    String? resultTitle,
    String whiteName = 'White',
    String blackName = 'Black',
    String? opponentLabel,
    String? tournamentTitle,
    String? whiteCustomSetId,
    String? blackCustomSetId,
    String? whiteCustomName,
    String? blackCustomName,
  }) {
    final inferredResult = _savedResult(saved);
    final inferredStatus = inferredResult == null
        ? GameHistoryStatus.unfinished
        : GameHistoryStatus.completed;
    return GameHistoryRecord(
      id: id ?? legacySavedGameId(saved),
      completedAt: DateTime.fromMillisecondsSinceEpoch(
        saved.updatedAtEpochMs,
        isUtc: true,
      ),
      resultTitle:
          resultTitle ??
          (status == GameHistoryStatus.unfinished
              ? 'Game unfinished'
              : inferredResult ??
                    (status == GameHistoryStatus.completed
                        ? 'Game complete'
                        : 'Game unfinished')),
      mode:
          mode ??
          (saved.mode == PlayerMode.local
              ? GameHistoryMode.local
              : GameHistoryMode.computer),
      status: status ?? inferredStatus,
      moves: saved.moves,
      whiteName: whiteName,
      blackName: blackName,
      humanSide: saved.humanSide,
      opponentLabel: opponentLabel,
      whitePackId: saved.whitePack,
      blackPackId: saved.blackPack,
      boardPackId: saved.boardPack,
      classicPieces: saved.classicPieces,
      classicStyle: saved.classicStyle,
      difficulty: saved.mode == PlayerMode.computer ? saved.difficulty : null,
      tournamentTitle: tournamentTitle,
      whiteCustomSetId: whiteCustomSetId,
      blackCustomSetId: blackCustomSetId,
      whiteCustomName: whiteCustomName,
      blackCustomName: blackCustomName,
    );
  }

  factory GameHistoryRecord.fromJson(Map<String, Object?> json) {
    if (json['version'] != 1 || json['initialFen'] != Chess.initial.fen) {
      throw const FormatException('Unsupported game history schema');
    }
    final rawMoves = json['moves'];
    if (rawMoves is! List || rawMoves.any((move) => move is! String)) {
      throw const FormatException('Invalid game history moves');
    }
    return GameHistoryRecord(
      id: json['id'] as String,
      completedAt: DateTime.fromMillisecondsSinceEpoch(
        json['completedAtEpochMs'] as int,
        isUtc: true,
      ),
      resultTitle: json['resultTitle'] as String,
      mode: GameHistoryMode.values.byName(json['mode'] as String),
      status: GameHistoryStatus.values.byName(
        json['status'] as String? ?? 'completed',
      ),
      moves: rawMoves.cast<String>(),
      finalFen: json['finalFen'] as String,
      whiteName: json['whiteName'] as String,
      blackName: json['blackName'] as String,
      humanSide: json['humanSide'] == null
          ? null
          : Side.values.byName(json['humanSide'] as String),
      opponentLabel: json['opponentLabel'] as String,
      whitePackId: PiecePackId.values.byName(json['whitePackId'] as String),
      blackPackId: PiecePackId.values.byName(json['blackPackId'] as String),
      boardPackId: PiecePackId.values.byName(json['boardPackId'] as String),
      classicPieces: json['classicPieces'] as bool,
      classicStyle: ClassicPieceStyle.values.byName(
        json['classicStyle'] as String,
      ),
      whiteCustomSetId: json['whiteCustomSetId'] as String?,
      blackCustomSetId: json['blackCustomSetId'] as String?,
      whiteCustomName: json['whiteCustomName'] as String?,
      blackCustomName: json['blackCustomName'] as String?,
      tournamentTitle: json['tournamentTitle'] as String?,
      difficulty: json['difficulty'] == null
          ? null
          : ComputerDifficulty.values.byName(json['difficulty'] as String),
    );
  }

  final String id;
  final DateTime completedAt;
  DateTime get recordedAt => completedAt;
  int get completedAtEpochMs => completedAt.millisecondsSinceEpoch;
  int get recordedAtEpochMs => completedAtEpochMs;
  final String resultTitle;
  final GameHistoryMode mode;
  final GameHistoryStatus status;
  final List<String> moves;
  final String finalFen;
  String get initialFen => Chess.initial.fen;
  final String whiteName;
  final String blackName;
  final Side? humanSide;
  final String opponentLabel;
  final PiecePackId whitePackId;
  final PiecePackId blackPackId;
  final PiecePackId boardPackId;
  final bool classicPieces;
  final ClassicPieceStyle classicStyle;
  final String? whiteCustomSetId;
  final String? blackCustomSetId;
  final String? whiteCustomName;
  final String? blackCustomName;
  final String? tournamentTitle;
  final ComputerDifficulty? difficulty;

  String get modeLabel => switch (mode) {
    GameHistoryMode.local => 'Local',
    GameHistoryMode.computer => 'Computer',
    GameHistoryMode.tournament => 'Tournament',
    GameHistoryMode.online => 'Online',
  };
  String get statusLabel =>
      status == GameHistoryStatus.completed ? 'Completed' : 'Unfinished';

  Map<String, Object?> toJson() => {
    'version': 1,
    'id': id,
    'completedAtEpochMs': completedAtEpochMs,
    'resultTitle': resultTitle,
    'mode': mode.name,
    'status': status.name,
    'moves': moves,
    'initialFen': initialFen,
    'finalFen': finalFen,
    'whiteName': whiteName,
    'blackName': blackName,
    'humanSide': humanSide?.name,
    'opponentLabel': opponentLabel,
    'whitePackId': whitePackId.name,
    'blackPackId': blackPackId.name,
    'boardPackId': boardPackId.name,
    'classicPieces': classicPieces,
    'classicStyle': classicStyle.name,
    'whiteCustomSetId': whiteCustomSetId,
    'blackCustomSetId': blackCustomSetId,
    'whiteCustomName': whiteCustomName,
    'blackCustomName': blackCustomName,
    'tournamentTitle': tournamentTitle,
    'difficulty': difficulty?.name,
  };
}

String? _optionalText(String? value) =>
    value?.trim().isNotEmpty == true ? value!.trim() : null;

String? _savedResult(SavedGame saved) {
  final suppliedResult = saved.historyResultTitle;
  if (suppliedResult != null) {
    if (suppliedResult.trim().isEmpty) {
      throw const FormatException('Invalid retained game result');
    }
    return suppliedResult.trim();
  }
  if (saved.whiteMilliseconds < 0 || saved.blackMilliseconds < 0) {
    throw const FormatException('Invalid retained game clocks');
  }
  final game = GameSession.fromMoves(moves: saved.moves);
  final position = game.position;
  if (position.isCheckmate) {
    return '${position.turn == Side.white ? 'Black' : 'White'} wins by checkmate';
  }
  if (position.isStalemate) return 'Draw by stalemate';
  if (position.isInsufficientMaterial) return 'Draw by insufficient material';
  if (game.isRuleDraw) return 'Game drawn';
  if (saved.timeControl.timed) {
    if (saved.whiteMilliseconds <= 0 && saved.blackMilliseconds > 0) {
      return 'Black wins on time';
    }
    if (saved.blackMilliseconds <= 0 && saved.whiteMilliseconds > 0) {
      return 'White wins on time';
    }
  }
  return null;
}

class GameHistoryUnavailableRecord {
  const GameHistoryUnavailableRecord({
    required this.label,
    required this.reason,
    this.id,
    this.completedAt,
    this.resultTitle,
  });
  final String label;
  final String reason;
  final String? id;
  final DateTime? completedAt;
  final String? resultTitle;
}

class GameHistorySnapshot {
  GameHistorySnapshot({
    required List<GameHistoryRecord> records,
    List<GameHistoryUnavailableRecord> unavailable = const [],
  }) : records = List.unmodifiable(records),
       unavailable = List.unmodifiable(unavailable);
  final List<GameHistoryRecord> records;
  final List<GameHistoryUnavailableRecord> unavailable;
}

class _Archive {
  _Archive(this.records, {this.unreadable = false});
  final List<Object?> records;
  final bool unreadable;
}

/// Durable device-local history. Writes across all instances are ordered; a
/// failed write leaves the resumable sources and existing archive untouched.
/// No record is automatically evicted, including unreadable individual records.
class GameHistoryStorage {
  GameHistoryStorage({Future<SharedPreferences> Function()? preferences})
    : _preferences = preferences ?? SharedPreferences.getInstance;

  static const storageKey = 'game_history_v1';
  static Future<void>? _tail;
  final Future<SharedPreferences> Function() _preferences;

  Future<T> _serial<T>(Future<T> Function() operation) {
    final pending = _tail;
    final result = pending == null
        ? Future<T>.sync(operation)
        : pending.then((_) => operation());
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    _tail = tail;
    // Release the completed queue rather than retaining its originating zone.
    // A newer operation may already have installed its own tail.
    tail.then((_) {
      if (identical(_tail, tail)) _tail = null;
    });
    return result;
  }

  Future<List<GameHistoryRecord>> load() async =>
      (await loadSnapshot()).records;

  Future<GameHistorySnapshot> loadSnapshot() => _serial(() async {
    final prefs = await _preferences();
    final archive = _read(prefs);
    if (!archive.unreadable) {
      final changed = _migrate(prefs, archive.records);
      if (changed) await _write(prefs, archive.records);
    }
    return _snapshot(archive);
  });

  /// Call before a legacy resume loader clears a terminal or unresumable slot.
  /// Scanning is idempotent and never edits or deletes the retained source slots.
  Future<void> migrateRetainedGames() async {
    await loadSnapshot();
  }

  Future<void> save(GameHistoryRecord record) => _serial(() async {
    final prefs = await _preferences();
    final archive = _read(prefs);
    if (archive.unreadable) {
      throw StateError(
        'Existing game history could not be read; it was preserved',
      );
    }
    final changed = _upsert(archive.records, record);
    if (changed) await _write(prefs, archive.records);
  });

  _Archive _read(SharedPreferences prefs) {
    final encoded = prefs.get(storageKey);
    if (encoded == null) return _Archive([]);
    try {
      if (encoded is! String) throw const FormatException('Invalid history');
      final decoded = jsonDecode(encoded);
      if (decoded is! Map ||
          decoded['version'] != 1 ||
          decoded['records'] is! List) {
        throw const FormatException('Unsupported history');
      }
      return _Archive(List<Object?>.of(decoded['records'] as List));
    } catch (_) {
      return _Archive([], unreadable: true);
    }
  }

  Future<void> _write(SharedPreferences prefs, List<Object?> records) async {
    try {
      if (!await prefs.setString(
        storageKey,
        jsonEncode({'version': 1, 'records': records}),
      )) {
        throw StateError('Game history could not be saved');
      }
    } catch (_) {
      // SharedPreferences updates its cache before the platform write resolves.
      // Refresh it on failure so a later load cannot report unpersisted games.
      try {
        await prefs.reload();
      } catch (_) {
        // Preserve the original write error for the caller's retry UI.
      }
      rethrow;
    }
  }

  bool _upsert(List<Object?> raw, GameHistoryRecord record) {
    for (var i = 0; i < raw.length; i++) {
      final candidate = raw[i];
      if (candidate is! Map || candidate['id'] != record.id) continue;
      GameHistoryRecord existing;
      try {
        existing = GameHistoryRecord.fromJson(
          candidate.cast<String, Object?>(),
        );
      } catch (_) {
        // Do not replace unreadable data; a valid new record can coexist with it.
        continue;
      }
      if (existing.status == GameHistoryStatus.completed) {
        if (record.status == GameHistoryStatus.unfinished) return false;
        if (!_sameMoves(existing.moves, record.moves) ||
            existing.finalFen != record.finalFen) {
          throw StateError(
            'A completed game ID cannot identify a different game',
          );
        }
        return false;
      }
      if (record.status == GameHistoryStatus.unfinished &&
          record.recordedAtEpochMs <= existing.recordedAtEpochMs) {
        return false;
      }
      raw[i] = record.toJson();
      return true;
    }
    raw.add(record.toJson());
    return true;
  }

  GameHistorySnapshot _snapshot(_Archive archive) {
    if (archive.unreadable) {
      return GameHistorySnapshot(
        records: [],
        unavailable: const [
          GameHistoryUnavailableRecord(
            label: 'Saved game history',
            reason:
                'The archive could not be read. Its stored data was preserved.',
          ),
        ],
      );
    }
    final records = <GameHistoryRecord>[];
    final unavailable = <GameHistoryUnavailableRecord>[];
    final ids = <String>{};
    for (final raw in archive.records) {
      try {
        if (raw is! Map) throw const FormatException('Invalid record');
        final record = GameHistoryRecord.fromJson(raw.cast<String, Object?>());
        if (!ids.add(record.id)) {
          throw const FormatException('Duplicate game ID');
        }
        records.add(record);
      } catch (_) {
        final map = raw is Map ? raw : const <String, Object?>{};
        final title = map['resultTitle'] is String
            ? map['resultTitle'] as String
            : null;
        unavailable.add(
          GameHistoryUnavailableRecord(
            id: map['id'] is String ? map['id'] as String : null,
            resultTitle: title,
            label: title?.trim().isNotEmpty == true
                ? title!
                : 'Unavailable recorded game',
            reason:
                'The saved move history could not be validated. Its data was preserved.',
          ),
        );
      }
    }
    records.sort((a, b) {
      final date = b.recordedAt.compareTo(a.recordedAt);
      return date != 0 ? date : a.id.compareTo(b.id);
    });
    return GameHistorySnapshot(records: records, unavailable: unavailable);
  }

  bool _migrate(SharedPreferences prefs, List<Object?> raw) {
    var changed = false;
    void addSaved(
      Object? value, {
      GameHistoryMode? mode,
      String? tournamentTitle,
    }) {
      try {
        if (value is! Map) return;
        final saved = SavedGame.fromJson(value.cast<String, Object?>());
        if (mode == GameHistoryMode.tournament &&
            saved.mode != PlayerMode.computer) {
          return;
        }
        final result = _savedResult(saved);
        if (saved.moves.isEmpty && result == null) return;
        final computer = '${saved.difficulty.label} computer';
        final opponent = tournamentTitle == null
            ? computer
            : 'Tournament opponent';
        final white = saved.mode == PlayerMode.local
            ? 'White player'
            : saved.humanSide == Side.white
            ? 'You'
            : opponent;
        final black = saved.mode == PlayerMode.local
            ? 'Black player'
            : saved.humanSide == Side.black
            ? 'You'
            : opponent;
        final record = GameHistoryRecord.fromSavedGame(
          saved,
          mode: mode,
          whiteName: white,
          blackName: black,
          tournamentTitle: tournamentTitle,
        );
        changed = _upsert(raw, record) || changed;
      } catch (_) {
        // A corrupt legacy slot is isolated; never clear its original data.
      }
    }

    final last = prefs.get('lastOpenGameV1');
    if (last is String) {
      try {
        addSaved(jsonDecode(last));
      } catch (_) {
        // Retain unparseable source slots for a future recovery attempt.
      }
    }
    void addTournament(String cupId, Object? encoded) {
      try {
        if (encoded is! String) return;
        final state = jsonDecode(encoded);
        if (state is! Map || state['version'] != 1 || state['game'] is! Map) {
          return;
        }
        final cup = [
          ...builtInTournaments,
          ...builtInConquests,
        ].where((cup) => cup.id == cupId).firstOrNull;
        addSaved(
          state['game'],
          mode: GameHistoryMode.tournament,
          tournamentTitle: cup?.title ?? 'Tournament $cupId',
        );
      } catch (_) {
        // Old completed rounds without moves cannot be reconstructed.
      }
    }

    for (final key in prefs.getKeys().where(
      (key) => key.startsWith('bot_tournament_'),
    )) {
      addTournament(key.substring('bot_tournament_'.length), prefs.get(key));
    }
    final conquest = prefs.get('conquest_player_v1');
    if (conquest is String) {
      try {
        final state = jsonDecode(conquest);
        if (state is Map) {
          for (final entry in state.entries) {
            if (entry.key is String && entry.key != 'player') {
              addTournament(entry.key as String, entry.value);
            }
          }
        }
      } catch (_) {
        // Preserve the conquest ledger and every other source slot untouched.
      }
    }
    return changed;
  }
}

bool _sameMoves(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
