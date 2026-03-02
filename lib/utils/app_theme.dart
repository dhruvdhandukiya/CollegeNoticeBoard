// lib/utils/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Color Palette ──────────────────────────────────────────────────────────
  static const Color primary     = Color(0xFF1A237E); // Deep navy blue
  static const Color accent      = Color(0xFFFF6F00); // Vivid amber
  static const Color surface     = Color(0xFFF5F7FF);
  static const Color cardBg      = Color(0xFFFFFFFF);
  static const Color textDark    = Color(0xFF0D1B2A);
  static const Color textMuted   = Color(0xFF6B7A99);
  static const Color success     = Color(0xFF00C853);
  static const Color danger      = Color(0xFFD50000);
  static const Color warning     = Color(0xFFFFAB00);
  static const Color important   = Color(0xFFE53935);

  // Department Colors
  static const Color colorIT     = Color(0xFF1565C0);
  static const Color colorCS     = Color(0xFF00695C);
  static const Color colorEXTC   = Color(0xFF6A1B9A);
  static const Color colorMECH   = Color(0xFFBF360C);

  // ── Text Styles ────────────────────────────────────────────────────────────
  static TextStyle get heading1 => GoogleFonts.plusJakartaSans(
    fontSize: 28, fontWeight: FontWeight.w800, color: textDark,
  );

  static TextStyle get heading2 => GoogleFonts.plusJakartaSans(
    fontSize: 22, fontWeight: FontWeight.w700, color: textDark,
  );

  static TextStyle get heading3 => GoogleFonts.plusJakartaSans(
    fontSize: 16, fontWeight: FontWeight.w600, color: textDark,
  );

  static TextStyle get body => GoogleFonts.dmSans(
    fontSize: 14, fontWeight: FontWeight.w400, color: textDark,
  );

  static TextStyle get bodyMuted => GoogleFonts.dmSans(
    fontSize: 13, fontWeight: FontWeight.w400, color: textMuted,
  );

  static TextStyle get label => GoogleFonts.dmSans(
    fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5,
  );

  // ── Theme Data ─────────────────────────────────────────────────────────────
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: primary,
      secondary: accent,
      surface: surface,
      background: surface,
    ),
    scaffoldBackgroundColor: surface,
    appBarTheme: AppBarTheme(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.plusJakartaSans(
        fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 15, fontWeight: FontWeight.w700,
        ),
        elevation: 0,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDDE3F0), width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDDE3F0), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      labelStyle: GoogleFonts.dmSans(color: textMuted, fontSize: 14),
      hintStyle: GoogleFonts.dmSans(color: Color(0xFFB0BEC5), fontSize: 14),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFECEFF9), width: 1),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
    ),
  );

  // ── Department Tag Color ────────────────────────────────────────────────────
  static Color deptColor(String dept) {
    switch (dept.toUpperCase()) {
      case 'IT':   return colorIT;
      case 'CS':   return colorCS;
      case 'EXTC': return colorEXTC;
      case 'MECH': return colorMECH;
      default:     return primary;
    }
  }

  // ── Visibility Tag Color ───────────────────────────────────────────────────
  static Color visibilityColor(String v) {
    switch (v) {
      case 'all':        return success;
      case 'department': return colorIT;
      case 'committee':  return colorEXTC;
      default:           return textMuted;
    }
  }
}