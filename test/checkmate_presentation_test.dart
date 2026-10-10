import 'dart:convert';
import 'dart:io' as io;
import 'dart:ui' as ui;

import 'package:battle_chess_arena/src/domain/animated_army_theme.dart';
import 'package:battle_chess_arena/src/domain/game_result_analysis.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/play/board_appearance.dart';
import 'package:battle_chess_arena/src/features/play/checkmate_animation.dart';
import 'package:battle_chess_arena/src/features/play/checkmate_dialog.dart';
import 'package:battle_chess_arena/src/features/play/neon_illustrated_stage.dart';
import 'package:battle_chess_arena/src/theme/app_theme.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _message = GameResultMessage(
  sentiment: 'Well played.',
  comment: 'Review the game and return for the next battle.',
);

PiecePack get _neon =>
    availablePiecePacks.firstWhere((pack) => pack.id == PiecePackId.futuristic);

const _capturePreviews = bool.fromEnvironment('CAPTURE_CHECKMATE_PREVIEWS');

void main() {
  testWidgets('mate animation finishes before the result becomes available', (
    tester,
  ) async {
    var finished = false;
    await tester.pumpWidget(
      _harness(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              await showCheckmateAnimation(
                context: context,
                winner: Side.white,
                appearance: BoardAppearance.forPack(_neon).withStandardPieces(),
              );
              finished = true;
              if (!context.mounted) return;
              await showCheckmateDialog(
                context: context,
                userWon: true,
                title: 'Congratulations!',
                message: _message,
                appearance: BoardAppearance.forPack(_neon).withStandardPieces(),
              );
            },
            child: const Text('Finish'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Finish'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2500));
    expect(finished, isFalse);
    expect(find.byKey(const ValueKey('checkmate-animation')), findsOneWidget);
    expect(find.text('Congratulations!'), findsNothing);
    expect(find.text('Review Board'), findsNothing);
    expect(
      tester.widget<NeonFigureSprite>(find.byType(NeonFigureSprite)).piece,
      const Piece(color: Side.black, role: Role.king),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    expect(finished, isTrue);
    expect(find.byKey(const ValueKey('checkmate-animation')), findsNothing);
    expect(find.text('Congratulations!'), findsOneWidget);
    expect(find.byKey(const ValueKey('result-neon-city')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'mate presentation pauses for background time and completes once',
    (tester) async {
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      var completions = 0;
      await tester.pumpWidget(
        _harness(
          CheckmateAnimation(
            winner: Side.black,
            onComplete: () => completions++,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final controller =
          tester
                  .widget<AnimatedBuilder>(
                    find
                        .descendant(
                          of: find.byType(CheckmateAnimation),
                          matching: find.byType(AnimatedBuilder),
                        )
                        .first,
                  )
                  .animation
              as AnimationController;
      expect(controller.value, closeTo(500 / 2600, .001));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 6));
      expect(completions, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2090));
      expect(completions, 0);
      await tester.pump(const Duration(milliseconds: 11));
      await tester.pump();
      expect(completions, 1);
      await tester.pump(const Duration(seconds: 4));
      expect(completions, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('reduced motion holds a static mate before completion', (
    tester,
  ) async {
    var finished = false;
    await tester.pumpWidget(
      _harness(
        CheckmateAnimation(
          winner: Side.white,
          appearance: BoardAppearance.forPack(_neon),
          onComplete: () => finished = true,
        ),
        reducedMotion: true,
      ),
    );
    await tester.pump();
    final firstTransform = tester
        .widget<Transform>(find.byKey(const ValueKey('checkmate-king-motion')))
        .transform
        .storage
        .toList();
    await tester.pump(const Duration(milliseconds: 640));
    final controller =
        tester
                .widget<AnimatedBuilder>(
                  find
                      .descendant(
                        of: find.byType(CheckmateAnimation),
                        matching: find.byType(AnimatedBuilder),
                      )
                      .first,
                )
                .animation
            as AnimationController;
    expect(controller.value, closeTo(640 / 650, .001));
    expect(finished, isFalse);
    expect(
      tester
          .widget<Transform>(
            find.byKey(const ValueKey('checkmate-king-motion')),
          )
          .transform
          .storage
          .toList(),
      firstTransform,
    );
    await tester.pump(const Duration(milliseconds: 11));
    await tester.pump();
    expect(finished, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'completion removes only its own route when another route covers it',
    (tester) async {
      var finished = false;
      late BuildContext source;
      await tester.pumpWidget(
        _harness(
          Builder(
            builder: (context) {
              source = context;
              return FilledButton(
                onPressed: () async {
                  await showCheckmateAnimation(
                    context: context,
                    winner: Side.black,
                  );
                  finished = true;
                },
                child: const Text('Finish'),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Finish'));
      await tester.pump();
      Navigator.of(source).push<void>(
        PageRouteBuilder(
          opaque: false,
          pageBuilder: (_, _, _) => const Scaffold(body: Text('Covered route')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(finished, isTrue);
      expect(find.text('Covered route'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('removing the presentation early cancels callbacks safely', (
    tester,
  ) async {
    var completions = 0;
    await tester.pumpWidget(
      _harness(
        CheckmateAnimation(winner: Side.white, onComplete: () => completions++),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));
    expect(completions, 0);
    expect(tester.takeException(), isNull);
  });

  for (final pack in availablePiecePacks) {
    testWidgets('${pack.name} result retains its world with Classic pieces', (
      tester,
    ) async {
      final appearance = BoardAppearance.forPack(pack).withStandardPieces();
      await tester.pumpWidget(
        _harness(
          Builder(
            builder: (context) => FilledButton(
              onPressed: () => showGameResultDialog(
                context: context,
                outcome: GameResultOutcome.victory,
                heading: 'CHECKMATE',
                title: 'Congratulations!',
                message: _message,
                appearance: appearance,
              ),
              child: const Text('Finish'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Finish'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      final backdrop = tester.widget<MatchResultBackdrop>(
        find.byKey(const ValueKey('result-animated-backdrop')),
      );
      expect(backdrop.appearance, same(appearance));
      final theme = AnimatedArmyTheme.forPack(pack.id)!;
      final world = tester.widget<Image>(
        find.descendant(
          of: find.byType(MatchResultBackdrop),
          matching: find.byType(Image),
        ),
      );
      expect((world.image as AssetImage).assetName, theme.worldAsset);
      expect(find.byType(WorldBackdrop), findsNothing);
      expect(find.text('Review Board'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'every Animated world checkmates its own king with Classic sprites',
    (tester) async {
      for (final theme in AnimatedArmyTheme.values) {
        final pack = availablePiecePacks.singleWhere(
          (pack) => pack.id == theme.packId,
        );
        final appearance = BoardAppearance.forPack(pack).withStandardPieces();
        await tester.pumpWidget(
          _harness(
            CheckmateAnimation(
              key: ValueKey(theme),
              winner: Side.black,
              appearance: appearance,
              onComplete: () {},
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 900));
        final king = tester.widget<NeonFigureSprite>(
          find.byType(NeonFigureSprite),
        );
        expect(king.piece, Piece.whiteKing);
        expect(king.theme, theme);
        final cast = tester
            .widgetList<Image>(
              find.descendant(
                of: find.byType(NeonFigureSprite),
                matching: find.byType(Image),
              ),
            )
            .single;
        expect(
          (cast.image as AssetImage).assetName,
          theme.castAsset(Side.white),
        );
        final world = tester.widget<Image>(
          find.descendant(
            of: find.byType(MatchResultBackdrop),
            matching: find.byType(Image),
          ),
        );
        expect((world.image as AssetImage).assetName, theme.worldAsset);
        expect(find.text('Black wins'), findsOneWidget);
        expect(find.text('White king has no legal escape.'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    testWidgets('mate fits $size with enlarged text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _harness(
          CheckmateAnimation(
            winner: Side.white,
            appearance: BoardAppearance.forPack(_neon).withStandardPieces(),
            onComplete: () {},
          ),
          textScale: 2,
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.byKey(const ValueKey('checkmate-animation-title')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('capture actual-art mate and Classic Neon result review frames', (
    tester,
  ) async {
    final preview = GlobalKey();
    await _loadPreviewFonts(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    for (final size in [const Size(390, 844), const Size(844, 390)]) {
      tester.view.physicalSize = size;
      late BuildContext source;
      final appearance = BoardAppearance.forPack(_neon).withStandardPieces();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme().copyWith(
            textTheme: buildAppTheme().textTheme.apply(fontFamily: 'Roboto'),
          ),
          builder: (context, child) => DefaultAssetBundle(
            bundle: _FileArtworkBundle(),
            child: RepaintBoundary(key: preview, child: child!),
          ),
          home: Builder(
            builder: (context) {
              source = context;
              return Scaffold(
                body: CheckmateAnimation(
                  winner: Side.white,
                  appearance: appearance,
                  onComplete: () {},
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        await Future.wait([
          precacheImage(
            const AssetImage('assets/cinematics/neon/city.png'),
            source,
          ),
          precacheImage(
            AssetImage(AnimatedArmyTheme.neon.castAsset(Side.black)),
            source,
          ),
        ]);
      });
      await tester.pump(const Duration(milliseconds: 1450));
      expect(find.byType(NeonFigureSprite), findsOneWidget);
      expect(tester.takeException(), isNull);
      final orientation = size.width > size.height ? 'landscape' : 'portrait';
      await _savePreview(tester, preview, '$orientation-mate-impact');
      showGameResultDialog(
        context: source,
        outcome: GameResultOutcome.victory,
        heading: 'CHECKMATE',
        title: 'Congratulations!',
        message: _message,
        appearance: appearance,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));
      await _savePreview(tester, preview, '$orientation-neon-classic-result');
      await tester.pumpWidget(const SizedBox());
    }
  }, skip: !_capturePreviews);
}

class _FileArtworkBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) {
    final file = io.File(key);
    if (key.startsWith('assets/') && file.existsSync()) {
      return SynchronousFuture(ByteData.sublistView(file.readAsBytesSync()));
    }
    return rootBundle.load(key);
  }
}

Future<void> _loadPreviewFonts(WidgetTester tester) async {
  await tester.runAsync(() async {
    final config = io.File('.dart_tool/package_config.json').absolute;
    final packages =
        jsonDecode(await config.readAsString()) as Map<String, dynamic>;
    final flutter = (packages['packages'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((package) => package['name'] == 'flutter');
    final root = config.uri.resolve('${flutter['rootUri']}/');
    final fonts = root.resolve('../../bin/cache/artifacts/material_fonts/');
    final text = FontLoader('Roboto');
    for (final name in [
      'Roboto-Regular.ttf',
      'Roboto-Bold.ttf',
      'Roboto-Black.ttf',
    ]) {
      text.addFont(
        Future.value(
          ByteData.sublistView(
            await io.File.fromUri(fonts.resolve(name)).readAsBytes(),
          ),
        ),
      );
    }
    await text.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            await io.File.fromUri(
              fonts.resolve('MaterialIcons-Regular.otf'),
            ).readAsBytes(),
          ),
        ),
      );
    await icons.load();
  });
}

Future<void> _savePreview(
  WidgetTester tester,
  GlobalKey preview,
  String name,
) async {
  final boundary =
      preview.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = io.Directory('build/checkmate-preview');
    await directory.create(recursive: true);
    await io.File('${directory.path}/$name.png').writeAsBytes(
      data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    image.dispose();
  });
  expect(tester.takeException(), isNull, reason: name);
}

Widget _harness(
  Widget child, {
  bool reducedMotion = false,
  double textScale = 1,
}) => MaterialApp(
  builder: (context, widget) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      disableAnimations: reducedMotion,
      textScaler: TextScaler.linear(textScale),
    ),
    child: widget!,
  ),
  home: Scaffold(body: child),
);
