import 'package:flutter/material.dart';

import 'theme_config.dart';

/// -------------------------------
/// Theme (app-configurable)
/// -------------------------------
Color get kPrimary => AppThemeConfig.current.primary;
Color get kSecondary => AppThemeConfig.current.secondary;
Color get kBg => AppThemeConfig.current.background;
Color get kCard => AppThemeConfig.current.surface;

ThemeData buildTheme(AppThemeConfig config) {
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: config.primary,
      primary: config.primary,
      secondary: config.secondary,
      surface: config.surface,
      background: config.background,
    ),
    useMaterial3: true,
  );

  // IMPORTANT: CardThemeData for older Flutter versions.
  return base.copyWith(
    scaffoldBackgroundColor: config.background,
    appBarTheme: AppBarTheme(
      backgroundColor: config.background,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: config.surface,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: config.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: config.primary, width: 1.2),
      ),
    ),
  );
}
