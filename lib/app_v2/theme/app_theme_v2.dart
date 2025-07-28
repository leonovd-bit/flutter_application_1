import 'package:flutter/material.dart';

class AppThemeV2 {
  static final Color primary = Color(0xFF013220);
  static final Color background = Colors.white;
  static final Color accent = Color(0xFF013220);

  static final ThemeData lightTheme = ThemeData(
    colorScheme: ColorScheme.light(
      primary: primary,
      secondary: accent,
      background: background,
    ),
    scaffoldBackgroundColor: background,
    textTheme: const TextTheme(
      headline5: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      bodyText2: TextStyle(fontSize: 16),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
  );
}
