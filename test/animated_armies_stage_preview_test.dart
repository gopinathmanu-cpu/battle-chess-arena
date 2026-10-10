// SPDX-License-Identifier: GPL-3.0-or-later
// Opt-in original-art review, not platform goldens:
// flutter test --dart-define=CAPTURE_ANIMATED_ARMIES=true
// test/animated_armies_stage_preview_test.dart
import 'dart:convert';
import 'dart:io' as io;
import 'dart:ui' as ui;

import 'package:battle_chess_arena/src/domain/animated_army_theme.dart';
import 'package:battle_chess_arena/src/domain/cinematic_replay.dart';
import 'package:battle_chess_arena/src/domain/cinematic_threats.dart';
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

const _capture = bool.fromEnvironment('CAPTURE_ANIMATED_ARMIES');
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
        child: RepaintBoundary(key: _frame, child: child),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _save(WidgetTester tester, String name) async {
  // Decode every original source image, rather than capturing a loading slot.
  for (var wait = 0; wait < 50; wait++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    final raw = tester.widgetList<RawImage>(find.byType(RawImage));
    if (raw.length == tester.widgetList<Image>(find.byType(Image)).length &&
        raw.every((image) => image.image != null)) {
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
  await tester.pump();
  final boundary =
      _frame.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = io.Directory('build/animated-armies-preview-v1')
      ..createSync(recursive: true);
    await io.File(
      '${directory.path}/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
  expect(tester.takeException(), isNull);
}

Widget _gallery(AnimatedArmyTheme theme) => Material(
  color: Color(theme.baseColorArgb),
  child: Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          '${theme.displayName} · original six-role casts',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
      ),
      for (final side in Side.values)
        Expanded(
          child: Row(
            children: [
              for (final role in [
                Role.king,
                Role.queen,
                Role.bishop,
                Role.knight,
                Role.rook,
                Role.pawn,
              ])
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .08),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: NeonFigureSprite(
                              theme: theme,
                              piece: Piece(color: side, role: role),
                              faceRight: side == Side.white,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            '${side.name.toUpperCase()} ${role.name.toUpperCase()}',
                            style: const TextStyle(
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

Widget _stage(
  AnimatedArmyTheme theme,
  CinematicReplayScene scene,
  double progress, {
  bool reduced = false,
  bool finale = false,
  String result = 'Game unfinished',
}) => NeonIllustratedStage(
  theme: theme,
  scene: scene,
  progress: progress,
  intro: false,
  finale: finale,
  reducedMotion: reduced,
  title: '',
  subtitle: '',
  resultTitle: result,
  compact: true,
  captionInset: 0,
  threats: cinematicThreatsAfter(scene),
);

void main() {
  testWidgets('optional original four-army cast and action review', (
    tester,
  ) async {
    await _fonts(tester);
    final capture = CinematicReplay.fromMoves(
      moves: ['e2e4', 'd7d5', 'e4d5', 'd8d5'],
    ).scenes.last;
    final mate = CinematicReplay.fromMoves(
      moves: ['e2e4', 'e7e5', 'd1h5', 'b8c6', 'f1c4', 'g8f6', 'h5f7'],
    ).scenes.last;
    for (final theme in AnimatedArmyTheme.values) {
      await _mount(tester, _gallery(theme), const Size(1800, 940));
      await _save(tester, '${theme.name}-all-twelve-roles');
      await _mount(tester, _stage(theme, capture, .46), const Size(390, 260));
      await _save(tester, '${theme.name}-black-capture-strike');
      await _mount(
        tester,
        _stage(theme, mate, .68),
        const Size(320, 216),
        textScale: 2,
      );
      await _save(tester, '${theme.name}-capture-checkmate-small');
      await _mount(
        tester,
        _stage(theme, mate, .8, finale: true, result: 'White wins · Checkmate'),
        const Size(760, 240),
      );
      await _save(tester, '${theme.name}-verified-victory');
      await _mount(
        tester,
        _stage(theme, capture, .7, reduced: true),
        const Size(760, 115),
        textScale: 2,
      );
      await _save(tester, '${theme.name}-reduced-capture-short-landscape');

      final action = ValueNotifier<NeonLiveAction?>(null);
      final after = ValueNotifier(false);
      await _mount(
        tester,
        ValueListenableBuilder<bool>(
          valueListenable: after,
          builder: (context, moved, _) =>
              ValueListenableBuilder<NeonLiveAction?>(
                valueListenable: action,
                builder: (context, value, _) => NeonLiveArena(
                  key: const ValueKey('preview-live-continuation'),
                  theme: theme,
                  viewerSide: Side.black,
                  position: moved ? capture.after : capture.before,
                  action: value,
                ),
              ),
        ),
        const Size(390, 240),
      );
      action.value = NeonLiveAction.selection(
        position: capture.before,
        source: Square.d8,
        viewerSide: Side.black,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 210));
      await _save(tester, '${theme.name}-black-live-selection');
      final selected = tester.getRect(
        find.byKey(const ValueKey('neon-live-left-figure')),
      );
      after.value = true;
      action.value = NeonLiveAction.move(
        before: capture.before,
        after: capture.after,
        resolution: capture.resolution,
        viewerSide: Side.black,
      );
      await tester.pump();
      expect(
        tester.getRect(find.byKey(const ValueKey('neon-live-left-figure'))),
        selected,
      );
      await tester.pump(const Duration(milliseconds: 300));
      await _save(tester, '${theme.name}-black-live-capture-impact');
      await tester.pump(const Duration(milliseconds: 550));
      await _save(tester, '${theme.name}-black-live-capture-settled');
      await tester.pumpWidget(const SizedBox.shrink());
      action.dispose();
      after.dispose();
      await _mount(
        tester,
        NeonLiveArena(
          theme: theme,
          viewerSide: Side.white,
          position: mate.after,
          reducedMotion: true,
          action: NeonLiveAction.move(
            before: mate.before,
            after: mate.after,
            resolution: mate.resolution,
            viewerSide: Side.white,
          ),
        ),
        const Size(760, 115),
        textScale: 2,
      );
      await _save(tester, '${theme.name}-live-mate-short-landscape');
    }
    await tester.binding.setSurfaceSize(null);
  }, skip: !_capture);
}
