// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io' as io;
import 'dart:ui' as ui;

import 'package:battle_chess_arena/src/domain/custom_chess_set.dart';
import 'package:battle_chess_arena/src/features/studio/chess_set_studio_screen.dart';
import 'package:battle_chess_arena/src/features/studio/custom_piece.dart';
import 'package:battle_chess_arena/src/services/custom_chess_sets.dart';
import 'package:battle_chess_arena/src/theme/app_theme.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _captureVisuals = bool.fromEnvironment('STUDIO_VISUALS');
final _boundaryKey = GlobalKey();

Future<void> _capture(
  WidgetTester tester,
  String name, {
  bool scrollToTop = true,
}) async {
  if (!_captureVisuals) return;
  ScaffoldMessenger.maybeOf(
    tester.element(find.byType(Scaffold).last),
  )?.clearSnackBars();
  if (scrollToTop) {
    for (final element in find.byType(Scrollable).evaluate()) {
      final state = (element as StatefulElement).state as ScrollableState;
      if (state.position.hasPixels && state.position.pixels != 0) {
        state.position.jumpTo(0);
      }
    }
    await tester.pumpAndSettle();
  }
  await tester.runAsync(() async {
    final boundary =
        _boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = await io.Directory(
      'build/studio-visuals',
    ).create(recursive: true);
    await io.File(
      '${directory.path}/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> _pumpStudio(
  WidgetTester tester,
  CustomChessSets library, {
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundaryKey,
      child: CustomChessSetScope(
        controller: library,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const ChessSetStudioScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (_captureVisuals) {
    await tester.runAsync(() async {
      final context = tester.element(find.byType(ChessSetStudioScreen));
      await precacheImage(const AssetImage(CustomPieceParts.atlas), context);
      if (context.mounted) {
        await precacheImage(
          const AssetImage('assets/concepts/piece-families.png'),
          context,
        );
      }
    });
    await tester.pumpAndSettle();
  }
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    scrollable.position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      target,
      220,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 35,
    );
  } else {
    await tester.ensureVisible(target);
  }
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Finder _key(String value) => find.byKey(ValueKey(value));

class _FailingLibrary extends CustomChessSets {
  _FailingLibrary() : super(autoLoad: false);
  @override
  Future<bool> save(CustomChessSet set, {bool activate = true}) async => false;
}

void main() {
  setUpAll(() async {
    const fontDirectory = String.fromEnvironment('STUDIO_FONT_DIR');
    if (!_captureVisuals || fontDirectory.isEmpty) return;
    for (final entry in {
      'Roboto': 'Roboto-Regular.ttf',
      'MaterialIcons': 'MaterialIcons-Regular.otf',
    }.entries) {
      final bytes = await io.File(
        '$fontDirectory/${entry.value}',
      ).readAsBytes();
      await (FontLoader(
        entry.key,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('editor saves compatible formations, board and background', (
    tester,
  ) async {
    final library = CustomChessSets(autoLoad: false);
    addTearDown(library.dispose);
    await _pumpStudio(tester, library);
    await _tap(tester, _key('create-custom-set'));
    await _capture(tester, 'editor-preview-390');
    await tester.enterText(_key('custom-set-name'), 'My Forest Knights');
    await _tap(tester, _key('studio-part-formation-2'));
    await _capture(tester, 'editor-parts-390', scrollToTop: false);
    await _tap(tester, _key('studio-role-king'));
    await _tap(tester, _key('studio-part-formation-1'));
    await _tap(tester, _key('studio-side-black'));
    await _tap(tester, _key('studio-role-knight'));
    await _tap(tester, _key('studio-part-formation-3'));
    await _tap(tester, _key('studio-tab-1'));
    await _tap(tester, _key('studio-palette-Forest'));
    await _tap(tester, _key('studio-surface-neon'));
    await _capture(tester, 'editor-board-390');
    await _tap(tester, _key('studio-tab-2'));
    await _tap(tester, _key('studio-background-forest'));
    await _capture(tester, 'editor-background-390');
    await _tap(tester, _key('save-custom-set'));
    expect(find.text('Chess Set Studio'), findsOneWidget);
    expect(library.sets, hasLength(1));
    await _capture(tester, 'library-390');
    final saved = library.active!;
    expect(saved.name, 'My Forest Knights');
    expect(saved.designFor(Side.white, Role.knight).costume, 2);
    expect(saved.designFor(Side.black, Role.knight).costume, 3);
    expect(saved.designFor(Side.white, Role.king).costume, 1);
    expect(saved.designFor(Side.black, Role.king).costume, 1);
    expect(saved.designFor(Side.black, Role.knight).scale, 1);
    expect(saved.designFor(Side.white, Role.knight).scale, 1);
    expect(saved.lightSquare, 0xffe7e8cf);
    expect(saved.darkSquare, 0xff45654f);
    expect(saved.surface, CustomBoardSurface.neon);
    expect(saved.background, CustomBackground.forest);
    final restored = CustomChessSets();
    await restored.ready;
    expect(restored.active?.name, saved.name);
    restored.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'back confirms and discards a draft without changing the saved set',
    (tester) async {
      final library = CustomChessSets(autoLoad: false);
      addTearDown(library.dispose);
      await library.save(
        CustomChessSet.create(id: 'original', name: 'Original'),
      );
      await _pumpStudio(tester, library);
      await _tap(tester, find.text('Edit'));
      await tester.enterText(_key('custom-set-name'), 'Unsaved name');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Discard your changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Design your set'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('Chess Set Studio'), findsOneWidget);
      expect(library.active?.name, 'Original');
      expect(library.sets, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('save errors retain the draft and empty names cannot save', (
    tester,
  ) async {
    final library = _FailingLibrary();
    addTearDown(library.dispose);
    await _pumpStudio(tester, library);
    await _tap(tester, _key('create-custom-set'));
    await tester.enterText(_key('custom-set-name'), '');
    await _tap(tester, _key('save-custom-set'));
    expect(find.text('Give your set a name.'), findsOneWidget);
    await tester.enterText(_key('custom-set-name'), 'Still here');
    await _tap(tester, _key('save-custom-set'));
    expect(find.text('Design your set'), findsOneWidget);
    expect(find.textContaining('Could not save your set.'), findsOneWidget);
    expect(library.sets, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('delete requires confirmation and deactivates a deleted set', (
    tester,
  ) async {
    final library = CustomChessSets(autoLoad: false);
    addTearDown(library.dispose);
    await library.save(CustomChessSet.create(id: 'delete-me'));
    await _pumpStudio(tester, library);
    await _tap(tester, find.byTooltip('Set options'));
    await _tap(tester, find.text('Delete'));
    expect(find.text('Delete this chess set?'), findsOneWidget);
    await tester.tap(find.text('Keep set'));
    await tester.pumpAndSettle();
    expect(library.sets, hasLength(1));
    await _tap(tester, find.byTooltip('Set options'));
    await _tap(tester, find.text('Delete'));
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(library.sets, isEmpty);
    expect(library.active, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'duplicate preserves the design under a new id without replacing the original',
    (tester) async {
      final library = CustomChessSets(autoLoad: false);
      addTearDown(library.dispose);
      final original =
          CustomChessSet.create(id: 'original', name: 'My original')
              .copyWith(background: CustomBackground.royal)
              .withDesign(
                Side.black,
                Role.rook,
                const CustomPieceDesign(structure: 3, scale: .8),
              );
      await library.save(original);
      await _pumpStudio(tester, library);
      await _tap(tester, find.byTooltip('Set options'));
      await _tap(tester, find.text('Duplicate'));
      await _tap(tester, _key('save-custom-set'));
      expect(library.sets, hasLength(2));
      expect(library.active?.id, isNot(original.id));
      expect(library.active?.name, 'My original copy');
      expect(library.active?.background, CustomBackground.royal);
      expect(
        library.active?.designFor(Side.black, Role.rook),
        original.designFor(Side.black, Role.rook),
      );
      expect(library.sets.first.name, 'My original');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'custom colour uses the visual range and resets only after confirmation',
    (tester) async {
      final library = CustomChessSets(autoLoad: false);
      addTearDown(library.dispose);
      await _pumpStudio(tester, library);
      await _tap(tester, _key('create-custom-set'));
      await _tap(tester, _key('studio-tab-1'));
      await _tap(tester, _key('studio-colour-Light squares'));
      final range = _key('studio-colour-range');
      expect(range, findsOneWidget);
      expect(find.textContaining('Hex colour'), findsNothing);
      final rangeRect = tester.getRect(range);
      await tester.tapAt(
        Offset(rangeRect.left + rangeRect.width * .7, rangeRect.top + 70),
      );
      await tester.pump();
      await tester.tap(find.text('Apply colour'));
      await tester.pumpAndSettle();
      expect(find.textContaining('#'), findsNothing);
      await tester.tap(find.byTooltip('Reset draft'));
      await tester.pumpAndSettle();
      expect(find.text('Reset this draft?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      await _tap(tester, _key('save-custom-set'));
      expect(library.active?.lightSquare, isNot(0xfff3e6cf));
      expect(tester.takeException(), isNull);
    },
  );

  for (final configuration in [
    (const Size(320, 568), 2.0),
    (const Size(844, 390), 1.0),
  ]) {
    testWidgets(
      'studio fits ${configuration.$1} at ${configuration.$2}x text',
      (tester) async {
        final library = CustomChessSets(autoLoad: false);
        addTearDown(library.dispose);
        await _pumpStudio(
          tester,
          library,
          size: configuration.$1,
          textScale: configuration.$2,
        );
        await _tap(tester, _key('create-custom-set'));
        await _capture(
          tester,
          'editor-${configuration.$1.width.toInt()}-text${configuration.$2}',
        );
        expect(tester.takeException(), isNull);
        if (configuration.$1.width < 700) {
          await _tap(tester, _key('studio-part-formation-2'));
          await _tap(tester, _key('studio-role-king'));
          await _tap(tester, _key('studio-part-formation-3'));
          expect(tester.takeException(), isNull);
          await _capture(
            tester,
            'editor-parts-320-text2.0',
            scrollToTop: false,
          );
        }
        await _tap(tester, _key('studio-tab-1'));
        expect(tester.takeException(), isNull);
        await _tap(tester, _key('studio-tab-2'));
        expect(tester.takeException(), isNull);
        expect(_key('save-custom-set').hitTestable(), findsOneWidget);
      },
    );
  }
}
