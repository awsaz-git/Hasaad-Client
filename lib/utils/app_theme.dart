import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors - Unified to #015E54
  static const Color primary = Color(0xFF015E54); 
  static const Color primaryLight = Color(0xFF2B8B7E);
  static const Color primaryLighter = Color(0xFFE0F2F1);
  static const Color primaryDark = Color(0xFF003D37);
  
  // Replaced bright green with brand primary for consistency
  static const Color accentGreen = Color(0xFF015E54); 
  
  static const Color backgroundColor = Color(0xFFF8F9FA);
  static const Color surfaceColor = Colors.white;
  static const Color borderColor = Color(0xFFE0E0E0);
  static const Color errorColor = Color(0xFFE57373);
  static const Color successColor = Color(0xFF015E54); // Consistent with brand

  // Spacing System
  static const double s8 = 8.0;
  static const double s12 = 12.0;
  static const double s16 = 16.0;
  static const double s20 = 20.0;
  static const double s24 = 24.0;
  static const double s32 = 32.0;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: primary,
        surface: surfaceColor,
        error: errorColor,
        brightness: Brightness.light,
      ),
      textTheme: GoogleFonts.cairoTextTheme().copyWith(
        titleLarge: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 22, color: primary),
        titleMedium: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18, color: primary),
        bodyLarge: GoogleFonts.cairo(fontWeight: FontWeight.normal, fontSize: 16),
        bodyMedium: GoogleFonts.cairo(fontWeight: FontWeight.normal, fontSize: 14),
        labelLarge: GoogleFonts.cairo(fontWeight: FontWeight.w500, fontSize: 14),
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: primary),
        titleTextStyle: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 20),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 55),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16),
          elevation: 2,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary),
          minimumSize: const Size(double.infinity, 55),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: s20, vertical: s16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: errorColor),
        ),
        labelStyle: GoogleFonts.cairo(color: primary, fontWeight: FontWeight.w500),
        hintStyle: GoogleFonts.cairo(color: Colors.grey),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFF0F0F0)),
        ),
      ),
    );
  }

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );

  static const LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Colors.white70, Colors.white30],
  );
}
