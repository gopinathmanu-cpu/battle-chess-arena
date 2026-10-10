// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io' as io;
import 'dart:ui' as ui;

import 'package:battle_chess_arena/src/domain/custom_avatar.dart';
import 'package:battle_chess_arena/src/domain/custom_avatar_presets.dart';
import 'package:battle_chess_arena/src/features/online/custom_avatar_builder_screen.dart';
import 'package:battle_chess_arena/src/features/online/custom_avatar_portrait.dart';
import 'package:battle_chess_arena/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _visuals = bool.fromEnvironment('AVATAR_STUDIO_VISUALS');
final _boundary = GlobalKey();
Finder _key(String name) => find.byKey(ValueKey(name));

class _BuilderResult {
  String? avatarId;
  int returned = 0;
}

Future<_BuilderResult> _openBuilder(
  WidgetTester tester, {
  CustomAvatarDesign? initialDesign,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  final result = _BuilderResult();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundary,
      child: MaterialApp(
        theme: buildAppTheme(),
        debugShowCheckedModeBanner: false,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  result.avatarId = await Navigator.of(context).push<String>(
                    MaterialPageRoute(
                      builder: (_) => CustomAvatarBuilderScreen(
                        initialDesign: initialDesign,
                      ),
                    ),
                  );
                  result.returned++;
                },
                child: const Text('Create avatar'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Create avatar'));
  await tester.pumpAndSettle();
  return result;
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    final scroll = find
        .descendant(
          of: _key('avatar-options-scroll'),
          matching: find.byType(Scrollable),
        )
        .first;
    tester.state<ScrollableState>(scroll).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: scroll,
      maxScrolls: 60,
    );
  } else {
    await tester.ensureVisible(target);
  }
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

CustomAvatarDesign _preview(WidgetTester tester) => tester
    .widget<CustomAvatarPortrait>(_key('custom-avatar-live-preview'))
    .design;

Future<void> _capture(WidgetTester tester, String name) async {
  if (!_visuals) return;
  await tester.runAsync(() async {
    final render =
        _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = await io.Directory(
      'build/avatar-studio-visuals',
    ).create(recursive: true);
    await io.File(
      '${directory.path}/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  testWidgets(
    'portrait-inspired starter remains editable and returns portable avatar',
    (tester) async {
      final result = await _openBuilder(tester);
      final look = _key('avatar-portrait-look-0');
      await tester.scrollUntilVisible(
        look,
        200,
        scrollable: find.descendant(
          of: _key('avatar-options-scroll'),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(look);
      await tester.pump();
      final preview = tester.widget<CustomAvatarPortrait>(
        find.byType(CustomAvatarPortrait).first,
      );
      expect(preview.design, customAvatarPresets.first.$2);
      await tester.tap(_key('use-custom-avatar'));
      await tester.pumpAndSettle();
      expect(
        CustomAvatarDesign.tryParse(result.avatarId!),
        customAvatarPresets.first.$2,
      );
    },
  );

  setUpAll(() async {
    const fontDirectory = String.fromEnvironment(
      'AVATAR_STUDIO_FONT_DIR',
      defaultValue: String.fromEnvironment('STUDIO_FONT_DIR'),
    );
    if (!_visuals || fontDirectory.isEmpty) return;
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

  testWidgets(
    'all avatar categories remain editable and return the chosen design only on use',
    (tester) async {
      final result = await _openBuilder(tester);
      await _capture(tester, 'face-390');
      await _tap(tester, _key('avatar-starter-girl'));
      expect(_preview(tester).presentation, 1);
      expect(_preview(tester).age, 0);
      await _tap(tester, _key('avatar-age-3'));
      await _tap(tester, _key('avatar-face-2'));
      await _tap(tester, _key('avatar-skin-7'));
      await _tap(tester, _key('avatar-tab-hair'));
      await _capture(tester, 'hair-390');
      await _tap(tester, _key('avatar-hair-11'));
      await _tap(tester, _key('avatar-hair-colour-8'));
      await _tap(tester, _key('avatar-tab-facialHair'));
      await _tap(tester, _key('avatar-moustache-3'));
      await _tap(tester, _key('avatar-beard-5'));
      await _tap(tester, _key('avatar-tab-glasses'));
      await _tap(tester, _key('avatar-glasses-4'));
      await _capture(tester, 'glasses-390');
      await _tap(tester, _key('avatar-tab-style'));
      await _capture(tester, 'style-390');
      await _tap(tester, _key('avatar-outfit-4'));
      await _tap(tester, _key('avatar-outfit-colour-6'));
      await _tap(tester, _key('avatar-background-3'));
      expect(result.returned, 0);
      expect(result.avatarId, isNull);
      expect(_key('custom-avatar-live-preview').hitTestable(), findsOneWidget);
      await _tap(tester, _key('use-custom-avatar'));
      expect(result.returned, 1);
      expect(
        CustomAvatarDesign.tryParse(result.avatarId!),
        const CustomAvatarDesign(
          presentation: 1,
          age: 3,
          face: 2,
          skinTone: 7,
          hairStyle: 11,
          hairColor: 8,
          moustache: 3,
          beard: 5,
          eyewear: 4,
          outfit: 4,
          outfitColor: 6,
          background: 3,
        ),
      );
      expect(find.byType(CustomAvatarBuilderScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'initial avatar reopens unchanged and can be used without edits',
    (tester) async {
      const initial = CustomAvatarDesign(
        presentation: 1,
        age: 1,
        face: 3,
        skinTone: 5,
        hairStyle: 9,
        hairColor: 4,
        eyewear: 3,
        outfit: 5,
        outfitColor: 4,
        background: 6,
      );
      final result = await _openBuilder(tester, initialDesign: initial);
      expect(_preview(tester), initial);
      await _tap(tester, _key('use-custom-avatar'));
      expect(result.avatarId, initial.avatarId);
      expect(result.returned, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('back confirms discarded edits and never returns the edited ID', (
    tester,
  ) async {
    const original = CustomAvatarDesign(age: 3, hairColor: 6);
    final result = await _openBuilder(tester, initialDesign: original);
    await _tap(tester, _key('avatar-starter-boy'));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard avatar changes?'), findsOneWidget);
    await tester.tap(find.text('Keep creating'));
    await tester.pumpAndSettle();
    expect(result.returned, 0);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(result.returned, 1);
    expect(result.avatarId, isNull);
    expect(original.age, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reset requires confirmation and only resets the draft', (
    tester,
  ) async {
    const initial = CustomAvatarDesign(
      presentation: 1,
      age: 3,
      hairStyle: 8,
      hairColor: 6,
      eyewear: 2,
    );
    final result = await _openBuilder(tester, initialDesign: initial);
    await _tap(tester, _key('avatar-reset'));
    expect(find.text('Reset this avatar?'), findsOneWidget);
    await tester.tap(find.text('Keep creating'));
    await tester.pumpAndSettle();
    expect(_preview(tester), initial);
    await _tap(tester, _key('avatar-reset'));
    await tester.tap(find.widgetWithText(FilledButton, 'Reset avatar'));
    await tester.pumpAndSettle();
    expect(_preview(tester), const CustomAvatarDesign());
    expect(result.returned, 0);
    await _tap(tester, _key('use-custom-avatar'));
    expect(result.avatarId, const CustomAvatarDesign().avatarId);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all four starting looks are available without locking options', (
    tester,
  ) async {
    await _openBuilder(tester);
    for (final (starter, presentation, age) in [
      ('man', 0, 2),
      ('woman', 1, 2),
      ('boy', 0, 0),
      ('girl', 1, 0),
    ]) {
      await _tap(tester, _key('avatar-starter-$starter'));
      expect(_preview(tester).presentation, presentation);
      expect(_preview(tester).age, age);
    }
    await _tap(tester, _key('avatar-age-1'));
    expect(_preview(tester).age, 1);
    await _tap(tester, _key('avatar-presentation-0'));
    expect(_preview(tester).presentation, 0);
    expect(_preview(tester).age, 1);
    expect(tester.takeException(), isNull);
  });

  for (final configuration in [
    (const Size(320, 568), 2.0),
    (const Size(640, 360), 1.0),
    (const Size(844, 390), 1.0),
  ]) {
    testWidgets(
      'avatar editor fits ${configuration.$1} at ${configuration.$2}x text',
      (tester) async {
        await _openBuilder(
          tester,
          size: configuration.$1,
          textScale: configuration.$2,
        );
        expect(tester.takeException(), isNull);
        await _capture(
          tester,
          'face-${configuration.$1.width.toInt()}-text${configuration.$2}',
        );
        await _tap(tester, _key('avatar-tab-hair'));
        await _tap(tester, _key('avatar-hair-10'));
        expect(tester.takeException(), isNull);
        expect(
          _key('custom-avatar-live-preview').hitTestable(),
          findsOneWidget,
        );
        await _capture(
          tester,
          'hair-${configuration.$1.width.toInt()}-text${configuration.$2}',
        );
        await _tap(tester, _key('avatar-tab-glasses'));
        await _tap(tester, _key('avatar-glasses-5'));
        await _tap(tester, _key('avatar-tab-style'));
        await _tap(tester, _key('avatar-background-7'));
        expect(_preview(tester).background, 7);
        expect(
          _key('custom-avatar-live-preview').hitTestable(),
          findsOneWidget,
        );
        expect(_key('use-custom-avatar').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
