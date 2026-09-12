// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:stockfish/stockfish.dart';

import 'computer_player_contract.dart';

ComputerPlayer createPrimaryComputerPlayer() => StockfishComputerPlayer();

class StockfishComputerPlayer implements ComputerPlayer {
  StockfishComputerPlayer({Future<Stockfish> Function()? engineFactory})
    : _engineFactory = engineFactory ?? stockfishAsync;

  final Future<Stockfish> Function() _engineFactory;
  Stockfish? _engine;
  StreamSubscription<String>? _output;
  Completer<String?>? _pending;
  Completer<void>? _ready;
  bool _disposed = false;

  Future<void> _ensureReady() async {
    _engine ??= await _engineFactory();
    if (_disposed) {
      _engine!.dispose();
      return;
    }
    _output ??= _engine!.stdout.listen((line) {
      if (line.trim() == 'readyok' && !(_ready?.isCompleted ?? true)) {
        _ready!.complete();
      }
      if (!line.startsWith('bestmove ')) return;
      final move = line.split(RegExp(r'\s+'))[1];
      if (!(_pending?.isCompleted ?? true)) {
        _pending!.complete(move == '(none)' ? null : move);
      }
    });
    _ready = Completer<void>();
    _engine!.stdin = 'isready';
    await _ready!.future.timeout(const Duration(seconds: 30));
  }

  @override
  Future<String?> bestMove(
    String fen, {
    ComputerDifficulty difficulty = ComputerDifficulty.medium,
  }) async {
    await _ensureReady();
    if (_disposed || _engine == null) return null;
    if (!(_pending?.isCompleted ?? true)) {
      _engine!.stdin = 'stop';
      await _pending!.future.timeout(const Duration(seconds: 5));
    }
    _pending = Completer<String?>();
    _engine!
      ..stdin = 'setoption name Skill Level value ${difficulty.stockfishSkill}'
      ..stdin = 'position fen $fen'
      ..stdin = 'go movetime ${difficulty.thinkTime.inMilliseconds}';
    return _pending!.future.timeout(
      difficulty.thinkTime + const Duration(seconds: 15),
      onTimeout: () {
        _engine?.stdin = 'stop';
        return _pending!.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () => null,
        );
      },
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _output?.cancel();
    if (_engine?.state.value == StockfishState.ready) _engine?.dispose();
    _engine = null;
  }
}
