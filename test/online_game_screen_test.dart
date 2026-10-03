import 'dart:convert';

import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/domain/online_player_profile.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/online/online_game_screen.dart';
import 'package:battle_chess_arena/src/features/online/online_avatar_image.dart';
import 'package:battle_chess_arena/src/features/online/online_lobby_screen.dart';
import 'package:battle_chess_arena/src/features/play/capture_battle_overlay.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:battle_chess_arena/src/services/online_match_client.dart';
import 'package:battle_chess_arena/src/services/online_game_history.dart';
import 'package:battle_chess_arena/src/services/arena_credit_controller.dart';
import 'package:battle_chess_arena/src/services/mobile_notifications.dart';
import 'package:battle_chess_arena/src/services/computer_player.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:battle_chess_arena/src/features/play/board_appearance.dart';
import 'support/game_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/online_fixtures.dart';

class _OnlineHintPlayer implements ComputerPlayer {
  int calls = 0;
  ComputerDifficulty? difficulty;

  @override
  Future<String?> bestMove(
    String fen, {
    ComputerDifficulty difficulty = ComputerDifficulty.medium,
    int? botLevel,
  }) async {
    calls++;
    this.difficulty = difficulty;
    return 'e2e4';
  }

  @override
  void dispose() {}
}

class _FakeMobileNotifications extends MobileNotificationService {
  _FakeMobileNotifications() : super(platform: TargetPlatform.android);

  final shown = <String>[];
  final scheduled = <String>[];

  @override
  bool get isSupported => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> show({
    required String id,
    required String title,
    required String body,
  }) async => shown.add(id);

  @override
  Future<void> schedule({
    required String id,
    required String title,
    required String body,
    required DateTime at,
  }) async => scheduled.add(id);

  @override
  Future<void> cancel(String id) async {}

  @override
  Future<void> cancelAll() async {}
}

Map<String, Object> _creditPolicyJson() => {
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
  testWidgets(
    'online setup hides transport details and offers avatar choices',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(home: OnlineLobbyScreen(pack: piecePacks.first)),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('WebSocket endpoint'), findsNothing);
      expect(find.textContaining('wss://'), findsNothing);
      expect(find.text('Create your online Avatar ID'), findsOneWidget);
      expect(find.byKey(const ValueKey('avatar-name-field')), findsOneWidget);
      expect(find.byKey(const ValueKey('human-avatar-picker')), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(
        find.byKey(const ValueKey('player-level-selector')),
        findsOneWidget,
      );
    },
  );

  testWidgets('first-time avatar Save action stays visible on a small phone', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: OnlineLobbyScreen(
          pack: piecePacks.first,
          endpoint: Uri.parse('wss://firebase-game.example.run.app'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final save = find.byKey(const ValueKey('enter-arena-button'));
    expect(save, findsOneWidget);
    expect(save.hitTestable(), findsOneWidget);
    expect(find.text('Save & Enter Arena'), findsOneWidget);
    expect(tester.getBottomRight(save).dy, lessThanOrEqualTo(568));
    expect(tester.takeException(), isNull);
  });

  testWidgets('online lobby reports the configured Firebase endpoint', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        home: OnlineLobbyScreen(
          pack: piecePacks.first,
          endpoint: Uri.parse('wss://firebase-game.example.run.app'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Play Online'), findsOneWidget);
    expect(find.text('Online play'), findsOneWidget);
    expect(find.text('Ready to connect.'), findsOneWidget);
    final enter = tester.widget<FilledButton>(
      find.byKey(const ValueKey('enter-arena-button')),
    );
    expect(enter.onPressed, isNotNull);
  });

  testWidgets('connected-player browser loads ten players at a time', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(500, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final channel = FakeChannel();
    final client = OnlineMatchClient(
      channelFactory: (_) => channel,
      profile: const OnlinePlayerProfile(
        name: 'List Viewer',
        avatarId: 'avatar-01',
      ),
    );
    await client.connect(Uri.parse('ws://localhost:8080'));
    channel.receive({
      'type': 'connected',
      'protocolVersion': 4,
      'capabilities': ['available_players'],
    });
    await tester.pump();
    final registration = channel.sent.single;
    channel.receive({
      'type': 'player_registered',
      'commandId': registration['commandId'],
      'name': 'List Viewer',
      'avatarId': 'avatar-01',
      'level': 'intermediate',
      'playerToken': 'list-viewer-token',
    });
    await tester.pumpWidget(
      MaterialApp(
        home: OnlineLobbyScreen(client: client, pack: piecePacks.first),
      ),
    );
    await tester.pump();
    final section = find.byKey(const ValueKey('find-opponent-section'));
    await tester.ensureVisible(section);
    await tester.tap(section);
    await tester.pump(const Duration(milliseconds: 300));
    final viewPlayers = find.byKey(const ValueKey('view-available-players'));
    tester.widget<OutlinedButton>(viewPlayers).onPressed!();
    final firstRequest = channel.sent.last;
    expect(firstRequest['type'], 'list_available_players');
    channel.receive({
      'type': 'available_players',
      'requestId': firstRequest['requestId'],
      'players': [
        for (var i = 0; i < 10; i++)
          {
            'name': 'Player $i',
            'avatarId': 'avatar-01',
            'level': 'intermediate',
            'online': true,
          },
      ],
      'nextCursor': 'cursor-10',
    });
    await tester.pump();
    expect(find.text('Player 0'), findsOneWidget);
    expect(find.text('Player 9'), findsOneWidget);
    final more = find.byKey(const ValueKey('show-more-players'));
    await tester.scrollUntilVisible(
      more,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    tester.widget<TextButton>(more).onPressed!();
    final secondRequest = channel.sent.last;
    expect(secondRequest['after'], 'cursor-10');
    channel.receive({
      'type': 'available_players',
      'requestId': secondRequest['requestId'],
      'players': [
        {
          'name': 'Player 10',
          'avatarId': 'avatar-01',
          'level': 'intermediate',
          'online': true,
        },
      ],
      'nextCursor': null,
    });
    await tester.pump();
    expect(find.text('Player 10'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    client.dispose();
  });

  testWidgets('legacy service invite defaults to a supported live clock', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(500, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final channel = FakeChannel();
    final client = OnlineMatchClient(
      channelFactory: (_) => channel,
      profile: const OnlinePlayerProfile(
        name: 'Invite Sender',
        avatarId: 'avatar-01',
      ),
    );
    await client.connect(Uri.parse('ws://localhost:8080'));
    channel.receive({'type': 'connected', 'protocolVersion': 4});
    await tester.pump();
    final registration = channel.sent.single;
    channel.receive({
      'type': 'player_registered',
      'commandId': registration['commandId'],
      'name': 'Invite Sender',
      'avatarId': 'avatar-01',
      'level': 'intermediate',
      'playerToken': 'invite-sender-token',
    });
    await tester.pump();
    client.findPlayer('Invite Target');
    channel.receive({
      'type': 'player_found',
      'player': {
        'name': 'Invite Target',
        'avatarId': 'avatar-02',
        'level': 'intermediate',
        'online': true,
      },
    });
    await tester.pumpWidget(
      MaterialApp(
        home: OnlineLobbyScreen(client: client, pack: piecePacks.first),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('find-opponent-section')));
    await tester.pump(const Duration(milliseconds: 300));
    final actions = find.descendant(
      of: find.byKey(const ValueKey('opponent-search-result')),
      matching: find.byType(PopupMenuButton<String>),
    );
    await tester.ensureVisible(actions);
    await tester.pump(const Duration(milliseconds: 300));
    tester.widget<PopupMenuButton<String>>(actions).onSelected!('now');
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('30 min · Classical'), findsOneWidget);
    final continueButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );
    expect(continueButton.onPressed, isNotNull);
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pump(const Duration(milliseconds: 300));
    final invitation = channel.sent.last;
    expect(invitation['type'], 'send_invite');
    expect(invitation['opponentName'], 'Invite Target');
    expect(invitation['baseMs'], 1800000);
    expect(invitation.containsKey('clockMode'), isFalse);
    expect(invitation.containsKey('incrementMs'), isFalse);
    await tester.pumpWidget(const SizedBox());
    client.dispose();
  });

  testWidgets(
    'saved players are grouped at the bottom with status and controls',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'online_favorites_v1': jsonEncode([
          {
            'name': 'Circle Pro',
            'avatarId': 'avatar-02',
            'circle': 'professionals',
          },
        ]),
      });
      await tester.binding.setSurfaceSize(const Size(500, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final channel = FakeChannel();
      final client = OnlineMatchClient(
        channelFactory: (_) => channel,
        profile: const OnlinePlayerProfile(
          name: 'Circle Owner',
          avatarId: 'avatar-01',
        ),
      );
      await client.connect(Uri.parse('ws://localhost:8080'));
      channel.receive({'type': 'connected', 'protocolVersion': 4});
      await tester.pump();
      final registration = channel.sent.single;
      channel.receive({
        'type': 'player_registered',
        'commandId': registration['commandId'],
        'name': 'Circle Owner',
        'avatarId': 'avatar-01',
        'level': 'intermediate',
        'playerToken': 'circle-owner-token',
      });
      await tester.pumpWidget(
        MaterialApp(
          home: OnlineLobbyScreen(client: client, pack: piecePacks.first),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        (await OnlineGameHistory.loadFavorites()).single.circle,
        OnlinePlayerCircle.professionals,
      );

      final connections = find.byKey(
        const ValueKey('player-connections-section'),
      );
      await tester.ensureVisible(connections);
      await tester.tap(connections);
      await tester.pump(const Duration(milliseconds: 400));
      final presenceRequest = channel.sent.lastWhere(
        (frame) => frame['type'] == 'presence',
      );
      expect(presenceRequest['names'], ['Circle Pro']);
      channel.receive({
        'type': 'presence',
        'statuses': [
          {'name': 'Circle Pro', 'online': true},
        ],
      });
      await tester.pump();

      final professionals = find.byKey(
        const ValueKey('connections-professionals'),
      );
      expect(professionals, findsOneWidget);
      final tile = find.byKey(
        const ValueKey('connection-professionals-Circle Pro'),
      );
      expect(tile, findsOneWidget);
      expect(
        find.descendant(of: tile, matching: find.text('Online')),
        findsOneWidget,
      );
      expect(find.byTooltip('Invite Circle Pro'), findsOneWidget);

      final manageMenu = find.descendant(
        of: tile,
        matching: find.byType(PopupMenuButton<String>),
      );
      final menu = tester.widget<PopupMenuButton<String>>(manageMenu);
      final entries = menu.itemBuilder(tester.element(manageMenu));
      expect(
        entries.whereType<PopupMenuItem<String>>().map((item) => item.value),
        contains('remove'),
      );
      await tester.pumpWidget(const SizedBox());
      client.dispose();
    },
  );

  testWidgets('online lobby explains the authoritative credit balance', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final channel = FakeChannel();
    final client = OnlineMatchClient(
      channelFactory: (_) => channel,
      profile: const OnlinePlayerProfile(
        name: 'Credit Viewer',
        avatarId: 'avatar-01',
      ),
    );
    await client.connect(Uri.parse('ws://localhost:8080'));
    channel.receive({
      'type': 'connected',
      'protocolVersion': 4,
      'capabilities': ['credits'],
    });
    await tester.pump();
    final registration = channel.sent.single;
    channel.receive({
      'type': 'player_registered',
      'commandId': registration['commandId'],
      'name': 'Credit Viewer',
      'avatarId': 'avatar-01',
      'level': 'intermediate',
      'playerToken': 'credit-viewer-token',
      'credits': 300,
      'bonusCredits': 300,
      'purchasedCredits': 0,
      'creditPolicy': _creditPolicyJson(),
    });
    await tester.pump();
    final creditHeader = ArenaCreditController();
    await tester.pumpWidget(
      MaterialApp(
        home: ArenaCreditScope(
          controller: creditHeader,
          child: OnlineLobbyScreen(client: client, pack: piecePacks.first),
        ),
      ),
    );
    await tester.pump();

    expect(creditHeader.credits, 300);
    expect(creditHeader.isLive, isTrue);
    expect(find.byKey(const ValueKey('online-credits-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('credit-balance-chip')), findsNothing);
    expect(find.text('300 Credits'), findsOneWidget);
    expect(find.textContaining('Live match 2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('online-credits-balance')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('WHAT USES CREDITS'), findsOneWidget);
    expect(find.text('Live game with a real player'), findsOneWidget);
    expect(find.text('Online move suggestion'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('The rest of the game stays free'),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('online-credits-explanation')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('The rest of the game stays free'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('credit-packs-coming-soon')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('online-credits-explanation')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Credit packs · Coming later'), findsOneWidget);
    expect(
      find.textContaining('secure App Store or Google Play'),
      findsOneWidget,
    );

    channel.receive({
      'type': 'credit_balance',
      'account': {
        'credits': 297,
        'bonusCredits': 247,
        'purchasedCredits': 50,
        'lifetimeEarned': 300,
        'lifetimeSpent': 3,
        'completionRewardsToday': 0,
        'nextDailyLoginAt': 86400000,
        'recentTransactions': [
          {
            'transactionId': 'round:room:1:player',
            'delta': -3,
            'type': 'round_fee',
            'reason': 'daily_human_round',
            'createdAt': DateTime.now().millisecondsSinceEpoch,
            'gameId': 'room',
            'round': 1,
          },
        ],
      },
      'creditPolicy': _creditPolicyJson(),
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(client.credits, 297);
    expect(creditHeader.credits, 297);
    expect(find.byKey(const ValueKey('credit-spend-feedback')), findsOneWidget);
    expect(find.text('3 credits used · Daily player round'), findsOneWidget);
    await tester.tap(find.byTooltip('Close credits'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('297 Credits'), findsOneWidget);

    channel.receive({
      'type': 'credit_balance',
      'account': {
        'credits': 298,
        'bonusCredits': 248,
        'purchasedCredits': 50,
        'lifetimeEarned': 301,
        'lifetimeSpent': 3,
        'completionRewardsToday': 1,
        'nextDailyLoginAt': 86400000,
        'recentTransactions': [
          {
            'transactionId': 'completion:room:1:player',
            'delta': 1,
            'type': 'completion_reward',
            'reason': 'meaningful_round_completed',
            'createdAt': DateTime.now().millisecondsSinceEpoch,
            'gameId': 'room',
            'round': 1,
          },
        ],
      },
      'creditPolicy': _creditPolicyJson(),
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(creditHeader.lastChange?.delta, 1);
    expect(
      find.byKey(const ValueKey('credit-reward-feedback')),
      findsOneWidget,
    );
    expect(find.textContaining('Congratulations! +1 credit'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    creditHeader.dispose();
    client.dispose();
    await tester.pump();
  });

  testWidgets('leaderboard uses live totals and never crowns a lone player', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(500, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final channel = FakeChannel();
    final client = OnlineMatchClient(
      channelFactory: (_) => channel,
      profile: const OnlinePlayerProfile(
        name: 'Solo Tester',
        avatarId: 'avatar-01',
      ),
    );
    await client.connect(Uri.parse('ws://localhost:8080'));
    channel.receive({'type': 'connected', 'protocolVersion': 4});
    await tester.pump();
    final registration = channel.sent.first;
    channel.receive({
      'type': 'player_registered',
      'commandId': registration['commandId'],
      'name': 'Solo Tester',
      'avatarId': 'avatar-01',
      'level': 'intermediate',
      'playerToken': 'solo-token',
    });
    await tester.pump();
    channel.receive({
      'type': 'leaderboard',
      'leaders': [
        {
          'name': 'Solo Tester',
          'avatarId': 'avatar-01',
          'level': 'intermediate',
          'points': 0,
          'wins': 0,
          'draws': 0,
          'losses': 0,
        },
      ],
    });
    channel.receive({'type': 'points_history', 'matches': []});
    await tester.pumpWidget(
      MaterialApp(
        home: OnlineLobbyScreen(client: client, pack: piecePacks.first),
      ),
    );
    await tester.pump();

    final open = find.widgetWithText(FilledButton, 'View leaderboard');
    await tester.ensureVisible(open);
    await tester.tap(open);
    await tester.pump();
    channel.receive({
      'type': 'leaderboard',
      'leaders': [
        {
          'name': 'Solo Tester',
          'avatarId': 'avatar-01',
          'level': 'intermediate',
          'points': 0,
          'wins': 0,
          'draws': 0,
          'losses': 0,
        },
      ],
    });
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.text('0 completed online games · 0W · 0D · 0L'),
      findsOneWidget,
    );
    expect(find.textContaining('Win 3'), findsNothing);
    expect(find.textContaining('only ranked player'), findsWidgets);
    expect(find.textContaining('topper'), findsNothing);
    expect(find.textContaining('No other ranked players'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    client.dispose();
    await tester.pump();
  });

  testWidgets('mobile option notifies for invites and schedules game alerts', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'online_mobile_notifications_v1': true,
    });
    final channel = FakeChannel();
    final client = OnlineMatchClient(channelFactory: (_) => channel)
      ..setProfile(
        const OnlinePlayerProfile(name: 'Notify Player', avatarId: 'avatar-01'),
      );
    final notifications = _FakeMobileNotifications();
    await client.connect(Uri.parse('ws://localhost:8080'));
    await tester.pumpWidget(
      MaterialApp(
        home: OnlineLobbyScreen(
          client: client,
          pack: piecePacks.first,
          notifications: notifications,
        ),
      ),
    );
    await tester.pump();
    final scheduledAt = DateTime.now().add(const Duration(hours: 1));
    channel.receive({
      'type': 'invites',
      'invites': [
        {
          'inviteId': 'notify-me',
          'sender': {'name': 'Challenger', 'avatarId': 'avatar-02'},
          'recipient': {'name': 'Notify Player', 'avatarId': 'avatar-01'},
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'status': 'pending',
          'awaitingResponseFromName': 'Notify Player',
          'scheduledAt': scheduledAt.millisecondsSinceEpoch,
        },
      ],
    });
    await tester.pump();
    await tester.pump();
    expect(notifications.shown, contains('invite:notify-me'));
    expect(
      notifications.scheduled,
      containsAll(['scheduled-soon:notify-me', 'scheduled-start:notify-me']),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('mobile-notifications-toggle')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const ValueKey('mobile-notifications-toggle')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    client.dispose();
  });

  testWidgets(
    'edit profile shows large portraits and saves the new selection on a narrow phone',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final channel = FakeChannel();
      final client = OnlineMatchClient(channelFactory: (_) => channel);
      await client.connect(Uri.parse('ws://localhost:8080'));
      client.setProfile(
        const OnlinePlayerProfile(name: 'Avatar Tester', avatarId: 'avatar-01'),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: OnlineLobbyScreen(client: client, pack: piecePacks.first),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(find.byTooltip('Edit Avatar ID and image'));
      await tester.tap(find.byTooltip('Edit Avatar ID and image'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Edit online profile'), findsOneWidget);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('selected-avatar-preview')))
            .width,
        120,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('avatar-avatar-02')),
      );
      await tester.tap(find.byKey(const ValueKey('avatar-avatar-02')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester
            .widget<OnlineAvatarImage>(
              find.byKey(const ValueKey('selected-avatar-preview')),
            )
            .avatarId,
        'avatar-02',
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Save'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(channel.sent.last['type'], 'update_player');
      expect(channel.sent.last['avatarId'], 'avatar-02');
      await tester.pumpWidget(const SizedBox());
      client.dispose();
    },
  );

  Future<OnlineMatchClient> showGame(
    WidgetTester tester,
    FakeChannel channel, {
    String seat = 'w',
    GameSession? game,
    Size size = const Size(400, 900),
    ComputerPlayer? computerPlayer,
    bool blackComputer = false,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final client = OnlineMatchClient(channelFactory: (_) => channel);
    await client.connect(Uri.parse('ws://localhost:8080'));
    channel.seat(
      seat: seat,
      state: stateJson(game: game, blackComputer: blackComputer),
    );
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        home: OnlineGameScreen(
          client: client,
          pack: piecePacks.first,
          computerPlayer: computerPlayer,
        ),
      ),
    );
    return client;
  }

  testWidgets('landscape keeps the complete board beside match controls', (
    tester,
  ) async {
    final channel = FakeChannel();
    final client = await showGame(tester, channel, size: const Size(650, 360));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('landscape-online-layout')),
      findsOneWidget,
    );
    final board = tester.getRect(find.byType(ChessBoard));
    expect(board.width, closeTo(board.height, .1));
    expect(board.left, greaterThanOrEqualTo(0));
    expect(board.top, greaterThanOrEqualTo(0));
    expect(board.right, lessThanOrEqualTo(650));
    expect(board.bottom, lessThanOrEqualTo(360));
    expect(
      find.byKey(const ValueKey('online-opponent-profile')),
      findsOneWidget,
    );
    expect(find.text('Black Hero'), findsOneWidget);
    await tester.tap(find.byTooltip('Hide top bar'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Show top bar'), findsOneWidget);
    final expandedBoard = tester.getRect(find.byType(ChessBoard));
    expect(expandedBoard.height, greaterThan(board.height));
    expect(expandedBoard.bottom, lessThanOrEqualTo(360));
    await openGameSettings(tester, target: find.text('Capture battles'));
    expect(find.text('Capture battles'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    client.dispose();
  });

  testWidgets('board waits for authoritative commit and shows legal targets', (
    tester,
  ) async {
    final channel = FakeChannel();
    final client = await showGame(tester, channel);
    await tester.tap(find.byKey(const ValueKey('square-e2')));
    await tester.pump();
    expect(
      tester.widget<ChessBoard>(find.byType(ChessBoard)).legalTargets,
      contains(Square.e4),
    );
    await tester.tap(find.byKey(const ValueKey('square-e4')));
    await tester.pump();
    expect(channel.sent.last['type'], 'move');
    expect(client.state!.san, isEmpty);
    expect(find.byType(CaptureBattleOverlay), findsNothing);
    final game = GameSession()..playUci('e2e4');
    channel.receive({
      'type': 'game_state',
      'state': stateJson(game: game, sequence: 2),
    });
    await tester.pump();
    expect(
      tester
          .widget<ChessBoard>(find.byType(ChessBoard))
          .position
          .board
          .pieceAt(Square.e4)
          ?.role,
      Role.pawn,
    );
    await tester.pumpWidget(const SizedBox());
    client.dispose();
  });

  testWidgets('online lifeline is authoritative and clears on tap or timeout', (
    tester,
  ) async {
    final channel = FakeChannel();
    final hintPlayer = _OnlineHintPlayer();
    final client = await showGame(
      tester,
      channel,
      computerPlayer: hintPlayer,
      blackComputer: true,
    );
    final button = find.byKey(const ValueKey('use-online-computer-lifeline'));
    await tester.scrollUntilVisible(
      button,
      150,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pump();
    final request = channel.sent.last;
    expect(request['type'], 'use_lifeline');

    channel.receive({
      'type': 'game_state',
      'state': stateJson(
        sequence: 2,
        blackComputer: true,
        whiteLifelines: 2,
        whiteLifelineRequests: 1,
      ),
    });
    channel.receive({
      'type': 'command_result',
      'commandId': request['commandId'],
      'accepted': true,
    });
    await tester.pump();
    expect(hintPlayer.calls, 1);
    expect(hintPlayer.difficulty, suggestionDifficulty);
    var board = tester.widget<ChessBoard>(find.byType(ChessBoard));
    expect(board.suggestedFrom, Square.e2);
    expect(board.suggestedTo, Square.e4);
    expect(find.text('Suggest move'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('square-a2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('square-a2')));
    await tester.pump();
    board = tester.widget<ChessBoard>(find.byType(ChessBoard));
    expect(board.suggestedFrom, isNull);
    expect(board.suggestedTo, isNull);

    final sentCount = channel.sent.length;
    await tester.scrollUntilVisible(
      button,
      150,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pump();
    expect(channel.sent.length, sentCount + 1);
    final secondRequest = channel.sent.last;
    expect(secondRequest['type'], 'use_lifeline');

    channel.receive({
      'type': 'game_state',
      'state': stateJson(
        sequence: 3,
        blackComputer: true,
        whiteLifelines: 1,
        whiteLifelineRequests: 2,
      ),
    });
    channel.receive({
      'type': 'command_result',
      'commandId': secondRequest['commandId'],
      'accepted': true,
    });
    await tester.pump();
    expect(hintPlayer.calls, 1);
    expect(find.text('Suggest move'), findsOneWidget);
    expect(
      tester.widget<ChessBoard>(find.byType(ChessBoard)).suggestedTo,
      Square.e4,
    );
    expect(
      find.byKey(const ValueKey('online-suggestion-credit-cost')),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 10));
    expect(
      tester.widget<ChessBoard>(find.byType(ChessBoard)).suggestedTo,
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
    client.dispose();
  });

  testWidgets('move suggestions stay hidden against a real online opponent', (
    tester,
  ) async {
    final channel = FakeChannel();
    final client = await showGame(tester, channel);
    expect(
      find.byKey(const ValueKey('online-computer-lifelines')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('use-online-computer-lifeline')),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox());
    client.dispose();
  });

  testWidgets(
    'opponent move is highlighted and quick piece style can be toggled',
    (tester) async {
      final channel = FakeChannel();
      final client = await showGame(tester, channel);
      final game = GameSession()..playUci('e2e4');

      channel.receive({
        'type': 'game_state',
        'state': stateJson(game: game, sequence: 2),
      });
      await tester.pump();
      expect(find.text('OPPONENT’S TURN · PLEASE WAIT'), findsOneWidget);
      game.playUci('e7e5');
      channel.receive({
        'type': 'game_state',
        'state': stateJson(game: game, sequence: 3),
      });
      await tester.pump();

      var board = tester.widget<ChessBoard>(find.byType(ChessBoard));
      expect(board.lastMoveFrom, Square.e7);
      expect(board.lastMoveTo, Square.e5);
      expect(find.text('YOUR TURN · PLAY NOW'), findsOneWidget);

      final toggle = find.byKey(
        const ValueKey('online-quick-piece-style-toggle'),
      );
      expect(find.text('Game settings'), findsNothing);
      await tester.tap(toggle);
      await tester.pump();
      board = tester.widget<ChessBoard>(find.byType(ChessBoard));
      expect(board.appearance?.white.id, PiecePackId.anime);
      expect(board.appearance?.black.id, PiecePackId.anime);
      expect(board.appearance?.standardPieces, isTrue);
      expect(find.byTooltip('Use themed character pieces'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          home: OnlineGameScreen(client: client, pack: piecePacks.first),
        ),
      );
      await tester.pump();
      board = tester.widget<ChessBoard>(find.byType(ChessBoard));
      expect(board.lastMoveFrom, Square.e7);
      expect(board.lastMoveTo, Square.e5);
      await tester.pumpWidget(const SizedBox());
      client.dispose();
    },
  );

  testWidgets(
    'black is at bottom and cannot move white pieces or out of turn',
    (tester) async {
      final channel = FakeChannel();
      final client = await showGame(tester, channel, seat: 'b');
      expect(
        tester.widget<ChessBoard>(find.byType(ChessBoard)).orientation,
        Side.black,
      );
      expect(
        tester.getCenter(find.byKey(const ValueKey('square-e8'))).dy,
        greaterThan(
          tester.getCenter(find.byKey(const ValueKey('square-e1'))).dy,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('square-e7')));
      await tester.pump();
      expect(
        tester.widget<ChessBoard>(find.byType(ChessBoard)).selected,
        isNull,
      );
      final game = GameSession()..playUci('e2e4');
      channel.receive({
        'type': 'game_state',
        'state': stateJson(game: game, sequence: 2),
      });
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('square-d2')));
      await tester.pump();
      expect(
        tester.widget<ChessBoard>(find.byType(ChessBoard)).selected,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('square-e7')));
      await tester.pump();
      expect(
        tester.widget<ChessBoard>(find.byType(ChessBoard)).legalTargets,
        contains(Square.e5),
      );
      await tester.pumpWidget(const SizedBox());
      client.dispose();
    },
  );

  testWidgets('promotion dialog sends the selected knight without committing', (
    tester,
  ) async {
    final channel = FakeChannel();
    final game = GameSession(
      position: Chess.fromSetup(Setup.parseFen('7k/P7/8/8/8/8/8/7K w - - 0 1')),
    );
    final client = await showGame(tester, channel, game: game);
    await tester.tap(find.byKey(const ValueKey('square-a7')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('square-a8')));
    await tester.pumpAndSettle();
    expect(channel.sent, isEmpty);
    await tester.tap(find.byTooltip('knight'));
    await tester.pumpAndSettle();
    expect((channel.sent.last['move'] as Map)['promotion'], 'n');
    expect(client.state!.position.board.pieceAt(Square.a7)?.role, Role.pawn);
    await tester.pumpWidget(const SizedBox());
    client.dispose();
  });

  testWidgets(
    'committed pawn capture renders character art, skip and duplicate safety',
    (tester) async {
      final channel = FakeChannel();
      final game = GameSession()
        ..playUci('e2e4')
        ..playUci('d7d5');
      final client = await showGame(tester, channel, game: game);
      await tester.tap(find.byKey(const ValueKey('square-e4')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('square-d5')));
      await tester.pump();
      expect(find.byType(CaptureBattleOverlay), findsNothing);
      game.playUci('e4d5');
      final frame = {
        'type': 'game_state',
        'state': stateJson(game: game, sequence: 2),
      };
      channel.receive(frame);
      await tester.pump();
      expect(find.byType(CaptureBattleOverlay), findsOneWidget);
      expect(
        tester
            .widget<CaptureBattleOverlay>(find.byType(CaptureBattleOverlay))
            .useCharacterAsset,
        isTrue,
      );
      expect(
        find.descendant(
          of: find.byType(CaptureBattleOverlay),
          matching: find.byType(CharacterPiece),
        ),
        findsNWidgets(2),
      );
      final sequence = client.state!.sequence;
      await tester.tap(find.text('Skip'));
      await tester.pump();
      expect(find.byType(CaptureBattleOverlay), findsNothing);
      expect(client.state!.sequence, sequence);
      channel.receive(frame);
      await tester.pump();
      expect(find.byType(CaptureBattleOverlay), findsNothing);
      await tester.pumpWidget(const SizedBox());
      client.dispose();
    },
  );

  testWidgets('back-to-back online capture cinematics keep a two-second gap', (
    tester,
  ) async {
    final channel = FakeChannel();
    final game = GameSession()
      ..playUci('e2e4')
      ..playUci('d7d5');
    final client = await showGame(tester, channel, game: game);
    game.playUci('e4d5');
    channel.receive({
      'type': 'game_state',
      'state': stateJson(game: game, sequence: 2),
    });
    await tester.pump();
    expect(
      tester
          .widget<CaptureBattleOverlay>(find.byType(CaptureBattleOverlay))
          .battle
          .move
          .from,
      Square.e4,
    );

    game.playUci('d8d5');
    channel.receive({
      'type': 'game_state',
      'state': stateJson(game: game, sequence: 3),
    });
    await tester.pump();
    expect(
      tester
          .widget<CaptureBattleOverlay>(find.byType(CaptureBattleOverlay))
          .battle
          .move
          .from,
      Square.e4,
    );
    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(find.byType(CaptureBattleOverlay), findsNothing);
    await tester.pump(const Duration(milliseconds: 1999));
    expect(find.byType(CaptureBattleOverlay), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    expect(
      tester
          .widget<CaptureBattleOverlay>(find.byType(CaptureBattleOverlay))
          .battle
          .move
          .from,
      Square.d8,
    );
    await tester.pumpWidget(const SizedBox());
    client.dispose();
  });

  testWidgets('disconnect disables board input and shows recovery UI', (
    tester,
  ) async {
    final channel = FakeChannel();
    final client = await showGame(tester, channel);
    client.disconnect();
    await tester.pump();
    expect(find.byKey(const ValueKey('connection-status')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('square-e2')));
    await tester.pump();
    expect(tester.widget<ChessBoard>(find.byType(ChessBoard)).selected, isNull);
    expect(channel.sent, isEmpty);
    await tester.pumpWidget(const SizedBox());
    client.dispose();
  });

  testWidgets('system reduced motion selects fade renderer', (tester) async {
    final channel = FakeChannel();
    final game = GameSession()
      ..playUci('e2e4')
      ..playUci('d7d5');
    final client = await showGame(tester, channel, game: game);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: OnlineGameScreen(client: client, pack: piecePacks.first),
        ),
      ),
    );
    game.playUci('e4d5');
    channel.receive({
      'type': 'game_state',
      'state': stateJson(game: game, sequence: 2),
    });
    await tester.pump();
    expect(
      tester
          .widget<CaptureBattleOverlay>(find.byType(CaptureBattleOverlay))
          .reduced,
      isTrue,
    );
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(CaptureBattleOverlay), findsNothing);
    await tester.pumpWidget(const SizedBox());
    client.dispose();
  });
  testWidgets('lobby opens the board when the second player joins', (
    tester,
  ) async {
    final channel = FakeChannel();
    final client = OnlineMatchClient(channelFactory: (_) => channel);
    await client.connect(Uri.parse('ws://localhost:8080'));
    await tester.pumpWidget(
      MaterialApp(
        home: OnlineLobbyScreen(client: client, pack: piecePacks.first),
      ),
    );
    channel.seat(state: stateJson(status: 'waiting'));
    await tester.pump();
    expect(find.byType(OnlineGameScreen), findsNothing);
    channel.receive({'type': 'game_state', 'state': stateJson(sequence: 2)});
    await tester.pumpAndSettle();
    expect(find.byType(OnlineGameScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    client.dispose();
  });

  testWidgets('lobby starts and cancels quick matchmaking', (tester) async {
    final channel = FakeChannel();
    final client = OnlineMatchClient(channelFactory: (_) => channel);
    await client.connect(Uri.parse('ws://localhost:8080'));
    await tester.pumpWidget(
      MaterialApp(
        home: OnlineLobbyScreen(client: client, pack: piecePacks.first),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('quick-match-button')));
    await tester.pump();
    final quick = channel.sent.single;
    channel.receive({
      'type': 'matchmaking_waiting',
      'commandId': quick['commandId'],
      'gameId': 'quick-room',
      'seat': 'w',
      'seatToken': 'quick-secret',
      'state': stateJson(gameId: 'quick-room', status: 'waiting'),
    });
    await tester.pump();
    expect(find.byKey(const ValueKey('matchmaking-waiting')), findsOneWidget);
    await tester.ensureVisible(find.text('Cancel search'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Cancel search'));
    expect(channel.sent.last['type'], 'cancel_matchmaking');
    await tester.pumpWidget(const SizedBox());
    client.dispose();
  });

  testWidgets(
    'WhatsApp invitation shares Avatar instructions without creating a room',
    (tester) async {
      final channel = FakeChannel();
      final client = OnlineMatchClient(channelFactory: (_) => channel);
      await client.connect(Uri.parse('ws://localhost:8080'));
      client.setProfile(
        const OnlinePlayerProfile(
          name: 'Amina Player',
          avatarId: 'avatar-01',
          level: OnlinePlayerLevel.beginner,
        ),
      );
      Uri? launched;
      await tester.pumpWidget(
        MaterialApp(
          home: OnlineLobbyScreen(
            client: client,
            pack: piecePacks.first,
            launchExternal: (uri) async {
              launched = uri;
              return true;
            },
          ),
        ),
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('invite-via-whatsapp')),
      );
      await tester.tap(find.byKey(const ValueKey('invite-via-whatsapp')));
      await tester.pump();
      expect(
        channel.sent.where((frame) => frame['type'] == 'create_game'),
        isEmpty,
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(launched?.host, 'wa.me');
      final message = launched?.queryParameters['text'] ?? '';
      expect(message, contains('Amina Player'));
      expect(message, contains('search for my Avatar name'));
      expect(message, contains('send me an invite'));
      expect(message, isNot(contains('battlechessarena://')));
      await tester.pumpWidget(const SizedBox());
      client.dispose();
    },
  );

  testWidgets(
    'WhatsApp shares a revocable HTTPS link with fallback and deletion',
    (tester) async {
      final channel = FakeChannel();
      final client = OnlineMatchClient(channelFactory: (_) => channel);
      await client.connect(
        Uri.parse('wss://battle-chess-arena-firebase-jdth6ggixa-el.a.run.app'),
      );
      client.supportsSharedInvites = true;
      client.supportsInviteClocks = true;
      client.supportsDailyGames = true;
      client.setProfile(
        const OnlinePlayerProfile(name: 'Nova Friend', avatarId: 'avatar-01'),
      );
      channel.receive({'type': 'active_games', 'games': []});
      Uri? launched;
      await tester.pumpWidget(
        MaterialApp(
          home: OnlineLobbyScreen(
            client: client,
            pack: piecePacks.first,
            launchExternal: (uri) async {
              launched = uri;
              return true;
            },
          ),
        ),
      );
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const ValueKey('invite-via-whatsapp')),
      );
      await tester.tap(find.byKey(const ValueKey('invite-via-whatsapp')));
      await tester.pump();
      expect(find.text('Daily · 24 hours per move'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pump();
      final create = channel.sent.lastWhere(
        (frame) => frame['type'] == 'create_shared_invite',
      );
      expect(create['clockMode'], 'daily');
      expect(create['baseMs'], 86400000);
      expect(create['incrementMs'], 0);
      expect(client.gameId, isNull);
      final invite = {
        'inviteId': 'share_1234',
        'avatarName': 'Nova Friend',
        'status': 'pending',
        'expiresAt': DateTime.now()
            .add(const Duration(hours: 24))
            .millisecondsSinceEpoch,
      };
      channel.receive({
        'type': 'shared_invite_created',
        'commandId': create['commandId'],
        'invite': invite,
      });
      await tester.pumpAndSettle();
      final text = launched!.queryParameters['text']!;
      expect(
        text,
        contains(
          'https://battle-chess-arena-firebase-jdth6ggixa-el.a.run.app/invite/share_1234',
        ),
      );
      expect(text, contains('If the link does not open'));
      expect(text, contains('search for my Avatar name "Nova Friend"'));
      expect(text, contains('expires 24 hours'));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('delete-shared-invite-share_1234')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(
        find.byKey(const ValueKey('delete-shared-invite-share_1234')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Delete invitation link?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(channel.sent.last['type'], 'delete_shared_invite');
      channel.receive({
        'type': 'shared_invite_updated',
        'invite': {...invite, 'status': 'deleted'},
      });
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('shared-invite-share_1234')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
      client.dispose();
    },
  );

  for (final status in ['deleted', 'expired']) {
    testWidgets('opening a $status shared invitation shows the server message', (
      tester,
    ) async {
      final channel = FakeChannel();
      final client = OnlineMatchClient(channelFactory: (_) => channel);
      await client.connect(Uri.parse('ws://localhost:8080'));
      client.supportsSharedInvites = true;
      client.setProfile(
        const OnlinePlayerProfile(name: 'Friend Name', avatarId: 'avatar-01'),
      );
      channel.receive({'type': 'active_games', 'games': []});
      await tester.pumpWidget(
        MaterialApp(
          home: OnlineLobbyScreen(
            client: client,
            pack: piecePacks.first,
            initialSharedInviteId: 'share_1234',
          ),
        ),
      );
      await tester.pump();
      final open = channel.sent.lastWhere(
        (frame) => frame['type'] == 'open_shared_invite',
      );
      final message =
          'This invitation has $status. Ask your friend to send a new invite.';
      channel.receive({
        'type': 'error',
        'commandId': open['commandId'],
        'code': 'INVITE_${status.toUpperCase()}',
        'message': message,
      });
      await tester.pumpAndSettle();
      expect(find.text(message), findsOneWidget);
      expect(client.gameId, isNull);
      expect(find.byType(OnlineGameScreen), findsNothing);
      await tester.pumpWidget(const SizedBox());
      client.dispose();
    });
  }

  testWidgets('shared app link joins its game automatically', (tester) async {
    final channel = FakeChannel();
    final client = OnlineMatchClient(channelFactory: (_) => channel);
    await client.connect(Uri.parse('ws://localhost:8080'));
    client.setProfile(
      const OnlinePlayerProfile(
        name: 'Joining Friend',
        avatarId: 'avatar-02',
        level: OnlinePlayerLevel.intermediate,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: OnlineLobbyScreen(
          client: client,
          pack: piecePacks.first,
          initialGameId: 'shared-room',
        ),
      ),
    );
    await tester.pump();

    expect(channel.sent.last['type'], 'join_game');
    expect(channel.sent.last['gameId'], 'shared-room');
    await tester.pumpWidget(const SizedBox());
    client.dispose();
  });

  testWidgets('lobby deletes invitations but retains completed history cards', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final channel = FakeChannel();
    final client = OnlineMatchClient(channelFactory: (_) => channel);
    await client.connect(Uri.parse('ws://localhost:8080'));
    await tester.pumpWidget(
      MaterialApp(
        home: OnlineLobbyScreen(client: client, pack: piecePacks.first),
      ),
    );
    channel.receive({
      'type': 'invites',
      'invites': [
        {
          'inviteId': 'delete-me',
          'sender': {'name': 'Moon Mage', 'avatarId': 'moon'},
          'recipient': {'name': 'Nova Knight', 'avatarId': 'mage'},
          'createdAt': 1,
          'status': 'declined',
        },
      ],
    });
    channel.receive({
      'type': 'points_history',
      'matches': [
        {
          'recordId': 'history-one',
          'gameId': 'finished-one',
          'opponentName': 'Moon Mage',
          'opponentAvatarId': 'moon',
          'result': 'win',
          'points': 3,
          'completedAt': 1000,
        },
      ],
    });
    await tester.pump();

    final deleteInvite = find.byKey(const ValueKey('delete-invite-delete-me'));
    await tester.scrollUntilVisible(
      deleteInvite,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(deleteInvite);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pump();
    expect(channel.sent.any((frame) => frame['type'] == 'delete_invite'), true);

    final historyButton = find.text('Game history');
    await tester.scrollUntilVisible(
      historyButton,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(historyButton);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('WON ·'), findsOneWidget);
    expect(find.byTooltip('Delete game history'), findsNothing);
    expect(
      channel.sent.any((frame) => frame['type'] == 'delete_history'),
      false,
    );
    await tester.pumpWidget(const SizedBox());
    client.dispose();
  });

  testWidgets('online victory shows the celebratory result atmosphere', (
    tester,
  ) async {
    final channel = FakeChannel();
    final client = await showGame(tester, channel);
    channel.receive({
      'type': 'game_state',
      'state': stateJson(
        sequence: 2,
        status: 'complete',
        result: {'reason': 'checkmate', 'winner': 'w'},
      ),
    });
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byKey(const ValueKey('result-atmosphere')), findsOneWidget);
    expect(find.text('CHECKMATE'), findsOneWidget);
    expect(find.text('You Win!'), findsOneWidget);
    expect(find.text('Review Board'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    client.dispose();
  });

  testWidgets('online timeout names the opponent as winner', (tester) async {
    final channel = FakeChannel();
    final client = await showGame(tester, channel);
    channel.receive({
      'type': 'game_state',
      'state': stateJson(
        sequence: 2,
        status: 'complete',
        whiteMs: 0,
        result: {'reason': 'timeout', 'winner': 'b'},
      ),
    });
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('WINNER BY TIMEOUT'), findsOneWidget);
    expect(find.text('You Lost'), findsOneWidget);
    expect(find.byKey(const ValueKey('result-atmosphere')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    client.dispose();
  });
}
