import 'package:flutter/material.dart';

import '../../config/app_config.dart';

/// Builds the app [ThemeData] from the white-label [AppConfig].
/// Called once at startup — colors come from --dart-define, never hard-coded.
ThemeData buildTheme(AppConfig config) {
  final scheme = ColorScheme.fromSeed(
    seedColor: config.primaryColor,
    primary: config.primaryColor,
    secondary: config.secondaryColor,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    appBarTheme: AppBarTheme(
      backgroundColor: config.primaryColor,
      foregroundColor: Colors.white,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: config.primaryColor,
        foregroundColor: Colors.white,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: config.primaryColor,
      foregroundColor: Colors.white,
    ),
  );
}
