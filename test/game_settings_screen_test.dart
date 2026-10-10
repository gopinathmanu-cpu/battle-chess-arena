import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/online/online_game_screen.dart';
import 'package:battle_chess_arena/src/features/play/animation_lab_screen.dart';
import 'package:battle_chess_arena/src/features/play/board_appearance.dart';
import 'package:battle_chess_arena/src/features/play/captured_pieces_panel.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:battle_chess_arena/src/features/play/neon_live_game_layout.dart';
import 'package:battle_chess_arena/src/features/settings/game_settings_sheet.dart';
import 'package:battle_chess_arena/src/services/computer_player.dart';
import 'package:battle_chess_arena/src/services/game_display_settings.dart';
import 'package:battle_chess_arena/src/services/last_game_storage.dart';
import 'package:battle_chess_arena/src/services/online_match_client.dart';
import 'package:battle_chess_arena/src/services/theme_music.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/game_settings.dart';
import 'support/piece_choice.dart';
import 'theme_music_test.dart' show FakeMusicOutput;
import 'support/online_fixtures.dart';

const moves = ['e2e4', 'd7d5', 'e4d5', 'd8d5'];
const saved = SavedGame(
  mode: PlayerMode.local,
  homePack: PiecePackId.anime,
  difficulty: ComputerDifficulty.easy,
  moves: moves,
  whiteMilliseconds: 300000,
  blackMilliseconds: 300000,
  fastBattles: true,
  whitePack: PiecePackId.anime,
  blackPack: PiecePackId.greek,
  boardPack: PiecePackId.anime,
  updatedAtEpochMs: 1,
);

Future<void> _tapHeader(WidgetTester tester, String tooltip) async {
  final icon = find.byTooltip(tooltip);
  await tester.ensureVisible(icon);
  await tester.tap(icon);
}

Future<void> _openSettings(WidgetTester tester, {Finder? target}) async {
  await tester.ensureVisible(find.byTooltip('Game settings'));
  await openGameSettings(tester, target: target);
}

void main() {
  setUp(() {
    AnimationLabScreen.debugClockFactory = () =>
        TestWidgetsFlutterBinding.ensureInitialized().clock.stopwatch();
  });
  tearDown(() => AnimationLabScreen.debugClockFactory = null);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'music picker has eight choices and reset keeps the current game',
    (tester) async {
      final music = ThemeMusic(
        output: FakeMusicOutput(),
        saveMuted: (_) async {},
      );
      await tester.pumpWidget(
        MusicScope(
          controller: music,
          child: MaterialApp(
            home: AnimationLabScreen(pack: piecePacks.first, savedGame: saved),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Mute music'), findsOneWidget);
      await _tapHeader(tester, 'Mute music');
      await tester.pump();
      expect(music.muted, isTrue);
      expect(find.byTooltip('Unmute music'), findsOneWidget);
      await _tapHeader(tester, 'Unmute music');
      await tester.pump();
      expect(music.muted, isFalse);
      final fen = tester
          .widget<ChessBoard>(find.byType(ChessBoard))
          .position
          .fen;
      await _openSettings(
        tester,
        target: find.byKey(const ValueKey('background-music-theme')),
      );
      expect(find.byType(DropdownButton), findsNothing);
      expect(find.byType(DropdownButtonFormField), findsNothing);
      await tester.tap(find.byKey(const ValueKey('background-music-theme')));
      await tester.pumpAndSettle();
      expect(BackgroundMusic.values.length, 8);
      final choiceList = tester.widget<ListView>(
        find.byKey(const ValueKey('settings-choice-background music')),
      );
      expect(
        (choiceList.childrenDelegate as SliverChildListDelegate).children,
        hasLength(BackgroundMusic.values.length),
      );
      await tester.scrollUntilVisible(
        find.text(BackgroundMusic.zen.label),
        120,
        scrollable: find
            .descendant(
              of: find.byKey(
                const ValueKey('settings-choice-background music'),
              ),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text(BackgroundMusic.zen.label).last);
      await tester.pumpAndSettle();
      expect(music.selection, BackgroundMusic.zen);
      music.setMuted(true);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('reset-settings')),
        250,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('game-settings-list')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.byKey(const ValueKey('reset-settings')));
      await tester.pumpAndSettle();
      expect(music.selection, BackgroundMusic.theme);
      expect(music.muted, false);
      await tester.tap(find.byTooltip('Close settings'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ChessBoard>(find.byType(ChessBoard)).position.fen,
        fen,
      );
      final restored = await LastGameStorage.load();
      expect(restored!.moves, saved.moves);
      expect(restored.fastBattles, false);
      expect(restored.difficulty, ComputerDifficulty.medium);
      await tester.pumpWidget(const SizedBox());
      music.dispose();
    },
  );

  testWidgets(
    'settings are opt-in, dismissible and preserve the board, clock and captures',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: AnimationLabScreen(pack: piecePacks.first, savedGame: saved),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SwitchListTile), findsNothing);
      expect(find.byTooltip('Game settings'), findsOneWidget);
      final board = tester.widget<ChessBoard>(find.byType(ChessBoard));
      final boardRect = tester.getRect(find.byType(ChessBoard));
      final panel = tester.widget<CapturedPiecesPanel>(
        find.byType(CapturedPiecesPanel),
      );
      expect(panel.pieces!.length, 2);
      expect(find.text('Taken by White · 1'), findsOneWidget);
      expect(find.text('Taken by Black · 1'), findsOneWidget);
      final takenBlack = tester.widget<CharacterPiece>(
        find.descendant(
          of: find.byKey(const ValueKey('captured-white-0')),
          matching: find.byType(CharacterPiece),
        ),
      );
      expect(takenBlack.pack.id, PiecePackId.greek);

      await _openSettings(tester);
      final clock = tester
          .widget<NeonLiveStatusBar>(find.byType(NeonLiveStatusBar))
          .whiteTime;
      await tester.pump(const Duration(seconds: 3));
      expect(
        tester
            .widget<NeonLiveStatusBar>(find.byType(NeonLiveStatusBar))
            .whiteTime,
        clock - const Duration(seconds: 3),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('show-captured-pieces-toggle')),
        180,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('game-settings-list')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('show-captured-pieces-toggle')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const ValueKey('show-captured-pieces-toggle')),
            )
            .value,
        isFalse,
      );
      await tester.tap(find.byTooltip('Close settings'));
      await tester.pumpAndSettle();
      expect(find.byType(SwitchListTile), findsNothing);
      expect(find.byType(CapturedPiecesPanel), findsNothing);
      expect(
        tester.widget<ChessBoard>(find.byType(ChessBoard)).position.fen,
        board.position.fen,
      );
      expect(tester.getRect(find.byType(ChessBoard)), boardRect);

      await _tapHeader(tester, 'Hide top bar');
      await tester.pumpAndSettle();
      await _openSettings(tester);
      await tester.tap(
        find.byKey(const ValueKey('show-captured-pieces-toggle')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close settings'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CapturedPiecesPanel>(find.byType(CapturedPiecesPanel))
            .pieces!
            .length,
        2,
      );
      await _tapHeader(tester, 'Show top bar');
      await tester.pumpAndSettle();
      await _tapHeader(tester, 'Undo');
      await tester.pump();
      expect(
        tester
            .widget<CapturedPiecesPanel>(find.byType(CapturedPiecesPanel))
            .pieces!
            .length,
        1,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('board palette has two pickers, persists, and toggles alone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: AnimationLabScreen(pack: piecePacks.first)),
    );
    await tester.pumpAndSettle();
    final original = tester
        .widget<ChessBoard>(find.byType(ChessBoard))
        .appearance!;

    await _openSettings(
      tester,
      target: find.byKey(const ValueKey('choose-board-colors')),
    );
    await tester.tap(find.byKey(const ValueKey('choose-board-colors')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('light-square-color-picker')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dark-square-color-picker')),
      findsOneWidget,
    );
    await tester.tap(find.text('Ocean blue'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('apply-board-colors')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close settings'));
    await tester.pumpAndSettle();

    var appearance = tester
        .widget<ChessBoard>(find.byType(ChessBoard))
        .appearance!;
    expect(appearance.lightSquare, const Color(0xFFE0F4FF));
    expect(appearance.darkSquare, const Color(0xFF28668A));
    expect(appearance.white.id, original.white.id);
    expect(appearance.black.id, original.black.id);

    await tester.ensureVisible(
      find.byKey(const ValueKey('quick-board-color-toggle')),
    );
    await tester.tap(find.byKey(const ValueKey('quick-board-color-toggle')));
    await tester.pumpAndSettle();
    appearance = tester.widget<ChessBoard>(find.byType(ChessBoard)).appearance!;
    expect(appearance.lightSquare, original.lightSquare);
    expect(appearance.darkSquare, original.darkSquare);

    await tester.ensureVisible(
      find.byKey(const ValueKey('quick-board-color-toggle')),
    );
    await tester.tap(find.byKey(const ValueKey('quick-board-color-toggle')));
    await tester.pumpAndSettle();
    appearance = tester.widget<ChessBoard>(find.byType(ChessBoard)).appearance!;
    expect(appearance.lightSquare, const Color(0xFFE0F4FF));
    expect(appearance.darkSquare, const Color(0xFF28668A));
    await tester.pumpWidget(const SizedBox());

    final reopened = GameDisplaySettings();
    await tester.pump();
    expect(reopened.customBoardColorsEnabled, isTrue);
    expect(reopened.boardLightSquare, const Color(0xFFE0F4FF));
    expect(reopened.boardDarkSquare, const Color(0xFF28668A));
    reopened.dispose();
  });

  testWidgets(
    'online restores saved visibility, rebuilds reconnect captures, and clears on rematch',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        GameDisplaySettings.capturedPiecesKey: false,
      });
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final channel = FakeChannel();
      final client = OnlineMatchClient(
        channelFactory: (_) => channel,
        heartbeatInterval: const Duration(minutes: 5),
      );
      await client.connect(Uri.parse('ws://localhost:8080'));
      final game = GameSession.fromMoves(moves: moves);
      channel.seat(
        seat: 'b',
        state: stateJson(game: game),
      );
      await tester.pump();
      await tester.pumpWidget(
        MaterialApp(
          home: OnlineGameScreen(client: client, pack: piecePacks.first),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CapturedPiecesPanel), findsNothing);
      final sentCount = channel.sent.length;
      await _openSettings(tester);
      await tester.tap(
        find.byKey(const ValueKey('show-captured-pieces-toggle')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close settings'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(CapturedPiecesPanel),
        140,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('portrait-online-match-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      final panel = tester.widget<CapturedPiecesPanel>(
        find.byType(CapturedPiecesPanel),
      );
      expect(panel.playerSide, Side.black);
      expect(panel.pieces!.length, 2);
      expect(find.text('You captured · 1'), findsOneWidget);
      expect(find.text('Opponent captured · 1'), findsOneWidget);
      expect(channel.sent.length, sentCount);
      // A full reconnect snapshot can skip many states; captures must not be lost.
      expect(game.playUci('b1c3'), isNotNull);
      expect(game.playUci('d5d2'), isNotNull);
      channel.receive({
        'type': 'game_state',
        'synced': true,
        'state': stateJson(game: game, sequence: 6),
      });
      // d5d2 checks the king, whose check pulse deliberately keeps animating.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester
            .widget<CapturedPiecesPanel>(find.byType(CapturedPiecesPanel))
            .pieces!
            .length,
        3,
      );
      channel.receive({
        'type': 'game_state',
        'state': stateJson(round: 2, sequence: 7),
      });
      await tester.pumpAndSettle();
      await chooseGamePieces(tester);
      await tester.scrollUntilVisible(
        find.byType(CapturedPiecesPanel),
        140,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('portrait-online-match-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        tester
            .widget<CapturedPiecesPanel>(find.byType(CapturedPiecesPanel))
            .pieces,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      final beforeReset = client.state!.fen;
      final beforeResetMessages = channel.sent.length;
      await _openSettings(
        tester,
        target: find.byKey(const ValueKey('reset-settings')),
      );
      await tester.tap(find.byKey(const ValueKey('reset-settings')));
      await tester.pumpAndSettle();
      expect(client.state!.fen, beforeReset);
      expect(channel.sent.length, beforeResetMessages);
      await tester.tap(find.byTooltip('Close settings'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      client.dispose();
    },
  );

  for (final size in [const Size(320, 568), const Size(650, 360)]) {
    testWidgets('settings scroll and close at 2x text on $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final display = GameDisplaySettings();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: IconButton(
                  tooltip: 'Game settings',
                  icon: const Icon(Icons.settings),
                  onPressed: () => showGameSettings(
                    context: context,
                    display: display,
                    onCustomize: () {},
                    controls: (_) => [
                      for (var i = 0; i < 5; i++)
                        SwitchListTile(
                          title: Text('Setting $i'),
                          value: false,
                          onChanged: (_) {},
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _openSettings(tester, target: find.text('Setting 4'));
      expect(
        find.text('Setting 4').hitTestable(),
        findsOneWidget,
        reason:
            'Target ${tester.getRect(find.text('Setting 4'))}; list ${tester.getRect(find.byKey(const ValueKey('game-settings-list')))}',
      );
      expect(find.byTooltip('Close settings').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Close settings'));
      await tester.pumpAndSettle();
      expect(find.text('Game settings'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      display.dispose();
    });
  }
}
