// SPDX-License-Identifier: GPL-3.0-or-later
// Opt-in original-art review, not platform goldens:
// flutter test --dart-define=CAPTURE_EQUAL_SCALE=true
// test/animated_equal_scale_preview_test.dart
import 'dart:convert';
import 'dart:io' as io;
import 'dart:ui' as ui;

import 'package:battle_chess_arena/src/domain/cinematic_replay.dart';
import 'package:battle_chess_arena/src/domain/animated_army_theme.dart';
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

const _capture = bool.fromEnvironment('CAPTURE_EQUAL_SCALE');
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
  for (var wait = 0; wait < 50; wait++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    final raw = tester.widgetList<RawImage>(find.byType(RawImage)).toList();
    final poseCount = tester
        .widgetList<NeonFigureSprite>(find.byType(NeonFigureSprite))
        .where(
          (figure) =>
              figure.theme == AnimatedArmyTheme.neon &&
              (figure.pose != NeonFigurePose.rest || figure.fromPose != null),
        )
        .length;
    final paintedPoses = find
        .byWidgetPredicate(
          (widget) =>
              widget is CustomPaint &&
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith('neon-pose-'),
        )
        .evaluate()
        .length;
    if (raw.length == tester.widgetList<Image>(find.byType(Image)).length &&
        raw.every((image) => image.image != null) &&
        paintedPoses == poseCount) {
      break;
    }
  }
  expect(
    tester
        .widgetList<RawImage>(find.byType(RawImage))
        .every((image) => image.image != null),
    isTrue,
  );
  final boundary =
      _frame.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = io.Directory('build/animated-equal-scale-preview')
      ..createSync(recursive: true);
    await io.File(
      '${directory.path}/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets(
    'opt-in equal-body capture and finale art review for all four armies',
    (tester) async {
      await _fonts(tester);
      final scene = CinematicReplay.fromMoves(
        moves: ['e2e4', 'e7e5', 'd1h5', 'b8c6', 'f1c4', 'g8f6', 'h5f7'],
      ).scenes.last;
      for (final theme in AnimatedArmyTheme.values) {
        for (final shape in [
          ('portrait', const Size(390, 240), 1.0),
          ('landscape-2x', const Size(760, 115), 2.0),
        ]) {
          final action = ValueNotifier<NeonLiveAction?>(null);
          final moved = ValueNotifier(false);
          await _mount(
            tester,
            ValueListenableBuilder<bool>(
              valueListenable: moved,
              builder: (context, changed, _) =>
                  ValueListenableBuilder<NeonLiveAction?>(
                    valueListenable: action,
                    builder: (context, value, _) => NeonLiveArena(
                      theme: theme,
                      viewerSide: Side.white,
                      position: changed ? scene.after : scene.before,
                      action: value,
                      reducedMotion: false,
                    ),
                  ),
            ),
            shape.$2,
            textScale: shape.$3,
          );
          // Decode source sheets before the timed capture; loading must not be mistaken for an outcome.
          await _save(tester, '${theme.name}-${shape.$1}-live-idle');
          action.value = NeonLiveAction.selection(
            position: scene.before,
            source: scene.source,
            viewerSide: Side.white,
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 180));
          await _save(tester, '${theme.name}-${shape.$1}-live-selected');
          action.value = NeonLiveAction.move(
            before: scene.before,
            after: scene.after,
            resolution: scene.resolution,
            viewerSide: Side.white,
          );
          moved.value = true;
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 395));
          await _save(tester, '${theme.name}-${shape.$1}-live-impact');
          await tester.pump(const Duration(milliseconds: 455));
          await _save(tester, '${theme.name}-${shape.$1}-live-aftermath');
          await tester.pumpWidget(const SizedBox.shrink());
          action.dispose();
          moved.dispose();
          for (final progress in [.56, .9]) {
            await _mount(
              tester,
              NeonIllustratedStage(
                scene: scene,
                progress: progress,
                intro: false,
                finale: false,
                reducedMotion: false,
                title: '',
                subtitle: '',
                resultTitle: 'White wins',
                theme: theme,
                compact: true,
                captionInset: 0,
                threats: cinematicThreatsAfter(scene),
              ),
              shape.$2,
              textScale: shape.$3,
            );
            await _save(
              tester,
              '${theme.name}-${shape.$1}-film-${progress == .56 ? 'impact' : 'aftermath'}',
            );
          }
        }
        await _mount(
          tester,
          NeonIllustratedStage(
            scene: null,
            progress: 1,
            intro: false,
            finale: true,
            reducedMotion: true,
            title: '',
            subtitle: '',
            resultTitle: 'Black wins',
            theme: theme,
            compact: true,
            captionInset: 0,
          ),
          const Size(390, 240),
        );
        await _save(tester, '${theme.name}-film-black-victory-equal-leaders');
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.binding.setSurfaceSize(null);
    },
    skip: !_capture,
  );
}
