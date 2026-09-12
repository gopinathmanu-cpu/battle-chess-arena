import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/services/computer_player.dart';
import 'package:battle_chess_arena/src/services/last_game_storage.dart';
import 'package:battle_chess_arena/src/services/one_time_cleanup.dart';
import 'package:battle_chess_arena/src/services/online_game_history.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('historical data is cleared once and new records remain', () async {
    SharedPreferences.setMockInitialValues({});
    const game = SavedGame(
      mode: PlayerMode.local,
      homePack: PiecePackId.greek,
      difficulty: ComputerDifficulty.medium,
      moves: ['e2e4'],
      whiteMilliseconds: 600000,
      blackMilliseconds: 600000,
      fastBattles: false,
      whitePack: PiecePackId.greek,
      blackPack: PiecePackId.greek,
      boardPack: PiecePackId.greek,
      updatedAtEpochMs: 1,
    );
    final history = OnlineGameRecord(
      gameId: 'old-game',
      seat: 'w',
      seatToken: 'old-token',
      opponentName: 'Old Opponent',
      opponentAvatarId: 'crown',
      status: 'complete',
      moveCount: 12,
      updatedAt: DateTime(2026),
    );
    await LastGameStorage.save(game);
    await OnlineGameHistory.upsert(history);
    await OnlineGameHistory.saveReminders({'old-invite'});

    await OneTimeCleanup.run();
    expect(await LastGameStorage.load(), isNull);
    expect(await OnlineGameHistory.loadGames(), isEmpty);
    expect(await OnlineGameHistory.loadReminders(), isEmpty);

    await OnlineGameHistory.upsert(history);
    await OneTimeCleanup.run();
    expect(await OnlineGameHistory.loadGames(), hasLength(1));
  });
}
