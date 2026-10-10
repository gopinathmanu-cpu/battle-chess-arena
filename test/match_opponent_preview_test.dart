// SPDX-License-Identifier: GPL-3.0-or-later
// Opt-in actual-art review of the shared opponent/board presentation.
import 'dart:convert';
import 'dart:io' as io;
import 'dart:ui' as ui;

import 'package:battle_chess_arena/src/domain/online_player_profile.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/online/online_avatar_image.dart';
import 'package:battle_chess_arena/src/features/play/board_appearance.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:battle_chess_arena/src/features/play/match_opponent_panel.dart';
import 'package:battle_chess_arena/src/features/play/neon_live_game_layout.dart';
import 'package:battle_chess_arena/src/features/play/play_assist_style.dart';
import 'package:battle_chess_arena/src/theme/app_theme.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _capture = bool.fromEnvironment('CAPTURE_MATCH_OPPONENTS');

class _ArtworkBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) {
    final file = io.File(key);
    return key.startsWith('assets/') && file.existsSync()
        ? SynchronousFuture(ByteData.sublistView(file.readAsBytesSync()))
        : rootBundle.load(key);
  }
}

Future<void> _fonts(WidgetTester tester) => tester.runAsync(() async {
  final config = io.File('.dart_tool/package_config.json').absolute;
  final json = jsonDecode(await config.readAsString()) as Map<String, dynamic>;
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
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
});

void main() {
  testWidgets('optional actual-art opponent panels in both match page families', (
    tester,
  ) async {
    await _fonts(tester);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pack = piecePacks.singleWhere(
      (pack) => pack.id == PiecePackId.futuristic,
    );
    final opponent = builtInComputerOpponents.first;
    for (final tournament in [false, true]) {
      for (final classic in [false, true]) {
        for (final landscape in [false, true]) {
          final size = landscape ? const Size(844, 390) : const Size(390, 844);
          await tester.binding.setSurfaceSize(size);
          final controller = ScrollController();
          final boundary = GlobalKey();
          final appearance = BoardAppearance.forPack(pack);
          final theme = buildAppTheme();
          await tester.pumpWidget(
            DefaultAssetBundle(
              bundle: _ArtworkBundle(),
              child: MaterialApp(
                theme: theme.copyWith(
                  textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
                ),
                home: RepaintBoundary(
                  key: boundary,
                  child: Scaffold(
                    appBar: AppBar(
                      title: Text(
                        tournament ? 'Tournament match' : 'Play Online',
                      ),
                    ),
                    body: NeonLiveGameLayout(
                      compactPortraitArena: true,
                      arena: MatchOpponentPanel(
                        name: tournament ? opponent.name : 'Maya',
                        details: tournament
                            ? 'Round 1 · ${opponent.difficultyLabel} · Computer · You play White'
                            : 'Gold player · Online player · Timed game',
                        avatarBuilder: (size) => OnlineAvatarImage(
                          avatarId: tournament
                              ? opponent.avatarId
                              : 'avatar-14',
                          size: size,
                        ),
                      ),
                      board: ChessBoard(
                        position: Chess.initial,
                        selected: null,
                        legalTargets: const {},
                        accent: pack.accent,
                        appearance: classic
                            ? appearance.withStandardPieces()
                            : appearance,
                        showCoordinates: !classic,
                        showPieceRoles: true,
                        onSquareTap: (_) {},
                      ),
                      header: const NeonLiveStatusBar(
                        status: 'Your turn',
                        whiteTime: Duration(minutes: 5),
                        blackTime: Duration(minutes: 5),
                        turn: Side.white,
                        timed: true,
                      ),
                      quickActions: Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonalIcon(
                              style: playAssistButtonStyle,
                              onPressed: () {},
                              icon: const Icon(Icons.lightbulb_outline),
                              label: const Text('Suggest move'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.tonalIcon(
                              style: playAssistButtonStyle,
                              onPressed: () {},
                              icon: const Icon(Icons.security_outlined),
                              label: const Text('Threat scan'),
                            ),
                          ),
                        ],
                      ),
                      details: const [
                        Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('Match controls and move history'),
                        ),
                      ],
                      scrollController: controller,
                    ),
                  ),
                ),
              ),
            ),
          );
          for (var wait = 0; wait < 50; wait++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 50)),
            );
            await tester.pump();
            final avatars = find.byWidgetPredicate(
              (widget) =>
                  widget is CustomPaint &&
                  widget.painter is AvatarPortraitPainter,
            );
            final images = tester.widgetList<Image>(find.byType(Image)).length;
            final raw = tester.widgetList<RawImage>(find.byType(RawImage));
            if (avatars.evaluate().length == 1 &&
                raw.length == images &&
                raw.every((image) => image.image != null)) {
              break;
            }
          }
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is CustomPaint &&
                  widget.painter is AvatarPortraitPainter,
            ),
            findsOneWidget,
          );
          final images = tester.widgetList<Image>(find.byType(Image)).length;
          final raw = tester.widgetList<RawImage>(find.byType(RawImage));
          expect(raw.length, images);
          expect(raw.every((image) => image.image != null), isTrue);
          expect(find.byType(MatchOpponentPanel), findsOneWidget);
          expect(find.byType(ChessBoard), findsOneWidget);
          expect(tester.takeException(), isNull);
          final panel = tester.getRect(find.byType(MatchOpponentPanel));
          final board = tester.getRect(find.byType(ChessBoard));
          if (landscape) {
            expect(panel.right, lessThan(board.left));
            expect(board.bottom, lessThanOrEqualTo(size.height));
          } else {
            expect(panel.bottom, lessThan(board.top));
          }
          final name =
              '${tournament ? 'tournament' : 'online'}-${classic ? 'classic' : 'animated'}-${landscape ? 'landscape' : 'portrait'}';
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final folder = io.Directory('build/match-opponent-preview')
              ..createSync(recursive: true);
            await io.File(
              '${folder.path}/$name.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
          await tester.pumpWidget(const SizedBox.shrink());
          controller.dispose();
        }
      }
    }
  }, skip: !_capture);
}
