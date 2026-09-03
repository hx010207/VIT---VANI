/// PURPOSE: Quiet Vault design system theme definitions, typography, and color tokens.
/// ROLE IN SYSTEM: Enforces deep green (#1B4332), ivory (#FAF7F0), brass (#B08968), and 18sp text.
/// TALKS TO: app/lib/main.dart, app/lib/widgets/, app/lib/screens/
import 'package:flutter/material.dart';

class QuietVaultColors {
  // Light Palette
  static const Color primary = Color(0xFF0B3D2E);       // Deep Vault Green
  static const Color primaryDark = Color(0xFF072A20);
  static const Color surface = Color(0xFFFAF8F4);       // Warm Ivory
  static const Color surfaceAlt = Color(0xFFF0EDE6);
  static const Color ink = Color(0xFF1A1D1A);           // Near-black text
  static const Color inkSecondary = Color(0xFF4A524C);
  static const Color accent = Color(0xFFB8860B);        // Brass (caution only)
  static const Color danger = Color(0xFF9B1C1C);        // Muted Red
  static const Color success = Color(0xFF1B6E4A);
  static const Color focusRing = Color(0xFFD97706);     // 3px visible focus ring

  // Dark Palette
  static const Color darkSurface = Color(0xFF101512);
  static const Color darkSurfaceAlt = Color(0xFF181F1B);
  static const Color darkInk = Color(0xFFEDEBE6);
  static const Color darkInkSecondary = Color(0xFFA2AAA4);
  static const Color darkPrimary = Color(0xFF3E9B7A);

  // Approved Matte Black & Amber Palette tokens
  static const Color background = Color(0xFF1E1E1E);
  static const Color card = Color(0xFFFAFAFA);
  static const Color textPrimary = Color(0xFFFAFAFA);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color amberAccent = Color(0xFFFFB300);
}

class QuietVaultTheme {
  static const double minTouchTarget = 64.0;
  static const double focusRingWidth = 3.0;

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: QuietVaultColors.primary,
      scaffoldBackgroundColor: QuietVaultColors.surface,
      colorScheme: const ColorScheme.light(
        primary: QuietVaultColors.primary,
        onPrimary: QuietVaultColors.surface,
        surface: QuietVaultColors.surface,
        onSurface: QuietVaultColors.ink,
        surfaceContainerHighest: QuietVaultColors.surfaceAlt,
        error: QuietVaultColors.danger,
        onError: QuietVaultColors.surface,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 34,
          height: 40 / 34,
          fontWeight: FontWeight.w600,
          color: QuietVaultColors.ink,
        ),
        titleLarge: TextStyle(
          fontSize: 24,
          height: 32 / 24,
          fontWeight: FontWeight.w600,
          color: QuietVaultColors.ink,
        ),
        bodyLarge: TextStyle(
          fontSize: 18,
          height: 28 / 18,
          fontWeight: FontWeight.w400,
          color: QuietVaultColors.ink,
        ),
        bodyMedium: TextStyle(
          fontSize: 18,
          height: 28 / 18,
          fontWeight: FontWeight.w400,
          color: QuietVaultColors.inkSecondary,
        ),
        bodySmall: TextStyle(
          fontSize: 14,
          height: 20 / 14,
          fontWeight: FontWeight.w400,
          color: QuietVaultColors.inkSecondary,
        ),
      ),
      focusColor: QuietVaultColors.focusRing,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(minTouchTarget, minTouchTarget),
          backgroundColor: QuietVaultColors.primary,
          foregroundColor: QuietVaultColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(minTouchTarget, minTouchTarget),
          foregroundColor: QuietVaultColors.primary,
          side: const BorderSide(color: QuietVaultColors.primary, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: QuietVaultColors.darkPrimary,
      scaffoldBackgroundColor: QuietVaultColors.darkSurface,
      colorScheme: const ColorScheme.dark(
        primary: QuietVaultColors.darkPrimary,
        onPrimary: QuietVaultColors.darkSurface,
        surface: QuietVaultColors.darkSurface,
        onSurface: QuietVaultColors.darkInk,
        surfaceContainerHighest: QuietVaultColors.darkSurfaceAlt,
        error: QuietVaultColors.danger,
        onError: QuietVaultColors.darkInk,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 34,
          height: 40 / 34,
          fontWeight: FontWeight.w600,
          color: QuietVaultColors.darkInk,
        ),
        titleLarge: TextStyle(
          fontSize: 24,
          height: 32 / 24,
          fontWeight: FontWeight.w600,
          color: QuietVaultColors.darkInk,
        ),
        bodyLarge: TextStyle(
          fontSize: 18,
          height: 28 / 18,
          fontWeight: FontWeight.w400,
          color: QuietVaultColors.darkInk,
        ),
        bodyMedium: TextStyle(
          fontSize: 18,
          height: 28 / 18,
          fontWeight: FontWeight.w400,
          color: QuietVaultColors.darkInkSecondary,
        ),
        bodySmall: TextStyle(
          fontSize: 14,
          height: 20 / 14,
          fontWeight: FontWeight.w400,
          color: QuietVaultColors.darkInkSecondary,
        ),
      ),
      focusColor: QuietVaultColors.focusRing,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(minTouchTarget, minTouchTarget),
          backgroundColor: QuietVaultColors.darkPrimary,
          foregroundColor: QuietVaultColors.darkSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
