import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/online/online_game_screen.dart';
import 'package:battle_chess_arena/src/features/online/online_lobby_screen.dart';
import 'package:battle_chess_arena/src/features/play/capture_battle_overlay.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:battle_chess_arena/src/services/online_match_client.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/online_fixtures.dart';

void main() {
  testWidgets(
    'online setup hides transport details and offers avatar choices',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(home: OnlineLobbyScreen(pack: piecePacks.first)),
      );
      await tester.pumpAndSettle();
      expect(find.text('WebSocket endpoint'), findsNothing);
      expect(find.textContaining('wss://'), findsNothing);
      expect(find.text('Create your online Avatar ID'), findsOneWidget);
      expect(find.byKey(const ValueKey('avatar-name-field')), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNWidgets(8));
    },
  );

  Future<OnlineMatchClient> showGame(
    WidgetTester tester,
    FakeChannel channel, {
    String seat = 'w',
    GameSession? game,
    Size size = const Size(400, 900),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final client = OnlineMatchClient(channelFactory: (_) => channel);
    await client.connect(Uri.parse('ws://localhost:8080'));
    channel.seat(
      seat: seat,
      state: stateJson(game: game),
    );
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        home: OnlineGameScreen(client: client, pack: piecePacks.first),
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
    await tester.scrollUntilVisible(
      find.text('Capture battles'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
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
          matching: find.byType(Image),
        ),
        findsNWidgets(4),
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
}
