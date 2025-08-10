import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppThemeV3 {
  // White and Green Color Scheme
  static const Color primaryGreen = Color(0xFF4CAF50);       // Primary green
  static const Color primaryDark = Color(0xFF388E3C);        // Darker green
  static const Color primaryLight = Color(0xFF81C784);       // Lighter green
  
  // Background & Surface Colors
  static const Color background = Color(0xFFFFFFFF);         // Pure white background
  static const Color surface = Color(0xFFFFFFFF);            // Pure white cards
  static const Color surfaceElevated = Color(0xFFF8F9FA);    // Very light gray elevated surface
  static const Color surfaceDark = Color(0xFF2D2D2D);        // Dark surface for contrast
  
  // Text Colors
  static const Color textPrimary = Color(0xFF212121);        // Dark text
  static const Color textSecondary = Color(0xFF757575);      // Medium gray
  static const Color textLight = Color(0xFFBDBDBD);          // Light gray
  static const Color textOnDark = Color(0xFFFFFFFF);         // White on dark
  
  // UI Colors
  static const Color accent = Color(0xFF4CAF50);             // Primary green accent
  static const Color accentLight = Color(0xFF81C784);        // Light green
  static const Color success = Color(0xFF4CAF50);            // Success green
  static const Color warning = Color(0xFFFF9800);            // Warning orange
  static const Color error = Color(0xFFF44336);              // Error red
  
  // Border & Divider Colors
  static const Color border = Color(0xFFE0E0E0);             // Light border
  static const Color borderLight = Color(0xFFF5F5F5);        // Very light border
  static const Color hover = Color(0xFFE8F5E8);              // Light green hover

  // Safe font getter with fallback to system fonts
  static TextStyle _safeGoogleFont(String fontFamily, {
    required double fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    try {
      return GoogleFonts.getFont(
        fontFamily,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );
    } catch (e) {
      // Fallback to system font if Google Fonts fails
      return TextStyle(
        fontFamily: 'Inter', // System fallback
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );
    }
  }

  // Enhanced shadows for clean styling
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 4,
      offset: const Offset(0, 2),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      blurRadius: 6,
      offset: const Offset(0, 3),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get boldShadow => [
    BoxShadow(
      color: accent.withValues(alpha: 0.3),
      blurRadius: 6,
      offset: const Offset(0, 3),
      spreadRadius: 0,
    ),
  ];

  // Clean gradient definitions
  static LinearGradient get primaryGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      accent,
      primaryDark,
    ],
  );

  static LinearGradient get surfaceGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
  surface,
  surface.withValues(alpha: 0.95),
    ],
  );

  static LinearGradient get backgroundGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
  background,
  background.withValues(alpha: 0.95),
    ],
  );

  // Text styles with FreshPunk branding - Bold, friendly, and food-focused
  static TextTheme get textTheme => TextTheme(
    displayLarge: _safeGoogleFont(
      'Poppins',
      fontSize: 32,
      fontWeight: FontWeight.w900,
      color: textPrimary,
      letterSpacing: -0.5,
    ),
    displayMedium: _safeGoogleFont(
      'Poppins',
      fontSize: 28,
      fontWeight: FontWeight.w800,
      color: textPrimary,
      letterSpacing: -0.3,
    ),
    displaySmall: _safeGoogleFont(
      'Poppins',
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: textPrimary,
      letterSpacing: -0.2,
    ),
    headlineLarge: _safeGoogleFont(
      'Poppins',
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: textPrimary,
      letterSpacing: -0.1,
    ),
    headlineMedium: _safeGoogleFont(
      'Poppins',
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: textPrimary,
    ),
    headlineSmall: _safeGoogleFont(
      'Poppins',
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: textPrimary,
    ),
    titleLarge: _safeGoogleFont(
      'Inter',
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: textPrimary,
    ),
    titleMedium: _safeGoogleFont(
      'Inter',
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: textPrimary,
    ),
    titleSmall: _safeGoogleFont(
      'Inter',
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: textPrimary,
    ),
    bodyLarge: _safeGoogleFont(
      'inter',
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: textPrimary,
    ),
    bodyMedium: _safeGoogleFont(
      'inter',
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: textPrimary,
    ),
    bodySmall: _safeGoogleFont(
      'inter',
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: textSecondary,
    ),
    labelLarge: _safeGoogleFont(
      'inter',
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: textPrimary,
    ),
    labelMedium: _safeGoogleFont(
      'inter',
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: textPrimary,
    ),
    labelSmall: _safeGoogleFont(
      'inter',
      fontSize: 10,
      fontWeight: FontWeight.w500,
      color: textSecondary,
    ),
  );

  // Bold styling utilities
  static BoxDecoration get boldCardDecoration => BoxDecoration(
    gradient: surfaceGradient,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: accent.withValues(alpha: 0.2),
      width: 2,
    ),
    boxShadow: elevatedShadow,
  );

  static BoxDecoration get boldButtonDecoration => BoxDecoration(
    gradient: primaryGradient,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: accent.withValues(alpha: 0.5),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
    ],
  );

  static BoxDecoration get boldIconDecoration => BoxDecoration(
  color: accent.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: accent.withValues(alpha: 0.3),
        blurRadius: 4,
        offset: const Offset(0, 1),
      ),
    ],
  );

  static BoxDecoration get boldHeaderDecoration => BoxDecoration(
    gradient: surfaceGradient,
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.25),
        blurRadius: 8,
        offset: const Offset(0, 2),
        spreadRadius: 0,
      ),
    ],
  );

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primarySwatch: MaterialColor(
      accent.value,
      <int, Color>{
        50: const Color(0xFFE8F5E8),
        100: const Color(0xFFC8E6C8),
        200: const Color(0xFFA5D6A7),
        300: const Color(0xFF81C784),
        400: const Color(0xFF66BB6A),
        500: accent,
        600: const Color(0xFF43A047),
        700: const Color(0xFF388E3C),
        800: const Color(0xFF2E7D32),
        900: const Color(0xFF1B5E20),
      },
    ),
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.light(
      primary: accent,
      secondary: accentLight,
      surface: surface,
      error: error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: textPrimary,
      onError: Colors.white,
    ),
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      elevation: 2,
  shadowColor: Colors.black.withValues(alpha: 0.1),
      scrolledUnderElevation: 2,
      titleTextStyle: textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: accent),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 2,
  shadowColor: accent.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: accent,
        side: BorderSide(color: accent, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: accent, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: error, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: TextStyle(
        color: textSecondary,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      labelStyle: TextStyle(
        color: accent,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 2,
  shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        side: BorderSide(color: border, width: 0.5),
      ),
    ),
  );
}
