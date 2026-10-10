// SPDX-License-Identifier: GPL-3.0-or-later
// Opt-in real-art palette contact sheet; no golden baseline.
import 'dart:convert';
import 'dart:io' as io;
import 'dart:ui' as ui;

import 'package:battle_chess_arena/src/domain/animated_army_theme.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/play/board_appearance.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:battle_chess_arena/src/features/play/themed_piece_sprite.dart';
import 'package:battle_chess_arena/src/features/play/neon_illustrated_stage.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _capture = bool.fromEnvironment('CAPTURE_ANIMATED_BOARD_PALETTES');

class _ArtworkBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) {
    final file = io.File(key);
    return key.startsWith('assets/') && file.existsSync()
        ? SynchronousFuture(ByteData.sublistView(file.readAsBytesSync()))
        : rootBundle.load(key);
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
    final fonts = config.uri.resolve(
      '${flutter['rootUri']}/../../bin/cache/artifacts/material_fonts/',
    );
    final loader = FontLoader('Roboto');
    for (final name in ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']) {
      loader.addFont(
        io.File.fromUri(
          fonts.resolve(name),
        ).readAsBytes().then(ByteData.sublistView),
      );
    }
    await loader.load();
  });
}

void main() {
  testWidgets('optional eight-panel actual-art Animated board palettes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(760, 1644));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _fonts(tester);
    final boundary = GlobalKey();
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: _ArtworkBundle(),
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true).copyWith(
            textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Roboto'),
          ),
          home: RepaintBoundary(
            key: boundary,
            child: Scaffold(
              backgroundColor: const Color(0xFF0F1723),
              body: GridView.count(
                crossAxisCount: 2,
                padding: const EdgeInsets.all(16),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: .91,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final theme in AnimatedArmyTheme.values)
                    for (final classic in [false, true])
                      _Panel(theme: theme, classic: classic),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    for (var attempt = 0; attempt < 40; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      final sprites = find.byType(ThemedPieceSprite);
      final loaded = find.descendant(
        of: sprites,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint &&
              widget.painter is ThemedPieceSpritePainter,
        ),
      );
      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      final decoded = tester
          .widgetList<RawImage>(find.byType(RawImage))
          .toList();
      if (loaded.evaluate().length == sprites.evaluate().length &&
          decoded.length == images.length &&
          decoded.every((image) => image.image != null)) {
        break;
      }
    }
    expect(find.byType(ChessBoard), findsNWidgets(8));
    expect(find.byType(NeonFigureSprite), findsNWidgets(128));
    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    final decoded = tester.widgetList<RawImage>(find.byType(RawImage)).toList();
    expect(decoded.length, images.length);
    expect(
      decoded.every((image) => image.image != null),
      isTrue,
      reason:
          'Every Animated and Classic piece must use its decoded original asset.',
    );
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 1);
      final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      final output = io.Directory('build/animated-board-palette-preview');
      await output.create(recursive: true);
      await io.File('${output.path}/board-palettes.png').writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      image.dispose();
    });
    await tester.pumpWidget(const SizedBox.shrink());
  }, skip: !_capture);
}

class _Panel extends StatelessWidget {
  const _Panel({required this.theme, required this.classic});
  final AnimatedArmyTheme theme;
  final bool classic;

  @override
  Widget build(BuildContext context) {
    final pack = piecePacks.singleWhere((pack) => pack.id == theme.packId);
    final world = BoardAppearance.forPack(pack);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF202C3A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            SizedBox(
              height: 27,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${theme.displayName} · ${classic ? 'Classic' : 'Animated'}',
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: ChessBoard(
                    position: Chess.initial,
                    selected: null,
                    legalTargets: const {},
                    accent: Color(theme.accentColorArgb),
                    appearance: classic ? world.withStandardPieces() : world,
                    showCoordinates: true,
                    showPieceRoles: true,
                    onSquareTap: (_) {},
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
