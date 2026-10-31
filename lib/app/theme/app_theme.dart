import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Authoritative Brand Tokens (matching Web SaaS Slate & Blue design system)
  static const Color primary      = Color(0xFF2563EB); // Tailwind blue-600
  static const Color primaryDark  = Color(0xFF1D4ED8); // Tailwind blue-700
  static const Color background   = Color(0xFFF8FAFC); // Slate 50
  static const Color surface      = Color(0xFFFFFFFF); // Clean Card White
  static const Color border       = Color(0xFFE2E8F0); // Slate 200
  static const Color textMain     = Color(0xFF0F172A); // Slate 900
  static const Color textMuted    = Color(0xFF64748B); // Slate 500
  static const Color success      = Color(0xFF10B981); // Emerald 500
  static const Color danger       = Color(0xFFEF4444); // Rose 500

  // Scanner Viewfinder Reticle
  static const Color reticleGreen = Color(0xFF00E676);

  // Backward-compatibility aliases
  static const Color secondary    = primaryDark;
  static const Color tertiary     = Color(0xFFF97316); // Vibrant Orange CTA
  static const Color error        = danger;
  static const Color textDark     = textMain;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: primaryDark,
        tertiary: tertiary,
        surface: surface,
        error: danger,
        onSurface: textMain,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme().apply(
        bodyColor: textMain,
        displayColor: textMain,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textMain,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textMain),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0, // Flat design: No elevation shadows
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
    );
  }
}
