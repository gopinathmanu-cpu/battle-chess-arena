// SPDX-License-Identifier: GPL-3.0-or-later
// Opt-in review frames, not platform goldens:
// flutter test --dart-define=CAPTURE_PLAY_ASSIST_PREVIEWS=true
// test/play_assist_preview_test.dart
import 'dart:convert';
import 'dart:io' as io;
import 'dart:ui' as ui;

import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/domain/game_time_control.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/play/animation_lab_screen.dart';
import 'package:battle_chess_arena/src/features/play/captured_pieces_panel.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:battle_chess_arena/src/features/play/themed_piece_sprite.dart';
import 'package:battle_chess_arena/src/services/computer_player.dart';
import 'package:battle_chess_arena/src/services/game_history_storage.dart';
import 'package:battle_chess_arena/src/services/last_game_storage.dart';
import 'package:battle_chess_arena/src/theme/app_theme.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auto_play_test.dart' show PendingAutoPlayer, TestMoveCommentary;

const _capture = bool.fromEnvironment('CAPTURE_PLAY_ASSIST_PREVIEWS');

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

Future<void> _fonts(WidgetTester tester) async {
  await tester.runAsync(() async {
    final config = io.File('.dart_tool/package_config.json').absolute;
    final json =
        jsonDecode(await config.readAsString()) as Map<String, dynamic>;
    final flutter = (json['packages'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((package) => package['name'] == 'flutter');
    final root = config.uri.resolve('${flutter['rootUri']}/');
    final fonts = root.resolve('../../bin/cache/artifacts/material_fonts/');
    for (final family in ['Roboto', 'Ahem']) {
      final loader = FontLoader(family);
      for (final file in [
        'Roboto-Regular.ttf',
        'Roboto-Bold.ttf',
        'Roboto-Black.ttf',
      ]) {
        loader.addFont(
          io.File.fromUri(
            fonts.resolve(file),
          ).readAsBytes().then(ByteData.sublistView),
        );
      }
      await loader.load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
}

Future<void> _save(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String name,
) async {
  // Await actual atlas painters for the captured pieces as well as the board.
  final sprites = find.byType(ThemedPieceSprite);
  for (var attempt = 0; attempt < 40; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    final ready = find.descendant(
      of: sprites,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is ThemedPieceSpritePainter,
      ),
    );
    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    final decoded = tester.widgetList<RawImage>(find.byType(RawImage)).toList();
    if (ready.evaluate().length == sprites.evaluate().length &&
        images.length == decoded.length &&
        decoded.every((image) => image.image != null)) {
      break;
    }
  }
  expect(
    tester.widgetList<RawImage>(find.byType(RawImage)).length,
    tester.widgetList<Image>(find.byType(Image)).length,
  );
  expect(
    tester
        .widgetList<RawImage>(find.byType(RawImage))
        .every((image) => image.image != null),
    isTrue,
    reason: '$name: board and captured figures must use decoded source art.',
  );
  // Android supplies Roboto for unspecified font families. The test runner
  // supplies Ahem instead, even after registering a real TextTheme; substitute
  // the shipping default only in these opt-in renders, retaining every colour,
  // weight, size and explicit icon font from the real widgets.
  for (final element in find.byType(RichText).evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    final span = paragraph.text;
    if (span is TextSpan && span.style?.fontFamily == null) {
      paragraph.text = TextSpan(
        text: span.text,
        children: span.children,
        style: (span.style ?? const TextStyle()).copyWith(fontFamily: 'Roboto'),
      );
    }
  }
  await tester.pump();
  expect(tester.takeException(), isNull, reason: name);
  await tester.runAsync(() async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = io.Directory('build/play-assist-preview-v1');
    await directory.create(recursive: true);
    await io.File('${directory.path}/$name.png').writeAsBytes(
      data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    image.dispose();
  });
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  var drained = false;
  GameHistoryStorage().loadSnapshot().then((_) => drained = true);
  for (var attempt = 0; !drained && attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(drained, isTrue);
}

void main() {
  testWidgets('optional actual-screen assist and capture surfaces review', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    AnimationLabScreen.debugClockFactory = () =>
        tester.binding.clock.stopwatch();
    addTearDown(() {
      AnimationLabScreen.debugClockFactory = null;
      return tester.binding.setSurfaceSize(null);
    });
    await _fonts(tester);
    final pack = piecePacks.singleWhere(
      (pack) => pack.id == PiecePackId.futuristic,
    );
    for (final classic in [false, true]) {
      for (final size in [const Size(390, 844), const Size(650, 360)]) {
        final boundary = GlobalKey();
        final portrait = size.height > size.width;
        await tester.binding.setSurfaceSize(size);
        final theme = buildAppTheme();
        await tester.pumpWidget(
          MaterialApp(
            theme: theme.copyWith(
              textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
              primaryTextTheme: theme.primaryTextTheme.apply(
                fontFamily: 'Roboto',
              ),
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                size: size,
                textScaler: const TextScaler.linear(1),
                padding: portrait
                    ? const EdgeInsets.fromLTRB(0, 24, 0, 16)
                    : const EdgeInsets.symmetric(horizontal: 20),
                viewPadding: portrait
                    ? const EdgeInsets.fromLTRB(0, 24, 0, 16)
                    : const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: RepaintBoundary(key: boundary, child: child!),
            ),
            home: DefaultAssetBundle(
              bundle: _ArtworkBundle(),
              child: AnimationLabScreen(
                key: UniqueKey(),
                pack: pack,
                mode: PlayerMode.computer,
                humanSide: Side.white,
                computerPlayer: PendingAutoPlayer(),
                moveCommentary: TestMoveCommentary(),
                timeControl: GameTimeControl.practice,
                savedGame: SavedGame(
                  mode: PlayerMode.computer,
                  humanSide: Side.white,
                  homePack: pack.id,
                  difficulty: ComputerDifficulty.medium,
                  moves: const ['e2e4', 'd7d5', 'e4d5', 'd8d5'],
                  whiteMilliseconds: 600000,
                  blackMilliseconds: 600000,
                  fastBattles: true,
                  classicPieces: classic,
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
        await tester.pump(const Duration(milliseconds: 900));
        expect(
          tester
              .widget<ChessBoard>(find.byType(ChessBoard))
              .appearance!
              .standardPieces,
          classic,
        );
        final suggest = find.byKey(const ValueKey('use-computer-lifeline'));
        final scan = find.byKey(const ValueKey('analyse-threats'));
        expect(suggest.hitTestable(), findsOneWidget);
        expect(scan.hitTestable(), findsOneWidget);
        final prefix =
            '${classic ? 'classic' : 'animated'}-${portrait ? 'portrait' : 'landscape'}';
        await _save(tester, boundary, '$prefix-assists');
        final scroll = find
            .descendant(
              of: find.byKey(
                ValueKey(
                  portrait ? 'portrait-match-scroll' : 'landscape-match-scroll',
                ),
              ),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          find.byType(CapturedPiecesPanel),
          120,
          scrollable: scroll,
        );
        await tester.pump();
        expect(
          tester
              .widget<CapturedPiecesPanel>(find.byType(CapturedPiecesPanel))
              .pieces!
              .length,
          2,
        );
        await _save(tester, boundary, '$prefix-captured');
        await _close(tester);
      }
    }
  }, skip: !_capture);
}
