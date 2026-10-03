import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/services/computer_player.dart';
import 'package:battle_chess_arena/src/services/last_game_storage.dart';
import 'package:battle_chess_arena/src/services/one_time_cleanup.dart';
import 'package:battle_chess_arena/src/services/online_game_history.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'beta upgrades preserve saves even without the old cleanup marker',
    () async {
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
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        'bot_tournament_beginner-cup-v1',
        'existing-cup',
      );
      await preferences.setBool('musicMuted', true);
      final before = {
        for (final key in preferences.getKeys()) key: preferences.get(key),
      };

      await OneTimeCleanup.run();
      expect((await LastGameStorage.load())!.moves, ['e2e4']);
      expect(await OnlineGameHistory.loadGames(), hasLength(1));
      expect(await OnlineGameHistory.loadReminders(), {'old-invite'});
      expect(preferences.getBool(OneTimeCleanup.markerKey), isTrue);
      for (final entry in before.entries) {
        expect(preferences.get(entry.key), entry.value);
      }

      await OnlineGameHistory.upsert(history);
      await OneTimeCleanup.run();
      expect(await OnlineGameHistory.loadGames(), hasLength(1));
    },
  );
}
