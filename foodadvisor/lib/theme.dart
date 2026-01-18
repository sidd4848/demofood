import 'package:flutter/material.dart';

/// -------------------------------
/// Theme (2 colors: warm + healing)
/// -------------------------------
const Color kPrimary = Color(0xFFE76F51); // warm coral
const Color kSecondary = Color(0xFF2A9D8F); // healing teal
const Color kBg = Color(0xFFFFFBF7); // warm off-white
const Color kCard = Color(0xFFFFFFFF);

ThemeData buildTheme() {
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: kPrimary,
      primary: kPrimary,
      secondary: kSecondary,
      surface: kCard,
      background: kBg,
    ),
    useMaterial3: true,
  );

  // IMPORTANT: CardThemeData for older Flutter versions.
  return base.copyWith(
    scaffoldBackgroundColor: kBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: kBg,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: const CardThemeData(
      color: kCard,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
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
        borderSide: const BorderSide(color: kPrimary, width: 1.2),
      ),
    ),
  );
}
