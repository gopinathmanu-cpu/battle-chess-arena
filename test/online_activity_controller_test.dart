import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/services/mobile_notifications.dart';
import 'package:battle_chess_arena/src/services/online_activity_controller.dart';
import 'package:battle_chess_arena/src/services/online_game_history.dart';
import 'package:battle_chess_arena/src/services/online_match_client.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartchess/dartchess.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/online_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<void> flush() => Future<void>.delayed(Duration.zero);
  late FakeChannel channel;
  late OnlineMatchClient client;
  late OnlineActivityController activity;
  final calls = <MethodCall>[];
  const bridge = MethodChannel('test/game_activity');
  Map<String, dynamic> game(Map<String, dynamic> state) => {
    'gameId': state['gameId'],
    'seat': 'w',
    'seatToken': 'secret',
    'state': state,
  };
  Future<void> update(Map<String, dynamic> state) async {
    channel.receive({'type': 'game_activity', 'game': game(state)});
    await flush();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    OnlineGameHistory.profileChanges.value = null;
    OnlineGameHistory.notificationChanges.value = null;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bridge, (call) async {
          calls.add(call);
          return null;
        });
    channel = FakeChannel();
    client = OnlineMatchClient(channelFactory: (_) => channel);
    activity = OnlineActivityController(
      client: client,
      notifications: MobileNotificationService(
        channel: bridge,
        platform: TargetPlatform.android,
      ),
    );
    await activity.start();
    await client.connect(Uri.parse('ws://localhost:8080'));
    channel.receive({
      'type': 'active_games',
      'games': [game(stateJson())],
    });
    await flush();
  });
  tearDown(() {
    activity.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bridge, null);
  });
  test(
    'baseline and own moves are silent; other-game opponent move alerts once',
    () async {
      expect(activity.alerts, isEmpty);
      final session = GameSession()..play(Square.e2, Square.e4);
      await update(stateJson(game: session, sequence: 2));
      expect(activity.alerts, isEmpty);
      session.play(Square.e7, Square.e5);
      final state = stateJson(game: session, sequence: 3);
      await update(state);
      expect(activity.alerts.single.message, contains('Black Hero played e5'));
      expect(calls.where((call) => call.method == 'playAlert').length, 1);
      await update(state);
      expect(activity.alerts.length, 1);
      expect(calls.where((call) => call.method == 'playAlert').length, 1);
      expect(client.state, isNull); // Account monitoring never steals a seat.
    },
  );
  test(
    'visible game suppresses alerts; viewing it clears queued updates',
    () async {
      activity.viewGame('room');
      final session = GameSession()
        ..play(Square.e2, Square.e4)
        ..play(Square.e7, Square.e5);
      await update(stateJson(game: session, sequence: 3));
      expect(activity.alerts, isEmpty);
      expect(calls, isEmpty);
      activity.viewGame(null);
      await update(stateJson(gameId: 'another-game'));
      expect(activity.alerts.single.message, contains('joined'));
      activity.viewGame('another-game');
      expect(activity.alerts, isEmpty);
    },
  );
  test(
    'inactive app sends local notification only with preference enabled',
    () async {
      activity.active = false;
      await update(stateJson(gameId: 'first-game'));
      expect(calls.where((call) => call.method == 'show'), isEmpty);
      await OnlineGameHistory.saveMobileNotificationsEnabled(true);
      await update(stateJson(gameId: 'second-game'));
      expect(
        calls.where((call) => call.method == 'show').single.arguments,
        containsPair('id', 'game:second-game'),
      );
      await OnlineGameHistory.saveMobileNotificationsEnabled(false);
      await update(stateJson(gameId: 'third-game'));
      expect(calls.where((call) => call.method == 'show').length, 1);
    },
  );
  test(
    'stale activity cannot replace newer state or retrigger alerts',
    () async {
      final session = GameSession()
        ..play(Square.e2, Square.e4)
        ..play(Square.e7, Square.e5);
      await update(stateJson(game: session, sequence: 5));
      await update(stateJson(sequence: 1));
      expect(client.activeGames.single.state.sequence, 5);
      expect(calls.where((call) => call.method == 'playAlert').length, 1);
    },
  );
}
