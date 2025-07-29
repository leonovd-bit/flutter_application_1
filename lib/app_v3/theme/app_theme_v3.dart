import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppThemeV3 {
  // Color Palette for FreshPunk
  static const Color primaryGreen = Color(0xFF10B981);       // Primary FreshPunk green
  static const Color background = Color(0xFFF8F9FA);        // Light gray background
  static const Color surface = Color(0xFFFFFFFF);           // Pure white
  static const Color surfaceElevated = Color(0xFFF5F5F5);   // Slightly elevated surface
  static const Color textPrimary = Color(0xFF1A1A1A);       // Dark text
  static const Color textSecondary = Color(0xFF6B7280);     // Gray text
  static const Color accent = Color(0xFF10B981);            // Fresh green accent
  static const Color accentLight = Color(0xFF34D399);       // Lighter green
  static const Color border = Color(0xFFE5E7EB);            // Light border
  static const Color borderLight = Color(0xFFF3F4F6);       // Very light border
  static const Color hover = Color(0xFFECFDF5);             // Light green hover
  static const Color success = Color(0xFF10B981);           // Success green
  static const Color warning = Color(0xFFF59E0B);           // Warning amber
  static const Color error = Color(0xFFEF4444);             // Error red

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

  // Enhanced shadows for bold styling - smaller and darker
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.15),
      blurRadius: 6,
      offset: const Offset(0, 2),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.20),
      blurRadius: 8,
      offset: const Offset(0, 3),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get boldShadow => [
    BoxShadow(
      color: accent.withOpacity(0.4),
      blurRadius: 8,
      offset: const Offset(0, 4),
      spreadRadius: 1,
    ),
  ];

  // Gradient definitions for bold styling
  static LinearGradient get primaryGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      accent,
      accent.withOpacity(0.8),
    ],
  );

  static LinearGradient get surfaceGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      surface,
      surface.withOpacity(0.95),
    ],
  );

  static LinearGradient get backgroundGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      background,
      background.withOpacity(0.95),
    ],
  );

  // Text styles with enhanced bold fonts and safe fallbacks
  static TextTheme get textTheme => TextTheme(
    displayLarge: _safeGoogleFont(
      'inter',
      fontSize: 32,
      fontWeight: FontWeight.w900,
      color: textPrimary,
      letterSpacing: -0.8,
    ),
    displayMedium: _safeGoogleFont(
      'inter',
      fontSize: 28,
      fontWeight: FontWeight.w800,
      color: textPrimary,
      letterSpacing: -0.5,
    ),
    displaySmall: _safeGoogleFont(
      'inter',
      fontSize: 24,
      fontWeight: FontWeight.w800,
      color: textPrimary,
      letterSpacing: -0.3,
    ),
    headlineLarge: _safeGoogleFont(
      'inter',
      fontSize: 22,
      fontWeight: FontWeight.w800,
      color: textPrimary,
      letterSpacing: -0.2,
    ),
    headlineMedium: _safeGoogleFont(
      'inter',
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: textPrimary,
      letterSpacing: -0.1,
    ),
    headlineSmall: _safeGoogleFont(
      'inter',
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: textPrimary,
    ),
    titleLarge: _safeGoogleFont(
      'inter',
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: textPrimary,
    ),
    titleMedium: _safeGoogleFont(
      'inter',
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: textPrimary,
    ),
    titleSmall: _safeGoogleFont(
      'inter',
      fontSize: 12,
      fontWeight: FontWeight.w600,
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
      color: accent.withOpacity(0.2),
      width: 2,
    ),
    boxShadow: elevatedShadow,
  );

  static BoxDecoration get boldButtonDecoration => BoxDecoration(
    gradient: primaryGradient,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: accent.withOpacity(0.5),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
    ],
  );

  static BoxDecoration get boldIconDecoration => BoxDecoration(
    color: accent.withOpacity(0.1),
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: accent.withOpacity(0.3),
        blurRadius: 4,
        offset: const Offset(0, 1),
      ),
    ],
  );

  static BoxDecoration get boldHeaderDecoration => BoxDecoration(
    gradient: surfaceGradient,
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.25),
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
      accent.toARGB32(),
      <int, Color>{
        50: const Color(0xFFECFDF5),
        100: const Color(0xFFD1FAE5),
        200: const Color(0xFFA7F3D0),
        300: const Color(0xFF6EE7B7),
        400: const Color(0xFF34D399),
        500: accent,
        600: const Color(0xFF059669),
        700: const Color(0xFF047857),
        800: const Color(0xFF065F46),
        900: const Color(0xFF064E3B),
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
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.1),
      scrolledUnderElevation: 8,
      titleTextStyle: textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      iconTheme: IconThemeData(color: accent),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 8,
        shadowColor: accent.withOpacity(0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
        textStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: accent,
        side: BorderSide(color: accent, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
        textStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: border, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: border, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: accent, width: 3),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      hintStyle: GoogleFonts.inter(
        color: textSecondary,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      labelStyle: GoogleFonts.inter(
        color: accent,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        side: BorderSide(color: accent.withOpacity(0.2), width: 2),
      ),
    ),
  );
}
