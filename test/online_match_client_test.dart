import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/services/online_match_client.dart';
import 'package:battle_chess_arena/src/domain/online_player_profile.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/online_fixtures.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);

Map<String, Object> creditPolicyJson() => {
  'version': 1,
  'starterCredits': 300,
  'dailyLoginCredits': 3,
  'dailyAllowanceCap': 300,
  'completionRewardCredits': 1,
  'dailyCompletionRewardCap': 5,
  'costs': {
    'liveHumanRound': 2,
    'dailyHumanRound': 3,
    'computerRound': 4,
    'onlineMoveSuggestion': 1,
  },
};

void main() {
  test(
    'available player pages append, deduplicate and clear on disconnect',
    () async {
      final channel = FakeChannel();
      final client = OnlineMatchClient(channelFactory: (_) => channel);
      addTearDown(client.dispose);
      await client.connect(Uri.parse('ws://localhost:8080'));
      channel.receive({
        'type': 'connected',
        'protocolVersion': 4,
        'capabilities': ['available_players'],
      });
      await flush();
      client.loadAvailablePlayers();
      final request = channel.sent.last['requestId'];
      client.loadAvailablePlayers();
      expect(channel.sent.length, 1);
      Map<String, Object> player(int i) => {
        'name': 'Player $i',
        'avatarId': 'avatar-01',
        'online': true,
      };
      channel.receive({
        'type': 'available_players',
        'requestId': request,
        'players': List.generate(10, player),
        'nextCursor': 'cursor-1',
      });
      await flush();
      expect(client.availablePlayers.length, 10);
      client.loadAvailablePlayers(more: true);
      expect(channel.sent.last['after'], 'cursor-1');
      final next = channel.sent.last['requestId'];
      channel.receive({
        'type': 'available_players',
        'requestId': request,
        'players': [],
        'nextCursor': null,
      });
      await flush();
      expect(client.availablePlayersLoading, isTrue);
      channel.receive({
        'type': 'available_players',
        'requestId': next,
        'players': [player(9), player(10)],
        'nextCursor': null,
      });
      await flush();
      expect(client.availablePlayers.length, 11);
      expect(client.hasMoreAvailablePlayers, isFalse);
      await client.disconnect();
      expect(client.availablePlayers, isEmpty);
      expect(client.availablePlayersLoading, isFalse);
    },
  );
  test(
    'capability-less server falls back to leaderboard presence pages',
    () async {
      final channel = FakeChannel();
      final client = OnlineMatchClient(channelFactory: (_) => channel);
      addTearDown(client.dispose);
      await client.connect(Uri.parse('ws://localhost:8080'));
      channel.receive({'type': 'connected', 'protocolVersion': 4});
      await flush();

      client.loadAvailablePlayers();
      expect(channel.sent.last['type'], 'leaderboard');
      channel.receive({
        'type': 'leaderboard',
        'leaders': [
          for (var i = 0; i < 12; i++)
            {
              'name': 'Legacy $i',
              'avatarId': 'avatar-01',
              'level': 'intermediate',
              'points': 0,
              'wins': 0,
              'draws': 0,
              'losses': 0,
            },
        ],
      });
      await flush();
      expect(channel.sent.last['type'], 'presence');
      channel.receive({
        'type': 'presence',
        'statuses': [
          for (var i = 0; i < 12; i++) {'name': 'Legacy $i', 'online': true},
        ],
      });
      await flush();
      expect(client.availablePlayers.length, 10);
      expect(client.hasMoreAvailablePlayers, isTrue);

      client.loadAvailablePlayers(more: true);
      expect(client.availablePlayers.length, 12);
      expect(client.hasMoreAvailablePlayers, isFalse);
    },
  );

  test(
    'Daily invites require durable capability and preserve clock fields',
    () async {
      final channel = FakeChannel();
      final client = OnlineMatchClient(channelFactory: (_) => channel);
      addTearDown(client.dispose);
      await client.connect(Uri.parse('ws://localhost:8080'));
      channel.receive({'type': 'connected', 'protocolVersion': 4});
      await flush();
      client.sendInvitation('Daily Friend');
      expect(channel.sent, isEmpty);
      expect(client.error, contains('Daily games are not available'));
      channel.receive({
        'type': 'connected',
        'protocolVersion': 4,
        'capabilities': ['invite_clocks', 'daily_games'],
      });
      await flush();
      client.sendInvitation('Daily Friend');
      expect(channel.sent.last['clockMode'], 'daily');
      expect(channel.sent.last['baseMs'], 86400000);
      expect(channel.sent.last['incrementMs'], 0);
      client.sendInvitation(
        'Live Friend',
        clockMode: 'live',
        baseMs: 900000,
        incrementMs: 10000,
      );
      expect(channel.sent.last['clockMode'], 'live');
      expect(channel.sent.last['incrementMs'], 10000);
    },
  );
  test(
    'toss requires capability and sends optional field only when requested',
    () async {
      final channel = FakeChannel();
      final client = OnlineMatchClient(channelFactory: (_) => channel);
      addTearDown(client.dispose);
      await client.connect(Uri.parse('ws://localhost:8080'));
      channel.receive({'type': 'connected', 'protocolVersion': 4});
      await flush();
      client.quickMatch(tossForColors: true);
      expect(channel.sent, isEmpty);
      expect(client.error, contains('Colour toss is not available'));
      channel.receive({
        'type': 'connected',
        'protocolVersion': 4,
        'capabilities': ['color_toss'],
      });
      await flush();
      client.quickMatch(tossForColors: true);
      expect(channel.sent.last['tossForColors'], true);
      expect(channel.sent.last['type'], 'quick_match');
    },
  );
  test('player avatar catalog has fifty unique human portrait IDs', () {
    expect(onlineAvatarChoices, hasLength(50));
    expect(
      onlineAvatarChoices.map((avatar) => avatar.id).toSet(),
      hasLength(50),
    );
    expect(onlineAvatarChoices.first.id, 'avatar-01');
    expect(onlineAvatarChoices.last.id, 'avatar-50');
  });

  test('built-in online roster has twenty unique global computer profiles', () {
    expect(builtInComputerOpponents, hasLength(20));
    expect(
      builtInComputerOpponents.map((opponent) => opponent.id).toSet(),
      hasLength(20),
    );
    expect(
      builtInComputerOpponents.map((opponent) => opponent.name).toSet(),
      hasLength(20),
    );
    expect(
      builtInComputerOpponents.map((opponent) => opponent.level).toSet(),
      OnlinePlayerLevel.values.toSet(),
    );
  });

  test('registers a unique player profile before enabling the lobby', () async {
    final channel = FakeChannel();
    final client = OnlineMatchClient(
      channelFactory: (_) => channel,
      profile: const OnlinePlayerProfile(
        name: 'Nova Knight',
        avatarId: 'mage',
        level: OnlinePlayerLevel.advanced,
      ),
    );
    addTearDown(client.dispose);
    await client.connect(Uri.parse('wss://arena.example'));
    expect(client.connected, isFalse);
    channel.receive({'type': 'connected', 'protocolVersion': 4});
    await flush();
    final registration = channel.sent.single;
    expect(registration['type'], 'register_player');
    expect(registration['name'], 'Nova Knight');
    expect(registration['level'], 'advanced');
    channel.receive({
      'type': 'player_registered',
      'commandId': registration['commandId'],
      'name': 'Nova Knight',
      'avatarId': 'mage',
      'level': 'advanced',
      'playerToken': 'player-secret',
    });
    await flush();
    expect(client.connected, isTrue);
    expect(client.profile!.playerToken, 'player-secret');
    client.updateProfile(
      name: 'Nova Knight',
      avatarId: 'robot',
      level: OnlinePlayerLevel.beginner,
    );
    final update = channel.sent.last;
    expect(update['type'], 'update_player');
    expect(update['level'], 'beginner');
    channel.receive({
      'type': 'player_updated',
      'commandId': update['commandId'],
      'name': 'Nova Knight',
      'avatarId': 'robot',
      'level': 'beginner',
      'playerToken': 'player-secret',
    });
    await flush();
    expect(client.profile!.avatarId, 'robot');
    expect(client.profile!.level, OnlinePlayerLevel.beginner);
    expect(
      channel.sent.skip(1).map((frame) => frame['type']),
      containsAll([
        'leaderboard',
        'points_history',
        'list_invites',
        'list_games',
      ]),
    );
    client.findPlayer('Moon Mage');
    expect(channel.sent.last, {'type': 'find_player', 'query': 'Moon Mage'});
    channel.receive({
      'type': 'player_found',
      'player': {
        'name': 'Moon Mage',
        'avatarId': 'moon',
        'level': 'intermediate',
        'online': true,
      },
    });
    channel.receive({
      'type': 'points_history',
      'matches': [
        {
          'recordId': 'record-one',
          'gameId': 'finished-one',
          'opponentName': 'Moon Mage',
          'opponentAvatarId': 'moon',
          'result': 'win',
          'points': 3,
          'completedAt': 1000,
        },
      ],
    });
    channel.receive({
      'type': 'active_games',
      'games': [
        {
          'gameId': 'active-one',
          'seat': 'w',
          'seatToken': 'active-secret',
          'state': stateJson(gameId: 'active-one'),
        },
      ],
    });
    channel.receive({
      'type': 'presence',
      'statuses': [
        {'name': 'Moon Mage', 'online': true},
      ],
    });
    channel.receive({
      'type': 'invites',
      'invites': [
        {
          'inviteId': 'invite-one',
          'sender': {'name': 'Moon Mage', 'avatarId': 'moon'},
          'recipient': {'name': 'Nova Knight', 'avatarId': 'mage'},
          'scheduledAt': null,
          'createdAt': 1,
          'status': 'pending',
          'awaitingResponseFromName': 'Nova Knight',
        },
      ],
    });
    await flush();
    expect(client.presence['Moon Mage'], isTrue);
    expect(client.invitations.single.senderName, 'Moon Mage');
    expect(client.invitations.single.canRespondBy('Nova Knight'), isTrue);
    expect(client.playerSearchResult!.name, 'Moon Mage');
    expect(client.pointHistory.single.points, 3);
    expect(client.activeGames.single.gameId, 'active-one');
    expect(client.pointHistory.single.recordId, 'record-one');
    expect(client.activeGamesLoaded, isTrue);
    client.loadActiveGames();
    expect(client.activeGamesLoaded, isFalse);
    expect(client.activeGames, isEmpty);
    expect(channel.sent.last['type'], 'list_games');
    client.deleteInvitation('invite-one');
    expect(channel.sent.last['type'], 'delete_invite');
    expect(client.invitations, isEmpty);
    client.proposeInvitationTime(
      'invite-one',
      DateTime.fromMillisecondsSinceEpoch(5000),
      baseMs: 1800000,
      clockMode: 'live',
    );
    expect(channel.sent.last['type'], 'propose_invite_time');
  });

  test(
    'credits capability restores and refreshes a server-owned account',
    () async {
      final channel = FakeChannel();
      final client = OnlineMatchClient(
        channelFactory: (_) => channel,
        profile: const OnlinePlayerProfile(
          name: 'Credit Knight',
          avatarId: 'avatar-01',
        ),
      );
      addTearDown(client.dispose);
      await client.connect(Uri.parse('wss://arena.example'));
      channel.receive({
        'type': 'connected',
        'protocolVersion': 4,
        'capabilities': ['credits'],
      });
      await flush();
      final registration = channel.sent.single;
      channel.receive({
        'type': 'player_registered',
        'commandId': registration['commandId'],
        'name': 'Credit Knight',
        'avatarId': 'avatar-01',
        'level': 'intermediate',
        'playerToken': 'credit-secret',
        'credits': 300,
        'bonusCredits': 300,
        'purchasedCredits': 0,
        'creditPolicy': creditPolicyJson(),
      });
      await flush();

      expect(client.supportsCredits, isTrue);
      expect(client.credits, 300);
      expect(client.creditPolicy.liveHumanRoundCost, 2);
      expect(client.creditPolicy.dailyAllowanceCap, 300);

      channel.receive({
        'type': 'credit_balance',
        'account': {
          'credits': 299,
          'bonusCredits': 249,
          'purchasedCredits': 50,
          'lifetimeEarned': 301,
          'lifetimeSpent': 2,
          'completionRewardsToday': 1,
          'nextDailyLoginAt': 86400000,
          'recentTransactions': [
            {
              'transactionId': 'reward-1',
              'delta': 1,
              'type': 'earn',
              'reason': 'completed_round',
              'createdAt': 1000,
              'gameId': 'room',
              'round': 1,
            },
          ],
        },
        'creditPolicy': creditPolicyJson(),
      });
      await flush();

      expect(client.credits, 299);
      expect(client.creditAccount!.lifetimeEarned, 301);
      expect(client.creditAccount!.bonusCredits, 249);
      expect(client.creditAccount!.purchasedCredits, 50);
      expect(client.creditAccount!.completionRewardsToday, 1);
      expect(client.creditAccount!.recentTransactions.single.delta, 1);

      // Setup/action acknowledgements carry an atomic balance summary too.
      channel.receive({
        'type': 'command_result',
        'commandId': 'unrelated-command',
        'accepted': true,
        'credits': 297,
        'bonusCredits': 247,
        'purchasedCredits': 50,
      });
      await flush();
      expect(client.credits, 297);
      expect(client.creditAccount!.lifetimeEarned, 301);
    },
  );

  test(
    'stale Firebase protocol reports both versions and disconnects',
    () async {
      final channel = FakeChannel();
      final client = OnlineMatchClient(channelFactory: (_) => channel);
      addTearDown(client.dispose);

      await client.connect(Uri.parse('wss://firebase-game.example.run.app'));
      channel.receive({'type': 'connected', 'protocolVersion': 3});
      await flush();
      await flush();

      expect(client.connection, MatchConnection.disconnected);
      expect(
        client.error,
        'Online play needs an app update. Install the latest version.',
      );
    },
  );

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
      expect(client.error, 'Online play returned an unexpected response');
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

  test('waiting quick match can switch to a built-in computer', () async {
    final channel = FakeChannel();
    final client = OnlineMatchClient(channelFactory: (_) => channel);
    addTearDown(client.dispose);
    await client.connect(Uri.parse('ws://localhost:8080'));
    client.quickMatch(baseMs: 180000);
    final quick = channel.sent.single;
    channel.receive({
      'type': 'matchmaking_waiting',
      'commandId': quick['commandId'],
      'gameId': 'quick-room',
      'seat': 'w',
      'seatToken': 'quick-secret',
      'state': stateJson(gameId: 'quick-room', status: 'waiting'),
    });
    await flush();
    client.startComputerGame('priya-nair', baseMs: 180000);
    final request = channel.sent.last;
    expect(request['type'], 'start_computer_game');
    expect(request['opponentId'], 'priya-nair');
    final state = stateJson(
      gameId: 'computer-room',
      blackName: 'Priya Nair',
      blackAvatar: 'bot_priya',
      blackComputer: true,
    );
    channel.receive({
      'type': 'computer_match_found',
      'commandId': request['commandId'],
      'gameId': 'computer-room',
      'seat': 'w',
      'seatToken': 'computer-secret',
      'state': state,
    });
    await flush();
    expect(client.searchingForOpponent, isFalse);
    expect(client.state!.blackPlayer.name, 'Priya Nair');
    expect(client.state!.blackPlayer.computer, isTrue);
  });
}
