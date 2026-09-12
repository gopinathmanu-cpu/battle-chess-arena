import 'package:battle_chess_arena/src/domain/online_player_profile.dart';
import 'package:battle_chess_arena/src/services/online_game_history.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'persists profile and keeps one latest history entry per game',
    () async {
      SharedPreferences.setMockInitialValues({});
      const profile = OnlinePlayerProfile(
        name: 'History Hero',
        avatarId: 'dragon',
        playerToken: 'player-token',
      );
      await OnlineGameHistory.saveProfile(profile);
      expect((await OnlineGameHistory.loadProfile())!.name, 'History Hero');

      final first = OnlineGameRecord(
        gameId: 'game-one',
        seat: 'w',
        seatToken: 'seat-secret',
        opponentName: 'Moon Mage',
        opponentAvatarId: 'moon',
        status: 'active',
        moveCount: 4,
        updatedAt: DateTime(2026, 9, 12),
      );
      await OnlineGameHistory.upsert(first);
      await OnlineGameHistory.upsert(
        OnlineGameRecord(
          gameId: first.gameId,
          seat: first.seat,
          seatToken: first.seatToken,
          opponentName: first.opponentName,
          opponentAvatarId: first.opponentAvatarId,
          status: 'complete',
          moveCount: 19,
          updatedAt: DateTime(2026, 9, 13),
        ),
      );
      final history = await OnlineGameHistory.loadGames();
      expect(history, hasLength(1));
      expect(history.single.opponentName, 'Moon Mage');
      expect(history.single.status, 'complete');
      expect(history.single.moveCount, 19);

      var favorites = await OnlineGameHistory.toggleFavorite(
        const OnlineFavorite(name: 'Moon Mage', avatarId: 'moon'),
      );
      expect(favorites.single.name, 'Moon Mage');
      favorites = await OnlineGameHistory.toggleFavorite(favorites.single);
      expect(favorites, isEmpty);

      await OnlineGameHistory.saveReminders({'invite-one'});
      expect(await OnlineGameHistory.loadReminders(), {'invite-one'});
    },
  );
}
