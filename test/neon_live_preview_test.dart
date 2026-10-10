// SPDX-License-Identifier: GPL-3.0-or-later
// Opt-in real-art review: flutter test --dart-define=CAPTURE_NEON_LIVE_PREVIEWS=true
// test/neon_live_preview_test.dart. These are review frames, not platform goldens.
// Selection/move continuity: --dart-define=CAPTURE_NEON_LIVE_MOTION_PREVIEWS=true
import 'dart:convert';
import 'dart:io' as io;
import 'dart:ui' as ui;

import 'package:battle_chess_arena/src/domain/game_session.dart';
import 'package:battle_chess_arena/src/domain/game_time_control.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/online/online_game_screen.dart';
import 'package:battle_chess_arena/src/features/play/animation_lab_screen.dart';
import 'package:battle_chess_arena/src/features/play/chess_widgets.dart';
import 'package:battle_chess_arena/src/features/play/neon_live_arena.dart';
import 'package:battle_chess_arena/src/features/play/neon_illustrated_stage.dart';
import 'package:battle_chess_arena/src/features/play/themed_piece_sprite.dart';
import 'package:battle_chess_arena/src/services/computer_player.dart';
import 'package:battle_chess_arena/src/services/game_history_storage.dart';
import 'package:battle_chess_arena/src/services/last_game_storage.dart';
import 'package:battle_chess_arena/src/services/match_appearance_storage.dart';
import 'package:battle_chess_arena/src/services/online_match_client.dart';
import 'package:battle_chess_arena/src/theme/app_theme.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auto_play_test.dart' show PendingAutoPlayer, TestMoveCommentary;
import 'support/online_fixtures.dart';

const _capture = bool.fromEnvironment('CAPTURE_NEON_LIVE_PREVIEWS');
const _captureMotion = bool.fromEnvironment(
  'CAPTURE_NEON_LIVE_MOTION_PREVIEWS',
);
final _previewKey = GlobalKey();
final _neon = piecePacks.singleWhere((p) => p.id == PiecePackId.futuristic);
Finder _key(String name) => find.byKey(ValueKey(name));
NeonLiveArena _arena(WidgetTester tester) =>
    tester.widget<NeonLiveArena>(find.byType(NeonLiveArena));
ChessBoard _board(WidgetTester tester) =>
    tester.widget<ChessBoard>(find.byType(ChessBoard));

/// Read actual shipping artwork even when a widget-test asset bundle would
/// otherwise return an empty or placeholder image. Manifests/icons use Flutter's
/// bundled assets, preserving the same resolution/asset lookup as the app.
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

SavedGame _saved(
  List<String> moves, {
  Side side = Side.white,
  PlayerMode mode = PlayerMode.local,
  bool timed = false,
  bool classic = false,
}) => SavedGame(
  mode: mode,
  humanSide: side,
  homePack: PiecePackId.futuristic,
  difficulty: ComputerDifficulty.medium,
  moves: moves,
  whiteMilliseconds: 595000,
  blackMilliseconds: 601000,
  fastBattles: true,
  classicPieces: classic,
  whitePack: PiecePackId.futuristic,
  blackPack: PiecePackId.futuristic,
  boardPack: PiecePackId.futuristic,
  updatedAtEpochMs: 1,
  timeControl: timed ? GameTimeControl.rapid : GameTimeControl.practice,
);

Future<void> _mount(
  WidgetTester tester,
  Widget screen, {
  Size size = const Size(390, 844),
  double scale = 1,
  bool reduced = false,
}) async {
  await tester.binding.setSurfaceSize(size);
  final shippingTheme = buildAppTheme();
  await tester.pumpWidget(
    MaterialApp(
      theme: shippingTheme.copyWith(
        textTheme: shippingTheme.textTheme.apply(fontFamily: 'Roboto'),
        primaryTextTheme: shippingTheme.primaryTextTheme.apply(
          fontFamily: 'Roboto',
        ),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          size: size,
          textScaler: TextScaler.linear(scale),
          disableAnimations: reduced,
          padding: size.width > size.height
              ? const EdgeInsets.symmetric(horizontal: 20)
              : const EdgeInsets.fromLTRB(0, 24, 0, 16),
          viewPadding: size.width > size.height
              ? const EdgeInsets.symmetric(horizontal: 20)
              : const EdgeInsets.fromLTRB(0, 24, 0, 16),
        ),
        child: RepaintBoundary(key: _previewKey, child: child!),
      ),
      home: DefaultAssetBundle(bundle: _FileArtworkBundle(), child: screen),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
}

Future<void> _offline(
  WidgetTester tester, {
  required List<String> moves,
  Side side = Side.white,
  PlayerMode mode = PlayerMode.local,
  bool timed = false,
  bool classic = false,
  Size size = const Size(390, 844),
  double scale = 1,
  bool reduced = false,
}) async {
  await _close(tester);
  await _mount(
    tester,
    AnimationLabScreen(
      key: UniqueKey(),
      pack: _neon,
      savedGame: _saved(
        moves,
        side: side,
        mode: mode,
        timed: timed,
        classic: classic,
      ),
      mode: mode,
      humanSide: side,
      computerPlayer: PendingAutoPlayer(),
      moveCommentary: TestMoveCommentary(),
      timeControl: timed ? GameTimeControl.rapid : GameTimeControl.practice,
    ),
    size: size,
    scale: scale,
    reduced: reduced,
  );
}

Future<void> _select(
  WidgetTester tester,
  Square square, {
  Duration settle = const Duration(milliseconds: 900),
}) async {
  final before = _board(tester).position.fen;
  await tester.tap(_key('square-${square.name}'));
  await tester.pump();
  await tester.pump(settle);
  expect(_arena(tester).action!.isSelection, isTrue);
  expect(_arena(tester).action!.source, square);
  expect(_board(tester).position.fen, before);
  expect(_board(tester).selected, square);
}

Future<void> _save(
  WidgetTester tester,
  String name, {
  bool scrolled = false,
  bool boardOnLeft = false,
}) async {
  // Role badges appear before their separately decoded atlas. Await every real
  // board sprite, rather than capturing whichever loading frame happens to be
  // available after a fixed delay. Each wait releases the real image decoder.
  final sprites = find.descendant(
    of: find.byType(ChessBoard),
    matching: find.byType(ThemedPieceSprite),
  );
  final painters = find.descendant(
    of: sprites,
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint && widget.painter is ThemedPieceSpritePainter,
    ),
  );
  final classic = _board(tester).appearance?.standardPieces ?? false;
  final figures = find.descendant(
    of: find.byType(ChessBoard),
    matching: find.byType(NeonFigureSprite),
  );
  final images = find.descendant(
    of: find.byType(ChessBoard),
    matching: find.byType(Image),
  );
  final decoded = find.descendant(
    of: find.byType(ChessBoard),
    matching: find.byType(RawImage),
  );
  for (var attempt = 0; attempt < 40; attempt++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    if (painters.evaluate().length == sprites.evaluate().length &&
        decoded.evaluate().length == images.evaluate().length &&
        tester
            .widgetList<RawImage>(decoded)
            .every((image) => image.image != null)) {
      break;
    }
  }
  if (!classic) {
    expect(
      figures.evaluate().isNotEmpty || sprites.evaluate().isNotEmpty,
      isTrue,
      reason: '$name must render actual board art',
    );
  }
  expect(
    painters.evaluate().length,
    sprites.evaluate().length,
    reason: '$name: every board piece must finish decoding before capture',
  );
  expect(decoded.evaluate().length, images.evaluate().length);
  expect(
    tester.widgetList<RawImage>(decoded).every((image) => image.image != null),
    isTrue,
    reason: '$name: every illustrated/Classic board figure must be decoded.',
  );
  expect(tester.takeException(), isNull, reason: name);
  final panel = tester.getRect(find.byType(NeonLiveArena));
  final board = tester.getRect(find.byType(ChessBoard));
  if (_key('neon-live-landscape-action-board-row').evaluate().isNotEmpty) {
    expect(
      boardOnLeft ? board.right : panel.right,
      lessThanOrEqualTo(boardOnLeft ? panel.left : board.left),
      reason: name,
    );
    expect(panel.top, board.top, reason: name);
  } else {
    expect(panel.bottom, lessThanOrEqualTo(board.top), reason: name);
  }
  if (!scrolled) {
    expect(
      board.bottom,
      lessThanOrEqualTo(tester.view.physicalSize.height),
      reason: name,
    );
  }
  final boundary =
      _previewKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = io.Directory(
      _captureMotion
          ? 'build/neon-live-preview-v3'
          : 'build/neon-live-preview-v2',
    );
    await directory.create(recursive: true);
    await io.File('${directory.path}/$name.png').writeAsBytes(
      data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    image.dispose();
  });
}

Future<void> _close(WidgetTester tester, {OnlineMatchClient? client}) async {
  await tester.pumpWidget(const SizedBox());
  client?.dispose();
  await tester.pump();
  var drained = false;
  Future.wait([
    GameHistoryStorage().loadSnapshot(),
    MatchAppearanceStorage.load('room', 'w'),
    if (client != null) client.gameArchive.pending,
  ]).then((_) => drained = true);
  for (var i = 0; !drained && i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(drained, isTrue);
}

Future<void> _fonts(WidgetTester tester) async {
  await tester.runAsync(() async {
    final config = io.File('.dart_tool/package_config.json').absolute;
    final json =
        jsonDecode(await config.readAsString()) as Map<String, dynamic>;
    final flutter = (json['packages'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((p) => p['name'] == 'flutter');
    final root = config.uri.resolve('${flutter['rootUri']}/');
    final fonts = root.resolve('../../bin/cache/artifacts/material_fonts/');
    // Explicit ButtonStyle text styles can omit a family and bypass TextTheme.
    // Match Android's default Roboto instead of the test-only Ahem rectangles.
    for (final family in ['Roboto', 'Ahem']) {
      final text = FontLoader(family);
      for (final name in [
        'Roboto-Regular.ttf',
        'Roboto-Bold.ttf',
        'Roboto-Black.ttf',
      ]) {
        text.addFont(
          io.File.fromUri(
            fonts.resolve(name),
          ).readAsBytes().then(ByteData.sublistView),
        );
      }
      await text.load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
}

void main() {
  testWidgets('optional actual-art continuous move and checkmate review', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    AnimationLabScreen.debugClockFactory = () =>
        tester.binding.clock.stopwatch();
    final reportError = FlutterError.onError;
    FlutterError.onError = (details) {
      debugPrint(details.toString());
      reportError?.call(details);
    };
    try {
      await _fonts(tester);
      for (final fixture in [
        ('white', ['e2e4', 'd7d5'], Side.white, Square.e4, Square.d5),
        ('black', ['e2e4', 'd7d5', 'e4d5'], Side.black, Square.d8, Square.d5),
      ]) {
        await _offline(
          tester,
          moves: fixture.$2,
          side: fixture.$3,
          mode: PlayerMode.computer,
          timed: true,
        );
        await _select(
          tester,
          fixture.$4,
          settle: const Duration(milliseconds: 210),
        );
        await _save(tester, '${fixture.$1}-rapid-selection-pose');
        final selected = tester.getRect(_key('neon-live-left-figure'));
        await tester.tap(_key('square-${fixture.$5.name}'));
        await tester.pump();
        expect(_arena(tester).action!.isSelection, isFalse);
        expect(_arena(tester).action!.captured, isNotNull);
        expect(
          tester.getRect(_key('neon-live-left-figure')),
          selected,
          reason: 'Commit must retain the selected artwork pose',
        );
        await _save(tester, '${fixture.$1}-capture-continuation-start');
        await tester.pump(const Duration(milliseconds: 300));
        await _save(tester, '${fixture.$1}-capture-strike-follow-through');
        await tester.pump(const Duration(milliseconds: 550));
        await _save(tester, '${fixture.$1}-capture-settled-defeated');
      }

      await _offline(
        tester,
        moves: ['e2e4', 'e7e5', 'd1h5', 'b8c6', 'f1c4', 'g8f6'],
      );
      await _select(tester, Square.h5);
      await tester.tap(_key('square-f7'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_board(tester).position.isCheckmate, isTrue);
      expect(find.text('VICTORY · WHITE'), findsOneWidget);
      expect(find.text('CHECKMATED\nE8'), findsOneWidget);
      expect(_arena(tester).action!.captured, Piece.blackPawn);
      await _save(tester, 'white-capture-checkmate-portrait');

      await _offline(
        tester,
        moves: ['f2f3', 'e7e5', 'g2g4'],
        mode: PlayerMode.computer,
        side: Side.black,
        size: const Size(760, 330),
        scale: 2,
      );
      await _select(tester, Square.d8);
      await tester.tap(_key('square-h4'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_board(tester).position.isCheckmate, isTrue);
      expect(find.text('VICTORY · BLACK'), findsOneWidget);
      expect(find.text('CHECKMATED\nE1'), findsOneWidget);
      expect(_key('neon-live-capture-defeated'), findsNothing);
      await _save(tester, 'black-quiet-checkmate-landscape-large-text');
      expect(_key('analyse-threats').hitTestable(), findsOneWidget);
      expect(_key('use-computer-lifeline').hitTestable(), findsOneWidget);
      await tester.tap(_key('neon-live-swap-panels'));
      await tester.pump();
      await _save(
        tester,
        'black-checkmate-swapped-landscape-visible-assists',
        boardOnLeft: true,
      );
    } finally {
      await _close(tester);
      AnimationLabScreen.debugClockFactory = null;
      FlutterError.onError = reportError;
      await tester.binding.setSurfaceSize(null);
    }
  }, skip: !_captureMotion);

  testWidgets('optional actual-art full live Neon screen review', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    AnimationLabScreen.debugClockFactory = () =>
        tester.binding.clock.stopwatch();
    OnlineMatchClient? activeClient;
    try {
      await _fonts(tester);
      await _offline(tester, moves: const []);
      expect(_arena(tester).action, isNull);
      expect(_key('neon-live-left-figure'), findsNothing);
      expect(_key('neon-live-right-figure'), findsNothing);
      await _save(tester, 'idle-no-default-figures-portrait');

      await _offline(tester, moves: ['e2e4', 'd7d5'], classic: true);
      await _select(tester, Square.e4);
      expect(_board(tester).appearance!.standardPieces, isTrue);
      expect(_key('neon-live-right-figure'), findsNothing);
      await _save(tester, 'neon-classic-selection-portrait');
      final selected = _arena(tester).action;
      final selectionFen = _board(tester).position.fen;
      await tester.drag(find.byType(ChessBoard), const Offset(-90, 0));
      await tester.pump();
      expect(_board(tester).appearance!.standardPieces, isFalse);
      expect(_arena(tester).action, same(selected));
      expect(_board(tester).position.fen, selectionFen);
      await _save(tester, 'neon-animated-after-swipe-portrait');

      await _offline(
        tester,
        moves: ['e2e4', 'd7d5', 'e4d5'],
        classic: true,
        size: const Size(760, 330),
        reduced: true,
      );
      expect(_key('neon-live-capture-defeated'), findsOneWidget);
      await _save(tester, 'neon-classic-defeated-landscape');
      final capture = _arena(tester).action;
      final captureFen = _board(tester).position.fen;
      await tester.drag(find.byType(ChessBoard), const Offset(90, 0));
      await tester.pump();
      expect(_board(tester).appearance!.standardPieces, isFalse);
      expect(_arena(tester).action, same(capture));
      expect(_board(tester).position.fen, captureFen);
      await _save(tester, 'neon-animated-defeated-landscape');
      await tester.drag(find.byType(ChessBoard), const Offset(-90, 0));
      await tester.pump();
      expect(_board(tester).appearance!.standardPieces, isTrue);
      expect(_arena(tester).action, same(capture));

      await _offline(tester, moves: ['e2e4', 'd7d5'], timed: true);
      await _select(tester, Square.e4);
      expect(_arena(tester).action!.threats.single.square, Square.d5);
      await _save(tester, 'white-selection-timed-portrait');

      await _offline(
        tester,
        moves: ['e2e4', 'd7d5', 'e4d5'],
        size: const Size(320, 568),
      );
      expect(_arena(tester).action!.captured, Piece.blackPawn);
      await _save(tester, 'white-capture-small-portrait');

      await _offline(
        tester,
        moves: ['e2e4', 'd7d5', 'e4d5'],
        side: Side.black,
        mode: PlayerMode.computer,
      );
      await _select(tester, Square.d8);
      await _save(tester, 'black-player-selection-portrait');

      await _offline(tester, moves: ['e2e4', 'd7d5', 'e4d5']);
      await _select(tester, Square.d8);
      expect(_arena(tester).viewerSide, Side.white);
      expect(_arena(tester).action!.actor.color, Side.black);
      await _save(tester, 'local-black-selection-portrait');

      await _offline(
        tester,
        moves: ['e2e4', 'd7d5', 'e4d5', 'd8d5'],
        timed: true,
      );
      expect(_arena(tester).action!.actorOnLeft, isFalse);
      expect(_arena(tester).action!.captured, Piece.whitePawn);
      await _save(tester, 'opponent-capture-timed-portrait');

      await _offline(
        tester,
        moves: ['e2e4', 'd7d5', 'e4d5', 'd8d5'],
        size: const Size(760, 330),
        scale: 2,
        reduced: true,
      );
      await _save(tester, 'opponent-capture-landscape-large-text-reduced');
      final landscapeScroll = find.ancestor(
        of: find.byType(NeonLiveArena),
        matching: find.byType(ListView),
      );
      await tester.drag(landscapeScroll, const Offset(0, -180));
      await tester.pump(const Duration(milliseconds: 300));
      await _save(
        tester,
        'landscape-clocks-controls-below-row',
        scrolled: true,
      );

      await _offline(tester, moves: ['e2e4', 'f7f6']);
      await _select(tester, Square.d1);
      expect(_arena(tester).action!.threats.first.possibleCheck, isTrue);
      await _save(tester, 'possible-king-check-portrait');

      await _offline(tester, moves: ['e2e4', 'f7f6', 'd1h5']);
      expect(_arena(tester).action!.threats.first.isCheck, isTrue);
      expect(_arena(tester).action!.captured, isNull);
      await _save(tester, 'actual-king-check-portrait');

      await _offline(
        tester,
        moves: ['b1c3', 'f7f6', 'c3d5', 'g7g5'],
        size: const Size(320, 568),
        scale: 2,
      );
      await _select(tester, Square.d5);
      expect(_arena(tester).action!.threats.length, greaterThan(3));
      await _save(tester, 'four-threats-small-portrait-page-one');
      await tester.tap(_key('neon-live-threat-next'));
      await tester.pump();
      await _save(tester, 'four-threats-small-portrait-page-two');

      await _close(tester);
      final channels = <FakeChannel>[];
      activeClient = OnlineMatchClient(
        channelFactory: (_) {
          final channel = FakeChannel();
          channels.add(channel);
          return channel;
        },
      );
      await activeClient.connect(Uri.parse('ws://localhost:8080'));
      channels.last.seat(
        seat: 'b',
        state: stateJson(
          game: GameSession.fromMoves(moves: ['e2e4', 'd7d5', 'e4d5']),
        ),
      );
      await tester.pump();
      await _mount(tester, OnlineGameScreen(client: activeClient, pack: _neon));
      await _select(tester, Square.d8);
      await _save(tester, 'online-black-selection-timed-portrait');
      await _close(tester, client: activeClient);
      activeClient = null;

      activeClient = OnlineMatchClient(
        channelFactory: (_) {
          final channel = FakeChannel();
          channels.add(channel);
          return channel;
        },
      );
      await activeClient.connect(Uri.parse('ws://localhost:8080'));
      final game = GameSession.fromMoves(moves: ['e2e4', 'f7f6']);
      channels.last.seat(
        seat: 'b',
        state: stateJson(game: game),
      );
      await tester.pump();
      await _mount(
        tester,
        OnlineGameScreen(client: activeClient, pack: _neon),
        size: const Size(650, 360),
      );
      expect(game.playUci('d1h5'), isNotNull);
      channels.last.receive({
        'type': 'game_state',
        'state': stateJson(game: game, sequence: 2),
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      expect(_arena(tester).action!.actorOnLeft, isFalse);
      expect(_arena(tester).action!.threats.first.isCheck, isTrue);
      await _save(tester, 'online-opponent-check-timed-landscape');
      await _close(tester, client: activeClient);
      activeClient = null;

      // Resolve the true move through the interactive live board. Decode before
      // moving so the impact frame remains deterministic while the 850ms arena
      // animation is running.
      await _offline(tester, moves: ['e2e4', 'd7d5']);
      await _select(tester, Square.e4);
      await _save(tester, 'capture-before-impact-portrait');
      await tester.tap(_key('square-d5'));
      await tester.pump();
      for (var i = 0; i < 30 && _arena(tester).action?.captured == null; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(_arena(tester).action!.captured, Piece.blackPawn);
      await tester.pump(const Duration(milliseconds: 350));
      await _save(tester, 'capture-impact-defeat-portrait');
      await tester.pump(const Duration(milliseconds: 600));
      await _save(tester, 'capture-settled-defeated-portrait');
    } finally {
      await _close(tester, client: activeClient);
      AnimationLabScreen.debugClockFactory = null;
      await tester.binding.setSurfaceSize(null);
    }
  }, skip: !_capture);
}
