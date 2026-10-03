import 'package:flutter/material.dart';

import '../services/app_color_scheme_controller.dart';

ThemeData buildAppTheme([
  AppColorSchemePreset preset = AppColorSchemePreset.goldenArena,
]) {
  final generated = ColorScheme.fromSeed(
    seedColor: preset.seed,
    brightness: Brightness.dark,
  );
  // Application chrome uses one coherent hue family. Material's generated
  // secondary/tertiary tones can otherwise drift (gold can yield magenta
  // tonal buttons), making menus and buttons look unrelated.
  final scheme = generated.copyWith(
    secondary: generated.primary,
    onSecondary: generated.onPrimary,
    secondaryContainer: generated.primaryContainer,
    onSecondaryContainer: generated.onPrimaryContainer,
    tertiary: generated.primary,
    onTertiary: generated.onPrimary,
    tertiaryContainer: generated.primaryContainer,
    onTertiaryContainer: generated.onPrimaryContainer,
  );
  final warmGold = preset == AppColorSchemePreset.goldenArena;
  final background = Color.alphaBlend(
    preset.seed.withValues(alpha: warmGold ? .055 : .04),
    const Color(0xFF0B0C12),
  );
  final surface = Color.alphaBlend(
    preset.seed.withValues(alpha: .09),
    const Color(0xFF151720),
  );
  final elevatedSurface = Color.alphaBlend(
    preset.seed.withValues(alpha: .14),
    const Color(0xFF1B1D28),
  );
  final border = scheme.outlineVariant.withValues(alpha: .72);
  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
    side: BorderSide(color: border),
  );
  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    canvasColor: surface,
    cardTheme: CardThemeData(
      color: surface,
      margin: EdgeInsets.zero,
      elevation: 1,
      shape: rounded,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: elevatedSurface,
      shape: rounded,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: elevatedSurface,
      modalBackgroundColor: elevatedSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: elevatedSurface,
      shape: rounded,
      elevation: 8,
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(elevatedSurface),
        shape: WidgetStatePropertyAll(rounded),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        disabledBackgroundColor: scheme.onSurface.withValues(alpha: .12),
        disabledForegroundColor: scheme.onSurface.withValues(alpha: .38),
        shape: buttonShape,
        minimumSize: const Size(48, 44),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        shape: buttonShape,
        minimumSize: const Size(48, 44),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.primary,
        side: BorderSide(color: scheme.outline),
        shape: buttonShape,
        minimumSize: const Size(48, 44),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        shape: buttonShape,
        minimumSize: const Size(40, 40),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: scheme.primary),
    ),
    drawerTheme: DrawerThemeData(backgroundColor: elevatedSurface),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: scheme.primaryContainer,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: border),
      ),
    ),
    dividerTheme: DividerThemeData(color: border),
    chipTheme: ChipThemeData(
      backgroundColor: surface,
      selectedColor: scheme.secondaryContainer,
      side: BorderSide(color: border),
    ),
  );
}
