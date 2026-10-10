// SPDX-License-Identifier: GPL-3.0-or-later
// Opt-in original-art review, not platform goldens:
// flutter test --dart-define=CAPTURE_NEON_POSES=true
// test/neon_capture_pose_preview_test.dart
import 'dart:convert';
import 'dart:io' as io;
import 'dart:ui' as ui;

import 'package:battle_chess_arena/src/domain/cinematic_replay.dart';
import 'package:battle_chess_arena/src/domain/animated_army_theme.dart';
import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/domain/neon_live_action.dart';
import 'package:battle_chess_arena/src/features/play/neon_illustrated_stage.dart';
import 'package:battle_chess_arena/src/features/play/neon_live_arena.dart';
import 'package:battle_chess_arena/src/theme/app_theme.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _capture = bool.fromEnvironment('CAPTURE_NEON_POSES');
final _frame = GlobalKey();

class _ArtworkBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) {
    final file = io.File(key);
    if (key.startsWith('assets/') && file.existsSync()) {
      return SynchronousFuture(ByteData.sublistView(file.readAsBytesSync()));
    }
    return rootBundle.load(key);
  }
}

Future<void> _fonts(WidgetTester tester) => tester.runAsync(() async {
  final config = io.File('.dart_tool/package_config.json').absolute;
  final json = jsonDecode(await config.readAsString()) as Map<String, dynamic>;
  final flutter = (json['packages'] as List)
      .cast<Map<String, dynamic>>()
      .singleWhere((package) => package['name'] == 'flutter');
  final fonts = config.uri
      .resolve('${flutter['rootUri']}/')
      .resolve('../../bin/cache/artifacts/material_fonts/');
  final loader = FontLoader('Roboto');
  for (final name in [
    'Roboto-Regular.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Black.ttf',
  ]) {
    loader.addFont(
      io.File.fromUri(
        fonts.resolve(name),
      ).readAsBytes().then(ByteData.sublistView),
    );
  }
  await loader.load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
});

Future<void> _mount(
  WidgetTester tester,
  Widget child,
  Size size, {
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(size);
  final theme = buildAppTheme();
  await tester.pumpWidget(
    MaterialApp(
      theme: theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(size: size, textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: DefaultAssetBundle(
        bundle: _ArtworkBundle(),
        child: Material(
          type: MaterialType.transparency,
          child: RepaintBoundary(key: _frame, child: child),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _save(WidgetTester tester, String name) async {
  final expectedPoses = name.endsWith('all-twelve-roles')
      ? 12
      : name.startsWith('neon-') &&
            (name.endsWith('-avatar') || name.endsWith('-accepted-impact'))
      ? 1
      : 0;
  // Decode every original source image, rather than capturing a loading slot.
  for (var wait = 0; wait < 50; wait++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    final raw = tester.widgetList<RawImage>(find.byType(RawImage));
    final posedGallery =
        expectedPoses == 0 ||
        find
                .byWidgetPredicate(
                  (widget) =>
                      widget is CustomPaint &&
                      widget.key is ValueKey<String> &&
                      (widget.key! as ValueKey<String>).value.startsWith(
                        'neon-pose-',
                      ),
                )
                .evaluate()
                .length >=
            expectedPoses;
    if (raw.length == tester.widgetList<Image>(find.byType(Image)).length &&
        raw.every((image) => image.image != null) &&
        posedGallery) {
      break;
    }
  }
  final raw = tester.widgetList<RawImage>(find.byType(RawImage)).toList();
  expect(raw.length, tester.widgetList<Image>(find.byType(Image)).length);
  expect(
    raw.every((image) => image.image != null),
    isTrue,
    reason: 'Every gallery/scene image must be an actual decoded asset',
  );
  if (expectedPoses > 0) {
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint &&
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('neon-pose-'),
      ),
      findsNWidgets(expectedPoses),
      reason: 'All measured pose frames must use the decoded pose painter.',
    );
  }
  await tester.pump();
  final boundary =
      _frame.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = io.Directory('build/neon-capture-pose-preview-v1')
      ..createSync(recursive: true);
    await io.File(
      '${directory.path}/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
  expect(tester.takeException(), isNull);
}

Widget _gallery(NeonFigurePose pose) => Material(
  color: const Color(0xFF101827),
  child: Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(10),
        child: Text(
          'NEON DOMINION · ${pose.name.toUpperCase()} · grounded capture poses',
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      for (var row = 0; row < 3; row++)
        Expanded(
          child: Row(
            children: [
              for (final entry in [
                for (final side in Side.values)
                  for (final role in [
                    Role.king,
                    Role.queen,
                    Role.bishop,
                    Role.knight,
                    Role.rook,
                    Role.pawn,
                  ])
                    (side, role),
              ].skip(row * 4).take(4))
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .05),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                const Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: ColoredBox(
                                    color: Color(0xFF597487),
                                    child: SizedBox(height: 1),
                                  ),
                                ),
                                NeonFigureSprite(
                                  piece: Piece(color: entry.$1, role: entry.$2),
                                  faceRight: entry.$1 == Side.white,
                                  pose: pose,
                                  // Recovery uses the same footprint at mix=1, so contacts
                                  // compare rest, ready and attack at identical body scales.
                                  fromPose: pose == NeonFigurePose.rest
                                      ? NeonFigurePose.attack
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            '${entry.$1.name.toUpperCase()} ${entry.$2.name.toUpperCase()}',
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
    ],
  ),
);

void main() {
  testWidgets('optional actual-art castles across all Animated armies', (
    tester,
  ) async {
    await _fonts(tester);
    for (final theme in AnimatedArmyTheme.values) {
      for (final fixture in [
        ('white', '5k2/8/8/8/8/8/8/4K2R w K - 0 1', 'e1g1'),
        ('black', 'r3k3/8/8/8/8/8/8/3K4 b q - 0 1', 'e8c8'),
      ]) {
        final before = Chess.fromSetup(Setup.parseFen(fixture.$2));
        final game = GameSession(position: before);
        final resolution = game.playUci(fixture.$3)!;
        final selected = NeonLiveAction.selection(
          position: before,
          source: resolution.move.from,
        );
        final accepted = NeonLiveAction.move(
          before: before,
          after: game.position,
          resolution: resolution,
          viewerSide: Side.white,
        )!;
        final moved = ValueNotifier(false);
        await _mount(
          tester,
          ValueListenableBuilder<bool>(
            valueListenable: moved,
            builder: (context, changed, _) => NeonLiveArena(
              key: const ValueKey('castle-art-preview'),
              viewerSide: Side.white,
              position: changed ? game.position : before,
              action: changed ? accepted : selected,
              theme: theme,
            ),
          ),
          const Size(450, 260),
        );
        moved.value = true;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        final king = tester.widget<NeonFigureSprite>(
          find.byKey(
            ValueKey(
              'neon-live-${accepted.actorOnLeft ? 'left' : 'right'}-figure',
            ),
          ),
        );
        final rook = tester.widget<NeonFigureSprite>(
          find.byKey(const ValueKey('neon-live-castling-rook')),
        );
        expect(king.bodyHeight, rook.bodyHeight);
        expect(king.faceRight, accepted.actorOnLeft);
        expect(rook.faceRight, accepted.actorOnLeft);
        expect(
          find.byKey(const ValueKey('neon-live-selection-comment')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('neon-live-capture-defeated')),
          findsNothing,
        );
        await _save(tester, '${theme.name}-${fixture.$1}-castle-landing');
        await tester.pump(const Duration(milliseconds: 450));
        await _save(tester, '${theme.name}-${fixture.$1}-castle-settled');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        moved.dispose();
      }
    }
    await tester.binding.setSurfaceSize(null);
  }, skip: !_capture);
  testWidgets(
    'optional stationary avatars and accepted moves in all Animated armies',
    (tester) async {
      await _fonts(tester);
      for (final theme in AnimatedArmyTheme.values) {
        for (final fixture in [
          ('white', ['e2e4', 'd7d5', 'e4d5'], Side.white, const Size(390, 240)),
          (
            'black',
            ['e2e4', 'd7d5', 'e4d5', 'd8d5'],
            Side.black,
            const Size(450, 240),
          ),
        ]) {
          final scene = CinematicReplay.fromMoves(
            moves: fixture.$2,
          ).scenes.last;
          final action = ValueNotifier<NeonLiveAction?>(
            NeonLiveAction.selection(
              position: scene.before,
              source: scene.source,
              viewerSide: fixture.$3,
            ),
          );
          final moved = ValueNotifier(false);
          await _mount(
            tester,
            ValueListenableBuilder<bool>(
              valueListenable: moved,
              builder: (context, changed, _) =>
                  ValueListenableBuilder<NeonLiveAction?>(
                    valueListenable: action,
                    builder: (context, value, _) => NeonLiveArena(
                      key: const ValueKey('avatar-preview'),
                      viewerSide: fixture.$3,
                      position: changed ? scene.after : scene.before,
                      action: value,
                      theme: theme,
                    ),
                  ),
            ),
            fixture.$4,
          );
          await _save(tester, '${theme.name}-${fixture.$1}-avatar');
          final avatar = find.byKey(const ValueKey('neon-live-left-figure'));
          final bounds = tester.getRect(avatar);
          expect(
            find.byKey(const ValueKey('neon-live-selection-comment')),
            findsOneWidget,
          );
          await tester.pump(const Duration(milliseconds: 500));
          expect(tester.getRect(avatar), bounds);
          action.value = NeonLiveAction.move(
            before: scene.before,
            after: scene.after,
            resolution: scene.resolution,
            viewerSide: fixture.$3,
          );
          moved.value = true;
          await tester.pump();
          expect(
            find.byKey(const ValueKey('neon-live-selection-comment')),
            findsNothing,
          );
          await tester.pump(const Duration(milliseconds: 400));
          await _save(tester, '${theme.name}-${fixture.$1}-accepted-impact');
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          action.dispose();
          moved.dispose();
        }
      }
      await tester.binding.setSurfaceSize(null);
    },
    skip: !_capture,
  );
  testWidgets(
    'optional Neon capture pose contact and continuous motion review',
    (tester) async {
      await _fonts(tester);
      for (final pose in NeonFigurePose.values) {
        await _mount(tester, _gallery(pose), const Size(2400, 1480));
        await _save(tester, '${pose.name}-all-twelve-roles');
      }
      for (final fixture in [
        ('white-pawn', ['e2e4', 'd7d5', 'e4d5'], Side.white),
        ('black-queen', ['e2e4', 'd7d5', 'e4d5', 'd8d5'], Side.black),
        ('local-black-queen', ['e2e4', 'd7d5', 'e4d5', 'd8d5'], Side.white),
      ]) {
        final scene = CinematicReplay.fromMoves(moves: fixture.$2).scenes.last;
        final action = ValueNotifier<NeonLiveAction?>(null);
        final moved = ValueNotifier(false);
        final lane = scene.side == fixture.$3 ? 'left' : 'right';
        await _mount(
          tester,
          ValueListenableBuilder<bool>(
            valueListenable: moved,
            builder: (context, changed, _) =>
                ValueListenableBuilder<NeonLiveAction?>(
                  valueListenable: action,
                  builder: (context, value, _) => NeonLiveArena(
                    key: const ValueKey('pose-live-continuation'),
                    viewerSide: fixture.$3,
                    position: changed ? scene.after : scene.before,
                    action: value,
                  ),
                ),
          ),
          const Size(390, 240),
        );
        // Let both pose sheets finish precaching before the first selection.
        await _save(tester, '${fixture.$1}-idle');
        action.value = NeonLiveAction.selection(
          position: scene.before,
          source: scene.resolution.move.from,
          viewerSide: fixture.$3,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        await _save(tester, '${fixture.$1}-ready-selection');
        final selected = tester.getRect(
          find.byKey(ValueKey('neon-live-$lane-figure')),
        );
        action.value = NeonLiveAction.move(
          before: scene.before,
          after: scene.after,
          resolution: scene.resolution,
          viewerSide: fixture.$3,
        );
        moved.value = true;
        await tester.pump();
        expect(
          tester.getRect(find.byKey(ValueKey('neon-live-$lane-figure'))),
          selected,
        );
        await _save(tester, '${fixture.$1}-handoff');
        await tester.pump(const Duration(milliseconds: 250));
        await _save(tester, '${fixture.$1}-windup');
        await tester.pump(const Duration(milliseconds: 145));
        await _save(tester, '${fixture.$1}-impact');
        await tester.pump(const Duration(milliseconds: 255));
        await _save(tester, '${fixture.$1}-recovery');
        await tester.pump(const Duration(milliseconds: 200));
        await _save(tester, '${fixture.$1}-settled');
        await tester.pumpWidget(const SizedBox.shrink());
        action.dispose();
        moved.dispose();
      }
      await tester.binding.setSurfaceSize(null);
    },
    skip: !_capture,
  );
}
