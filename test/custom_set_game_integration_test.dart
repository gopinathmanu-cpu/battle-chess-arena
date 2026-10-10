// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:battle_chess_arena/src/app.dart';
import 'package:battle_chess_arena/src/domain/custom_chess_set.dart';
import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/home/home_screen.dart';
import 'package:battle_chess_arena/src/features/online/online_game_screen.dart';
import 'package:battle_chess_arena/src/features/online/online_lobby_screen.dart';
import 'package:battle_chess_arena/src/features/play/animation_lab_screen.dart';
import 'package:battle_chess_arena/src/features/play/board_appearance.dart';
import 'package:battle_chess_arena/src/features/play/capture_battle_overlay.dart';
import 'package:battle_chess_arena/src/features/play/captured_pieces_panel.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:battle_chess_arena/src/features/studio/custom_board_surface.dart';
import 'package:battle_chess_arena/src/features/studio/custom_piece.dart';
import 'package:battle_chess_arena/src/features/tournaments/tournaments_screen.dart';
import 'package:battle_chess_arena/src/services/custom_chess_sets.dart';
import 'package:battle_chess_arena/src/services/home_chess_set.dart';
import 'package:battle_chess_arena/src/services/online_match_client.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/online_fixtures.dart';
import 'theme_music_test.dart' show FakeMusicOutput;
import 'support/piece_choice.dart';

CustomChessSet _royalSet() =>
    CustomChessSet.create(
          id: 'royal-integration-set',
          name: 'My royal guardians',
        )
        .copyWith(
          lightSquare: 0xFFDDEEDD,
          darkSquare: 0xFF193D37,
          surface: CustomBoardSurface.marble,
          background: CustomBackground.forest,
          backgroundColor: 0xFF123829,
        )
        .withDesign(
          Side.white,
          Role.knight,
          const CustomPieceDesign(horse: 3, costume: 2, weapon: 1, scale: 1.15),
        );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<CustomChessSets> savedLibrary() async {
    final library = CustomChessSets();
    addTearDown(library.dispose);
    expect(await library.save(_royalSet()), isTrue);
    return library;
  }

  Future<void> phone(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  Future<void> openApp(WidgetTester tester) async {
    await tester.pumpWidget(
      BattleChessArenaApp(
        musicOutput: FakeMusicOutput(),
        incomingLinks: const Stream.empty(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> scopedGame(
    WidgetTester tester,
    CustomChessSets library,
    Widget game,
  ) async {
    await tester.pumpWidget(
      CustomChessSetScope(
        controller: library,
        child: MaterialApp(home: game),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder boardArt() => find.descendant(
    of: find.byType(ChessBoard),
    matching: find.byType(CustomPiece),
  );

  testWidgets('a new player has no custom-theme creation entry', (
    tester,
  ) async {
    await phone(tester);
    await openApp(tester);
    expect(find.byKey(const ValueKey('create-custom-theme')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('choose-themed')));
    await tester.pumpAndSettle();
    final filter = tester.widget<DropdownButton>(
      find.byKey(const ValueKey('chess-set-group-filter')),
    );
    expect(
      filter.items!.map((item) => (item.child as Text).data),
      isNot(contains('My Themes')),
    );
    await tester.tap(find.byKey(const ValueKey('home-settings-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('settings-chess-set-studio')),
      findsNothing,
    );
    await tester.tap(find.byTooltip('Close settings'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('choose-classic')), findsOneWidget);
    expect(find.byKey(const ValueKey('choose-themed')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'the full board uses all 32 custom designs, chosen square colors and texture',
    (tester) async {
      final set = _royalSet();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox.square(
                dimension: 360,
                child: ChessBoard(
                  position: Chess.initial,
                  selected: null,
                  legalTargets: const {},
                  accent: Colors.amber,
                  appearance: BoardAppearance.forPack(
                    piecePacks.first,
                  ).withCustomSet(set),
                  onSquareTap: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(boardArt(), findsNWidgets(32));
      for (final piece in tester.widgetList<CustomPiece>(boardArt())) {
        expect(piece.chessSet.id, set.id);
      }
      Color color(String square) => tester
          .widget<ColoredBox>(
            find
                .descendant(
                  of: find.byKey(ValueKey('square-$square')),
                  matching: find.byType(ColoredBox),
                )
                .first,
          )
          .color;
      expect(color('a8'), Color(set.lightSquare));
      expect(color('b8'), Color(set.darkSquare));
      final surfaces = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((widget) => widget.painter)
          .whereType<CustomBoardSurfacePainter>();
      expect(surfaces, hasLength(64));
      expect(
        surfaces.every(
          (painter) => painter.surface == CustomBoardSurface.marble,
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'saved custom editing and games remain available without theme creation entries',
    (tester) async {
      await phone(tester);
      await savedLibrary();
      await openApp(tester);
      var library = CustomChessSetScope.of(
        tester.element(find.byType(HomeScreen)),
      );
      expect(library.activeId, _royalSet().id);
      expect(find.text('My Themes'), findsWidgets);
      expect(find.byKey(const ValueKey('my-themes-selector')), findsNothing);
      expect(find.byKey(const ValueKey('my-themes-carousel')), findsOneWidget);
      expect(find.text(_royalSet().name), findsWidgets);
      expect(find.byKey(const ValueKey('create-custom-theme')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('home-settings-button')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('settings-chess-set-studio')),
        findsNothing,
      );
      await tester.tap(find.byTooltip('Close settings'));
      await tester.pumpAndSettle();
      final edit = find.byKey(const ValueKey('edit-custom-theme'));
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      expect(find.text('Design your set'), findsOneWidget);
      expect(find.byKey(const ValueKey('create-custom-set')), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await openApp(tester);
      library = CustomChessSetScope.of(tester.element(find.byType(HomeScreen)));
      expect(library.activeId, _royalSet().id);
      final play = find.byKey(const ValueKey('play-computer-button'));
      await tester.ensureVisible(play);
      await tester.tap(play);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('computer-difficulty-easy')));
      await tester.tap(find.byKey(const ValueKey('start-computer-game')));
      await chooseGamePieces(tester, classic: false);
      await tester.pumpAndSettle();
      expect(find.byType(AnimationLabScreen), findsOneWidget);
      final game = tester.widget<AnimationLabScreen>(
        find.byType(AnimationLabScreen),
      );
      expect(game.initialClassicPieces, isFalse);
      expect(game.initialAnimatedArena, isFalse);
      expect((await HomeChessSet.load()).classic, isTrue);
      final board = tester.widget<ChessBoard>(find.byType(ChessBoard));
      expect(board.appearance?.customSet?.id, _royalSet().id);
      expect(board.appearance?.animatedArena, isFalse);
      expect(board.position.fen, Chess.initial.fen);
      expect(boardArt(), findsNWidgets(32));
      expect(
        tester
            .widget<WorldBackdrop>(find.byType(WorldBackdrop))
            .customSet
            ?.background,
        CustomBackground.forest,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final route in ['Play Online', 'Tournaments', 'Conquests']) {
    testWidgets(
      'saved custom selection reaches $route without replacing its artwork',
      (tester) async {
        await phone(tester);
        await savedLibrary();
        await openApp(tester);
        final launch = find.text(route);
        await tester.ensureVisible(launch);
        await tester.pumpAndSettle();
        await tester.tap(launch);
        await tester.pumpAndSettle();
        if (route == 'Play Online') {
          final lobby = tester.widget<OnlineLobbyScreen>(
            find.byType(OnlineLobbyScreen),
          );
          expect(lobby.initialClassicPieces, isFalse);
          expect(lobby.initialAnimatedArena, isFalse);
        } else {
          final event = tester.widget<TournamentsScreen>(
            find.byType(TournamentsScreen),
          );
          expect(event.initialClassicPieces, isFalse);
          expect(event.initialAnimatedArena, isFalse);
          expect(event.conquests, route == 'Conquests');
        }
        expect((await HomeChessSet.load()).classic, isTrue);
        final destination = route == 'Play Online'
            ? find.byType(OnlineLobbyScreen)
            : find.byType(TournamentsScreen);
        expect(
          CustomChessSetScope.of(tester.element(destination)).activeId,
          _royalSet().id,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets('My Themes swipes and arrows activate custom sets', (
    tester,
  ) async {
    await phone(tester);
    final library = await savedLibrary();
    final second = CustomChessSet.create(
      id: 'second-integration-set',
      name: 'My silver sentinels',
    );
    expect(await library.save(second, activate: false), isTrue);
    await openApp(tester);
    var appLibrary = CustomChessSetScope.of(
      tester.element(find.byType(HomeScreen)),
    );
    expect(appLibrary.activeId, _royalSet().id);
    expect(find.text('1 / 2 · Swipe to choose'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('next-custom-chess-set')));
    await tester.pumpAndSettle();
    expect(find.text(second.name), findsWidgets);
    expect(appLibrary.activeId, second.id);

    await tester.pumpWidget(const SizedBox());
    await openApp(tester);
    appLibrary = CustomChessSetScope.of(
      tester.element(find.byType(HomeScreen)),
    );
    expect(appLibrary.activeId, second.id);
    expect(find.text('2 / 2 · Swipe to choose'), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('my-themes-carousel')),
      const Offset(220, 0),
    );
    await tester.pumpAndSettle();
    expect(appLibrary.activeId, _royalSet().id);
  });

  testWidgets('home My Themes can delete the active custom chess set', (
    tester,
  ) async {
    await phone(tester);
    await savedLibrary();
    await openApp(tester);

    final library = CustomChessSetScope.of(
      tester.element(find.byType(HomeScreen)),
    );
    await tester.tap(find.byKey(const ValueKey('delete-custom-theme')));
    await tester.pumpAndSettle();
    expect(find.text('Delete this chess set?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('confirm-delete-custom-theme')));
    await tester.pumpAndSettle();

    expect(library.sets, isEmpty);
    expect(library.active, isNull);
    expect(find.byKey(const ValueKey('delete-custom-theme')), findsNothing);
    expect(find.byKey(const ValueKey('choose-classic')), findsOneWidget);
    expect(find.textContaining('deleted.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final classic in [false, true]) {
    testWidgets(
      'choosing ${classic ? 'Classic' : 'Themed'} on home leaves the custom set and remembers it',
      (tester) async {
        await phone(tester);
        await savedLibrary();
        await openApp(tester);
        final family = find.byKey(
          ValueKey(classic ? 'choose-classic' : 'choose-themed'),
        );
        await tester.ensureVisible(family);
        await tester.tap(family);
        await tester.pumpAndSettle();
        final library = CustomChessSetScope.of(
          tester.element(find.byType(HomeScreen)),
        );
        expect(library.active, isNull);
        expect(library.sets, hasLength(1));
        expect(boardArt(), findsNothing);
        final board = tester.widget<ChessBoard>(find.byType(ChessBoard));
        expect(board.appearance?.standardPieces, classic);
        await tester.pumpWidget(const SizedBox());
        await openApp(tester);
        expect(
          CustomChessSetScope.of(
            tester.element(find.byType(HomeScreen)),
          ).active,
          isNull,
        );
        expect(
          tester
              .widget<ChessBoard>(find.byType(ChessBoard))
              .appearance
              ?.standardPieces,
          classic,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'custom local play keeps legal moves and built-in switching preserves the position',
    (tester) async {
      await phone(tester);
      final library = await savedLibrary();
      await scopedGame(
        tester,
        library,
        AnimationLabScreen(pack: piecePacks.first),
      );
      expect(boardArt(), findsNWidgets(32));
      await tester.tap(find.byKey(const ValueKey('square-e2')));
      await tester.pump();
      var board = tester.widget<ChessBoard>(find.byType(ChessBoard));
      expect(board.legalTargets, containsAll([Square.e3, Square.e4]));
      expect(board.legalTargets, isNot(contains(Square.e5)));
      await tester.tap(find.byKey(const ValueKey('square-e4')));
      await tester.pumpAndSettle();
      board = tester.widget<ChessBoard>(find.byType(ChessBoard));
      final afterMove = board.position.fen;
      expect(board.position.turn, Side.black);
      expect(board.position.board.pieceAt(Square.e4)?.role, Role.pawn);
      expect(board.position.board.pieceAt(Square.e2), isNull);
      await tester.tap(find.byKey(const ValueKey('quick-piece-style-toggle')));
      await tester.pumpAndSettle();
      board = tester.widget<ChessBoard>(find.byType(ChessBoard));
      expect(library.active, isNull);
      expect(board.appearance?.customSet, isNull);
      expect(board.appearance?.standardPieces, isTrue);
      expect(board.position.fen, afterMove);
      expect(boardArt(), findsNothing);
      await tester.tap(find.byKey(const ValueKey('square-e7')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('square-e5')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ChessBoard>(find.byType(ChessBoard)).position.turn,
        Side.white,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'an early built-in choice wins over a delayed custom-library restore',
    (tester) async {
      await phone(tester);
      await savedLibrary();
      final preferences = await SharedPreferences.getInstance();
      final restore = Completer<SharedPreferences>();
      final library = CustomChessSets(preferences: () => restore.future);
      addTearDown(library.dispose);
      await scopedGame(
        tester,
        library,
        AnimationLabScreen(pack: piecePacks.first),
      );
      expect(library.loaded, isFalse);
      await tester.tap(find.byKey(const ValueKey('quick-piece-style-toggle')));
      await tester.pump();
      restore.complete(preferences);
      await tester.pumpAndSettle();
      expect(library.loaded, isTrue);
      expect(library.active, isNull);
      expect(library.sets, hasLength(1));
      final board = tester.widget<ChessBoard>(find.byType(ChessBoard));
      expect(board.appearance?.standardPieces, isTrue);
      expect(board.appearance?.customSet, isNull);
      expect(board.position.fen, Chess.initial.fen);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'online custom art does not change move protocol or authoritative position',
    (tester) async {
      await phone(tester);
      final library = await savedLibrary();
      final channel = FakeChannel();
      final client = OnlineMatchClient(channelFactory: (_) => channel);
      await client.connect(Uri.parse('ws://localhost:8080'));
      channel.seat(state: stateJson(timed: false));
      await tester.pump();
      await scopedGame(
        tester,
        library,
        OnlineGameScreen(client: client, pack: piecePacks.first),
      );
      expect(boardArt(), findsNWidgets(32));
      expect(
        tester.widget<WorldBackdrop>(find.byType(WorldBackdrop)).customSet?.id,
        _royalSet().id,
      );
      await tester.tap(find.byKey(const ValueKey('square-e2')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('square-e4')));
      await tester.pump();
      expect(channel.sent.last['type'], 'move');
      expect(channel.sent.last['move'], {
        'from': 'e2',
        'to': 'e4',
        'promotion': 'q',
      });
      expect(client.state!.position.fen, Chess.initial.fen);
      final game = GameSession()..playUci('e2e4');
      channel.receive({
        'type': 'game_state',
        'state': stateJson(game: game, sequence: 2, timed: false),
      });
      await tester.pumpAndSettle();
      expect(
        tester.widget<ChessBoard>(find.byType(ChessBoard)).position.fen,
        game.position.fen,
      );
      final messages = channel.sent.length;
      await tester.tap(
        find.byKey(const ValueKey('online-quick-piece-style-toggle')),
      );
      await tester.pumpAndSettle();
      expect(library.active, isNull);
      expect(
        tester.widget<ChessBoard>(find.byType(ChessBoard)).position.fen,
        game.position.fen,
      );
      expect(channel.sent.length, messages);
      expect(boardArt(), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      client.dispose();
    },
  );

  testWidgets(
    'online promotion choices show the custom set and keep selected promotion rules',
    (tester) async {
      await phone(tester);
      final library = await savedLibrary();
      final channel = FakeChannel();
      final client = OnlineMatchClient(channelFactory: (_) => channel);
      await client.connect(Uri.parse('ws://localhost:8080'));
      final game = GameSession(
        position: Chess.fromSetup(
          Setup.parseFen('7k/P7/8/8/8/8/8/7K w - - 0 1'),
        ),
      );
      channel.seat(state: stateJson(game: game, timed: false));
      await tester.pump();
      await scopedGame(
        tester,
        library,
        OnlineGameScreen(client: client, pack: piecePacks.first),
      );
      await tester.tap(find.byKey(const ValueKey('square-a7')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('square-a8')));
      await tester.pumpAndSettle();
      final choices = tester.widgetList<CustomPiece>(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(CustomPiece),
        ),
      );
      expect(choices, hasLength(4));
      expect(
        choices.every((piece) => piece.chessSet.id == _royalSet().id),
        isTrue,
      );
      await tester.tap(find.byTooltip('knight'));
      await tester.pumpAndSettle();
      expect((channel.sent.last['move'] as Map)['promotion'], 'n');
      expect(client.state!.position.board.pieceAt(Square.a7)?.role, Role.pawn);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      client.dispose();
    },
  );

  testWidgets(
    'capture cinematic and captured-pieces panel retain the custom designs',
    (tester) async {
      await phone(tester);
      final library = await savedLibrary();
      final channel = FakeChannel();
      final client = OnlineMatchClient(channelFactory: (_) => channel);
      await client.connect(Uri.parse('ws://localhost:8080'));
      final game = GameSession()
        ..playUci('e2e4')
        ..playUci('d7d5');
      channel.seat(state: stateJson(game: game, timed: false));
      await tester.pump();
      await scopedGame(
        tester,
        library,
        OnlineGameScreen(client: client, pack: piecePacks.first),
      );
      await tester.tap(find.byKey(const ValueKey('square-e4')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('square-d5')));
      await tester.pump();
      game.playUci('e4d5');
      channel.receive({
        'type': 'game_state',
        'state': stateJson(game: game, sequence: 2, timed: false),
      });
      await tester.pump();
      final overlay = tester.widget<CaptureBattleOverlay>(
        find.byType(CaptureBattleOverlay),
      );
      expect(overlay.appearance?.customSet?.id, _royalSet().id);
      final cinematicPieces = tester.widgetList<CustomPiece>(
        find.descendant(
          of: find.byType(CaptureBattleOverlay),
          matching: find.byType(CustomPiece),
        ),
      );
      expect(cinematicPieces.length, greaterThanOrEqualTo(2));
      expect(
        cinematicPieces.every((piece) => piece.chessSet.id == _royalSet().id),
        isTrue,
      );
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(client.state!.position.fen, game.position.fen);
      await tester.pumpWidget(const SizedBox());
      client.dispose();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CapturedPiecesPanel(
              pieces: game.capturedPieces,
              appearance: BoardAppearance.forPack(
                piecePacks.first,
              ).withCustomSet(library.active),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final captured = tester.widget<CustomPiece>(find.byType(CustomPiece));
      expect(captured.chessSet.id, _royalSet().id);
      expect(captured.piece, const Piece(color: Side.black, role: Role.pawn));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
