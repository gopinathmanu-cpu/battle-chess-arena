import 'package:battle_chess_arena/src/app.dart';
import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/play/animation_lab_screen.dart';
import 'package:battle_chess_arena/src/features/play/board_appearance.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:battle_chess_arena/src/features/online/online_game_screen.dart';
import 'package:battle_chess_arena/src/services/last_game_storage.dart';
import 'package:battle_chess_arena/src/services/match_appearance_storage.dart';
import 'package:battle_chess_arena/src/services/online_match_client.dart';
import 'package:battle_chess_arena/src/services/home_chess_set.dart';
import 'package:dartchess/dartchess.dart' show Square;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'last_game_storage_test.dart' show savedGame;
import 'computer_lifeline_test.dart' show HintPlayer;
import 'theme_music_test.dart' show FakeMusicOutput;
import 'support/online_fixtures.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LastGameStorage.clear();
  });

  ChessBoard board(WidgetTester tester) =>
      tester.widget<ChessBoard>(find.byType(ChessBoard));

  Future<void> pinchBoard(
    WidgetTester tester, {
    required double from,
    required double to,
  }) async {
    final center = tester.getCenter(find.byType(ZoomableChessBoard));
    final first = await tester.startGesture(center - Offset(from / 2, 0));
    final second = await tester.startGesture(center + Offset(from / 2, 0));
    await tester.pump();
    await first.moveTo(center - Offset(to / 2, 0));
    await second.moveTo(center + Offset(to / 2, 0));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pumpAndSettle();
  }

  testWidgets(
    'swipes toggle board pieces and resume without changing armies or style',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AnimationLabScreen(
            pack: piecePacks.first,
            savedGame: savedGame(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final fen = board(tester).position.fen;
      final original = board(tester).appearance!.white.id;
      final originalBlack = board(tester).appearance!.black.id;
      final originalWorld = board(tester).appearance!.board.id;
      final originalStyle = board(tester).appearance!.classicStyle;
      await tester.drag(find.byType(ChessBoard), const Offset(-130, 0));
      await tester.pumpAndSettle();
      expect(board(tester).appearance!.white.id, original);
      expect(board(tester).appearance!.black.id, originalBlack);
      expect(board(tester).appearance!.board.id, originalWorld);
      expect(board(tester).appearance!.classicStyle, originalStyle);
      expect(board(tester).appearance!.standardPieces, true);
      expect(board(tester).position.fen, fen);
      expect(board(tester).selected, isNull);
      final saved = (await LastGameStorage.load())!;
      expect(saved.whitePack, original);
      expect(saved.blackPack, originalBlack);
      expect(saved.classicPieces, true);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          home: AnimationLabScreen(pack: piecePacks.first, savedGame: saved),
        ),
      );
      await tester.pumpAndSettle();
      expect(board(tester).appearance!.white.id, original);
      await tester.drag(find.byType(ChessBoard), const Offset(130, 0));
      await tester.pumpAndSettle();
      expect(board(tester).appearance!.white.id, original);
      expect(board(tester).appearance!.standardPieces, false);
      expect(
        find.byKey(const ValueKey('switch-to-classic-icon')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('quick-piece-style-toggle')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('switch-to-themed-icon')),
        findsOneWidget,
      );
      final style = board(tester).appearance!.classicStyle;
      await tester.drag(find.byType(ChessBoard), const Offset(-130, 0));
      await tester.pumpAndSettle();
      expect(board(tester).appearance!.standardPieces, false);
      expect(board(tester).appearance!.classicStyle, style);
      expect(board(tester).appearance!.white.id, original);
      expect(
        (await LastGameStorage.load())!.classicStyle,
        board(tester).appearance!.classicStyle,
      );
      expect(board(tester).position.fen, fen);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final pack in [
    ...availablePiecePacks,
    piecePacks.firstWhere((pack) => pack.id == PiecePackId.japanese),
  ]) {
    testWidgets('${pack.name} swipes preserve the selected Classic material', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AnimationLabScreen(
            pack: pack,
            initialClassicPieces: true,
            initialAnimatedArena: true,
            initialClassicStyle: ClassicPieceStyle.wood,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final style = board(tester).appearance!.classicStyle;
      board(tester).onSquareTap(Square.e2);
      await tester.pumpAndSettle();
      expect(board(tester).selected, Square.e2);
      await tester.drag(find.byType(ChessBoard), const Offset(-130, 0));
      await tester.pumpAndSettle();
      expect(board(tester).appearance!.classicStyle, style);
      expect(board(tester).appearance!.white.id, pack.id);
      expect(board(tester).appearance!.standardPieces, false);
      expect(board(tester).selected, Square.e2);
      expect(board(tester).position.fen, GameSession().position.fen);
      await tester.drag(find.byType(ChessBoard), const Offset(130, 0));
      await tester.pumpAndSettle();
      expect(board(tester).appearance!.classicStyle, style);
      expect(board(tester).appearance!.white.id, pack.id);
      expect(board(tester).appearance!.standardPieces, true);
      expect(board(tester).selected, Square.e2);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('short and vertical drags do not change the chess set', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: AnimationLabScreen(pack: piecePacks.first)),
    );
    await tester.pumpAndSettle();
    final original = board(tester).appearance!.white.id;
    await tester.drag(find.byType(ChessBoard), const Offset(-20, 0));
    await tester.pumpAndSettle();
    expect(board(tester).appearance!.white.id, original);
    await tester.drag(find.byType(ChessBoard), const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(board(tester).appearance!.white.id, original);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'zoomed board pans without changing sets and restores swiping at 100%',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: AnimationLabScreen(pack: piecePacks.first)),
      );
      await tester.pumpAndSettle();
      final original = board(tester).appearance!.white.id;
      expect(board(tester).onSetSwipe, isNotNull);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.byKey(const ValueKey('chessboard-zoom-in')), findsNothing);

      await pinchBoard(tester, from: 40, to: 120);
      expect(board(tester).onSetSwipe, isNull);

      await tester.drag(find.byType(ChessBoard), const Offset(-130, 0));
      await tester.pumpAndSettle();
      expect(board(tester).appearance!.white.id, original);

      await pinchBoard(tester, from: 120, to: 20);
      expect(board(tester).onSetSwipe, isNotNull);
      await tester.drag(find.byType(ChessBoard), const Offset(-130, 0));
      await tester.pumpAndSettle();
      expect(board(tester).appearance!.white.id, original);
      expect(board(tester).appearance!.standardPieces, true);
    },
  );

  testWidgets(
    'online appearance survives reopening without changing another room',
    (tester) async {
      final channel = FakeChannel();
      final client = OnlineMatchClient(channelFactory: (_) => channel);
      await client.connect(Uri.parse('ws://localhost:8080'));
      channel.seat();
      await tester.pump();
      await MatchAppearanceStorage.save(
        'other-room',
        'w',
        BoardAppearance.forPack(piecePacks.last),
      );
      Future<void> open() async {
        await tester.pumpWidget(
          MaterialApp(
            home: OnlineGameScreen(client: client, pack: piecePacks.first),
          ),
        );
        await tester.pumpAndSettle();
      }

      await open();
      final fen = board(tester).position.fen;
      await pinchBoard(tester, from: 40, to: 120);
      expect(board(tester).onSetSwipe, isNull);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await pinchBoard(tester, from: 120, to: 20);
      expect(board(tester).onSetSwipe, isNotNull);
      await tester.drag(find.byType(ChessBoard), const Offset(-130, 0));
      await tester.pumpAndSettle();
      final selected = board(tester).appearance!.white.id;
      expect(selected, piecePacks.first.id);
      expect(board(tester).appearance!.standardPieces, true);
      expect(channel.sent.where((m) => m['type'] == 'move'), isEmpty);
      await tester.pumpWidget(const SizedBox());
      await open();
      expect(board(tester).appearance!.white.id, selected);
      expect(board(tester).appearance!.standardPieces, true);
      expect(board(tester).position.fen, fen);
      expect(
        (await MatchAppearanceStorage.load('other-room', 'w'))!.white.id,
        piecePacks.last.id,
      );
      expect(await MatchAppearanceStorage.load('room', 'b'), isNull);
      await tester.pumpWidget(const SizedBox());
      client.dispose();
    },
  );

  testWidgets(
    'legacy save keeps paid play assists reachable on a small phone',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final computer = HintPlayer();
      final legacy = SavedGame.fromJson(
        savedGame(mode: PlayerMode.computer, moves: const []).toJson()
          ..['lifelinesRemaining'] = 0,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: AnimationLabScreen(
            pack: piecePacks.first,
            mode: PlayerMode.computer,
            savedGame: legacy,
            computerPlayer: computer,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final suggestion = find.byKey(const ValueKey('use-computer-lifeline'));
      await tester.scrollUntilVisible(
        suggestion,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      for (var i = 0; i < 5; i++) {
        await tester.ensureVisible(suggestion);
        await tester.pumpAndSettle();
        await tester.tap(suggestion);
        await tester.pumpAndSettle();
      }
      expect(computer.calls, 5);
      expect(find.textContaining('left)'), findsNothing);
      expect(find.textContaining('vs Computer'), findsNothing);
      expect(find.byKey(const ValueKey('analyse-threats')), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Game settings'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Game settings').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Game settings'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byTooltip('Suggest best move'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'home settings open, persist family selection, and fit a small phone',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        BattleChessArenaApp(
          musicOutput: FakeMusicOutput(),
          incomingLinks: const Stream.empty(),
        ),
      );
      await tester.pumpAndSettle();
      // Home previews intentionally ignore square taps; the PageView receives
      // the gesture at this location, not the board's read-only render object.
      await tester.dragFrom(
        tester.getCenter(find.byType(ChessBoard)),
        const Offset(-180, 0),
      );
      await tester.pumpAndSettle();
      final browsedSet = await HomeChessSet.load();
      expect(browsedSet.classic, true);
      expect(browsedSet.style, isNot(ClassicPieceStyle.magneticTeaching));
      await tester.tap(find.byKey(const ValueKey('home-settings-button')));
      await tester.pumpAndSettle();
      expect(find.text('Game settings'), findsOneWidget);
      expect(
        find.text('Timed games keep running while settings are open.'),
        findsNothing,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('settings-animated-anime')),
        200,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('game-settings-list')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings-animated-anime')));
      await tester.pumpAndSettle();
      expect((await HomeChessSet.load()).classic, false);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
