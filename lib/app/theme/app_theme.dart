import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract class AppTheme {
  static const _primaryColor = Color(0xFF6C63FF);
  static const _secondaryColor = Color(0xFF00D9A6);
  static const _errorColor = Color(0xFFFF6B6B);

  // ── Dark palette ─────────────────────────────────────────────────────
  static const _surfaceDark = Color(0xFF1E1E2E);
  static const _backgroundDark = Color(0xFF13131E);
  static const _cardDark = Color(0xFF252540);

  // ── Light palette ────────────────────────────────────────────────────
  static const _surfaceLight = Color(0xFFF5F5FA);
  static const _backgroundLight = Color(0xFFFFFFFF);
  static const _cardLight = Color(0xFFEEEEF5);

  // ═══════════════════════════════════════════════════════════════════
  //  DARK THEME
  // ═══════════════════════════════════════════════════════════════════
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.dark(
      primary: _primaryColor,
      secondary: _secondaryColor,
      error: _errorColor,
      surface: _surfaceDark,
      onSurface: Colors.white,
      outline: Colors.white.withOpacity(0.12),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _backgroundDark,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      cardTheme: CardThemeData(
        color: _cardDark,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _backgroundDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: _surfaceDark,
        selectedIconTheme: const IconThemeData(color: _primaryColor),
        unselectedIconTheme: IconThemeData(
          color: Colors.white.withOpacity(0.5),
        ),
        indicatorColor: _primaryColor.withOpacity(0.15),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _cardDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primaryColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(_cardDark),
        dataRowColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return _primaryColor.withOpacity(0.05);
          }
          return Colors.transparent;
        }),
        dividerThickness: 0.5,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _cardDark,
        contentTextStyle: GoogleFonts.inter(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbVisibility: WidgetStateProperty.all(true),
        trackVisibility: WidgetStateProperty.all(true),
        interactive: true,
        thickness: WidgetStateProperty.all(8),
        radius: const Radius.circular(10),
        thumbColor: WidgetStateProperty.all(
          _primaryColor.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  LIGHT THEME
  // ═══════════════════════════════════════════════════════════════════
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.light(
      primary: _primaryColor,
      secondary: _secondaryColor,
      error: _errorColor,
      surface: _surfaceLight,
      onSurface: const Color(0xFF1A1A2E),
      outline: const Color(0xFF1A1A2E).withOpacity(0.12),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _backgroundLight,
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
      cardTheme: CardThemeData(
        color: _cardLight,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: const Color(0xFF1A1A2E).withOpacity(0.08)),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _backgroundLight,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1A1A2E),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1A1A2E)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: _surfaceLight,
        selectedIconTheme: const IconThemeData(color: _primaryColor),
        unselectedIconTheme: IconThemeData(
          color: const Color(0xFF1A1A2E).withOpacity(0.5),
        ),
        indicatorColor: _primaryColor.withOpacity(0.12),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _cardLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: const Color(0xFF1A1A2E).withOpacity(0.1),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: const Color(0xFF1A1A2E).withOpacity(0.1),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primaryColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(_cardLight),
        dataRowColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return _primaryColor.withOpacity(0.05);
          }
          return Colors.transparent;
        }),
        dividerThickness: 0.5,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _backgroundLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _cardLight,
        contentTextStyle: GoogleFonts.inter(color: const Color(0xFF1A1A2E)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbVisibility: WidgetStateProperty.all(true),
        trackVisibility: WidgetStateProperty.all(true),
        interactive: true,
        thickness: WidgetStateProperty.all(8),
        radius: const Radius.circular(10),
        thumbColor: WidgetStateProperty.all(
          _primaryColor.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
