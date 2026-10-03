import 'package:battle_chess_arena/src/domain/custom_avatar.dart';
import 'package:battle_chess_arena/src/domain/online_player_profile.dart';
import 'package:battle_chess_arena/src/services/online_game_history.dart';
import 'package:battle_chess_arena/src/services/online_match_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/online_fixtures.dart';

Future<void> flushAvatarFrames() => Future<void>.delayed(Duration.zero);

void acknowledgeProfile(FakeChannel channel, {bool update = false}) {
  final request = channel.sent.lastWhere(
    (frame) => frame['type'] == (update ? 'update_player' : 'register_player'),
  );
  channel.receive({
    'type': update ? 'player_updated' : 'player_registered',
    'commandId': request['commandId'],
    'name': request['name'],
    'avatarId': request['avatarId'],
    'level': request['level'],
    'playerToken': 'saved-identity-token',
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final customId = const CustomAvatarDesign(
    presentation: 1,
    age: 3,
    hairStyle: 10,
    hairColor: 8,
    eyewear: 1,
  ).avatarId;

  test(
    'custom design survives saved profile, favorites and game history',
    () async {
      SharedPreferences.setMockInitialValues({});
      final profile = OnlinePlayerProfile(
        name: 'Silver Queen',
        avatarId: customId,
        playerToken: 'saved-identity-token',
      );
      await OnlineGameHistory.saveProfile(profile);
      final restored = await OnlineGameHistory.loadProfile();
      expect(restored!.avatarId, customId);
      expect(restored.playerToken, profile.playerToken);
      final favorite = OnlineFavorite.fromJson(
        OnlineFavorite(name: profile.name, avatarId: customId).toJson(),
      );
      expect(favorite.avatarId, customId);
      final record = OnlineGameRecord.fromJson(
        OnlineGameRecord(
          gameId: 'saved-game',
          seat: 'w',
          seatToken: 'seat-token',
          opponentName: profile.name,
          opponentAvatarId: customId,
          status: 'active',
          moveCount: 3,
          updatedAt: DateTime(2026, 9, 26),
        ).toJson(),
      );
      expect(record.opponentAvatarId, customId);
    },
  );

  test(
    'capable service receives and shares custom profile unchanged',
    () async {
      final channel = FakeChannel();
      final client = OnlineMatchClient(
        channelFactory: (_) => channel,
        profile: OnlinePlayerProfile(name: 'Silver Queen', avatarId: customId),
      );
      addTearDown(client.dispose);
      await client.connect(Uri.parse('ws://localhost:8080'));
      channel.receive({
        'type': 'connected',
        'protocolVersion': 4,
        'capabilities': ['custom_avatars'],
      });
      await flushAvatarFrames();
      expect(channel.sent.single['avatarId'], customId);
      acknowledgeProfile(channel);
      await flushAvatarFrames();
      expect(client.connected, isTrue);
      expect(client.supportsCustomAvatars, isTrue);
      expect(client.profile!.avatarId, customId);
      expect(client.avatarCompatibilityNotice, isNull);

      final updated = const CustomAvatarDesign(hairStyle: 5, beard: 4).avatarId;
      client.updateProfile(
        name: 'Silver Queen',
        avatarId: updated,
        level: OnlinePlayerLevel.advanced,
      );
      expect(channel.sent.last['avatarId'], updated);
      acknowledgeProfile(channel, update: true);
      channel.receive({
        'type': 'player_found',
        'player': {'name': 'Friend', 'avatarId': customId, 'online': true},
      });
      channel.receive({
        'type': 'leaderboard',
        'leaders': [
          {
            'name': 'Friend',
            'avatarId': customId,
            'points': 3,
            'wins': 1,
            'draws': 0,
            'losses': 0,
          },
        ],
      });
      channel.seat(
        state: stateJson(whiteAvatar: updated, blackAvatar: customId),
      );
      await flushAvatarFrames();
      expect(client.profile!.avatarId, updated);
      expect(client.playerSearchResult!.avatarId, customId);
      expect(client.leaderboard.single.avatarId, customId);
      expect(client.state!.whitePlayer.avatarId, updated);
      expect(client.state!.blackPlayer.avatarId, customId);
      expect(client.error, isNull);
    },
  );

  test(
    'older service keeps play working without losing custom design',
    () async {
      var channel = FakeChannel();
      final client = OnlineMatchClient(
        channelFactory: (_) => channel,
        profile: OnlinePlayerProfile(name: 'Silver Queen', avatarId: customId),
      );
      addTearDown(client.dispose);
      await client.connect(Uri.parse('ws://localhost:8080'));
      channel.receive({'type': 'connected', 'protocolVersion': 4});
      await flushAvatarFrames();
      expect(channel.sent.single['avatarId'], 'avatar-01');
      acknowledgeProfile(channel);
      await flushAvatarFrames();
      expect(client.connected, isTrue);
      expect(client.profile!.avatarId, customId);
      expect(client.avatarCompatibilityNotice, contains('preset portrait'));

      final updated = const CustomAvatarDesign(
        hairStyle: 7,
        eyewear: 4,
      ).avatarId;
      client.updateProfile(
        name: 'Silver Queen',
        avatarId: updated,
        level: OnlinePlayerLevel.intermediate,
      );
      expect(channel.sent.last['avatarId'], 'avatar-01');
      acknowledgeProfile(channel, update: true);
      await flushAvatarFrames();
      expect(client.profile!.avatarId, updated);
      await OnlineGameHistory.saveProfile(client.profile!);
      expect((await OnlineGameHistory.loadProfile())!.avatarId, updated);

      channel = FakeChannel();
      await client.connect(Uri.parse('ws://localhost:8080'));
      channel.receive({
        'type': 'connected',
        'protocolVersion': 4,
        'capabilities': ['custom_avatars'],
      });
      await flushAvatarFrames();
      expect(channel.sent.single['avatarId'], updated);
      expect(channel.sent.single['playerToken'], 'saved-identity-token');
      acknowledgeProfile(channel);
      await flushAvatarFrames();
      expect(client.avatarCompatibilityNotice, isNull);
      expect(client.profile!.avatarId, updated);
    },
  );

  test('switching back to a preset clears compatibility fallback', () async {
    final channel = FakeChannel();
    final client = OnlineMatchClient(
      channelFactory: (_) => channel,
      profile: OnlinePlayerProfile(name: 'Silver Queen', avatarId: customId),
    );
    addTearDown(client.dispose);
    await client.connect(Uri.parse('ws://localhost:8080'));
    channel.receive({'type': 'connected', 'protocolVersion': 4});
    await flushAvatarFrames();
    acknowledgeProfile(channel);
    await flushAvatarFrames();
    client.updateProfile(
      name: 'Silver Queen',
      avatarId: 'avatar-50',
      level: OnlinePlayerLevel.intermediate,
    );
    expect(channel.sent.last['avatarId'], 'avatar-50');
    acknowledgeProfile(channel, update: true);
    await flushAvatarFrames();
    expect(client.profile!.avatarId, 'avatar-50');
    expect(client.avatarCompatibilityNotice, isNull);
  });

  test(
    'command-less errors preserve a queued avatar edit and healthy connection',
    () async {
      final channel = FakeChannel();
      final client = OnlineMatchClient(
        channelFactory: (_) => channel,
        profile: const OnlinePlayerProfile(
          name: 'Silver Queen',
          avatarId: 'avatar-02',
        ),
      );
      addTearDown(client.dispose);
      await client.connect(Uri.parse('ws://localhost:8080'));
      channel.receive({
        'type': 'connected',
        'protocolVersion': 4,
        'capabilities': ['custom_avatars'],
      });
      await flushAvatarFrames();
      acknowledgeProfile(channel);
      await flushAvatarFrames();

      client.createGame();
      expect(client.busy, isTrue);
      expect(channel.sent.last['type'], 'create_game');
      expect(
        client.updateProfile(
          name: 'Silver Queen',
          avatarId: customId,
          level: OnlinePlayerLevel.advanced,
        ),
        isTrue,
      );
      expect(client.profileSavePending, isTrue);
      expect(
        channel.sent.where((frame) => frame['type'] == 'update_player'),
        isEmpty,
      );

      channel.receive({
        'type': 'error',
        'code': 'INVALID_MESSAGE',
        'message': 'An unrelated request was rejected',
      });
      await flushAvatarFrames();
      expect(client.connected, isTrue);
      expect(client.connection, MatchConnection.ready);
      expect(client.profileSavePending, isTrue);
      expect(client.profile!.avatarId, 'avatar-02');
      expect(channel.sent.last['type'], 'update_player');
      expect(channel.sent.last['avatarId'], customId);
      for (var count = 0; count < 3; count++) {
        channel.receive({'type': 'pong'});
      }
      await flushAvatarFrames();
      expect(
        channel.sent.where((frame) => frame['type'] == 'update_player'),
        hasLength(1),
      );

      acknowledgeProfile(channel, update: true);
      await flushAvatarFrames();
      expect(client.profile!.avatarId, customId);
      expect(client.profileSavePending, isFalse);
      expect(client.busy, isFalse);
      expect(client.connected, isTrue);
      expect(client.error, isNull);
    },
  );

  test(
    'rejected avatar edits release busy and preserve the committed profile',
    () async {
      final channel = FakeChannel();
      final client = OnlineMatchClient(
        channelFactory: (_) => channel,
        profile: const OnlinePlayerProfile(
          name: 'Silver Queen',
          avatarId: 'avatar-02',
        ),
      );
      addTearDown(client.dispose);
      await client.connect(Uri.parse('ws://localhost:8080'));
      channel.receive({'type': 'connected', 'protocolVersion': 4});
      await flushAvatarFrames();
      acknowledgeProfile(channel);
      await flushAvatarFrames();
      final original = client.profile!.toJson();
      await OnlineGameHistory.saveProfile(client.profile!);

      expect(
        client.updateProfile(
          name: 'Already Taken',
          avatarId: customId,
          level: OnlinePlayerLevel.advanced,
        ),
        isTrue,
      );
      final attempted = channel.sent.last;
      expect(attempted['avatarId'], 'avatar-01');
      expect(client.busy, isTrue);
      channel.receive({
        'type': 'error',
        'commandId': attempted['commandId'],
        'code': 'AVATAR_NAME_TAKEN',
        'message': 'That Avatar ID is already in use',
      });
      await flushAvatarFrames();
      expect(client.profile!.toJson(), original);
      expect((await OnlineGameHistory.loadProfile())!.toJson(), original);
      expect(client.profileSavePending, isFalse);
      expect(client.busy, isFalse);
      expect(client.connected, isTrue);
      expect(client.error, contains('already in use'));
      expect(client.avatarCompatibilityNotice, isNull);
      channel.receive({'type': 'pong'});
      await flushAvatarFrames();
      expect(
        channel.sent.where((frame) => frame['type'] == 'update_player'),
        hasLength(1),
      );

      expect(
        client.updateProfile(
          name: 'Silver Queen',
          avatarId: 'avatar-01',
          level: OnlinePlayerLevel.intermediate,
        ),
        isTrue,
      );
      acknowledgeProfile(channel, update: true);
      await flushAvatarFrames();
      expect(client.profile!.avatarId, 'avatar-01');
      expect(client.avatarCompatibilityNotice, isNull);
      expect(client.profileSavePending, isFalse);
      expect(client.busy, isFalse);
      expect(client.error, isNull);
    },
  );

  for (final saveWhileOffline in [false, true]) {
    test(
      'profile edit retries after reconnect (offline save: $saveWhileOffline)',
      () async {
        var channel = FakeChannel();
        final client = OnlineMatchClient(
          channelFactory: (_) => channel,
          profile: const OnlinePlayerProfile(
            name: 'Silver Queen',
            avatarId: 'avatar-02',
          ),
        );
        addTearDown(client.dispose);
        await client.connect(Uri.parse('ws://localhost:8080'));
        channel.receive({
          'type': 'connected',
          'protocolVersion': 4,
          'capabilities': ['custom_avatars'],
        });
        await flushAvatarFrames();
        acknowledgeProfile(channel);
        await flushAvatarFrames();
        if (saveWhileOffline) await client.disconnect();
        expect(
          client.updateProfile(
            name: 'Silver Queen',
            avatarId: customId,
            level: OnlinePlayerLevel.advanced,
          ),
          isTrue,
        );
        expect(client.profileSavePending, isTrue);
        expect(client.profile!.avatarId, 'avatar-02');
        expect(
          client.updateProfile(
            name: 'Another Queen',
            avatarId: 'avatar-03',
            level: OnlinePlayerLevel.beginner,
          ),
          isFalse,
        );
        channel = FakeChannel();
        await client.reconnect();
        channel.receive({
          'type': 'connected',
          'protocolVersion': 4,
          'capabilities': ['custom_avatars'],
        });
        await flushAvatarFrames();
        acknowledgeProfile(channel);
        await flushAvatarFrames();
        expect(channel.sent.last['type'], 'update_player');
        expect(channel.sent.last['avatarId'], customId);
        acknowledgeProfile(channel, update: true);
        await flushAvatarFrames();
        expect(client.profile!.avatarId, customId);
        expect(client.profile!.level, OnlinePlayerLevel.advanced);
        expect(client.profileSavePending, isFalse);
        expect(client.busy, isFalse);
      },
    );
  }
}
