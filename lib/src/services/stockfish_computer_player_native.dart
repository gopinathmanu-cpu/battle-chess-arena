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
  Completer<void>? _uciReady;
  bool _supportsLimitStrength = false;
  int? _minimumElo;
  int? _maximumElo;
  bool _disposed = false;

  Future<void> _ensureReady() async {
    _engine ??= await _engineFactory();
    if (_disposed) {
      _engine!.dispose();
      return;
    }
    _output ??= _engine!.stdout.listen((line) {
      line = line.trim();
      if (line.startsWith('option name UCI_LimitStrength type check')) {
        _supportsLimitStrength = true;
      }
      if (line.startsWith('option name UCI_Elo type spin')) {
        _minimumElo = int.tryParse(
          RegExp(r'\bmin (\d+)').firstMatch(line)?.group(1) ?? '',
        );
        _maximumElo = int.tryParse(
          RegExp(r'\bmax (\d+)').firstMatch(line)?.group(1) ?? '',
        );
      }
      if (line == 'uciok' && !(_uciReady?.isCompleted ?? true)) {
        _uciReady!.complete();
      }
      if (line.trim() == 'readyok' && !(_ready?.isCompleted ?? true)) {
        _ready!.complete();
      }
      if (!line.startsWith('bestmove ')) return;
      final move = line.split(RegExp(r'\s+'))[1];
      if (!(_pending?.isCompleted ?? true)) {
        _pending!.complete(move == '(none)' ? null : move);
      }
    });
    if (_uciReady == null) {
      _uciReady = Completer<void>();
      _engine!.stdin = 'uci';
    }
    await _uciReady!.future.timeout(const Duration(seconds: 30));
    _ready = Completer<void>();
    _engine!.stdin = 'isready';
    await _ready!.future.timeout(const Duration(seconds: 30));
  }

  @override
  Future<String?> bestMove(
    String fen, {
    ComputerDifficulty difficulty = ComputerDifficulty.medium,
    int? botLevel,
  }) async {
    final bot = botLevel == null ? null : BotStrength(botLevel);
    final thinkTime = bot?.thinkTime ?? difficulty.thinkTime;
    await _ensureReady();
    if (_disposed || _engine == null) return null;
    if (!(_pending?.isCompleted ?? true)) {
      _engine!.stdin = 'stop';
      await _pending!.future.timeout(const Duration(seconds: 5));
    }
    _pending = Completer<String?>();
    final targetElo = difficulty.stockfishTargetElo;
    final useElo =
        bot == null &&
        _supportsLimitStrength &&
        _minimumElo != null &&
        _maximumElo != null &&
        targetElo >= _minimumElo! &&
        targetElo <= _maximumElo!;
    // Do not clamp Easy upwards to the engine's minimum Elo. An unsupported
    // target uses the requested skill and shallow search instead.
    if (_supportsLimitStrength) {
      _engine!.stdin = 'setoption name UCI_LimitStrength value $useElo';
    }
    if (useElo) {
      _engine!.stdin = 'setoption name UCI_Elo value $targetElo';
    }
    _engine!
      ..stdin =
          'setoption name Skill Level value ${bot?.stockfishSkill ?? difficulty.stockfishSkill}'
      // Clear search history so a previous Hard hint cannot strengthen Easy.
      ..stdin = 'ucinewgame'
      ..stdin = 'position fen $fen'
      ..stdin =
          'go depth ${bot?.depth ?? difficulty.stockfishDepth} '
          'movetime ${thinkTime.inMilliseconds}';
    return _pending!.future.timeout(
      thinkTime + const Duration(seconds: 15),
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
