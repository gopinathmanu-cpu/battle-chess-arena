import 'package:battle_chess_arena/src/domain/animated_army_theme.dart';
import 'package:battle_chess_arena/src/domain/cinematic_replay.dart';
import 'package:battle_chess_arena/src/domain/cinematic_threats.dart';
import 'package:battle_chess_arena/src/domain/capture_threat.dart';
import 'package:battle_chess_arena/src/features/play/neon_illustrated_stage.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder portrait(String side, String role) => find.byWidgetPredicate(
  (widget) =>
      widget is Semantics &&
      widget.properties.label == '$side $role illustration',
);

Future<void> render(
  WidgetTester tester,
  CinematicReplayScene scene, {
  double progress = .4,
  bool reduced = false,
  bool compact = false,
  bool showThreats = true,
  List<CinematicThreat>? threats,
  double? captionInset,
  double textScale = 1,
  Size size = const Size(400, 640),
  AnimatedArmyTheme theme = AnimatedArmyTheme.neon,
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
      home: Center(
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: NeonIllustratedStage(
            scene: scene,
            progress: progress,
            intro: false,
            finale: false,
            reducedMotion: reduced,
            title: '',
            subtitle: '',
            resultTitle: 'Game complete',
            theme: theme,
            compact: compact,
            captionInset: captionInset,
            threats:
                threats ??
                (showThreats ? cinematicThreatsAfter(scene) : const []),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  for (final theme in AnimatedArmyTheme.values) {
    testWidgets(
      '${theme.name} capture bodies stay equal before impact and after defeat',
      (tester) async {
        final scene = CinematicReplay.fromMoves(
          moves: ['e2e4', 'd7d5', 'e4d5', 'd8d5'],
        ).scenes.last;
        for (final size in [const Size(320, 216), const Size(760, 115)]) {
          for (final progress in [.3, .56, .85, 1.0]) {
            await render(
              tester,
              scene,
              theme: theme,
              progress: progress,
              size: size,
              compact: true,
              captionInset: 0,
              textScale: 2,
            );
            final actor = tester.widget<NeonFigureSprite>(
              find.byKey(const ValueKey('film-hero-black-queen')),
            );
            final victim = tester.widget<NeonFigureSprite>(
              find.byKey(const ValueKey('film-victim-white-pawn')),
            );
            expect(actor.bodyHeight, isPositive);
            expect(victim.bodyHeight, actor.bodyHeight);
            expect(
              tester.getSize(find.byKey(actor.key!)),
              tester.getSize(find.byKey(victim.key!)),
              reason: 'A cinematic outcome cannot shrink the defeated slot.',
            );
            expect(tester.takeException(), isNull);
          }
        }
      },
    );

    testWidgets(
      '${theme.name} both leaders retain equal bodies for either victor and draw',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 240));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        for (final result in ['White wins', 'Black wins', 'Draw']) {
          await tester.pumpWidget(
            MaterialApp(
              home: NeonIllustratedStage(
                scene: null,
                progress: 1,
                intro: false,
                finale: true,
                reducedMotion: true,
                title: '',
                subtitle: '',
                resultTitle: result,
                theme: theme,
                compact: true,
                captionInset: 0,
              ),
            ),
          );
          await tester.pump();
          final white = find.byKey(const ValueKey('film-leader-white'));
          final black = find.byKey(const ValueKey('film-leader-black'));
          expect(
            tester.widget<NeonFigureSprite>(white).bodyHeight,
            tester.widget<NeonFigureSprite>(black).bodyHeight,
          );
          expect(tester.getSize(white), tester.getSize(black));
          expect(
            tester.getBottomLeft(white).dy,
            tester.getBottomLeft(black).dy,
          );
          expect(tester.takeException(), isNull);
        }
      },
    );

    testWidgets('${theme.name} renders both six-role casts facing inward', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(720, 420));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              for (final side in Side.values)
                Expanded(
                  child: Row(
                    children: [
                      for (final role in Role.values)
                        Expanded(
                          child: NeonFigureSprite(
                            piece: Piece(color: side, role: role),
                            theme: theme,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
      await tester.pump();
      for (final side in Side.values) {
        for (final role in Role.values) {
          final sprite = find.descendant(
            of: portrait(side.name, role.name),
            matching: find.byType(Image),
          );
          expect(
            tester.widget<Image>(sprite).image,
            AssetImage(theme.castAsset(side)),
          );
          final flip = tester.widget<Transform>(
            find.byKey(
              ValueKey('neon-figure-mirror-${side.name}-${role.name}'),
            ),
          );
          expect(flip.transform.storage[0], side == Side.white ? 1 : -1);
        }
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '${theme.name} capture and check remain factual across landing in small stage',
      (tester) async {
        final scene = CinematicReplay.fromMoves(
          moves: ['e2e4', 'e7e5', 'd1h5', 'b8c6', 'f1c4', 'g8f6', 'h5f7'],
        ).scenes.last;
        for (final size in [const Size(320, 216), const Size(760, 115)]) {
          await render(
            tester,
            scene,
            theme: theme,
            progress: .55,
            compact: true,
            captionInset: 0,
            size: size,
            textScale: 2,
          );
          expect(find.image(AssetImage(theme.worldAsset)), findsOneWidget);
          expect(
            find.byKey(const ValueKey('neon-capture-strike')),
            findsOneWidget,
          );
          expect(find.text('DEFEATED'), findsNothing);
          expect(
            find.byKey(const ValueKey('neon-check-aura-e8')),
            findsNothing,
          );
          await render(
            tester,
            scene,
            theme: theme,
            progress: .56,
            reduced: true,
            compact: true,
            captionInset: 0,
            size: size,
            textScale: 2,
          );
          expect(find.text('DEFEATED'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('film-victim-black-pawn')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('film-victim-black-king')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('neon-check-aura-e8')),
            findsOneWidget,
          );
          expect(
            tester
                .widgetList<NeonFigureSprite>(find.byType(NeonFigureSprite))
                .every((figure) => figure.theme == theme),
            isTrue,
          );
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  testWidgets(
    'actual atlas transforms mirror every Black pose and preserve White',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(720, 420));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              for (final side in Side.values)
                Expanded(
                  child: Row(
                    children: [
                      for (final role in Role.values)
                        Expanded(
                          child: NeonFigureSprite(
                            piece: Piece(color: side, role: role),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
      await tester.pump();
      for (final side in Side.values) {
        for (final role in Role.values) {
          final flip = tester.widget<Transform>(
            find.byKey(
              ValueKey('neon-figure-mirror-${side.name}-${role.name}'),
            ),
          );
          expect(
            flip.transform.storage[0],
            side == Side.white ? 1 : -1,
            reason:
                '${side.name} ${role.name} uses the actual right-facing source atlas',
          );
        }
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'capture magic belongs to real captures and check aura to the surviving king',
    (tester) async {
      final capture = CinematicReplay.fromMoves(
        moves: ['e2e4', 'e7e5', 'd1h5', 'b8c6', 'f1c4', 'g8f6', 'h5f7'],
      ).scenes.last;
      await render(
        tester,
        capture,
        progress: .55,
        compact: true,
        captionInset: 0,
      );
      expect(find.byKey(const ValueKey('neon-capture-strike')), findsOneWidget);
      expect(find.byKey(const ValueKey('neon-check-aura-e8')), findsNothing);
      await render(
        tester,
        capture,
        progress: .56,
        compact: true,
        captionInset: 0,
      );
      expect(find.byKey(const ValueKey('neon-check-aura-e8')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('film-victim-black-pawn')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('film-victim-black-king')),
        findsNothing,
      );
      final check = CinematicReplay.fromMoves(
        moves: ['e2e4', 'f7f6', 'd1h5'],
      ).scenes.last;
      await render(tester, check, progress: .8, compact: true, captionInset: 0);
      expect(find.byKey(const ValueKey('neon-capture-strike')), findsNothing);
      expect(find.byKey(const ValueKey('neon-check-aura-e8')), findsOneWidget);
      expect(find.text('DEFEATED'), findsNothing);
      final quiet = CinematicReplay.fromMoves(moves: ['g1f3']).scenes.single;
      await render(tester, quiet, progress: .8, compact: true, captionInset: 0);
      expect(find.byKey(const ValueKey('neon-capture-strike')), findsNothing);
      expect(find.byKey(const ValueKey('neon-check-aura-e8')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'victory uses the factual side and never celebrates draws or unfinished games',
    (tester) async {
      final mate = CinematicReplay.fromMoves(
        moves: ['f2f3', 'e7e5', 'g2g4', 'd8h4'],
      ).scenes.last;
      for (final result in [
        ('Computer Wins', Side.black, Side.black),
        ('You Win! · Checkmate', Side.white, Side.white),
        ('Black wins by checkmate', null, Side.black),
        ('Draw by agreement', Side.white, null),
        ('Game unfinished', Side.black, null),
        ('Game cancelled', Side.black, null),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              width: 390,
              height: 320,
              child: NeonIllustratedStage(
                scene: mate,
                progress: .7,
                intro: false,
                finale: true,
                reducedMotion: false,
                title: '',
                subtitle: '',
                resultTitle: result.$1,
                winnerSide: result.$2,
                compact: true,
                captionInset: 0,
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          find.byKey(const ValueKey('neon-victory-white')),
          result.$3 == Side.white ? findsOneWidget : findsNothing,
        );
        expect(
          find.byKey(const ValueKey('neon-victory-black')),
          result.$3 == Side.black ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets('every actor faces inward and black approach travels leftward', (
    tester,
  ) async {
    final black = CinematicReplay.fromMoves(
      moves: ['e2e4', 'd7d5', 'e4d5', 'd8d5'],
    ).scenes.last;
    await render(
      tester,
      black,
      progress: .2,
      compact: true,
      captionInset: 0,
      size: const Size(390, 354),
    );
    final startingX = tester
        .getCenter(find.byKey(const ValueKey('film-hero-black-queen')))
        .dx;
    await render(
      tester,
      black,
      progress: .85,
      compact: true,
      captionInset: 0,
      size: const Size(390, 354),
    );
    final endingX = tester
        .getCenter(find.byKey(const ValueKey('film-hero-black-queen')))
        .dx;
    expect(endingX, lessThan(startingX));
    final stage = tester.getRect(
      find.byKey(const ValueKey('neon-illustrated-stage')),
    );
    expect(
      tester.getCenter(find.byKey(const ValueKey('neon-threat-bubbles'))).dx,
      lessThan(stage.center.dx),
    );
    for (final actor in tester.widgetList<NeonFigureSprite>(
      find.byType(NeonFigureSprite),
    )) {
      expect(actor.faceRight, actor.piece.color == Side.white);
    }
    final white = CinematicReplay.fromMoves(
      moves: ['e2e4', 'e7e5', 'd1h5'],
    ).scenes.last;
    await render(
      tester,
      white,
      progress: .85,
      compact: true,
      captionInset: 0,
      size: const Size(390, 354),
    );
    expect(
      tester.getCenter(find.byKey(const ValueKey('neon-threat-bubbles'))).dx,
      greaterThan(stage.center.dx),
    );
    for (final actor in tester.widgetList<NeonFigureSprite>(
      find.byType(NeonFigureSprite),
    )) {
      expect(actor.faceRight, actor.piece.color == Side.white);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('both castling allies remain in their own faction half', (
    tester,
  ) async {
    final replay = CinematicReplay.fromMoves(
      moves: [
        'e2e4',
        'e7e5',
        'g1f3',
        'b8c6',
        'f1e2',
        'g8f6',
        'e1g1',
        'f8e7',
        'd2d3',
        'e8g8',
      ],
    );
    for (final scene in [replay.scenes[6], replay.scenes.last]) {
      await render(
        tester,
        scene,
        progress: .85,
        compact: true,
        captionInset: 0,
        size: const Size(390, 354),
      );
      final center = tester
          .getCenter(find.byKey(const ValueKey('neon-illustrated-stage')))
          .dx;
      for (final role in ['king', 'rook']) {
        final key = role == 'king'
            ? 'film-hero-${scene.side.name}-king'
            : 'film-victim-${scene.side.name}-rook';
        final x = tester.getCenter(find.byKey(ValueKey(key))).dx;
        expect(scene.side == Side.white ? x < center : x > center, isTrue);
      }
      for (final actor in tester.widgetList<NeonFigureSprite>(
        find.byType(NeonFigureSprite),
      )) {
        expect(actor.faceRight, actor.piece.color == Side.white);
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'intro and finale retain white left, black right and inward facing',
    (tester) async {
      for (final intro in [true, false]) {
        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              width: 390,
              height: 354,
              child: NeonIllustratedStage(
                scene: null,
                progress: .8,
                intro: intro,
                finale: !intro,
                reducedMotion: false,
                title: '',
                subtitle: '',
                resultTitle: 'Black wins by checkmate',
                compact: true,
                captionInset: 0,
              ),
            ),
          ),
        );
        await tester.pump();
        final white = find.byKey(const ValueKey('film-leader-white'));
        final black = find.byKey(const ValueKey('film-leader-black'));
        expect(
          tester.getCenter(white).dx,
          lessThan(tester.getCenter(black).dx),
        );
        expect(tester.widget<NeonFigureSprite>(white).faceRight, isTrue);
        expect(tester.widget<NeonFigureSprite>(black).faceRight, isFalse);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('black promotion keeps its lane, victim lane and direction', (
    tester,
  ) async {
    final scene = CinematicReplay.fromMoves(
      moves: [
        'a2a4',
        'h7h5',
        'a4a5',
        'h5h4',
        'a5a6',
        'h4h3',
        'a6b7',
        'h3g2',
        'b7a8n',
        'g2h1q',
      ],
    ).scenes.last;
    await render(
      tester,
      scene,
      progress: .85,
      compact: true,
      captionInset: 0,
      size: const Size(390, 354),
    );
    final queen = find.byKey(const ValueKey('film-hero-black-queen'));
    final rook = find.byKey(const ValueKey('film-victim-white-rook'));
    expect(tester.getCenter(queen).dx, greaterThan(tester.getCenter(rook).dx));
    expect(tester.widget<NeonFigureSprite>(queen).faceRight, isFalse);
    expect(tester.widget<NeonFigureSprite>(rook).faceRight, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'large threat portraits paginate in groups of three and reset by scene',
    (tester) async {
      final scene = CinematicReplay.fromMoves(
        moves: ['e2e4', 'f7f6', 'd1h5'],
      ).scenes.last;
      final fixtures =
          [
                (Piece.blackKing, Square.e8, true),
                (Piece.blackQueen, Square.d8, false),
                (Piece.blackRook, Square.h8, false),
                (Piece.blackKnight, Square.g8, false),
                (Piece.blackPawn, Square.f7, false),
              ]
              .map(
                (entry) => CinematicThreat(
                  piece: entry.$1,
                  square: entry.$2,
                  newlyThreatened: true,
                  attacks: [
                    CaptureThreat(
                      from: Square.h5,
                      to: entry.$2,
                      targetSquare: entry.$2,
                      attacker: Piece.whiteQueen,
                      target: entry.$1,
                      isCheck: entry.$3,
                    ),
                  ],
                ),
              )
              .toList();
      await render(
        tester,
        scene,
        progress: .85,
        compact: true,
        captionInset: 0,
        threats: fixtures,
        size: const Size(390, 354),
      );
      expect(find.text('1 / 2'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('neon-threat-black-king-e8')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('neon-threat-black-queen-d8')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('neon-threat-black-rook-h8')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('neon-threat-black-knight-g8')),
        findsNothing,
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('neon-threat-portrait-e8')))
            .width,
        greaterThanOrEqualTo(50),
      );
      final rows = [
        tester.getRect(find.byKey(const ValueKey('neon-threat-black-king-e8'))),
        tester.getRect(
          find.byKey(const ValueKey('neon-threat-black-queen-d8')),
        ),
        tester.getRect(find.byKey(const ValueKey('neon-threat-black-rook-h8'))),
      ];
      expect(rows[0].bottom, lessThanOrEqualTo(rows[1].top));
      expect(rows[1].bottom, lessThanOrEqualTo(rows[2].top));
      expect(rows[0].center.dx, closeTo(rows[1].center.dx, .01));
      expect(rows[1].center.dx, closeTo(rows[2].center.dx, .01));
      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('neon-threat-page-prev')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('neon-threat-page-next')));
      await tester.pump();
      expect(find.text('2 / 2'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('neon-threat-black-king-e8')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('neon-threat-black-knight-g8')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('neon-threat-black-pawn-f7')),
        findsOneWidget,
      );
      await render(
        tester,
        scene,
        progress: .95,
        compact: true,
        captionInset: 0,
        threats: fixtures,
        size: const Size(390, 354),
      );
      expect(find.text('2 / 2'), findsOneWidget);
      final nextScene = CinematicReplay.fromMoves(moves: ['g1f3']).scenes.last;
      await render(
        tester,
        nextScene,
        progress: .85,
        compact: true,
        captionInset: 0,
        threats: fixtures,
        size: const Size(390, 354),
      );
      expect(find.text('1 / 2'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('neon-threat-black-king-e8')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'capture retains the full victim and stamps its encounter after landing',
    (tester) async {
      final scene = CinematicReplay.fromMoves(
        moves: ['e2e4', 'd7d5', 'e4d5'],
      ).scenes.last;
      await render(tester, scene);
      expect(portrait('white', 'pawn'), findsOneWidget);
      expect(portrait('black', 'pawn'), findsOneWidget);
      expect(find.byKey(const ValueKey('neon-capture-winner')), findsNothing);
      expect(find.byKey(const ValueKey('neon-capture-defeated')), findsNothing);
      await render(tester, scene, progress: .55);
      expect(find.text('WINNER'), findsNothing);
      expect(find.text('DEFEATED'), findsNothing);
      await render(tester, scene, progress: .56);
      expect(find.byKey(const ValueKey('neon-capture-winner')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('neon-capture-defeated')),
        findsOneWidget,
      );
      await render(tester, scene, progress: .85);
      expect(portrait('white', 'pawn'), findsOneWidget);
      expect(portrait('black', 'pawn'), findsOneWidget);
      expect(portrait('black', 'king'), findsNothing);
      final hero = tester.getRect(
        find.byKey(const ValueKey('film-hero-white-pawn')),
      );
      final victim = tester.getRect(
        find.byKey(const ValueKey('film-victim-black-pawn')),
      );
      expect(victim.center.dx, greaterThan(hero.center.dx));
      expect(find.text('WINNER'), findsOneWidget);
      expect(find.text('DEFEATED'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'capture and check keep the victim separate from the threatened king',
    (tester) async {
      final scene = CinematicReplay.fromMoves(
        moves: ['e2e4', 'e7e5', 'd1h5', 'b8c6', 'f1c4', 'g8f6', 'h5f7'],
      ).scenes.last;
      expect(scene.isCheckmate, isTrue);
      await render(tester, scene);
      expect(
        find.byKey(const ValueKey('film-victim-black-pawn')),
        findsOneWidget,
      );
      expect(portrait('black', 'king'), findsNothing);
      await render(tester, scene, progress: .9);
      expect(
        find.byKey(const ValueKey('film-victim-black-pawn')),
        findsOneWidget,
      );
      expect(portrait('black', 'king'), findsOneWidget);
      expect(portrait('white', 'queen'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('neon-threat-black-king-e8')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('film-victim-black-king')),
        findsNothing,
      );
      expect(find.text('DEFEATED'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('castling presents the allied rook instead of an enemy', (
    tester,
  ) async {
    final scene = CinematicReplay.fromMoves(
      moves: ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1e2', 'g8f6', 'e1g1'],
    ).scenes.last;
    await render(tester, scene, progress: .8);
    expect(portrait('white', 'king'), findsOneWidget);
    expect(portrait('white', 'rook'), findsOneWidget);
    expect(portrait('black', 'rook'), findsNothing);
    expect(find.text('E1'), findsOneWidget);
    expect(find.text('G1'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('promotion changes the pawn into the actual selected role', (
    tester,
  ) async {
    final scene = CinematicReplay.fromMoves(
      moves: [
        'a2a4',
        'h7h5',
        'a4a5',
        'h5h4',
        'a5a6',
        'h4h3',
        'a6b7',
        'h3g2',
        'b7a8n',
      ],
    ).scenes.last;
    await render(tester, scene);
    expect(portrait('white', 'pawn'), findsOneWidget);
    await render(tester, scene, progress: .82);
    expect(portrait('white', 'pawn'), findsNothing);
    expect(portrait('white', 'knight'), findsOneWidget);
    expect(portrait('white', 'queen'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reduced motion keeps the composition stable while time advances',
    (tester) async {
      final scene = CinematicReplay.fromMoves(moves: ['g1f3']).scenes.single;
      await render(tester, scene, progress: .1, reduced: true);
      final before = tester.getRect(portrait('white', 'knight'));
      await render(tester, scene, progress: .9, reduced: true);
      expect(tester.getRect(portrait('white', 'knight')), before);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('art stage fits narrow and landscape screens without overflow', (
    tester,
  ) async {
    final scene = CinematicReplay.fromMoves(moves: ['e2e4']).scenes.single;
    await render(tester, scene, size: const Size(320, 480));
    expect(tester.takeException(), isNull);
    await render(tester, scene, size: const Size(760, 330));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'black captures put the black mover right and white victim left',
    (tester) async {
      final scene = CinematicReplay.fromMoves(
        moves: ['e2e4', 'd7d5', 'e4d5', 'd8d5'],
      ).scenes.last;
      await render(
        tester,
        scene,
        progress: .85,
        compact: true,
        size: const Size(390, 354),
      );
      final hero = tester.getRect(
        find.byKey(const ValueKey('film-hero-black-queen')),
      );
      final victim = tester.getRect(
        find.byKey(const ValueKey('film-victim-white-pawn')),
      );
      expect(hero.center.dx, greaterThan(victim.center.dx));
      final stage = tester.getRect(
        find.byKey(const ValueKey('neon-illustrated-stage')),
      );
      expect(hero.center.dx, greaterThan(stage.center.dx));
      expect(victim.center.dx, lessThan(stage.center.dx));
      final winner = tester.getRect(
        find.byKey(const ValueKey('neon-capture-winner')),
      );
      final defeated = tester.getRect(
        find.byKey(const ValueKey('neon-capture-defeated')),
      );
      expect(winner.center.dx, greaterThan(defeated.center.dx));
      expect(find.byKey(const ValueKey('neon-capture-winner')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('neon-capture-defeated')),
        findsOneWidget,
      );
      expect(find.text('WINNER'), findsOneWidget);
      expect(find.text('DEFEATED'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('quiet move threats appear only once the move lands', (
    tester,
  ) async {
    final scene = CinematicReplay.fromMoves(
      moves: ['e2e4', 'e7e5', 'd1h5'],
    ).scenes.last;
    await render(
      tester,
      scene,
      progress: .55,
      compact: true,
      size: const Size(390, 354),
    );
    expect(find.byKey(const ValueKey('neon-threat-bubbles')), findsNothing);
    await render(
      tester,
      scene,
      progress: .56,
      compact: true,
      size: const Size(390, 354),
    );
    expect(find.byKey(const ValueKey('neon-threat-bubbles')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('neon-threat-black-pawn-e5')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('neon-threat-black-pawn-f7')),
      findsOneWidget,
    );
    expect(find.text('PAWN\nE5'), findsOneWidget);
    expect(find.text('PAWN\nF7'), findsOneWidget);
    expect(find.text('WINNER'), findsNothing);
    expect(find.text('DEFEATED'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reduced motion preserves the real landing time for outcome and threats',
    (tester) async {
      final scene = CinematicReplay.fromMoves(
        moves: ['e2e4', 'e7e5', 'd1h5', 'b8c6', 'f1c4', 'g8f6', 'h5f7'],
      ).scenes.last;
      await render(
        tester,
        scene,
        progress: .55,
        reduced: true,
        compact: true,
        size: const Size(390, 354),
      );
      expect(find.byKey(const ValueKey('neon-threat-bubbles')), findsNothing);
      expect(find.text('DEFEATED'), findsNothing);
      await render(
        tester,
        scene,
        progress: .56,
        reduced: true,
        compact: true,
        size: const Size(390, 354),
      );
      expect(
        find.byKey(const ValueKey('neon-threat-black-king-e8')),
        findsOneWidget,
      );
      expect(find.text('WINNER'), findsOneWidget);
      expect(find.text('DEFEATED'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('compact capture and threats fit short panes and large text', (
    tester,
  ) async {
    final scene = CinematicReplay.fromMoves(
      moves: ['e2e4', 'e7e5', 'd1h5', 'b8c6', 'f1c4', 'g8f6', 'h5f7'],
    ).scenes.last;
    for (final size in [const Size(320, 216), const Size(760, 115)]) {
      await render(tester, scene, progress: .85, compact: true, size: size);
      final stage = tester.getRect(
        find.byKey(const ValueKey('neon-illustrated-stage')),
      );
      for (final key in [
        'film-hero-white-queen',
        'film-victim-black-pawn',
        'neon-capture-winner',
        'neon-capture-defeated',
        'neon-threat-bubbles',
      ]) {
        final bounds = tester.getRect(find.byKey(ValueKey(key)));
        expect(stage.contains(bounds.topLeft), isTrue, reason: '$key in $size');
        expect(
          stage.contains(bounds.bottomRight - const Offset(.1, .1)),
          isTrue,
          reason: '$key in $size',
        );
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'separated captions leave a complete victim even in very short action space',
    (tester) async {
      final scene = CinematicReplay.fromMoves(
        moves: ['e2e4', 'e7e5', 'd1h5', 'b8c6', 'f1c4', 'g8f6', 'h5f7'],
      ).scenes.last;
      for (final size in [
        const Size(390, 270),
        const Size(320, 155),
        const Size(760, 70),
        const Size(650, 40),
      ]) {
        await render(
          tester,
          scene,
          progress: .85,
          compact: true,
          captionInset: 0,
          textScale: 1.5,
          size: size,
        );
        final stage = tester.getRect(
          find.byKey(const ValueKey('neon-illustrated-stage')),
        );
        for (final key in [
          'film-hero-white-queen',
          'film-victim-black-pawn',
          'neon-capture-winner',
          'neon-capture-defeated',
          'neon-threat-bubbles',
        ]) {
          final bounds = tester.getRect(find.byKey(ValueKey(key)));
          expect(bounds.height, greaterThan(0), reason: '$key in $size');
          expect(bounds.width, greaterThan(0), reason: '$key in $size');
          expect(
            stage.contains(bounds.topLeft),
            isTrue,
            reason: '$key in $size',
          );
          expect(
            stage.contains(bounds.bottomRight - const Offset(.1, .1)),
            isTrue,
            reason: '$key in $size',
          );
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'compact threat bubbles clear route labels and the defeat stamp',
    (tester) async {
      final scene = CinematicReplay.fromMoves(
        moves: ['e2e4', 'e7e5', 'd1h5', 'b8c6', 'f1c4', 'g8f6', 'h5f7'],
      ).scenes.last;
      for (final scale in [1.0, 1.5, 2.0]) {
        await render(
          tester,
          scene,
          progress: .85,
          compact: true,
          captionInset: 0,
          textScale: scale,
          size: const Size(390, 270),
        );
        final route = tester.getRect(
          find.byKey(const ValueKey('neon-move-route')),
        );
        final bubbles = tester.getRect(
          find.byKey(const ValueKey('neon-threat-bubbles')),
        );
        final defeated = tester.getRect(
          find.byKey(const ValueKey('neon-capture-defeated')),
        );
        expect(bubbles.top, greaterThanOrEqualTo(route.bottom));
        expect(defeated.overlaps(bubbles), isFalse);
        expect(find.text('H5'), findsOneWidget);
        expect(find.text('F7'), findsOneWidget);
        expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );
}
