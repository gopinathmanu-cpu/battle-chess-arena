// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/domain/game_time_control.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/online/online_game_screen.dart';
import 'package:battle_chess_arena/src/features/play/animation_lab_screen.dart';
import 'package:battle_chess_arena/src/features/play/capture_battle_overlay.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:battle_chess_arena/src/features/play/neon_illustrated_stage.dart';
import 'package:battle_chess_arena/src/features/play/neon_live_arena.dart';
import 'package:battle_chess_arena/src/services/computer_player.dart';
import 'package:battle_chess_arena/src/services/game_history_storage.dart';
import 'package:battle_chess_arena/src/services/last_game_storage.dart';
import 'package:battle_chess_arena/src/services/match_appearance_storage.dart';
import 'package:battle_chess_arena/src/services/online_match_client.dart';
import 'package:battle_chess_arena/src/services/theme_music.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/online_fixtures.dart';

class _MusicOutput implements MusicOutput {
  final effects = <CinematicSound>[];

  @override
  Future<void> play(
    PiecePackId theme, {
    BackgroundMusic selection = BackgroundMusic.theme,
  }) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> playEffect(CinematicSound effect) async => effects.add(effect);

  @override
  Future<void> dispose() async {}
}

Future<void> _openOffline(
  WidgetTester tester,
  ThemeMusic music, {
  required bool reduced,
  List<String> moves = const ['e2e4', 'd7d5'],
}) async {
  SharedPreferences.setMockInitialValues({});
  await tester.binding.setSurfaceSize(const Size(390, 844));
  final pack = piecePacks.singleWhere(
    (pack) => pack.id == PiecePackId.futuristic,
  );
  await tester.pumpWidget(
    MusicScope(
      controller: music,
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
          child: child!,
        ),
        home: AnimationLabScreen(
          pack: pack,
          mode: PlayerMode.local,
          timeControl: GameTimeControl.practice,
          savedGame: SavedGame(
            mode: PlayerMode.local,
            humanSide: Side.white,
            homePack: pack.id,
            difficulty: ComputerDifficulty.medium,
            moves: moves,
            whiteMilliseconds: 600000,
            blackMilliseconds: 600000,
            fastBattles: false,
            whitePack: pack.id,
            blackPack: pack.id,
            boardPack: pack.id,
            updatedAtEpochMs: 1,
            timeControl: GameTimeControl.practice,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _capture(
  WidgetTester tester,
  ThemeMusic music, {
  required bool reduced,
}) async {
  await _openOffline(tester, music, reduced: reduced);
  await tester.tap(find.byKey(const ValueKey('square-e4')));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('square-d5')));
  await tester.pump();
  final overlay = tester.widget<CaptureBattleOverlay>(
    find.byType(CaptureBattleOverlay),
  );
  expect(overlay.liveArena, isTrue);
  expect(overlay.battle.san, 'exd5');
  expect(overlay.reduced, reduced);
}

Future<void> _close(
  WidgetTester tester,
  ThemeMusic music, {
  OnlineMatchClient? client,
}) async {
  await tester.pumpWidget(const SizedBox());
  client?.dispose();
  music.dispose();
  await tester.pump();
  var drained = false;
  Future.wait([
    GameHistoryStorage().loadSnapshot(),
    MatchAppearanceStorage.load('room', 'w'),
    if (client != null) client.gameArchive.pending,
  ]).then((_) => drained = true);
  for (var attempt = 0; !drained && attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(drained, isTrue);
}

void main() {
  testWidgets(
    'Animated live capture impact follows its 391ms landing exactly once',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final output = _MusicOutput();
      final music = ThemeMusic(output: output, saveMuted: (_) async {});
      await _capture(tester, music, reduced: false);
      expect(output.effects, [CinematicSound.attack]);
      await tester.pump(const Duration(milliseconds: 390));
      expect(output.effects, [CinematicSound.attack]);
      expect(find.byType(CaptureBattleOverlay), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      expect(output.effects, [
        CinematicSound.attack,
        CinematicSound.lightImpact,
      ]);
      await tester.pump(const Duration(milliseconds: 459));
      expect(output.effects, [
        CinematicSound.attack,
        CinematicSound.lightImpact,
      ]);
      expect(tester.takeException(), isNull);
      await _close(tester, music);
    },
  );

  testWidgets(
    'Reduced Animated capture sounds immediately once through overlay removal',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final output = _MusicOutput();
      final music = ThemeMusic(output: output, saveMuted: (_) async {});
      await _capture(tester, music, reduced: true);
      expect(output.effects, [
        CinematicSound.attack,
        CinematicSound.lightImpact,
      ]);
      await tester.pump(const Duration(milliseconds: 324));
      expect(find.byType(CaptureBattleOverlay), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byType(CaptureBattleOverlay), findsNothing);
      await tester.pump(const Duration(milliseconds: 100));
      expect(output.effects, [
        CinematicSound.attack,
        CinematicSound.lightImpact,
      ]);
      expect(tester.takeException(), isNull);
      await _close(tester, music);
    },
  );

  testWidgets(
    'Skipping compact overlay preserves the Animated arena landing sound',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final output = _MusicOutput();
      final music = ThemeMusic(output: output, saveMuted: (_) async {});
      await _capture(tester, music, reduced: false);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const ValueKey('live-capture-skip')));
      await tester.pump();
      expect(find.byType(CaptureBattleOverlay), findsNothing);
      await tester.pump(const Duration(milliseconds: 290));
      expect(output.effects, [CinematicSound.attack]);
      await tester.pump(const Duration(milliseconds: 1));
      expect(output.effects, [
        CinematicSound.attack,
        CinematicSound.lightImpact,
      ]);
      await tester.pump(const Duration(seconds: 1));
      expect(output.effects, [
        CinematicSound.attack,
        CinematicSound.lightImpact,
      ]);
      expect(tester.takeException(), isNull);
      await _close(tester, music);
    },
  );

  testWidgets(
    'Background pauses Animated impact until the visible landing resumes',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final output = _MusicOutput();
      final music = ThemeMusic(output: output, saveMuted: (_) async {});
      await _capture(tester, music, reduced: false);
      await tester.pump(const Duration(milliseconds: 100));
      music.setActive(false);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 3));
      expect(output.effects, [CinematicSound.attack]);
      music.setActive(true);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 290));
      expect(output.effects, [CinematicSound.attack]);
      await tester.pump(const Duration(milliseconds: 2));
      expect(output.effects, [
        CinematicSound.attack,
        CinematicSound.lightImpact,
      ]);
      await tester.pump(const Duration(seconds: 1));
      expect(output.effects, [
        CinematicSound.attack,
        CinematicSound.lightImpact,
      ]);
      expect(tester.takeException(), isNull);
      await _close(tester, music);
    },
  );

  testWidgets(
    'Restoring a saved capture remains silent instead of replaying its strike',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final output = _MusicOutput();
      final music = ThemeMusic(output: output, saveMuted: (_) async {});
      await _openOffline(
        tester,
        music,
        reduced: false,
        moves: const ['e2e4', 'd7d5', 'e4d5'],
      );
      expect(find.byType(CaptureBattleOverlay), findsNothing);
      final restored = tester
          .widget<NeonLiveArena>(find.byType(NeonLiveArena))
          .action!;
      expect(restored.isSelection, isFalse);
      expect(restored.source, Square.e4);
      expect(restored.target, Square.d5);
      expect(
        restored.captured,
        const Piece(color: Side.black, role: Role.pawn),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(output.effects, isEmpty);
      music.setActive(false);
      music.setActive(true);
      await tester.pump(const Duration(seconds: 1));
      expect(output.effects, isEmpty);
      expect(tester.takeException(), isNull);
      await _close(tester, music);
    },
  );

  testWidgets(
    'Threat scan restores last-capture facts without replaying their sound',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final output = _MusicOutput();
      final music = ThemeMusic(output: output, saveMuted: (_) async {});
      await _capture(tester, music, reduced: false);
      await tester.pump(const Duration(milliseconds: 1600));
      expect(output.effects, [
        CinematicSound.attack,
        CinematicSound.lightImpact,
      ]);
      final position = tester
          .widget<ChessBoard>(find.byType(ChessBoard))
          .position
          .fen;
      final settledVictim = tester
          .widget<Opacity>(
            find.byKey(const ValueKey('neon-live-defeat-opacity')),
          )
          .opacity;
      await tester.tap(find.byKey(const ValueKey('square-g8')));
      await tester.pump();
      expect(
        tester
            .widget<NeonLiveArena>(find.byType(NeonLiveArena))
            .action!
            .isSelection,
        isTrue,
      );
      final enteringActor = tester.getRect(
        find.byKey(const ValueKey('neon-live-right-figure')),
      );
      await tester.pump(const Duration(milliseconds: 90));
      expect(
        tester
            .getRect(find.byKey(const ValueKey('neon-live-right-figure')))
            .center
            .dx,
        closeTo(enteringActor.center.dx, .01),
        reason: 'A new selection shows a stationary avatar.',
      );
      await tester.tap(find.byKey(const ValueKey('analyse-threats')));
      await tester.pump();
      final restored = tester
          .widget<NeonLiveArena>(find.byType(NeonLiveArena))
          .action!;
      expect(restored.isSelection, isFalse);
      expect(restored.source, Square.e4);
      expect(restored.target, Square.d5);
      final settledActor = tester.widget<NeonFigureSprite>(
        find.byKey(const ValueKey('neon-live-left-figure')),
      );
      expect(settledActor.pose, NeonFigurePose.rest);
      expect(settledActor.poseBlend, 1);
      expect(
        find.byKey(const ValueKey('neon-live-capture-winner')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Opacity>(
              find.byKey(const ValueKey('neon-live-defeat-opacity')),
            )
            .opacity,
        settledVictim,
      );
      expect(
        tester.widget<ChessBoard>(find.byType(ChessBoard)).position.fen,
        position,
      );
      expect(find.byKey(const ValueKey('board-moving-e4-d5')), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      expect(output.effects, [
        CinematicSound.attack,
        CinematicSound.lightImpact,
      ]);
      expect(tester.takeException(), isNull);
      await _close(tester, music);
    },
  );

  testWidgets(
    'Accepted online capture sounds once across ACK and clock-only revisions',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final output = _MusicOutput();
      final music = ThemeMusic(output: output, saveMuted: (_) async {});
      final channel = FakeChannel();
      final client = OnlineMatchClient(channelFactory: (_) => channel);
      await client.connect(Uri.parse('ws://localhost:8080'));
      final game = GameSession.fromMoves(moves: ['e2e4', 'd7d5']);
      channel.seat(state: stateJson(game: game));
      await tester.pump();
      await tester.pumpWidget(
        MusicScope(
          controller: music,
          child: MaterialApp(
            home: OnlineGameScreen(
              client: client,
              pack: piecePacks.singleWhere(
                (pack) => pack.id == PiecePackId.futuristic,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('square-e4')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('square-d5')));
      await tester.pump();
      expect(
        output.effects,
        isEmpty,
        reason: 'Pending requests must not sound like accepted moves.',
      );
      final command = channel.sent.lastWhere(
        (frame) => frame['type'] == 'move',
      );
      game.playUci('e4d5');
      channel.receive({
        'type': 'game_state',
        'state': stateJson(game: game, sequence: 2),
      });
      await tester.pump();
      expect(output.effects, [CinematicSound.attack]);
      await tester.pump(const Duration(milliseconds: 100));
      channel.receive({
        'type': 'command_result',
        'commandId': command['commandId'],
        'accepted': true,
      });
      channel.receive({
        'type': 'game_state',
        'state': stateJson(game: game, sequence: 3, blackMs: 59000),
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 290));
      expect(output.effects, [CinematicSound.attack]);
      await tester.pump(const Duration(milliseconds: 1));
      expect(output.effects, [
        CinematicSound.attack,
        CinematicSound.lightImpact,
      ]);
      channel.receive({
        'type': 'game_state',
        'state': stateJson(game: game, sequence: 4, blackMs: 58000),
      });
      await tester.pump(const Duration(seconds: 1));
      expect(output.effects, [
        CinematicSound.attack,
        CinematicSound.lightImpact,
      ]);
      expect(tester.takeException(), isNull);
      await _close(tester, music, client: client);
    },
  );
}
