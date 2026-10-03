import 'package:battle_chess_arena/src/features/settings/game_settings_sheet.dart';
import 'package:battle_chess_arena/src/services/app_color_scheme_controller.dart';
import 'package:battle_chess_arena/src/theme/app_theme.dart';
import 'package:battle_chess_arena/src/domain/piece_pack.dart';
import 'package:battle_chess_arena/src/features/play/board_appearance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'app icon gold dynamic background is default and choices persist',
    () async {
      final controller = AppColorSchemeController();
      await controller.restore();
      expect(controller.preset, AppColorSchemePreset.goldenArena);
      expect(controller.backgroundMode, AppBackgroundMode.dynamic);

      await controller.setPreset(AppColorSchemePreset.emerald);
      await controller.setBackgroundMode(AppBackgroundMode.dynamic);
      final restored = AppColorSchemeController();
      await restored.restore();
      expect(restored.preset, AppColorSchemePreset.emerald);
      expect(restored.backgroundMode, AppBackgroundMode.dynamic);

      controller.dispose();
      restored.dispose();
    },
  );

  test('unknown saved values safely fall back to golden arena', () async {
    SharedPreferences.setMockInitialValues({
      AppColorSchemeController.preferenceKey: 'removed_palette',
    });
    final controller = AppColorSchemeController();
    await controller.restore();
    expect(controller.preset, AppColorSchemePreset.goldenArena);
    controller.dispose();
  });

  testWidgets('visual canvas changes mode and single background palette', (
    tester,
  ) async {
    final controller = AppColorSchemeController();
    await tester.pumpWidget(
      ListenableBuilder(
        listenable: controller,
        builder: (context, _) => MaterialApp(
          theme: buildAppTheme(controller.preset),
          home: Scaffold(
            body: ApplicationColorSchemePicker(controller: controller),
          ),
        ),
      ),
    );

    final initialTheme = Theme.of(
      tester.element(find.byType(ApplicationColorSchemePicker)),
    );
    expect(initialTheme.colorScheme.primary, isNot(const Color(0xFF3976D2)));
    expect(initialTheme.cardTheme.color, isNotNull);
    expect(initialTheme.popupMenuTheme.color, isNotNull);
    expect(find.text('Single scheme'), findsOneWidget);
    expect(find.text('Dynamic scheme'), findsOneWidget);
    expect(find.text('App Icon Gold'), findsOneWidget);
    expect(find.text('Selected: App Icon Gold'), findsOneWidget);
    expect(find.byType(DropdownButton<dynamic>), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('application-background-single')),
    );
    await tester.pump();
    expect(find.text('App Icon Gold'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('application-background-preset-royalBlue')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(controller.preset, AppColorSchemePreset.royalBlue);
    final changedTheme = Theme.of(
      tester.element(find.byType(ApplicationColorSchemePicker)),
    );
    expect(
      changedTheme.colorScheme.primary,
      isNot(initialTheme.colorScheme.primary),
    );
    expect(changedTheme.cardTheme.color, isNot(initialTheme.cardTheme.color));

    await tester.tap(
      find.byKey(const ValueKey('application-background-dynamic')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.backgroundMode, AppBackgroundMode.dynamic);
    expect(
      find.byKey(const ValueKey('application-background-preset-royalBlue')),
      findsOneWidget,
    );
    expect(find.text('Selected: Royal Blue'), findsOneWidget);
    controller.dispose();
  });

  testWidgets(
    'saved palette is selected after settings reopen in dynamic mode',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        AppColorSchemeController.preferenceKey:
            AppColorSchemePreset.amethyst.name,
        AppColorSchemeController.backgroundModePreferenceKey:
            AppBackgroundMode.dynamic.name,
      });
      final controller = AppColorSchemeController();
      await controller.restore();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(controller.preset),
          home: Scaffold(
            body: ApplicationColorSchemePicker(controller: controller),
          ),
        ),
      );
      expect(controller.preset, AppColorSchemePreset.amethyst);
      expect(controller.backgroundMode, AppBackgroundMode.dynamic);
      expect(find.text('Selected: Amethyst'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('application-background-preset-amethyst')),
        findsOneWidget,
      );
      final theme = Theme.of(
        tester.element(find.byType(ApplicationColorSchemePicker)),
      );
      expect(theme.colorScheme.secondary, theme.colorScheme.primary);
      expect(theme.colorScheme.tertiary, theme.colorScheme.primary);
      controller.dispose();
    },
  );

  testWidgets('single background ignores chess set and dynamic restores it', (
    tester,
  ) async {
    final controller = AppColorSchemeController();
    await controller.setBackgroundMode(AppBackgroundMode.single);
    await tester.pumpWidget(
      AppColorSchemeScope(
        controller: controller,
        child: MaterialApp(
          home: WorldBackdrop(
            pack: piecePacks.last,
            playSoundtrack: false,
            child: const Text('Arena'),
          ),
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey('single-application-background')),
      findsOneWidget,
    );

    await controller.setBackgroundMode(AppBackgroundMode.dynamic);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('single-application-background')),
      findsNothing,
    );
    expect(find.text('Arena'), findsOneWidget);
    controller.dispose();
  });
}
