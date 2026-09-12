import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const seed = Color(0xFF7C5CFF);
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: const Color(0xFF0B0C14),
    cardTheme: const CardThemeData(
      color: Color(0xFF151725),
      margin: EdgeInsets.zero,
    ),
  );
}
