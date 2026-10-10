import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/online/online_game_screen.dart';
import 'package:battle_chess_arena/src/features/play/animation_lab_screen.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:battle_chess_arena/src/features/play/neon_live_game_layout.dart';
import 'package:battle_chess_arena/src/services/computer_player.dart';
import 'package:battle_chess_arena/src/services/last_game_storage.dart';
import 'package:battle_chess_arena/src/services/online_match_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartchess/dartchess.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/online_fixtures.dart';

class ThreatTestComputer implements ComputerPlayer {
  int calls = 0;
  @override
  Future<String?> bestMove(
    String fen, {
    ComputerDifficulty difficulty = ComputerDifficulty.medium,
    int? botLevel,
  }) async {
    calls++;
    return 'e7e5';
  }

  @override
  void dispose() {}
}

const threatMoves = ['e2e4', 'd7d5', 'g1f3', 'b8c6', 'f1b5', 'd8d6'];
SavedGame threatSave({PlayerMode mode = PlayerMode.computer}) => SavedGame(
  mode: mode,
  homePack: PiecePackId.anime,
  difficulty: ComputerDifficulty.easy,
  moves: threatMoves,
  whiteMilliseconds: 300000,
  blackMilliseconds: 300000,
  fastBattles: true,
  whitePack: PiecePackId.anime,
  blackPack: PiecePackId.anime,
  boardPack: PiecePackId.anime,
  updatedAtEpochMs: 1,
  lifelinesRemaining: 3,
);

void main() {
  setUp(() {
    AnimationLabScreen.debugClockFactory = () =>
        TestWidgetsFlutterBinding.ensureInitialized().clock.stopwatch();
  });
  tearDown(() => AnimationLabScreen.debugClockFactory = null);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> scan(WidgetTester tester) async {
    expect(
      find.byKey(const ValueKey('analyse-threats')).hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('analyse-threats')));
    await tester.pump();
    await tester.pump();
  }

  ChessBoard board(WidgetTester tester) =>
      tester.widget<ChessBoard>(find.byType(ChessBoard));

  testWidgets(
    'play assists preserve the board viewport and threat status appears once',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: AnimationLabScreen(
            pack: piecePacks.first,
            mode: PlayerMode.computer,
            savedGame: threatSave(),
            computerPlayer: ThreatTestComputer(),
          ),
        ),
      );
      await tester.pump();
      final threatButton = find.byKey(const ValueKey('analyse-threats'));
      expect(threatButton.hitTestable(), findsOneWidget);
      expect(
        find.byKey(const ValueKey('use-computer-lifeline')).hitTestable(),
        findsOneWidget,
      );
      expect(
        tester.getRect(threatButton).top,
        greaterThanOrEqualTo(tester.getRect(find.byType(ChessBoard)).bottom),
      );
      final beforeThreat = tester.getTopLeft(find.byType(ChessBoard));
      await tester.tap(threatButton);
      await tester.pump();
      expect(tester.getTopLeft(find.byType(ChessBoard)), beforeThreat);
      expect(find.byKey(const ValueKey('threat-scan-message')), findsOneWidget);

      final beforeSuggestion = tester.getTopLeft(find.byType(ChessBoard));
      await tester.tap(find.byKey(const ValueKey('use-computer-lifeline')));
      await tester.pump();
      expect(tester.getTopLeft(find.byType(ChessBoard)), beforeSuggestion);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'phone scan reveals the board, blinks each pair, keeps clock and lifelines',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final computer = ThreatTestComputer();
      await tester.pumpWidget(
        MaterialApp(
          home: AnimationLabScreen(
            pack: piecePacks.first,
            mode: PlayerMode.computer,
            savedGame: threatSave(),
            computerPlayer: computer,
          ),
        ),
      );
      final originalFen = board(tester).position.fen;
      final startClock = tester
          .widget<NeonLiveStatusBar>(find.byType(NeonLiveStatusBar))
          .whiteTime;
      await scan(tester);
      expect(board(tester).threatFrom, Square.d5);
      expect(board(tester).threatTarget, Square.e4);
      expect(find.byKey(const ValueKey('threat-d5')), findsOneWidget);
      expect(find.byKey(const ValueKey('threat-e4')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      expect(board(tester).threatLit, isFalse);
      await tester.pump(const Duration(milliseconds: 2500));
      expect(board(tester).threatFrom, Square.d6);
      expect(board(tester).threatTarget, Square.h2);
      expect(
        tester
            .widget<NeonLiveStatusBar>(find.byType(NeonLiveStatusBar))
            .whiteTime,
        startClock - const Duration(seconds: 3),
      );
      await tester.pump(const Duration(seconds: 3));
      expect(board(tester).threatFrom, isNull);
      expect(board(tester).position.fen, originalFen);
      expect(find.text('Suggest move'), findsOneWidget);
      expect(computer.calls, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'moving and backgrounding cancel a scan; local play is supported',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: AnimationLabScreen(
            pack: piecePacks.first,
            savedGame: threatSave(mode: PlayerMode.local),
          ),
        ),
      );
      await scan(tester);
      expect(board(tester).threatFrom, isNotNull);
      await tester.tap(find.byKey(const ValueKey('square-a2')));
      await tester.pump();
      expect(board(tester).threatFrom, isNull);
      await tester.tap(find.byKey(const ValueKey('square-a3')));
      await tester.pump();
      expect(board(tester).position.board.pieceAt(Square.a3)?.role, Role.pawn);
      await scan(tester);
      expect(board(tester).threatFrom, isNotNull);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 10));
      expect(board(tester).threatFrom, isNull);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'online black-side scan is read-only and clears on server changes/disconnect',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final channel = FakeChannel();
      final client = OnlineMatchClient(
        channelFactory: (_) => channel,
        heartbeatInterval: const Duration(minutes: 5),
      );
      final computer = ThreatTestComputer();
      await client.connect(Uri.parse('ws://localhost:8080'));
      final game = GameSession.fromMoves(moves: ['e2e4', 'd7d5', 'b1c3']);
      channel.seat(
        seat: 'b',
        state: stateJson(game: game, whiteComputer: true),
      );
      await tester.pump();
      await tester.pumpWidget(
        MaterialApp(
          home: OnlineGameScreen(
            client: client,
            pack: piecePacks.first,
            computerPlayer: computer,
          ),
        ),
      );
      final sentCount = channel.sent.length;
      await scan(tester);
      expect(board(tester).orientation, Side.black);
      expect(board(tester).threatFrom, Square.c3);
      expect(board(tester).threatTarget, Square.d5);
      expect(client.state!.lifelinesFor('b'), 3);
      expect(channel.sent.length, sentCount);
      expect(computer.calls, 0);
      game.playUci('g8f6');
      channel.receive({
        'type': 'game_state',
        'state': stateJson(game: game, sequence: 2, whiteComputer: true),
      });
      await tester.pump();
      expect(board(tester).threatFrom, isNull);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('analyse-threats')))
            .onPressed,
        isNull,
      );
      game.playUci('g1f3');
      channel.receive({
        'type': 'game_state',
        'state': stateJson(game: game, sequence: 3, whiteComputer: true),
      });
      await tester.pump();
      await scan(tester);
      expect(board(tester).threatFrom, isNotNull);
      client.disconnect();
      await tester.pump();
      expect(board(tester).threatFrom, isNull);
      await tester.pumpWidget(const SizedBox());
      client.dispose();
    },
  );

  testWidgets(
    'reduced motion is steady red and disposal cancels an active scan',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(650, 360));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: AnimationLabScreen(
            pack: piecePacks.first,
            mode: PlayerMode.computer,
            savedGame: threatSave(),
            computerPlayer: ThreatTestComputer(),
          ),
        ),
      );
      await scan(tester);
      await tester.pump(const Duration(milliseconds: 500));
      expect(board(tester).threatLit, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
      expect(tester.takeException(), isNull);
    },
  );
}
