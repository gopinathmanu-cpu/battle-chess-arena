// SPDX-License-Identifier: GPL-3.0-or-later
import 'computer_player_contract.dart';

ComputerPlayer createPrimaryComputerPlayer() => StockfishComputerPlayer();

/// Browsers cannot load the native Stockfish FFI library. Returning no move
/// intentionally activates ReliableComputerPlayer's pure-Dart legal fallback.
class StockfishComputerPlayer implements ComputerPlayer {
  StockfishComputerPlayer({Future<Object?> Function()? engineFactory});

  @override
  Future<String?> bestMove(
    String fen, {
    ComputerDifficulty difficulty = ComputerDifficulty.medium,
  }) async => null;

  @override
  void dispose() {}
}
