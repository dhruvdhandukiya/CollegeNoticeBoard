import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Brand Colors ──────────────────────────────────────────────────────────
  static const Color primary     = Color(0xFF1A237E);
  static const Color primaryLight= Color(0xFF283593);
  static const Color accent      = Color(0xFFFF6F00);
  static const Color surface     = Color(0xFFF4F6FF);
  static const Color success     = Color(0xFF00695C);
  static const Color danger      = Color(0xFFC62828);
  static const Color purple      = Color(0xFF512DA8);
  static const Color textDark    = Color(0xFF1C1C1C);
  static const Color textMuted   = Color(0xFF78909C);

  // ── Dept Colors ───────────────────────────────────────────────────────────
  static Color deptColor(String dept) {
    switch (dept) {
      case 'IT':       return const Color(0xFF1565C0);
      case 'CS':       return const Color(0xFF00695C);
      case 'AIDS':     return const Color(0xFF6A1B9A);
      case 'EXTC':     return const Color(0xFFAD1457);
      case 'MECH':     return const Color(0xFFBF360C);
      case 'CHEMICAL': return const Color(0xFF4E342E);
      default:         return primary;
    }
  }

  static String deptFullName(String dept) {
    switch (dept) {
      case 'IT':       return 'Information Technology';
      case 'CS':       return 'Computer Science';
      case 'AIDS':     return 'AI & Data Science';
      case 'EXTC':     return 'Electronics & Telecomm.';
      case 'MECH':     return 'Mechanical Engineering';
      case 'CHEMICAL': return 'Chemical Engineering';
      default:         return dept;
    }
  }

  // ── Year Colors ───────────────────────────────────────────────────────────
  static Color yearColor(String year) {
    switch (year) {
      case 'FE': return const Color(0xFF00897B);
      case 'SE': return const Color(0xFF1565C0);
      case 'TE': return const Color(0xFFF57C00);
      case 'BE': return const Color(0xFF6A1B9A);
      default:   return primary;
    }
  }

  // ── Theme ─────────────────────────────────────────────────────────────────
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: primary),
    scaffoldBackgroundColor: surface,
    fontFamily: GoogleFonts.dmSans().fontFamily,
    appBarTheme: AppBarTheme(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.plusJakartaSans(
        fontSize: 18, 
        fontWeight: FontWeight.w700, 
        color: Colors.white
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)
        ),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w700, 
          fontSize: 15
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16, 
        vertical: 14
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDDE3F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDDE3F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: danger),
      ),
    ),
      cardTheme: CardThemeData(  // ✅ Changed from CardTheme to CardThemeData
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFECEFF9)), 
      ),
    ),
      );

  // ── Text Styles ───────────────────────────────────────────────────────────
  static TextStyle get heading1 => GoogleFonts.plusJakartaSans(
    fontSize: 24, 
    fontWeight: FontWeight.w800, 
    color: textDark
  );
  
  static TextStyle get heading2 => GoogleFonts.plusJakartaSans(
    fontSize: 18, 
    fontWeight: FontWeight.w700, 
    color: textDark
  );
  
  static TextStyle get heading3 => GoogleFonts.plusJakartaSans(
    fontSize: 14, 
    fontWeight: FontWeight.w700, 
    color: textDark
  );
  
  static TextStyle get body => TextStyle(
    fontSize: 14, 
    color: textDark, 
    height: 1.5
  );
  
  static TextStyle get bodyMuted => TextStyle(
    fontSize: 13, 
    color: textMuted, 
    height: 1.4
  );
  
  static TextStyle get label => const TextStyle(
    fontSize: 11, 
    fontWeight: FontWeight.w700, 
    letterSpacing: 0.3
  );
}