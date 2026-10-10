// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';

import '../domain/cinematic_replay.dart';
import '../domain/online_game_state.dart';
import '../domain/piece_pack.dart';
import '../features/play/board_appearance.dart';
import 'app_diagnostics.dart';
import 'game_history_storage.dart';
import 'home_chess_set.dart';
import 'match_appearance_storage.dart';

/// Archives full, accepted server snapshots independently of the game route.
/// Only public room/round/seat identifiers and replay metadata are retained.
class OnlineGameArchive extends ChangeNotifier {
  OnlineGameArchive({
    GameHistoryStorage? storage,
    Future<BoardAppearance?> Function(String, String)? loadMatchAppearance,
    Future<HomeChessSet> Function()? loadHomeChessSet,
    DateTime Function()? now,
    void Function(Object, StackTrace)? reportFailure,
  }) : _storage = storage ?? GameHistoryStorage(),
       _loadMatchAppearance =
           loadMatchAppearance ?? MatchAppearanceStorage.load,
       _loadHomeChessSet = loadHomeChessSet ?? HomeChessSet.load,
       _now = now ?? DateTime.now,
       _reportFailure =
           reportFailure ??
           ((error, stack) => AppDiagnostics.instance.record(
             DiagnosticSource.asynchronous,
             error,
             stack,
           ));

  final GameHistoryStorage _storage;
  final Future<BoardAppearance?> Function(String, String) _loadMatchAppearance;
  final Future<HomeChessSet> Function() _loadHomeChessSet;
  final DateTime Function() _now;
  final void Function(Object, StackTrace) _reportFailure;
  final _latest = <String, OnlineGameState>{};
  final _appearances = <String, BoardAppearance>{};
  final _savedSignatures = <String, String>{};
  final _failed = <String, _ArchiveRequest>{};
  Future<void> _tail = Future.value();
  int _lastTimestamp = -1;
  bool _disposed = false;

  static String recordId(String gameId, int round, String seat) =>
      'online-${Uri.encodeComponent(gameId)}-round-$round-seat-$seat';

  String? get error => _failed.isEmpty
      ? null
      : 'Could not save this game to history. Your online game can continue.';

  /// Includes every snapshot queued before this call, useful before reading
  /// the local archive. The writes themselves continue after a route closes.
  Future<void> get pending => _tail;

  Future<void> recordAcceptedState(
    OnlineGameState state, {
    required String seat,
  }) {
    if (seat != 'w' && seat != 'b') {
      throw ArgumentError.value(seat, 'seat');
    }
    final id = recordId(state.gameId, state.round, seat);
    final previous = _latest[id];
    if (previous != null && state.sequence <= previous.sequence) return _tail;
    _latest[id] = state;
    if (state.status == 'waiting' ||
        (state.status != 'complete' && state.san.isEmpty)) {
      return _tail;
    }
    return _enqueue(_request(state, seat));
  }

  /// Records the device-local chess set actually displayed for this round.
  /// Updating an active recording enriches it without changing its moves.
  Future<void> rememberAppearance({
    required String gameId,
    required int round,
    required String seat,
    required BoardAppearance appearance,
  }) {
    final id = recordId(gameId, round, seat);
    _appearances[id] = appearance;
    final state = _latest[id];
    if (state == null || state.status != 'active' || state.san.isEmpty) {
      return _tail;
    }
    return _enqueue(_request(state, seat));
  }

  _ArchiveRequest _request(OnlineGameState state, String seat) {
    final id = recordId(state.gameId, state.round, seat);
    final timestamp = _now().toUtc().millisecondsSinceEpoch;
    _lastTimestamp = timestamp > _lastTimestamp
        ? timestamp
        : _lastTimestamp + 1;
    // Start the appearance read when accepting the snapshot. Its completion
    // cannot reorder writes, and later screen choices cannot replace a known
    // appearance captured for an earlier round.
    final appearance = _appearances[id];
    return _ArchiveRequest(
      state: state,
      seat: seat,
      recordedAt: DateTime.fromMillisecondsSinceEpoch(
        _lastTimestamp,
        isUtc: true,
      ),
      appearance: _resolveAppearance(
        appearance == null
            ? _appearanceFor(state.gameId, seat)
            : Future.value(appearance),
      ),
    );
  }

  Future<BoardAppearance> _appearanceFor(String room, String seat) async {
    final saved = await _loadMatchAppearance(room, seat);
    if (saved != null) return saved;
    final home = await _loadHomeChessSet();
    final appearance = BoardAppearance.forPack(
      piecePacks.firstWhere((pack) => pack.id == home.pack),
    );
    return home.classic
        ? appearance.withStandardPieces(home.style)
        : appearance;
  }

  Future<_ArchiveAppearance> _resolveAppearance(
    Future<BoardAppearance> appearance,
  ) async {
    try {
      return _ArchiveAppearance(await appearance);
    } catch (error, stack) {
      return _ArchiveAppearance.failed(error, stack);
    }
  }

  Future<void> _enqueue(_ArchiveRequest request) {
    final operation = _tail.then((_) => _save(request));
    // _save handles storage/validation errors; the queue always remains usable.
    _tail = operation;
    return operation;
  }

  Future<void> _save(_ArchiveRequest request) async {
    final state = request.state;
    final id = recordId(state.gameId, state.round, request.seat);
    try {
      // Await the already-started read even on invalid SAN, consuming failures
      // without leaving an unhandled asynchronous error behind the queue.
      final resolved = await request.appearance;
      if (resolved.error != null) {
        Error.throwWithStackTrace(resolved.error!, resolved.stack!);
      }
      final appearance = resolved.value!;
      final moves = replayUciMovesFromSan(state.san, expectedFen: state.fen);
      final signature = jsonEncode([
        state.status,
        state.status == 'complete' ? state.statusLabel : 'Game unfinished',
        moves,
        state.fen,
        state.whitePlayer.name,
        state.blackPlayer.name,
        appearance.white.id.name,
        appearance.black.id.name,
        appearance.board.id.name,
        appearance.standardPieces,
        appearance.classicStyle.name,
        appearance.customSet?.id,
        appearance.customSet?.name,
      ]);
      if (_savedSignatures[id] == signature) {
        _clearFailure(id, request);
        return;
      }
      final record = request.record ??= GameHistoryRecord(
        id: id,
        completedAt: request.recordedAt,
        resultTitle: state.status == 'complete'
            ? state.statusLabel
            : 'Game unfinished',
        mode: GameHistoryMode.online,
        status: state.status == 'complete'
            ? GameHistoryStatus.completed
            : GameHistoryStatus.unfinished,
        moves: moves,
        finalFen: state.fen,
        whiteName: state.whitePlayer.name,
        blackName: state.blackPlayer.name,
        humanSide: request.seat == 'w' ? Side.white : Side.black,
        whitePackId: appearance.white.id,
        blackPackId: appearance.black.id,
        boardPackId: appearance.board.id,
        classicPieces: appearance.standardPieces,
        classicStyle: appearance.classicStyle,
        whiteCustomSetId: appearance.customSet?.id,
        blackCustomSetId: appearance.customSet?.id,
        whiteCustomName: appearance.customSet?.name,
        blackCustomName: appearance.customSet?.name,
      );
      await _storage.save(record);
      _savedSignatures[id] = signature;
      _clearFailure(id, request);
    } catch (error, stack) {
      _reportFailure(error, stack);
      final previous = _failed[id];
      if (previous == null ||
          (previous.state.status != 'complete' &&
              previous.state.sequence <= state.sequence) ||
          (state.status == 'complete' &&
              previous.state.sequence <= state.sequence)) {
        _failed[id] = request;
      }
      _notify();
    }
  }

  void _clearFailure(String id, _ArchiveRequest saved) {
    final failed = _failed[id];
    if (failed != null &&
        (identical(failed, saved) ||
            (failed.state.status != 'complete' &&
                saved.state.sequence >= failed.state.sequence) ||
            saved.state.status == 'complete')) {
      _failed.remove(id);
      _notify();
    }
  }

  /// Retries immutable failed recordings, including a room already left.
  Future<void> retryFailed() {
    for (final request in _failed.values.toList(growable: false)) {
      final id = recordId(
        request.state.gameId,
        request.state.round,
        request.seat,
      );
      final newest = _latest[id];
      if (newest != null &&
          request.state.status != 'complete' &&
          newest.sequence > request.state.sequence) {
        _enqueue(_request(newest, request.seat));
      } else if (request.record == null) {
        _enqueue(_request(request.state, request.seat));
      } else {
        _enqueue(request);
      }
    }
    return _tail;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class _ArchiveRequest {
  _ArchiveRequest({
    required this.state,
    required this.seat,
    required this.recordedAt,
    required this.appearance,
  });
  final OnlineGameState state;
  final String seat;
  final DateTime recordedAt;
  final Future<_ArchiveAppearance> appearance;
  GameHistoryRecord? record;
}

class _ArchiveAppearance {
  const _ArchiveAppearance(this.value) : error = null, stack = null;
  const _ArchiveAppearance.failed(this.error, this.stack) : value = null;
  final BoardAppearance? value;
  final Object? error;
  final StackTrace? stack;
}
