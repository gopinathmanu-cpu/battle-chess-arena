// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:battle_chess_arena/src/domain/bot_tournament.dart';
import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/domain/game_time_control.dart';
import 'package:battle_chess_arena/src/domain/online_player_profile.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/online/online_avatar_image.dart';
import 'package:battle_chess_arena/src/features/play/animation_lab_screen.dart';
import 'package:battle_chess_arena/src/features/play/animated_accepted_capture_cues.dart';
import 'package:battle_chess_arena/src/features/play/capture_battle_overlay.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:battle_chess_arena/src/features/play/match_opponent_panel.dart';
import 'package:battle_chess_arena/src/features/play/neon_live_arena.dart';
import 'package:battle_chess_arena/src/features/play/neon_live_game_layout.dart';
import 'package:battle_chess_arena/src/features/tournaments/tournament_match_config.dart';
import 'package:battle_chess_arena/src/services/computer_player.dart';
import 'package:battle_chess_arena/src/services/game_history_storage.dart';
import 'package:battle_chess_arena/src/services/last_game_storage.dart';
import 'package:battle_chess_arena/src/services/theme_music.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme_music_test.dart' show FakeMusicOutput;

class _RoundComputer implements ComputerPlayer {
  ComputerDifficulty? difficulty;
  int? botLevel;

  @override
  Future<String?> bestMove(
    String fen, {
    ComputerDifficulty difficulty = ComputerDifficulty.medium,
    int? botLevel,
  }) async {
    this.difficulty = difficulty;
    this.botLevel = botLevel;
    return 'e7e5';
  }

  @override
  void dispose() {}
}

final _cup = builtInTournaments.first;
final _opponent = _cup.opponents.first;
final _neon = availablePiecePacks.singleWhere(
  (pack) => pack.id == PiecePackId.futuristic,
);
Finder _key(String key) => find.byKey(ValueKey(key));
ChessBoard _board(WidgetTester tester) =>
    tester.widget<ChessBoard>(find.byType(ChessBoard));

TournamentMatchConfig _match({BotTournament? cup, List<SavedGame>? saves}) {
  final event = cup ?? _cup;
  return TournamentMatchConfig(
    title: '${event.title} · ${event.roundName(0)}',
    opponent: event.opponents.first,
    minutesPerSide: event.minutesPerSide,
    cup: event,
    roundIndex: 0,
    save: (game, result) async => saves?.add(game),
  );
}

Future<void> _open(
  WidgetTester tester, {
  PiecePack? pack,
  bool animated = true,
  Size size = const Size(390, 844),
  double scale = 1,
  TournamentMatchConfig? match,
  bool tournament = true,
  PlayerMode mode = PlayerMode.computer,
  ComputerPlayer? computer,
  SavedGame? saved,
  ThemeMusic? music,
}) async {
  await tester.binding.setSurfaceSize(size);
  final app = MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: AnimationLabScreen(
      pack: pack ?? _neon,
      mode: mode,
      computerPlayer: computer ?? _RoundComputer(),
      savedGame: saved,
      tournamentMatch: tournament ? match ?? _match() : null,
      initialClassicPieces: !animated,
      initialAnimatedArena: animated,
      initialClassicStyle: ClassicPieceStyle.wood,
      timeControl: GameTimeControl.practice,
    ),
  );
  await tester.pumpWidget(
    music == null ? app : MusicScope(controller: music, child: app),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void _panelTest(String name, Future<void> Function(WidgetTester) body) =>
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        var drained = false;
        GameHistoryStorage().loadSnapshot().then((_) => drained = true);
        for (var frame = 0; !drained && frame < 80; frame++) {
          await tester.pump(const Duration(milliseconds: 10));
        }
        expect(drained, isTrue);
        await tester.binding.setSurfaceSize(null);
      }
    });

void _expectOpponent(WidgetTester tester) {
  expect(find.byType(MatchOpponentPanel), findsOneWidget);
  expect(_key('tournament-opponent'), findsOneWidget);
  expect(_key('opponent-profile'), findsOneWidget);
  expect(find.byType(NeonLiveArena), findsNothing);
  final panel = tester.widget<MatchOpponentPanel>(
    find.byType(MatchOpponentPanel),
  );
  expect(panel.name, _opponent.name);
  expect(panel.details, contains(_opponent.difficultyLabel));
  expect(panel.details, contains('Computer'));
  expect(panel.details, contains('You play White'));
  final avatar = tester.widget<OnlineAvatarImage>(
    find.descendant(
      of: find.byType(MatchOpponentPanel),
      matching: find.byType(OnlineAvatarImage),
    ),
  );
  expect(avatar.avatarId, _opponent.avatarId);
  expect(tester.takeException(), isNull);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AnimationLabScreen.debugClockFactory = () =>
        TestWidgetsFlutterBinding.ensureInitialized().clock.stopwatch();
  });
  tearDown(() => AnimationLabScreen.debugClockFactory = null);

  _panelTest(
    'Tournament Classic swipe stays Classic until explicit mode toggle',
    (tester) async {
      await _open(tester, animated: false);
      expect(_board(tester).appearance?.standardPieces, isTrue);
      expect(_board(tester).appearance?.animatedArena, isFalse);
      final firstStyle = _board(tester).appearance!.classicStyle;
      _board(tester).onSetSwipe!(1);
      await tester.pump();
      await tester.pump();
      expect(_board(tester).appearance?.classicStyle, isNot(firstStyle));
      expect(_board(tester).appearance?.animatedArena, isFalse);
      await tester.tap(_key('quick-piece-style-toggle'));
      await tester.pump();
      await tester.pump();
      expect(_board(tester).appearance?.animatedArena, isTrue);
      expect(_board(tester).appearance?.standardPieces, isFalse);
      await tester.tap(_key('quick-piece-style-toggle'));
      await tester.pump();
      await tester.pump();
      expect(_board(tester).appearance?.animatedArena, isFalse);
      expect(_board(tester).appearance?.standardPieces, isTrue);
    },
  );

  SavedGame captureOpening({required bool animated}) => SavedGame(
    mode: PlayerMode.computer,
    humanSide: Side.white,
    homePack: _neon.id,
    difficulty: ComputerDifficulty.easy,
    moves: const ['e2e4', 'd7d5'],
    whiteMilliseconds: 600000,
    blackMilliseconds: 600000,
    fastBattles: false,
    classicPieces: !animated,
    animatedArena: animated,
    classicStyle: ClassicPieceStyle.wood,
    whitePack: _neon.id,
    blackPack: _neon.id,
    boardPack: _neon.id,
    updatedAtEpochMs: 1,
    timeControl: GameTimeControl.practice,
  );

  _panelTest(
    'Tournament Animated capture owns one attack and its 391ms impact after Skip',
    (tester) async {
      final output = FakeMusicOutput();
      final music = ThemeMusic(output: output, saveMuted: (_) async {});
      addTearDown(music.dispose);
      await _open(tester, saved: captureOpening(animated: true), music: music);
      _expectOpponent(tester);
      expect(output.effects, isEmpty);
      _board(tester).onSquareTap(Square.e4);
      await tester.pump();
      expect(output.effects, isEmpty);
      _board(tester).onSquareTap(Square.d5);
      await tester.pump();
      expect(
        tester
            .widget<AnimatedAcceptedCaptureCues>(
              _key('tournament-accepted-capture-cues'),
            )
            .enabled,
        isTrue,
      );
      expect(
        tester
            .widget<CaptureBattleOverlay>(find.byType(CaptureBattleOverlay))
            .liveArena,
        isTrue,
      );
      expect(output.effects, [CinematicSound.attack]);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(_key('live-capture-skip'));
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
      _expectOpponent(tester);
    },
  );

  _panelTest(
    'Tournament Classic capture keeps its full overlay as the only sound owner',
    (tester) async {
      final output = FakeMusicOutput();
      final music = ThemeMusic(output: output, saveMuted: (_) async {});
      addTearDown(music.dispose);
      await _open(
        tester,
        animated: false,
        saved: captureOpening(animated: false),
        music: music,
      );
      _expectOpponent(tester);
      expect(output.effects, isEmpty);
      _board(tester).onSquareTap(Square.e4);
      await tester.pump();
      _board(tester).onSquareTap(Square.d5);
      await tester.pump();
      expect(
        tester
            .widget<AnimatedAcceptedCaptureCues>(
              _key('tournament-accepted-capture-cues'),
            )
            .enabled,
        isFalse,
      );
      expect(
        tester
            .widget<CaptureBattleOverlay>(find.byType(CaptureBattleOverlay))
            .liveArena,
        isFalse,
      );
      expect(output.effects, [CinematicSound.attack]);
      final impactDelay = Duration(
        milliseconds:
            (captureBattleDuration(reduced: false, fast: false).inMilliseconds *
                    .32)
                .round(),
      );
      await tester.pump(impactDelay - const Duration(milliseconds: 1));
      expect(output.effects, [CinematicSound.attack]);
      await tester.pump(const Duration(milliseconds: 1));
      expect(output.effects, [
        CinematicSound.attack,
        CinematicSound.lightImpact,
      ]);
      await tester.pump(const Duration(milliseconds: 1100));
      expect(output.effects, [
        CinematicSound.attack,
        CinematicSound.lightImpact,
      ]);
      _expectOpponent(tester);
    },
  );

  for (final pack in availablePiecePacks) {
    _panelTest('${pack.name} Tournament shows opponent above its board', (
      tester,
    ) async {
      await _open(tester, pack: pack);
      _expectOpponent(tester);
      final panel = tester.getRect(find.byType(MatchOpponentPanel));
      final board = tester.getRect(find.byType(ChessBoard));
      expect(panel.bottom, lessThanOrEqualTo(board.top));
      expect(panel.height, lessThan(160));
      expect(board.width, closeTo(board.height, .01));
      expect(board.bottom, lessThanOrEqualTo(844));
      expect(_key('use-computer-lifeline').hitTestable(), findsOneWidget);
      expect(_key('analyse-threats').hitTestable(), findsOneWidget);
      expect(_board(tester).appearance!.white.id, pack.id);
      expect(_board(tester).appearance!.standardPieces, isFalse);
      await tester.drag(find.byType(ChessBoard), const Offset(-140, 0));
      await tester.pumpAndSettle();
      expect(_board(tester).appearance!.standardPieces, isTrue);
      _expectOpponent(tester);
    });
  }

  for (final animated in [true, false]) {
    for (final size in [const Size(320, 568), const Size(390, 844)]) {
      _panelTest(
        '${animated ? 'Animated' : 'Classic'} Tournament fits opponent and board at $size with enlarged text',
        (tester) async {
          await _open(tester, animated: animated, size: size, scale: 2);
          _expectOpponent(tester);
          final panel = tester.getRect(find.byType(MatchOpponentPanel));
          final board = tester.getRect(find.byType(ChessBoard));
          expect(panel.left, greaterThanOrEqualTo(0));
          expect(panel.right, lessThanOrEqualTo(size.width));
          expect(panel.bottom, lessThanOrEqualTo(board.top));
          expect(board.width, closeTo(board.height, .01));
          expect(board.bottom, lessThanOrEqualTo(size.height));
          expect(_board(tester).appearance!.standardPieces, !animated);
          expect(_board(tester).appearance!.animatedArena, animated);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final animated in [true, false]) {
    for (final (size, scale) in [
      (const Size(844, 390), 1.0),
      (const Size(640, 360), 2.0),
    ]) {
      _panelTest(
        '${animated ? 'Animated' : 'Classic'} Tournament landscape keeps a full board and swaps its opponent at $size / $scale',
        (tester) async {
          await _open(tester, animated: animated, size: size, scale: scale);
          _expectOpponent(tester);
          final panel = tester.getRect(find.byType(MatchOpponentPanel));
          final board = tester.getRect(find.byType(ChessBoard));
          final fen = _board(tester).position.fen;
          expect(panel.right, lessThanOrEqualTo(board.left));
          expect(board.width, closeTo(board.height, .01));
          expect(board.right, lessThanOrEqualTo(size.width));
          expect(board.bottom, lessThanOrEqualTo(size.height));
          expect(_key('use-computer-lifeline').hitTestable(), findsOneWidget);
          expect(_key('analyse-threats').hitTestable(), findsOneWidget);
          await tester.tap(_key('neon-live-swap-panels'));
          await tester.pumpAndSettle();
          final swappedPanel = tester.getRect(find.byType(MatchOpponentPanel));
          final swappedBoard = tester.getRect(find.byType(ChessBoard));
          expect(swappedBoard.right, lessThanOrEqualTo(swappedPanel.left));
          expect(swappedBoard.size, board.size);
          expect(_board(tester).position.fen, fen);
          _expectOpponent(tester);
        },
      );
    }
  }

  _panelTest(
    'Tournament moves retain bot strength and saving behind the panel',
    (tester) async {
      final computer = _RoundComputer();
      final saves = <SavedGame>[];
      await _open(
        tester,
        computer: computer,
        match: _match(saves: saves),
      );
      _board(tester).onSquareTap(Square.e2);
      await tester.pump();
      expect(_board(tester).selected, Square.e2);
      _expectOpponent(tester);
      _board(tester).onSquareTap(Square.e4);
      await tester.pump();
      for (
        var frame = 0;
        _board(tester).position.board.pieceAt(Square.e5) != Piece.blackPawn &&
            frame < 200;
        frame++
      ) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(_board(tester).position.board.pieceAt(Square.e4), Piece.whitePawn);
      expect(_board(tester).position.board.pieceAt(Square.e5), Piece.blackPawn);
      expect(computer.difficulty, tournamentDifficulty(_opponent.level));
      expect(computer.botLevel, _opponent.botLevel);
      expect(
        saves.any((saved) => saved.moves.join(' ') == 'e2e4 e7e5'),
        isTrue,
      );
      _expectOpponent(tester);
    },
  );

  for (final mode in [PlayerMode.computer, PlayerMode.local]) {
    _panelTest('$mode keeps its ordinary Animated action stage', (
      tester,
    ) async {
      await _open(tester, tournament: false, mode: mode);
      expect(find.byType(NeonLiveArena), findsOneWidget);
      expect(find.byType(MatchOpponentPanel), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  _panelTest('Animated Conquests retain their battle panel', (tester) async {
    const conquest = BotTournament(
      id: 'animated-conquest-panel-fixture',
      title: 'Animated campaign',
      description: 'A saved Fantasy campaign',
      level: OnlinePlayerLevel.beginner,
      conquestArmyIds: [PiecePackId.anime],
    );
    await _open(
      tester,
      pack: availablePiecePacks.first,
      match: _match(cup: conquest),
    );
    expect(find.byType(NeonLiveArena), findsOneWidget);
    expect(find.byType(MatchOpponentPanel), findsNothing);
    expect(
      tester
          .widget<NeonLiveGameLayout>(find.byType(NeonLiveGameLayout))
          .compactPortraitArena,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });
}
