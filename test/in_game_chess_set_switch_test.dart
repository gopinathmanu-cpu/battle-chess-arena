import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/domain/game_time_control.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/online/online_game_screen.dart';
import 'package:battle_chess_arena/src/features/play/animation_lab_screen.dart';
import 'package:battle_chess_arena/src/features/play/board_appearance.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:battle_chess_arena/src/features/play/neon_live_arena.dart';
import 'package:battle_chess_arena/src/features/play/match_opponent_panel.dart';
import 'package:battle_chess_arena/src/services/computer_player.dart';
import 'package:battle_chess_arena/src/services/last_game_storage.dart';
import 'package:battle_chess_arena/src/services/match_appearance_storage.dart';
import 'package:battle_chess_arena/src/services/online_match_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/game_settings.dart';
import 'support/online_fixtures.dart';

ChessBoard board(WidgetTester tester) =>
    tester.widget<ChessBoard>(find.byType(ChessBoard));

Future<void> chooseSet(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byTooltip('Game settings'));
  await openGameSettings(tester, target: find.byKey(ValueKey(key)));
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Close settings'));
  await tester.pumpAndSettle();
}

Future<void> verifyClassicSwipes(WidgetTester tester, String fen) async {
  for (final direction in [-1.0, 1.0]) {
    final original = board(tester).appearance!.classicStyle;
    final visited = <ClassicPieceStyle>{original};
    for (var i = 0; i < ClassicPieceStyle.values.length; i++) {
      await tester.ensureVisible(find.byType(ChessBoard));
      await tester.drag(find.byType(ChessBoard), Offset(direction * 140, 0));
      await tester.pumpAndSettle();
      visited.add(board(tester).appearance!.classicStyle);
      expect(board(tester).appearance!.standardPieces, isTrue);
      expect(board(tester).appearance!.animatedArena, isFalse);
      expect(find.byType(NeonLiveArena), findsNothing);
      expect(board(tester).position.fen, fen);
    }
    expect(visited, ClassicPieceStyle.values.toSet());
    expect(board(tester).appearance!.classicStyle, original);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AnimationLabScreen.debugClockFactory = () =>
        TestWidgetsFlutterBinding.ensureInitialized().clock.stopwatch();
  });
  tearDown(() => AnimationLabScreen.debugClockFactory = null);

  testWidgets(
    'all eight sets change the live page and survive offline resume',
    (tester) async {
      const moves = ['e2e4', 'e7e5'];
      const saved = SavedGame(
        mode: PlayerMode.local,
        homePack: PiecePackId.futuristic,
        difficulty: ComputerDifficulty.medium,
        moves: moves,
        whiteMilliseconds: 123456,
        blackMilliseconds: 234567,
        fastBattles: true,
        whitePack: PiecePackId.futuristic,
        blackPack: PiecePackId.futuristic,
        boardPack: PiecePackId.futuristic,
        updatedAtEpochMs: 1,
        timeControl: GameTimeControl.practice,
        animatedArena: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: AnimationLabScreen(pack: piecePacks.first, savedGame: saved),
        ),
      );
      await tester.pumpAndSettle();
      final fen = board(tester).position.fen;
      for (final style in ClassicPieceStyle.values) {
        await chooseSet(tester, 'settings-classic-${style.name}');
        expect(find.byType(NeonLiveArena), findsNothing);
        expect(board(tester).appearance!.classicStyle, style);
        expect(board(tester).appearance!.standardPieces, isTrue);
        expect(board(tester).position.fen, fen);
        final record = await LastGameStorage.load();
        expect(record!.moves, moves);
        expect(record.animatedArena, isFalse);
        expect(record.whiteMilliseconds, saved.whiteMilliseconds);
        expect(record.blackMilliseconds, saved.blackMilliseconds);
      }
      for (final pack in availablePiecePacks) {
        await chooseSet(tester, 'settings-animated-${pack.id.name}');
        expect(find.byType(NeonLiveArena), findsOneWidget);
        expect(board(tester).appearance!.white.id, pack.id);
        expect(board(tester).appearance!.black.id, pack.id);
        expect(board(tester).appearance!.board.id, pack.id);
        expect(board(tester).position.fen, fen);
        final record = await LastGameStorage.load();
        expect(record!.animatedArena, isTrue);
        expect(record.whitePack, pack.id);
        expect(record.moves, moves);
      }
      await chooseSet(tester, 'settings-classic-wood');
      final retained = await LastGameStorage.load();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          home: AnimationLabScreen(
            pack: piecePacks.first,
            savedGame: retained,
            initialAnimatedArena: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NeonLiveArena), findsNothing);
      expect(board(tester).position.fen, fen);
      expect(board(tester).appearance!.classicStyle, ClassicPieceStyle.wood);
      await verifyClassicSwipes(tester, fen);
      expect((await LastGameStorage.load())!.animatedArena, isFalse);
      expect(
        find.byKey(const ValueKey('chess-piece-type-dialog')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('online presentation switches locally and is restored per seat', (
    tester,
  ) async {
    final channel = FakeChannel();
    final client = OnlineMatchClient(channelFactory: (_) => channel);
    await client.connect(Uri.parse('ws://localhost:8080'));
    final game = GameSession.fromMoves(moves: ['e2e4', 'e7e5']);
    channel.seat(state: stateJson(game: game));
    await tester.pump();
    Widget page({bool initialAnimatedArena = true}) => MaterialApp(
      home: OnlineGameScreen(
        client: client,
        pack: piecePacks.first,
        initialAnimatedArena: initialAnimatedArena,
      ),
    );
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    for (final pack in availablePiecePacks) {
      await chooseSet(tester, 'settings-animated-${pack.id.name}');
      expect(find.byType(NeonLiveArena), findsNothing);
      expect(find.byType(MatchOpponentPanel), findsOneWidget);
      expect(board(tester).appearance!.animatedArena, isTrue);
      expect(board(tester).appearance!.white.id, pack.id);
      expect(board(tester).position.fen, game.position.fen);
    }
    for (final style in ClassicPieceStyle.values) {
      await chooseSet(tester, 'settings-classic-${style.name}');
      expect(find.byType(NeonLiveArena), findsNothing);
      expect(board(tester).appearance!.classicStyle, style);
      expect(board(tester).position.fen, game.position.fen);
      final retained = await MatchAppearanceStorage.load('room', 'w');
      expect(retained!.animatedArena, isFalse);
      expect(retained.classicStyle, style);
      expect(await MatchAppearanceStorage.load('room', 'b'), isNull);
    }
    expect(channel.sent.where((message) => message['type'] == 'move'), isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    expect(find.byType(NeonLiveArena), findsNothing);
    expect(board(tester).position.fen, game.position.fen);
    expect(
      board(tester).appearance!.classicStyle,
      ClassicPieceStyle.values.last,
    );
    await verifyClassicSwipes(tester, game.position.fen);
    expect(
      (await MatchAppearanceStorage.load('room', 'w'))!.animatedArena,
      isFalse,
    );
    expect(channel.sent.where((message) => message['type'] == 'move'), isEmpty);
    await tester.pumpWidget(const SizedBox());
    client.dispose();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy Classic icons keep their Animated room presentation', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      MatchAppearanceStorage.key('room', 'w'): [
        'futuristic',
        'futuristic',
        'futuristic',
        'classic',
        'wood',
      ],
    });
    final restored = await MatchAppearanceStorage.load('room', 'w');
    expect(restored!.animatedArena, isTrue);
    expect(usesAnimatedLiveArena(restored), isTrue);
    expect(
      restored.withBoardColors(Colors.blue, Colors.green).animatedArena,
      isTrue,
    );
    final classic = BoardAppearance(
      white: restored.white,
      black: restored.black,
      board: restored.board,
      standardPieces: true,
      animatedArena: false,
    );
    expect(usesAnimatedLiveArena(classic), isFalse);
    expect(classic.withStandardPieces().animatedArena, isFalse);
    expect(classic.withCustomSet(null).animatedArena, isFalse);
    await MatchAppearanceStorage.save('room', 'w', classic);
    expect(
      (await MatchAppearanceStorage.load('room', 'w'))!.animatedArena,
      isFalse,
    );
  });
}
