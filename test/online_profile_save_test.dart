import 'package:battle_chess_arena/src/domain/online_player_profile.dart';
import 'package:battle_chess_arena/src/services/online_game_history.dart';
import 'package:battle_chess_arena/src/services/online_match_client.dart';
import 'package:battle_chess_arena/src/services/online_profile_save.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/online_fixtures.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  for (final existing in [false, true]) {
    for (final rejected in [false, true]) {
      test(
        '${existing ? "edit" : "create"} caches only server-confirmed unique name (rejected=$rejected)',
        () async {
          SharedPreferences.setMockInitialValues({});
          const previous = OnlinePlayerProfile(
            name: 'Original Knight',
            avatarId: 'avatar-01',
            playerToken: 'owned-token',
          );
          const desired = OnlinePlayerProfile(
            name: '@Nova#42',
            avatarId: 'avatar-02',
          );
          if (existing) await OnlineGameHistory.saveProfile(previous);
          final channel = FakeChannel();
          final client = OnlineMatchClient(
            channelFactory: (_) => channel,
            profile: existing ? previous : desired,
          );
          addTearDown(client.dispose);
          final saving = saveOnlineProfileConfirmed(
            desired,
            previous: existing ? previous : null,
            client: client,
            endpoint: Uri.parse('ws://localhost:8080'),
          );
          final assertion = rejected
              ? expectLater(saving, throwsA(isA<StateError>()))
              : expectLater(saving, completion(isA<OnlinePlayerProfile>()));
          await flush();
          channel.receive({'type': 'connected', 'protocolVersion': 4});
          await flush();
          var command = channel.sent.lastWhere(
            (message) => message['type'] == 'register_player',
          );
          if (existing || !rejected) {
            channel.receive({
              'type': 'player_registered',
              'commandId': command['commandId'],
              'name': existing ? previous.name : desired.name,
              'avatarId': existing ? previous.avatarId : desired.avatarId,
              'playerToken': 'owned-token',
            });
            await flush();
            if (existing) {
              command = channel.sent.lastWhere(
                (message) => message['type'] == 'update_player',
              );
            }
          }
          if (rejected) {
            channel.receive({
              'type': 'error',
              'commandId': command['commandId'],
              'code': 'AVATAR_NAME_TAKEN',
              'message': 'That Avatar ID is already in use',
            });
          } else if (existing) {
            channel.receive({
              'type': 'player_updated',
              'commandId': command['commandId'],
              'name': desired.name,
              'avatarId': desired.avatarId,
              'playerToken': 'owned-token',
            });
          }
          await assertion;
          final cached = await OnlineGameHistory.loadProfile();
          expect(
            cached?.name,
            rejected ? (existing ? previous.name : null) : desired.name,
          );
          if (!rejected) expect(cached?.playerToken, 'owned-token');
        },
      );
    }
  }
}
