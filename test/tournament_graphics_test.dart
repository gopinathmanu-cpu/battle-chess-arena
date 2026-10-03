import 'dart:io';
import 'dart:ui' as ui;

import 'package:battle_chess_arena/src/domain/bot_tournament.dart';
import 'package:battle_chess_arena/src/features/tournaments/championship_celebration.dart';
import 'package:battle_chess_arena/src/features/tournaments/tournament_journey.dart';
import 'package:battle_chess_arena/src/features/play/board_appearance.dart';
import 'package:battle_chess_arena/src/services/theme_music.dart';
import 'package:battle_chess_arena/src/services/tournament_storage.dart';
import 'package:battle_chess_arena/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'theme_music_test.dart' show FakeMusicOutput;

// Optional native-widget visual QA:
// flutter test test/tournament_graphics_test.dart
//   --dart-define=TOURNAMENT_VISUALS=true
//   --dart-define=TOURNAMENT_FONT_DIR=<flutter>/bin/cache/artifacts/material_fonts
const captureVisuals = bool.fromEnvironment('TOURNAMENT_VISUALS');

Future<void> capture(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String name,
) async {
  if (!captureVisuals) return;
  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = await Directory(
      'build/tournament-visuals',
    ).create(recursive: true);
    await File(
      '${directory.path}/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    const fontDirectory = String.fromEnvironment('TOURNAMENT_FONT_DIR');
    if (!captureVisuals || fontDirectory.isEmpty) return;
    for (final entry in {
      'Roboto': 'Roboto-Regular.ttf',
      'MaterialIcons': 'MaterialIcons-Regular.otf',
    }.entries) {
      final bytes = await File('$fontDirectory/${entry.value}').readAsBytes();
      await (FontLoader(
        entry.key,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
  });

  for (final reducedMotion in [false, true]) {
    testWidgets(
      'journey and ceremony fit portrait, reduced motion: $reducedMotion',
      (tester) async {
        await tester.binding.setSurfaceSize(
          Size(reducedMotion ? 320 : 390, 844),
        );
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final cup = builtInTournaments.last;
        final run = TournamentRun.start(
          cup,
        ).beginAttempt().finish(TournamentRoundResult.win);
        final output = FakeMusicOutput();
        final music = ThemeMusic(
          output: output,
          muted: reducedMotion,
          saveMuted: (_) async {},
        );
        final boundaryKey = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildAppTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  disableAnimations: reducedMotion,
                  textScaler: TextScaler.linear(reducedMotion ? 2 : 1),
                ),
                child: MusicScope(controller: music, child: child!),
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  appBar: AppBar(title: Text(cup.title)),
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TournamentScoreBanner(
                          score: TournamentPlayerScore.fromRuns({cup: run}),
                        ),
                        const SizedBox(height: 20),
                        TournamentJourney(cup: cup, run: run),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: () => showChampionshipCelebration(
                            context: context,
                            cup: cup,
                          ),
                          child: const Text('Celebrate'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (captureVisuals) {
          await tester.runAsync(
            () => precacheImage(
              const AssetImage(CharacterPiece.atlas),
              tester.element(find.byType(TournamentJourney)),
            ),
          );
          await tester.pumpAndSettle();
        }
        expect(find.text('Won · +300'), findsOneWidget);
        expect(find.text('Up next'), findsOneWidget);
        expect(find.text('Locked'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (!reducedMotion) {
          await capture(tester, boundaryKey, 'journey-portrait');
        }
        await tester.ensureVisible(find.text('Celebrate'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Celebrate'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1200));
        if (!reducedMotion) {
          await capture(tester, boundaryKey, 'championship-portrait');
        }
        await tester.pumpAndSettle();
        expect(find.text('900 cup points earned'), findsOneWidget);
        expect(
          output.effects,
          reducedMotion
              ? isEmpty
              : [CinematicSound.youWon, CinematicSound.victoryApplause],
        );
        expect(tester.binding.hasScheduledFrame, isFalse);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(
          find.byKey(const ValueKey('championship-continue')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('championship-continue')));
        await tester.pumpAndSettle();
        expect(find.byType(ChampionshipCelebration), findsNothing);
        await tester.pumpWidget(const SizedBox());
        music.dispose();
      },
    );
  }

  testWidgets('championship is scrollable in short landscape windows', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(640, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: ChampionshipCelebration(
          cup: builtInTournaments.first,
          replay: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('championship-continue')),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('championship-continue')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
