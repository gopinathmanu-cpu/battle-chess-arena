import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/services/online_match_client.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/online_fixtures.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'move stays pending until receipt, canonical board changes only on state',
    () async {
      final channel = FakeChannel();
      final client = OnlineMatchClient(channelFactory: (_) => channel);
      addTearDown(client.dispose);
      await client.connect(Uri.parse('ws://localhost:8080'));
      channel.seat();
      await flush();
      client.requestMove(from: Square.e2, to: Square.e4);
      final command = channel.sent.last;
      expect(command['commandId'], isNotEmpty);
      expect(command['round'], 1);
      expect(command['ply'], 0);
      expect(client.state!.san, isEmpty);
      expect(client.busy, isTrue);
      client.requestMove(from: Square.d2, to: Square.d4);
      expect(channel.sent.where((f) => f['type'] == 'move').length, 1);
      final game = GameSession()..playUci('e2e4');
      channel.receive({
        'type': 'game_state',
        'state': stateJson(game: game, sequence: 2),
      });
      await flush();
      expect(client.state!.san, ['e4']);
      channel.receive({
        'type': 'command_result',
        'commandId': command['commandId'],
        'accepted': true,
      });
      await flush();
      expect(client.busy, isFalse);
      channel.receive({'type': 'game_state', 'state': stateJson(sequence: 1)});
      await flush();
      expect(client.state!.san, ['e4']);
    },
  );

  test(
    'reconnect restores seat, requests sync, retries the exact pending command',
    () async {
      final first = FakeChannel();
      final second = FakeChannel();
      var attempt = 0;
      final client = OnlineMatchClient(
        channelFactory: (_) => attempt++ == 0 ? first : second,
        retryDelay: const Duration(milliseconds: 10),
      );
      addTearDown(client.dispose);
      await client.connect(Uri.parse('ws://localhost:8080'));
      first.seat();
      await flush();
      client.requestMove(from: Square.e2, to: Square.e4);
      final pending = first.sent.last;
      await first.incoming.close();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(client.connected, isFalse);
      expect(second.sent.single['type'], 'resume_game');
      expect(second.sent.single['seatToken'], 'test-secret');
      second.receive({
        'type': 'seat_resumed',
        'gameId': 'room',
        'seat': 'w',
        'state': stateJson(sequence: 2),
      });
      await flush();
      expect(second.sent.last['type'], 'sync');
      expect(client.connected, isFalse);
      second.receive({
        'type': 'game_state',
        'synced': true,
        'state': stateJson(sequence: 3),
      });
      await flush();
      expect(client.connected, isTrue);
      expect(second.sent.last, pending);
      second.receive({
        'type': 'command_result',
        'commandId': pending['commandId'],
        'accepted': true,
        'duplicate': true,
      });
      await flush();
      expect(client.busy, isFalse);
      expect(client.session.committedCapture, isNull);
    },
  );

  test(
    'invalid frames do not mutate board; rejected requests unblock input',
    () async {
      final channel = FakeChannel();
      final client = OnlineMatchClient(channelFactory: (_) => channel);
      addTearDown(client.dispose);
      await client.connect(Uri.parse('ws://localhost:8080'));
      channel.seat();
      await flush();
      channel.incoming.add('invalid');
      await flush();
      expect(client.error, 'Received an invalid server response');
      expect(client.state!.sequence, 1);
      client.offerDraw();
      channel.receive({
        'type': 'command_result',
        'commandId': channel.sent.last['commandId'],
        'accepted': false,
        'message': 'Rejected',
      });
      await flush();
      expect(client.busy, isFalse);
      expect(client.error, 'Rejected');
    },
  );

  test(
    'disposing during connection does not notify or resurrect a client',
    () async {
      final channel = FakeChannel();
      final client = OnlineMatchClient(channelFactory: (_) => channel);
      final connecting = client.connect(Uri.parse('ws://localhost:8080'));
      client.dispose();
      await connecting;
      expect(client.connected, isFalse);
      expect(channel.sent, isEmpty);
    },
  );

  test('quick match waits, can cancel, and clears the reserved seat', () async {
    final channel = FakeChannel();
    final client = OnlineMatchClient(channelFactory: (_) => channel);
    addTearDown(client.dispose);
    await client.connect(Uri.parse('ws://localhost:8080'));
    client.quickMatch(baseMs: 180000);
    final quick = channel.sent.single;
    expect(quick['type'], 'quick_match');
    expect(quick['baseMs'], 180000);
    channel.receive({
      'type': 'matchmaking_waiting',
      'commandId': quick['commandId'],
      'gameId': 'quick-room',
      'seat': 'w',
      'seatToken': 'quick-secret',
      'state': stateJson(
        gameId: 'quick-room',
        status: 'waiting',
        whiteMs: 180000,
        blackMs: 180000,
      ),
    });
    await flush();
    expect(client.searchingForOpponent, isTrue);
    expect(client.gameId, 'quick-room');
    client.cancelMatchmaking();
    final cancel = channel.sent.last;
    expect(cancel['type'], 'cancel_matchmaking');
    channel.receive({
      'type': 'matchmaking_cancelled',
      'commandId': cancel['commandId'],
      'gameId': 'quick-room',
    });
    await flush();
    expect(client.searchingForOpponent, isFalse);
    expect(client.gameId, isNull);
    expect(client.state, isNull);
  });
}
