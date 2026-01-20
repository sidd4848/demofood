import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

class AppThemeConfig {
  final String appName;
  final Color primary;
  final Color secondary;
  final Color background;
  final Color surface;
  final String logoAsset;

  const AppThemeConfig({
    required this.appName,
    required this.primary,
    required this.secondary,
    required this.background,
    required this.surface,
    required this.logoAsset,
  });

  static AppThemeConfig current = AppThemeConfig.fallback();

  static AppThemeConfig fallback() {
    return const AppThemeConfig(
      appName: 'FoodAdvisor',
      primary: Color(0xFFE76F51),
      secondary: Color(0xFF2A9D8F),
      background: Color(0xFFFFFBF7),
      surface: Color(0xFFFFFFFF),
      logoAsset: 'assets/branding/logo.svg',
    );
  }

  static Future<AppThemeConfig> loadFromAsset(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    final yaml = loadYaml(raw);
    if (yaml is! YamlMap) {
      return fallback();
    }
    final theme = yaml['theme'] as YamlMap?;
    if (theme == null) {
      return fallback();
    }
    return AppThemeConfig(
      appName: theme['name']?.toString() ?? 'FoodAdvisor',
      primary: _parseColor(theme['primary']?.toString()) ?? fallback().primary,
      secondary: _parseColor(theme['secondary']?.toString()) ?? fallback().secondary,
      background: _parseColor(theme['background']?.toString()) ?? fallback().background,
      surface: _parseColor(theme['surface']?.toString()) ?? fallback().surface,
      logoAsset: theme['logo']?.toString() ?? fallback().logoAsset,
    );
  }

  static void apply(AppThemeConfig config) {
    current = config;
  }

  static Color? _parseColor(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim().replaceAll('#', '');
    if (normalized.length == 6) {
      return Color(int.parse('FF$normalized', radix: 16));
    }
    if (normalized.length == 8) {
      return Color(int.parse(normalized, radix: 16));
    }
    return null;
  }
}
