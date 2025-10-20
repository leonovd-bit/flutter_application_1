import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppThemeV3 {
  // Victus-Style Black & White Color Scheme
  static const Color primaryGreen = Color(0xFF000000);       // PRIMARY: Black
  static const Color primaryBlack = Color(0xFF000000);       // Pure black
  static const Color primaryDark = Color(0xFF1A1A1A);        // Slightly lighter black
  static const Color primaryLight = Color(0xFF333333);       // Dark gray
  
  // Background & Surface Colors
  static const Color background = Color(0xFFFFFFFF);         // Pure white background
  static const Color surface = Color(0xFFFFFFFF);            // Pure white cards
  static const Color surfaceElevated = Color(0xFFF5F5F5);    // Very light gray elevated surface
  static const Color surfaceDark = Color(0xFF000000);        // Black surface for contrast
  
  // Text Colors
  static const Color textPrimary = Color(0xFF000000);        // Black text
  static const Color textSecondary = Color(0xFF666666);      // Medium gray
  static const Color textLight = Color(0xFF999999);          // Light gray
  static const Color textOnDark = Color(0xFFFFFFFF);         // White on dark
  
  // UI Colors
  static const Color accent = Color(0xFF000000);             // Black accent (was green)
  static const Color accentLight = Color(0xFF333333);        // Dark gray
  static const Color success = Color(0xFF000000);            // Black (was green)
  static const Color warning = Color(0xFFFF9800);            // Warning orange
  static const Color error = Color(0xFFF44336);              // Error red
  
  // Border & Divider Colors - Victus Style (Bold Black Borders)
  static const Color border = Color(0xFF000000);             // BLACK BORDER (2px width)
  static const Color borderLight = Color(0xFFE0E0E0);        // Light border for subtle dividers
  static const Color hover = Color(0xFFF5F5F5);              // Light gray hover

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

  // Minimal shadows for Victus clean styling (less shadow, more borders)
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 2,
      offset: const Offset(0, 1),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 4,
      offset: const Offset(0, 2),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get boldShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 4,
      offset: const Offset(0, 2),
      spreadRadius: 0,
    ),
  ];

  // Black gradients for Victus styling
  static LinearGradient get primaryGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      primaryBlack,
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

  // Text styles with Victus branding - Bold, clean, and professional
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

  // Victus-style bold decorations (2px black borders, minimal shadows)
  static BoxDecoration get boldCardDecoration => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: border, // Black border
      width: 2,
    ),
    boxShadow: cardShadow,
  );

  static BoxDecoration get boldButtonDecoration => BoxDecoration(
    color: primaryBlack,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: border, // Black border
      width: 2,
    ),
    boxShadow: cardShadow,
  );

  static BoxDecoration get boldIconDecoration => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: border, // Black border
      width: 2,
    ),
    boxShadow: cardShadow,
  );

  static BoxDecoration get boldHeaderDecoration => BoxDecoration(
    color: surface,
    border: Border(
      bottom: BorderSide(
        color: border, // Black border
        width: 2,
      ),
    ),
    boxShadow: cardShadow,
  );

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primarySwatch: MaterialColor(
      primaryBlack.value,
      <int, Color>{
        50: const Color(0xFFF5F5F5),
        100: const Color(0xFFE0E0E0),
        200: const Color(0xFFBDBDBD),
        300: const Color(0xFF9E9E9E),
        400: const Color(0xFF757575),
        500: primaryBlack,
        600: const Color(0xFF424242),
        700: const Color(0xFF303030),
        800: const Color(0xFF212121),
        900: const Color(0xFF1B5E20),
      },
    ),
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.light(
      primary: primaryBlack,
      secondary: primaryDark,
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
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.04),
      scrolledUnderElevation: 0,
      titleTextStyle: textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
      iconTheme: const IconThemeData(color: primaryBlack),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryBlack,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border, width: 2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryBlack,
        side: const BorderSide(color: border, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderLight, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderLight, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: const TextStyle(
        color: textSecondary,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      labelStyle: const TextStyle(
        color: textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: const CardThemeData(
      color: surface,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: border, width: 2),
      ),
    ),
  );
}
