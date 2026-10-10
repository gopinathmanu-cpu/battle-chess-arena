import 'package:battle_chess_arena/src/domain/animated_army_theme.dart';
import 'package:battle_chess_arena/src/domain/cinematic_replay.dart';
import 'package:battle_chess_arena/src/domain/custom_chess_set.dart';
import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/domain/neon_live_action.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/domain/piece_selection_commentary.dart';
import 'package:battle_chess_arena/src/features/play/board_appearance.dart';
import 'package:battle_chess_arena/src/features/play/animated_move_timing.dart';
import 'package:battle_chess_arena/src/features/play/neon_illustrated_stage.dart';
import 'package:battle_chess_arena/src/features/play/neon_live_arena.dart';
import 'package:battle_chess_arena/src/services/theme_music.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Position position(List<String> moves) =>
    GameSession.fromMoves(moves: moves).position;

NeonLiveAction moveAction(List<String> moves, Side viewer) {
  final scene = CinematicReplay.fromMoves(moves: moves).scenes.last;
  return NeonLiveAction.move(
    before: scene.before,
    after: scene.after,
    resolution: scene.resolution,
    viewerSide: viewer,
  )!;
}

Future<void> showArena(
  WidgetTester tester, {
  required Position position,
  NeonLiveAction? action,
  Side viewer = Side.white,
  bool reduced = true,
  Size size = const Size(390, 240),
  double textScale = 1,
  AnimatedArmyTheme theme = AnimatedArmyTheme.neon,
  ThemeMusic? music,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) {
          final child = SizedBox(
            width: size.width,
            height: size.height,
            child: NeonLiveArena(
              position: position,
              action: action,
              viewerSide: viewer,
              reducedMotion: reduced,
              theme: theme,
            ),
          );
          return music == null
              ? child
              : MusicScope(controller: music, child: child);
        },
      ),
    ),
  );
  await tester.pump();
}

NeonFigureSprite figure(WidgetTester tester, String lane) => tester
    .widget<NeonFigureSprite>(find.byKey(ValueKey('neon-live-$lane-figure')));

double mirror(WidgetTester tester, String lane) => tester
    .widget<Transform>(
      find.descendant(
        of: find.byKey(ValueKey('neon-live-$lane-figure')),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Transform &&
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'neon-figure-mirror-',
              ),
        ),
      ),
    )
    .transform
    .storage[0];

class _CaptureMusicOutput implements MusicOutput {
  final effects = <CinematicSound>[];
  @override
  Future<void> play(
    PiecePackId theme, {
    BackgroundMusic selection = BackgroundMusic.theme,
  }) async {}
  @override
  Future<void> playEffect(CinematicSound effect) async {
    effects.add(effect);
  }

  @override
  Future<void> pause() async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  for (final theme in AnimatedArmyTheme.values) {
    for (final moves in [
      ['g1f3'],
      ['g1f3', 'g8f6'],
    ]) {
      testWidgets(
        '${theme.name} ${moves.length == 1 ? 'White' : 'Black'} knight lands its only leap before holding position',
        (tester) async {
          final scene = CinematicReplay.fromMoves(moves: moves).scenes.last;
          final action = moveAction(moves, Side.white);
          final output = _CaptureMusicOutput();
          final music = ThemeMusic(output: output, saveMuted: (_) async {});
          addTearDown(music.dispose);
          await showArena(
            tester,
            position: scene.before,
            reduced: false,
            theme: theme,
            music: music,
          );
          await showArena(
            tester,
            position: scene.before,
            action: NeonLiveAction.selection(
              position: scene.before,
              source: scene.source,
            ),
            reduced: false,
            theme: theme,
            music: music,
          );
          await showArena(
            tester,
            position: scene.after,
            action: action,
            reduced: false,
            theme: theme,
            music: music,
          );
          final actor = find.byKey(
            ValueKey(
              'neon-live-${action.actorOnLeft ? 'left' : 'right'}-figure',
            ),
          );
          final start = tester.getRect(actor);
          await tester.pump(const Duration(milliseconds: 196));
          final inFlight = tester.getRect(actor);
          expect(
            action.actorOnLeft
                ? inFlight.center.dx > start.center.dx
                : inFlight.center.dx < start.center.dx,
            isTrue,
          );
          expect(
            tester
                .widget<Transform>(
                  find.byKey(const ValueKey('neon-live-actor-pose')),
                )
                .transform
                .storage[13],
            lessThan(0),
          );
          await tester.pump(const Duration(milliseconds: 196));
          final landed = tester.getRect(actor);
          final shift = tester
              .widget<Transform>(
                find.byKey(const ValueKey('neon-live-actor-pose')),
              )
              .transform
              .clone();
          final lean = tester
              .widget<Transform>(
                find.byKey(const ValueKey('neon-live-actor-lean')),
              )
              .transform
              .clone();
          expect(
            shift.storage[13],
            0,
            reason: 'The primary leap reaches the ground at board landing.',
          );
          expect(lean.storage[1], 0);
          for (final elapsed in [50, 180, 228, 1000]) {
            await tester.pump(Duration(milliseconds: elapsed));
            expect(tester.getRect(actor), landed);
            expect(
              tester
                  .widget<Transform>(
                    find.byKey(const ValueKey('neon-live-actor-pose')),
                  )
                  .transform,
              shift,
            );
            expect(
              tester
                  .widget<Transform>(
                    find.byKey(const ValueKey('neon-live-actor-lean')),
                  )
                  .transform,
              lean,
            );
          }
          expect(
            figure(tester, action.actorOnLeft ? 'left' : 'right').faceRight,
            action.actorOnLeft,
          );
          expect(
            find.byKey(const ValueKey('neon-live-capture-defeated')),
            findsNothing,
          );
          expect(output.effects, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  for (final theme in AnimatedArmyTheme.values) {
    for (final fixture in [
      ('White kingside', '5k2/8/8/8/8/8/8/4K2R w K - 0 1', 'e1g1', Side.white),
      ('Black queenside', 'r3k3/8/8/8/8/8/8/3K4 b q - 0 1', 'e8c8', Side.white),
    ]) {
      testWidgets(
        '${theme.name} ${fixture.$1} castle commits two allied figures with no capture cues',
        (tester) async {
          final before = Chess.fromSetup(Setup.parseFen(fixture.$2));
          final session = GameSession(position: before);
          final resolution = session.playUci(fixture.$3)!;
          final output = _CaptureMusicOutput();
          final music = ThemeMusic(output: output, saveMuted: (_) async {});
          addTearDown(music.dispose);
          await showArena(
            tester,
            position: before,
            viewer: fixture.$4,
            reduced: false,
            theme: theme,
            music: music,
          );
          await showArena(
            tester,
            position: before,
            action: NeonLiveAction.selection(
              position: before,
              source: resolution.move.from,
              viewerSide: fixture.$4,
            ),
            viewer: fixture.$4,
            reduced: false,
            theme: theme,
            music: music,
          );
          expect(
            find.byKey(const ValueKey('neon-live-selection-comment')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('neon-live-castling-rook')),
            findsNothing,
          );
          final action = NeonLiveAction.move(
            before: before,
            after: session.position,
            resolution: resolution,
            viewerSide: fixture.$4,
          )!;
          await showArena(
            tester,
            position: session.position,
            action: action,
            viewer: fixture.$4,
            reduced: false,
            theme: theme,
            music: music,
          );
          expect(
            find.byKey(const ValueKey('animated-live-castling')),
            findsOneWidget,
          );
          expect(find.textContaining('CASTLING'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('neon-live-selection-comment')),
            findsNothing,
          );
          final lane = action.actorOnLeft ? 'left' : 'right';
          final king = figure(tester, lane);
          final rook = tester.widget<NeonFigureSprite>(
            find.byKey(const ValueKey('neon-live-castling-rook')),
          );
          expect(king.piece.role, Role.king);
          expect(rook.piece, Piece(color: before.turn, role: Role.rook));
          expect(king.bodyHeight, rook.bodyHeight);
          expect(king.faceRight, action.actorOnLeft);
          expect(rook.faceRight, action.actorOnLeft);
          final kingStart = tester.getRect(
            find.byKey(const ValueKey('animated-castling-king-motion')),
          );
          final rookStart = tester.getRect(
            find.byKey(const ValueKey('animated-castling-rook-motion')),
          );
          await tester.pump(const Duration(milliseconds: 400));
          expect(
            tester.getRect(
              find.byKey(const ValueKey('animated-castling-king-motion')),
            ),
            isNot(kingStart),
          );
          expect(
            tester.getRect(
              find.byKey(const ValueKey('animated-castling-rook-motion')),
            ),
            isNot(rookStart),
          );
          expect(
            find.byKey(const ValueKey('neon-live-capture-defeated')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('neon-live-capture-winner')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('neon-live-action-emphasis')),
            findsNothing,
          );
          await tester.pump(const Duration(milliseconds: 450));
          final settled = tester.getRect(
            find.byKey(const ValueKey('animated-castling-king-motion')),
          );
          await tester.pump(const Duration(seconds: 1));
          expect(
            tester.getRect(
              find.byKey(const ValueKey('animated-castling-king-motion')),
            ),
            settled,
          );
          expect(output.effects, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  for (final theme in AnimatedArmyTheme.values) {
    for (final viewer in Side.values) {
      testWidgets(
        '${theme.name} ${viewer.name} avatar replies stay fixed until a new selection',
        (tester) async {
          final board = viewer == Side.white
              ? Chess.initial
              : position(['e2e4']);
          final source = viewer == Side.white ? Square.g1 : Square.g8;
          final action = NeonLiveAction.selection(
            position: board,
            source: source,
            viewerSide: viewer,
          )!;
          final output = _CaptureMusicOutput();
          final music = ThemeMusic(output: output, saveMuted: (_) async {});
          addTearDown(music.dispose);
          await showArena(
            tester,
            position: board,
            action: action,
            viewer: viewer,
            theme: theme,
            reduced: false,
            music: music,
          );
          final avatar = find.byKey(const ValueKey('neon-live-left-figure'));
          final bounds = tester.getRect(avatar);
          final reply = tester
              .widget<Text>(
                find.byKey(const ValueKey('neon-live-selection-comment')),
              )
              .data!;
          expect(
            pieceSelectionCommentary(
              position: board,
              action: action,
              theme: theme,
            ),
            contains(reply),
          );
          expect(figure(tester, 'left').faceRight, isTrue);
          expect(
            find.byKey(const ValueKey('neon-live-right-figure')),
            findsNothing,
          );
          await tester.pump(const Duration(seconds: 3));
          expect(tester.getRect(avatar), bounds);
          await showArena(
            tester,
            position: board,
            action: NeonLiveAction.selection(
              position: board,
              source: source,
              viewerSide: viewer,
            ),
            viewer: viewer,
            theme: theme,
            reduced: false,
            music: music,
          );
          expect(
            tester
                .widget<Text>(
                  find.byKey(const ValueKey('neon-live-selection-comment')),
                )
                .data,
            reply,
          );
          expect(tester.getRect(avatar), bounds);
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          await tester.pump(const Duration(seconds: 2));
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pump(const Duration(seconds: 1));
          expect(tester.getRect(avatar), bounds);
          expect(
            tester
                .widget<Text>(
                  find.byKey(const ValueKey('neon-live-selection-comment')),
                )
                .data,
            reply,
          );
          expect(output.effects, isEmpty);
          await showArena(
            tester,
            position: board,
            viewer: viewer,
            theme: theme,
            music: music,
          );
          expect(
            find.byKey(const ValueKey('neon-live-selection-bubble')),
            findsNothing,
          );
          await showArena(
            tester,
            position: board,
            action: action,
            viewer: viewer,
            theme: theme,
            music: music,
          );
          expect(
            tester
                .widget<Text>(
                  find.byKey(const ValueKey('neon-live-selection-comment')),
                )
                .data,
            isNot(reply),
            reason:
                'Selecting again varies the reply without repeating the previous line.',
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  for (final theme in AnimatedArmyTheme.values) {
    for (final reduced in [false, true]) {
      testWidgets(
        '${theme.name} ${reduced ? 'static' : 'animated'} capture keeps both bodies equal through recovery',
        (tester) async {
          final scene = CinematicReplay.fromMoves(
            moves: ['e2e4', 'd7d5', 'e4d5', 'd8d5'],
          ).scenes.last;
          final selected = NeonLiveAction.selection(
            position: scene.before,
            source: scene.source,
            viewerSide: Side.black,
          );
          await showArena(
            tester,
            position: scene.before,
            action: selected,
            viewer: Side.black,
            theme: theme,
            reduced: reduced,
            textScale: 2,
            size: const Size(320, 216),
          );
          final selectedHeight = figure(tester, 'left').bodyHeight!;
          final action = moveAction([
            'e2e4',
            'd7d5',
            'e4d5',
            'd8d5',
          ], Side.black);
          await showArena(
            tester,
            position: scene.after,
            action: action,
            viewer: Side.black,
            theme: theme,
            reduced: reduced,
            textScale: 2,
            size: const Size(320, 216),
          );
          for (final elapsed in [0, 392, 458]) {
            await tester.pump(Duration(milliseconds: elapsed));
            expect(figure(tester, 'left').bodyHeight, selectedHeight);
            expect(
              figure(tester, 'right').bodyHeight,
              selectedHeight,
              reason:
                  'A captured pawn and winning queen keep the same body height.',
            );
            for (final key in [
              'neon-live-actor-scale',
              'neon-live-defeat-scale',
            ]) {
              final transform = tester.widget<Transform>(
                find.byKey(ValueKey(key)),
              );
              expect(transform.transform.storage[0], 1);
              expect(transform.transform.storage[5], 1);
              expect(transform.alignment, Alignment.bottomCenter);
            }
            expect(tester.takeException(), isNull);
          }
          final label = tester.widget<Text>(
            find.byKey(const ValueKey('neon-live-right-label')),
          );
          expect(label.style!.color, const Color(0xFFFF6E83));
          expect(
            find.byKey(const ValueKey('neon-live-capture-defeated')),
            findsOneWidget,
          );
        },
      );
    }
  }
  test(
    'live arena requires original Neon armies with Animated or Classic boards',
    () {
      final neon = piecePacks.firstWhere(
        (pack) => pack.id == PiecePackId.futuristic,
      );
      final greek = piecePacks.firstWhere(
        (pack) => pack.id == PiecePackId.greek,
      );
      final original = BoardAppearance.forPack(neon);
      expect(usesNeonLiveArena(original), isTrue);
      expect(usesNeonLiveArena(original.withStandardPieces()), isTrue);
      final classicPage = BoardAppearance(
        white: neon,
        black: neon,
        board: neon,
        standardPieces: true,
        animatedArena: false,
      );
      expect(usesNeonLiveArena(classicPage), isFalse);
      expect(usesAnimatedLiveArena(classicPage), isFalse);
      expect(animatedArmyThemeForAppearance(classicPage), isNull);
      expect(
        usesNeonLiveArena(
          original.withCustomSet(CustomChessSet.create(id: 'custom-neon')),
        ),
        isFalse,
      );
      expect(
        usesNeonLiveArena(
          BoardAppearance(white: neon, black: greek, board: neon),
        ),
        isFalse,
      );
      expect(
        usesNeonLiveArena(
          BoardAppearance(white: greek, black: neon, board: neon),
        ),
        isFalse,
      );
    },
  );

  test('all four matching armies stay Animated above either board style', () {
    for (final theme in AnimatedArmyTheme.values) {
      final pack = piecePacks.singleWhere((pack) => pack.id == theme.packId);
      for (final classic in [false, true]) {
        final original = BoardAppearance.forPack(pack);
        final appearance = classic ? original.withStandardPieces() : original;
        expect(animatedArmyThemeForAppearance(appearance), theme);
        expect(usesAnimatedLiveArena(appearance), isTrue);
        expect(usesNeonLiveArena(appearance), theme == AnimatedArmyTheme.neon);
        expect(
          usesAnimatedLiveArena(
            appearance.withCustomSet(
              CustomChessSet.create(id: 'custom-${theme.name}'),
            ),
          ),
          isFalse,
        );
      }
      final other = piecePacks.singleWhere(
        (pack) =>
            pack.id ==
            (theme == AnimatedArmyTheme.neon
                ? PiecePackId.anime
                : PiecePackId.futuristic),
      );
      expect(
        animatedArmyThemeForAppearance(
          BoardAppearance(white: pack, black: other, board: pack),
        ),
        isNull,
      );
    }
    for (final legacy in piecePacks.where(
      (pack) => AnimatedArmyTheme.forPack(pack.id) == null,
    )) {
      expect(usesAnimatedLiveArena(BoardAppearance.forPack(legacy)), isFalse);
    }
  });

  for (final theme in AnimatedArmyTheme.values) {
    testWidgets(
      '${theme.name} live world preserves capture, king and neutral outcome',
      (tester) async {
        await showArena(tester, position: Chess.initial, theme: theme);
        expect(find.image(AssetImage(theme.worldAsset)), findsOneWidget);
        expect(find.text(theme.displayName.toUpperCase()), findsOneWidget);
        expect(find.byType(NeonFigureSprite), findsNothing);
        final moves = ['e2e4', 'e7e5', 'd1h5', 'b8c6', 'f1c4', 'g8f6', 'h5f7'];
        await showArena(
          tester,
          position: position(moves),
          action: moveAction(moves, Side.white),
          theme: theme,
          size: const Size(320, 145),
          textScale: 2,
        );
        expect(figure(tester, 'left').piece, Piece.whiteQueen);
        expect(figure(tester, 'right').piece, Piece.blackPawn);
        expect(mirror(tester, 'left'), 1);
        expect(mirror(tester, 'right'), -1);
        expect(find.text('CHECKMATED\nE8'), findsOneWidget);
        expect(find.text('DEFEATED\nBLACK PAWN'), findsOneWidget);
        for (final sprite in tester.widgetList<NeonFigureSprite>(
          find.byType(NeonFigureSprite),
        )) {
          expect(sprite.theme, theme);
        }
        final victory =
            tester
                    .widget<CustomPaint>(
                      find.byKey(
                        const ValueKey('animated-live-victory-effect'),
                      ),
                    )
                    .painter!
                as AnimatedArmyVictoryPainter;
        expect(victory.theme, theme);
        expect(victory.winner, Side.white);
        expect(victory.winnerOnLeft, isTrue);
        expect(victory.reducedMotion, isTrue);
        final victim = tester.getRect(
          find.byKey(const ValueKey('neon-live-right-figure')),
        );
        await tester.pump(const Duration(seconds: 1));
        expect(
          tester.getRect(find.byKey(const ValueKey('neon-live-right-figure'))),
          victim,
        );
        final draw = Chess.fromSetup(
          Setup.parseFen('k7/8/1QK5/8/8/8/8/8 b - - 0 1'),
        );
        await showArena(tester, position: draw, theme: theme);
        expect(
          find.byKey(const ValueKey('animated-live-victory-effect')),
          findsNothing,
        );
        expect(find.byType(NeonFigureSprite), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('idle arena has scenery and no default character figures', (
    tester,
  ) async {
    await showArena(tester, position: Chess.initial);
    expect(find.byType(NeonFigureSprite), findsNothing);
    expect(find.byKey(const ValueKey('neon-live-threats')), findsNothing);
    expect(find.text('NEON DOMINION'), findsOneWidget);
    expect(find.textContaining('KING'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final fixture in [
    for (final theme in AnimatedArmyTheme.values) ...[
      ('${theme.name} White', ['e2e4', 'd7d5', 'e4d5'], Side.white, theme),
      (
        '${theme.name} Black',
        ['e2e4', 'd7d5', 'e4d5', 'd8d5'],
        Side.black,
        theme,
      ),
    ],
  ]) {
    testWidgets(
      '${fixture.$1} capture lands once and holds through defeat and pose recovery',
      (tester) async {
        final scene = CinematicReplay.fromMoves(moves: fixture.$2).scenes.last;
        await showArena(
          tester,
          position: scene.before,
          reduced: false,
          viewer: fixture.$3,
          theme: fixture.$4,
        );
        await showArena(
          tester,
          position: scene.before,
          reduced: false,
          viewer: fixture.$3,
          theme: fixture.$4,
          action: NeonLiveAction.selection(
            position: scene.before,
            source: scene.resolution.move.from,
            viewerSide: fixture.$3,
          ),
        );
        await tester.pump(const Duration(milliseconds: 80));
        final figureFinder = find.byKey(
          const ValueKey('neon-live-left-figure'),
        );
        final selectedBounds = tester.getRect(figureFinder);
        final selectedLean = tester
            .widget<Transform>(
              find.byKey(const ValueKey('neon-live-actor-lean')),
            )
            .transform
            .clone();
        final selectedShift = tester
            .widget<Transform>(
              find.byKey(const ValueKey('neon-live-actor-pose')),
            )
            .transform
            .clone();
        final selectedScale = tester
            .widget<Transform>(
              find.byKey(const ValueKey('neon-live-actor-scale')),
            )
            .transform
            .clone();
        await showArena(
          tester,
          position: scene.after,
          reduced: false,
          viewer: fixture.$3,
          theme: fixture.$4,
          action: moveAction(fixture.$2, fixture.$3),
        );
        expect(tester.getRect(figureFinder), selectedBounds);
        expect(
          tester
              .widget<Transform>(
                find.byKey(const ValueKey('neon-live-actor-lean')),
              )
              .transform,
          selectedLean,
        );
        expect(
          tester
              .widget<Transform>(
                find.byKey(const ValueKey('neon-live-actor-pose')),
              )
              .transform,
          selectedShift,
        );
        expect(
          tester
              .widget<Transform>(
                find.byKey(const ValueKey('neon-live-actor-scale')),
              )
              .transform,
          selectedScale,
        );
        expect(figure(tester, 'left').faceRight, isTrue);
        await tester.pump(const Duration(milliseconds: 300));
        final strikeBounds = tester.getRect(figureFinder);
        expect(strikeBounds.center.dx, greaterThan(selectedBounds.center.dx));
        final lean = tester
            .widget<Transform>(
              find.byKey(const ValueKey('neon-live-actor-lean')),
            )
            .transform
            .storage[1];
        expect(lean, greaterThan(.025));
        expect(
          tester
              .widget<Transform>(
                find.byKey(const ValueKey('neon-live-actor-pose')),
              )
              .transform
              .storage[13],
          lessThan(0),
        );
        await tester.pump(const Duration(milliseconds: 92));
        final landedBounds = tester.getRect(figureFinder);
        expect(landedBounds.center.dx, greaterThan(selectedBounds.center.dx));
        final landedShift = tester
            .widget<Transform>(
              find.byKey(const ValueKey('neon-live-actor-pose')),
            )
            .transform
            .clone();
        final landedLean = tester
            .widget<Transform>(
              find.byKey(const ValueKey('neon-live-actor-lean')),
            )
            .transform
            .clone();
        expect(landedShift.storage[13], 0);
        expect(landedLean.storage[1], 0);
        expect(
          find.byKey(const ValueKey('neon-live-capture-defeated')),
          findsOneWidget,
        );
        for (final elapsed in [100, 358, 500]) {
          await tester.pump(Duration(milliseconds: elapsed));
          expect(
            tester.getRect(figureFinder),
            landedBounds,
            reason: 'The actor cannot drift back after the capture lands.',
          );
          expect(
            tester
                .widget<Transform>(
                  find.byKey(const ValueKey('neon-live-actor-pose')),
                )
                .transform,
            landedShift,
          );
          expect(
            tester
                .widget<Transform>(
                  find.byKey(const ValueKey('neon-live-actor-lean')),
                )
                .transform,
            landedLean,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'selection is a stationary avatar and only a committed move starts its action',
    (tester) async {
      const moves = ['e2e4', 'd7d5', 'e4d5'];
      final scene = CinematicReplay.fromMoves(moves: moves).scenes.last;
      await showArena(tester, position: scene.before, reduced: false);
      await showArena(
        tester,
        position: scene.before,
        reduced: false,
        action: NeonLiveAction.selection(
          position: scene.before,
          source: Square.e4,
        ),
      );
      final actor = find.byKey(const ValueKey('neon-live-left-figure'));
      await tester.pump(const Duration(milliseconds: 70));
      final before = tester.getRect(actor);
      await tester.pump(const Duration(milliseconds: 10));
      final selected = tester.getRect(actor);
      expect(selected, before);
      expect(
        find.byKey(const ValueKey('neon-live-selection-comment')),
        findsOneWidget,
      );
      final reply = tester
          .widget<Text>(
            find.byKey(const ValueKey('neon-live-selection-comment')),
          )
          .data;
      await tester.pump(const Duration(seconds: 5));
      expect(tester.getRect(actor), selected);
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('neon-live-selection-comment')),
            )
            .data,
        reply,
      );
      await showArena(
        tester,
        position: scene.after,
        reduced: false,
        action: moveAction(moves, Side.white),
      );
      expect(tester.getRect(actor), selected);
      expect(
        find.byKey(const ValueKey('neon-live-selection-comment')),
        findsNothing,
      );
      await tester.pump(const Duration(milliseconds: 150));
      final moveStep = tester.getRect(actor).center.dx - selected.center.dx;
      expect(moveStep, greaterThan(0));
      expect(
        tester
            .widget<Transform>(
              find.byKey(const ValueKey('neon-live-actor-scale')),
            )
            .alignment,
        Alignment.bottomCenter,
      );
      expect(
        tester
            .widget<Transform>(
              find.byKey(const ValueKey('neon-live-actor-lean')),
            )
            .alignment,
        Alignment.bottomCenter,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'capture impact switches stamps, defeat and bubbles without moving the victim slot',
    (tester) async {
      const moves = ['e2e4', 'd7d5', 'e4d5'];
      final scene = CinematicReplay.fromMoves(moves: moves).scenes.last;
      await showArena(tester, position: scene.before, reduced: false);
      await showArena(
        tester,
        position: scene.before,
        reduced: false,
        action: NeonLiveAction.selection(
          position: scene.before,
          source: Square.e4,
        ),
      );
      await tester.pump(animatedSelectionDuration);
      await showArena(
        tester,
        position: scene.after,
        reduced: false,
        action: moveAction(moves, Side.white),
      );
      final slotFinder = find.byKey(const ValueKey('neon-live-capture-slot'));
      final slot = tester.getRect(slotFinder);
      expect(find.byKey(const ValueKey('neon-live-threat-d5')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('neon-live-capture-defeated')),
        findsNothing,
      );
      final impact = Duration(
        microseconds:
            (animatedMoveDuration.inMicroseconds * animatedMoveImpactFraction)
                .round(),
      );
      await tester.pump(impact - const Duration(milliseconds: 1));
      expect(
        find.byKey(const ValueKey('neon-live-capture-defeated')),
        findsNothing,
      );
      expect(
        tester
            .widget<Transform>(
              find.byKey(const ValueKey('neon-live-defeat-pose')),
            )
            .transform
            .storage[1],
        0,
      );
      final transition = tester
          .widget<Opacity>(
            find.byKey(const ValueKey('neon-live-threat-transition')),
          )
          .opacity;
      expect(transition, lessThan(.01));
      await tester.pump(const Duration(milliseconds: 2));
      expect(
        find.byKey(const ValueKey('neon-live-capture-defeated')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('neon-live-capture-winner')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('neon-live-threat-d5')), findsNothing);
      // The sprite's defeat transform changes its painted pose, not its layout.
      expect(tester.getRect(slotFinder), slot);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Neon capture uses its standard character throughout and a check never attacks a king',
    (tester) async {
      const moves = ['e2e4', 'd7d5', 'e4d5'];
      final scene = CinematicReplay.fromMoves(moves: moves).scenes.last;
      await showArena(tester, position: scene.before, reduced: false);
      await showArena(
        tester,
        position: scene.after,
        reduced: false,
        action: moveAction(moves, Side.white),
      );
      expect(figure(tester, 'left').pose, NeonFigurePose.rest);
      await tester.pump(const Duration(milliseconds: 300));
      expect(figure(tester, 'left').pose, NeonFigurePose.rest);
      expect(figure(tester, 'left').fromPose, isNull);
      await tester.pump(const Duration(milliseconds: 150));
      expect(figure(tester, 'left').pose, NeonFigurePose.rest);
      expect(figure(tester, 'left').fromPose, isNull);
      await tester.pump(const Duration(milliseconds: 400));
      expect(figure(tester, 'left').pose, NeonFigurePose.rest);
      expect(figure(tester, 'left').fromPose, isNull);
      expect(figure(tester, 'left').poseBlend, 1);
      const check = ['e2e4', 'f7f6', 'd1h5'];
      await showArena(
        tester,
        position: position(check),
        reduced: false,
        action: moveAction(check, Side.white),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(figure(tester, 'left').pose, NeonFigurePose.rest);
      expect(
        find.byKey(const ValueKey('neon-live-capture-defeated')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('neon-live-check-aura-e8')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'background pauses live motion and resumes at the board impact boundary',
    (tester) async {
      const moves = ['e2e4', 'd7d5', 'e4d5'];
      final scene = CinematicReplay.fromMoves(moves: moves).scenes.last;
      await showArena(tester, position: scene.before, reduced: false);
      await showArena(
        tester,
        position: scene.after,
        reduced: false,
        action: moveAction(moves, Side.white),
      );
      await tester.pump(const Duration(milliseconds: 250));
      final actor = find.byKey(const ValueKey('neon-live-left-figure'));
      final beforePause = tester.getRect(actor);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.getRect(actor), beforePause);
      expect(
        find.byKey(const ValueKey('neon-live-capture-defeated')),
        findsNothing,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));
      expect(
        find.byKey(const ValueKey('neon-live-capture-defeated')),
        findsNothing,
      );
      await tester.pump(const Duration(milliseconds: 2));
      expect(
        find.byKey(const ValueKey('neon-live-capture-defeated')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'capture audio stays silent on restoration and follows paused visible impact once',
    (tester) async {
      final output = _CaptureMusicOutput();
      final music = ThemeMusic(output: output, saveMuted: (_) async {});
      addTearDown(music.dispose);
      const moves = ['e2e4', 'd7d5', 'e4d5'];
      final scene = CinematicReplay.fromMoves(moves: moves).scenes.last;
      await showArena(
        tester,
        position: scene.after,
        action: moveAction(moves, Side.white),
        music: music,
      );
      await tester.pump(const Duration(seconds: 1));
      expect(
        output.effects,
        isEmpty,
        reason: 'Restored last captures never replay their sounds.',
      );
      await showArena(
        tester,
        position: scene.before,
        reduced: false,
        music: music,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await showArena(
        tester,
        position: scene.after,
        reduced: false,
        action: moveAction(moves, Side.white),
        music: music,
      );
      await tester.pump(const Duration(seconds: 2));
      expect(output.effects, isEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(output.effects, [CinematicSound.attack]);
      await tester.pump(const Duration(milliseconds: 390));
      expect(output.effects, [CinematicSound.attack]);
      await tester.pump(const Duration(milliseconds: 2));
      expect(output.effects, [
        CinematicSound.attack,
        CinematicSound.lightImpact,
      ]);
      await tester.pump(const Duration(seconds: 2));
      await showArena(
        tester,
        position: scene.after,
        reduced: false,
        action: moveAction(moves, Side.white),
        music: music,
      );
      expect(output.effects, [
        CinematicSound.attack,
        CinematicSound.lightImpact,
      ]);
      final restoredSelection = NeonLiveAction.selection(
        position: scene.after,
        source: Square.d8,
        viewerSide: Side.black,
      );
      await showArena(
        tester,
        position: scene.after,
        reduced: false,
        action: restoredSelection,
        music: music,
      );
      await showArena(
        tester,
        position: scene.after,
        reduced: false,
        action: moveAction(moves, Side.white),
        music: music,
      );
      expect(
        find.byKey(const ValueKey('neon-live-capture-defeated')),
        findsOneWidget,
        reason: 'Returning to an existing capture keeps its settled phase.',
      );
      final restored = tester.getRect(
        find.byKey(const ValueKey('neon-live-left-figure')),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester.getRect(find.byKey(const ValueKey('neon-live-left-figure'))),
        restored,
      );
      expect(output.effects, [
        CinematicSound.attack,
        CinematicSound.lightImpact,
      ], reason: 'A same-position return to the last capture remains silent.');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'new reduced-motion capture cues heavy and final impact only for real victims',
    (tester) async {
      final output = _CaptureMusicOutput();
      final music = ThemeMusic(output: output, saveMuted: (_) async {});
      addTearDown(music.dispose);
      for (final fixture in [
        (['e2e4', 'd7d5', 'e4d5', 'd8d5'], CinematicSound.heavyImpact),
        (
          ['e2e4', 'e7e5', 'd1h5', 'b8c6', 'f1c4', 'g8f6', 'h5f7'],
          CinematicSound.finalStrike,
        ),
      ]) {
        final scene = CinematicReplay.fromMoves(moves: fixture.$1).scenes.last;
        await showArena(tester, position: scene.before, music: music);
        output.effects.clear();
        await showArena(
          tester,
          position: scene.after,
          music: music,
          action: moveAction(fixture.$1, Side.white),
        );
        await tester.pump();
        expect(output.effects, [CinematicSound.attack, fixture.$2]);
        await tester.pump(const Duration(seconds: 2));
        expect(output.effects, [CinematicSound.attack, fixture.$2]);
      }
      const check = ['e2e4', 'f7f6', 'd1h5'];
      output.effects.clear();
      await showArena(
        tester,
        position: position(check),
        music: music,
        action: moveAction(check, Side.white),
      );
      expect(
        output.effects,
        isEmpty,
        reason: 'A surviving checked king is never struck as a capture.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'accepted opponent move lands toward the player and does not retreat afterwards',
    (tester) async {
      const moves = ['e2e4'];
      await showArena(
        tester,
        position: Chess.initial,
        viewer: Side.black,
        reduced: false,
      );
      await showArena(
        tester,
        position: position(moves),
        viewer: Side.black,
        reduced: false,
        action: moveAction(moves, Side.black),
      );
      final figureFinder = find.byKey(const ValueKey('neon-live-right-figure'));
      final first = tester.getRect(figureFinder);
      await tester.pump(const Duration(milliseconds: 300));
      final strike = tester.getRect(figureFinder);
      expect(strike.center.dx, lessThan(first.center.dx));
      expect(
        tester
            .widget<Transform>(
              find.byKey(const ValueKey('neon-live-actor-lean')),
            )
            .transform
            .storage[1],
        lessThan(-.025),
      );
      expect(mirror(tester, 'right'), -1);
      await tester.pump(const Duration(milliseconds: 92));
      final landed = tester.getRect(figureFinder);
      expect(landed.center.dx, lessThan(strike.center.dx));
      for (final elapsed in [100, 358, 500]) {
        await tester.pump(Duration(milliseconds: elapsed));
        expect(tester.getRect(figureFinder), landed);
      }
      expect(find.text('E2'), findsOneWidget);
      expect(find.text('E4'), findsOneWidget);
      expect(find.text('CHECKMATE'), findsNothing);
      expect(find.byKey(const ValueKey('neon-live-victory')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ordinary check and draw never declare checkmate or a victorious faction',
    (tester) async {
      final checkMoves = ['e2e4', 'f7f6', 'd1h5'];
      await showArena(
        tester,
        position: position(checkMoves),
        action: moveAction(checkMoves, Side.white),
      );
      expect(find.text('CHECK\nE8'), findsOneWidget);
      expect(find.text('CHECKMATE'), findsNothing);
      expect(find.byKey(const ValueKey('neon-live-victory')), findsNothing);
      final draw = Chess.fromSetup(
        Setup.parseFen('k7/8/1QK5/8/8/8/8/8 b - - 0 1'),
      );
      expect(draw.isStalemate, isTrue);
      await showArena(tester, position: draw);
      expect(find.byType(NeonFigureSprite), findsNothing);
      expect(find.text('CHECKMATE'), findsNothing);
      expect(find.byKey(const ValueKey('neon-live-victory')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mate victory and surviving king fit compact panes with static reduced motion',
    (tester) async {
      final moves = ['e2e4', 'e7e5', 'd1h5', 'b8c6', 'f1c4', 'g8f6', 'h5f7'];
      for (final size in [
        const Size(320, 180),
        const Size(650, 100),
        const Size(760, 70),
      ]) {
        await showArena(
          tester,
          position: position(moves),
          action: moveAction(moves, Side.white),
          size: size,
          textScale: 2,
        );
        final arena = tester.getRect(
          find.byKey(const ValueKey('neon-live-arena')),
        );
        expect(find.text('CHECKMATE'), findsOneWidget);
        expect(find.text('VICTORY · WHITE'), findsOneWidget);
        expect(find.text('CHECKMATED\nE8'), findsOneWidget);
        expect(figure(tester, 'right').piece, Piece.blackPawn);
        for (final key in [
          'neon-live-heading',
          'neon-live-victory',
          'neon-live-route',
          'neon-live-threats',
        ]) {
          final bounds = tester.getRect(find.byKey(ValueKey(key)));
          expect(
            arena.contains(bounds.topLeft),
            isTrue,
            reason: '$key at $size',
          );
          expect(
            arena.contains(bounds.bottomRight - const Offset(.01, .01)),
            isTrue,
            reason: '$key at $size',
          );
        }
        final before = tester.getRect(
          find.byKey(const ValueKey('neon-live-left-figure')),
        );
        await tester.pump(const Duration(seconds: 2));
        expect(
          tester.getRect(find.byKey(const ValueKey('neon-live-left-figure'))),
          before,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'a selected king is an actual actor without an opposing placeholder',
    (tester) async {
      final board = position(['e2e4', 'e7e5']);
      await showArena(
        tester,
        position: board,
        action: NeonLiveAction.selection(position: board, source: Square.e1),
      );
      expect(figure(tester, 'left').piece, Piece.whiteKing);
      expect(
        find.byKey(const ValueKey('neon-live-right-figure')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('neon-live-capture-defeated')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'true capture recoils and fades the actual victim then stays defeated',
    (tester) async {
      final scene = CinematicReplay.fromMoves(
        moves: ['e2e4', 'd7d5', 'e4d5'],
      ).scenes.last;
      await showArena(tester, position: scene.before, reduced: false);
      await showArena(
        tester,
        position: scene.after,
        reduced: false,
        action: moveAction(['e2e4', 'd7d5', 'e4d5'], Side.white),
      );
      final victim = find.byKey(const ValueKey('neon-live-defeat-opacity'));
      expect(tester.widget<Opacity>(victim).opacity, 0);
      await tester.pump(const Duration(milliseconds: 500));
      final impactOpacity = tester.widget<Opacity>(victim).opacity;
      expect(impactOpacity, inExclusiveRange(.48, 1));
      final impactTilt = tester
          .widget<Transform>(
            find.byKey(const ValueKey('neon-live-defeat-pose')),
          )
          .transform
          .storage[1];
      expect(impactTilt, greaterThan(0));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.widget<Opacity>(victim).opacity, closeTo(.48, .001));
      expect(figure(tester, 'right').piece, Piece.blackPawn);
      expect(find.text('DEFEATED\nBLACK PAWN'), findsOneWidget);
      expect(find.text('WINNER\nWHITE PAWN'), findsOneWidget);
      expect(find.textContaining('KING'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reduced-motion capture holds a static defeated pose on the real side',
    (tester) async {
      final moves = ['e2e4', 'd7d5', 'e4d5', 'd8d5'];
      await showArena(
        tester,
        position: position(moves),
        action: moveAction(moves, Side.white),
      );
      expect(figure(tester, 'left').piece, Piece.whitePawn);
      expect(find.text('DEFEATED\nWHITE PAWN'), findsOneWidget);
      final pose = find.byKey(const ValueKey('neon-live-defeat-pose'));
      final first = tester.widget<Transform>(pose).transform.clone();
      await tester.pump(const Duration(seconds: 2));
      expect(tester.widget<Transform>(pose).transform, first);
      expect(
        tester
            .widget<Opacity>(
              find.byKey(const ValueKey('neon-live-defeat-opacity')),
            )
            .opacity,
        closeTo(.48, .001),
      );
      expect(
        find.byKey(const ValueKey('neon-live-capture-defeated')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Black selection uses player left-facing-right and actual role/source',
    (tester) async {
      final board = position(['e2e4']);
      final fen = board.fen;
      final action = NeonLiveAction.selection(
        position: board,
        source: Square.e7,
        viewerSide: Side.black,
      )!;
      await showArena(
        tester,
        position: board,
        action: action,
        viewer: Side.black,
      );
      expect(figure(tester, 'left').piece, Piece.blackPawn);
      expect(figure(tester, 'left').faceRight, isTrue);
      expect(mirror(tester, 'left'), 1);
      expect(
        find.byKey(const ValueKey('neon-live-right-figure')),
        findsNothing,
      );
      expect(find.text('SELECTED · BLACK PAWN'), findsOneWidget);
      expect(find.text('E7'), findsOneWidget);
      expect(board.fen, fen);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'local Black selection and move share the right lane with inward-facing White bubbles',
    (tester) async {
      final board = position(['e2e4', 'd7d5', 'e4d5']);
      final action = NeonLiveAction.selection(
        position: board,
        source: Square.d8,
      )!;
      await showArena(tester, position: board, action: action);
      expect(figure(tester, 'right').piece, Piece.blackQueen);
      expect(mirror(tester, 'right'), -1);
      expect(find.byKey(const ValueKey('neon-live-left-figure')), findsNothing);
      expect(find.text('SELECTED\nBLACK QUEEN'), findsOneWidget);
      final bubble = tester.widget<NeonFigureSprite>(
        find.descendant(
          of: find.byKey(const ValueKey('neon-live-threat-portrait-d5')),
          matching: find.byType(NeonFigureSprite),
        ),
      );
      expect(bubble.piece, Piece.whitePawn);
      expect(bubble.faceRight, isTrue);
      expect(
        tester.getCenter(find.byKey(const ValueKey('neon-live-threat-d5'))).dx,
        lessThan(
          tester
              .getCenter(find.byKey(const ValueKey('neon-live-right-figure')))
              .dx,
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'opponent White move uses the right lane and material route arrow',
    (tester) async {
      final moves = ['e2e4'];
      final action = moveAction(moves, Side.black);
      await showArena(
        tester,
        position: position(moves),
        action: action,
        viewer: Side.black,
      );
      expect(figure(tester, 'right').piece, Piece.whitePawn);
      expect(figure(tester, 'right').faceRight, isFalse);
      expect(mirror(tester, 'right'), -1);
      expect(find.byKey(const ValueKey('neon-live-left-figure')), findsNothing);
      expect(find.text('LAST MOVE · WHITE PAWN'), findsOneWidget);
      expect(find.text('E2'), findsOneWidget);
      expect(find.text('E4'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selection check possibility is distinct from a committed king check',
    (tester) async {
      final before = position(['e2e4', 'f7f6']);
      final selection = NeonLiveAction.selection(
        position: before,
        source: Square.d1,
      )!;
      await showArena(tester, position: before, action: selection);
      expect(
        find.byKey(const ValueKey('neon-live-possible-check-aura-e8')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('neon-live-check-aura-e8')),
        findsNothing,
      );
      expect(find.text('POSSIBLE\nCHECK\nE8'), findsOneWidget);
      expect(find.textContaining('CAPTURED'), findsNothing);
      expect(
        find.byKey(const ValueKey('neon-live-capture-defeated')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('neon-live-right-figure')),
        findsNothing,
      );
      final moves = ['e2e4', 'f7f6', 'd1h5'];
      await showArena(
        tester,
        position: position(moves),
        action: moveAction(moves, Side.white),
      );
      expect(
        find.byKey(const ValueKey('neon-live-check-aura-e8')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('neon-live-possible-check-aura-e8')),
        findsNothing,
      );
      expect(find.text('CHECK\nE8'), findsOneWidget);
      expect(find.textContaining('CAPTURED'), findsNothing);
      expect(
        find.byKey(const ValueKey('neon-live-capture-defeated')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('idle checked king appears on its real player-perspective side', (
    tester,
  ) async {
    final board = position(['f2f3', 'e7e5', 'g2g4', 'd8h4']);
    await showArena(tester, position: board, viewer: Side.white);
    expect(find.text('CHECKMATE'), findsOneWidget);
    expect(find.text('VICTORY · BLACK'), findsOneWidget);
    expect(find.text('CHECKMATED\nE1'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('neon-live-check-aura-e1')),
      findsOneWidget,
    );
    final arena = tester.getRect(find.byKey(const ValueKey('neon-live-arena')));
    expect(
      tester.getCenter(find.byKey(const ValueKey('neon-live-threats'))).dx,
      lessThan(arena.center.dx),
    );
    expect(find.textContaining('CAPTURED'), findsNothing);
    expect(find.byKey(const ValueKey('neon-live-left-figure')), findsNothing);
    expect(find.byKey(const ValueKey('neon-live-right-figure')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'en passant retains actual victim while showing the true move route',
    (tester) async {
      final moves = ['e2e4', 'a7a6', 'e4e5', 'd7d5', 'e5d6'];
      final action = moveAction(moves, Side.white);
      expect(action.captureSquare, Square.d5);
      await showArena(tester, position: position(moves), action: action);
      expect(figure(tester, 'left').piece, Piece.whitePawn);
      expect(figure(tester, 'right').piece, Piece.blackPawn);
      expect(find.text('DEFEATED\nBLACK PAWN'), findsOneWidget);
      expect(find.text('WINNER\nWHITE PAWN'), findsOneWidget);
      expect(find.text('E5'), findsOneWidget);
      expect(find.text('D6'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'capture and mate keep captured pawn distinct from surviving king aura',
    (tester) async {
      final moves = ['e2e4', 'e7e5', 'd1h5', 'b8c6', 'f1c4', 'g8f6', 'h5f7'];
      final action = moveAction(moves, Side.white);
      await showArena(tester, position: position(moves), action: action);
      expect(figure(tester, 'right').piece, Piece.blackPawn);
      expect(find.text('DEFEATED\nBLACK PAWN'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('neon-live-check-aura-e8')),
        findsOneWidget,
      );
      expect(find.text('CHECKMATED\nE8'), findsOneWidget);
      expect(find.text('CHECKMATE'), findsOneWidget);
      expect(find.text('VICTORY · WHITE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'round victims stack vertically and paginate without losing entries',
    (tester) async {
      final board = Chess.fromSetup(
        Setup.parseFen('4k3/8/8/2p1p3/3Q4/2p1p3/8/4K3 w - - 0 1'),
      );
      final action = NeonLiveAction.selection(
        position: board,
        source: Square.d4,
      )!;
      expect(action.threats.length, greaterThan(3));
      await showArena(tester, position: board, action: action);
      final first = action.threats.take(3).toList();
      final bounds = first
          .map(
            (threat) => tester.getRect(
              find.byKey(ValueKey('neon-live-threat-${threat.square.name}')),
            ),
          )
          .toList();
      expect(bounds[0].bottom, lessThanOrEqualTo(bounds[1].top));
      expect(bounds[1].bottom, lessThanOrEqualTo(bounds[2].top));
      expect(
        find.byKey(
          ValueKey('neon-live-threat-${action.threats[3].square.name}'),
        ),
        findsNothing,
      );
      expect(find.text('1 / 2'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('neon-live-threat-next')));
      await tester.pump();
      expect(find.text('2 / 2'), findsOneWidget);
      for (final threat in action.threats.skip(3)) {
        expect(
          find.byKey(ValueKey('neon-live-threat-${threat.square.name}')),
          findsOneWidget,
        );
      }
      await showArena(tester, position: board, action: action);
      expect(find.text('2 / 2'), findsOneWidget);
      const initial = Chess.initial;
      await showArena(
        tester,
        position: initial,
        action: NeonLiveAction.selection(position: initial, source: Square.g1),
      );
      expect(find.byKey(const ValueKey('neon-live-threat-page')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'actors and bubble page controls fit short panes and large text',
    (tester) async {
      final board = Chess.fromSetup(
        Setup.parseFen('4k3/8/8/2p1p3/3Q4/2p1p3/8/4K3 w - - 0 1'),
      );
      final selection = NeonLiveAction.selection(
        position: board,
        source: Square.d4,
      )!;
      for (final size in [
        const Size(320, 180),
        const Size(650, 100),
        const Size(760, 70),
      ]) {
        await showArena(
          tester,
          position: board,
          action: selection,
          size: size,
          textScale: 2,
        );
        final arena = tester.getRect(
          find.byKey(const ValueKey('neon-live-arena')),
        );
        for (final key in [
          'neon-live-left-figure',
          'neon-live-threats',
          'neon-live-route',
          'neon-live-selection-bubble',
        ]) {
          final bounds = tester.getRect(find.byKey(ValueKey(key)));
          expect(
            arena.contains(bounds.topLeft),
            isTrue,
            reason: '$key at $size',
          );
          expect(
            arena.contains(bounds.bottomRight - const Offset(.01, .01)),
            isTrue,
            reason: '$key at $size',
          );
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'reduced motion stays stable and emphasis never blocks board controls',
    (tester) async {
      var taps = 0;
      const board = Chess.initial;
      final selection = NeonLiveAction.selection(
        position: board,
        source: Square.g1,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              SizedBox(
                height: 180,
                child: NeonLiveArena(
                  position: board,
                  viewerSide: Side.white,
                  reducedMotion: true,
                  action: selection,
                ),
              ),
              TextButton(
                key: const ValueKey('interactive-board-control'),
                onPressed: () => taps++,
                child: const Text('Board control'),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      final before = tester.getRect(
        find.byKey(const ValueKey('neon-live-left-figure')),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester.getRect(find.byKey(const ValueKey('neon-live-left-figure'))),
        before,
      );
      await tester.tap(find.byKey(const ValueKey('interactive-board-control')));
      await tester.pump();
      expect(taps, 1);
      expect(board.fen, Chess.initial.fen);
      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              SizedBox(
                height: 180,
                child: NeonLiveArena(
                  position: board,
                  viewerSide: Side.white,
                  action: NeonLiveAction.selection(
                    position: board,
                    source: Square.b1,
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey('interactive-board-control'),
                onPressed: () => taps++,
                child: const Text('Board control'),
              ),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 20));
      await tester.tap(find.byKey(const ValueKey('interactive-board-control')));
      await tester.pump();
      expect(taps, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );
}
