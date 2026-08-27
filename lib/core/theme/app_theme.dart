import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const primary = Color(0xFF8B5CF6);
  static const background = Color(0xFFFAF9FC);
  static const surface = Color(0xFFFFFFFF);
  static const success = Color(0xFF22A06B);
  static const danger = Color(0xFFDC4C64);
  static const warning = Color(0xFFF59E0B);

  static const darkBackground = Color(0xFF121116);
  static const darkSurface = Color(0xFF1E1C24);
  static const darkBorder = Color(0xFF3A3742);

  /// Vertical gap between consecutive cards in a list (Calendar, Queue,
  /// Customers, Payments, CRM, Staff, …). cardTheme below sets `margin:
  /// EdgeInsets.zero` deliberately (cards inside dialogs/detail views
  /// shouldn't carry list spacing baked in), so list screens are
  /// responsible for adding this themselves between rows — matches the
  /// spacing SkeletonList and staff_today_page.dart's ListView.separated
  /// already use for their own rows.
  static const listItemSpacing = 12.0;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
    ).copyWith(primary: primary, surface: surface, error: danger);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      // Inter for Latin script; Arabic-script glyphs (no coverage in Inter)
      // automatically fall back to Noto Sans Arabic per the spec's
      // typography requirement (slide 10).
      fontFamily: GoogleFonts.inter().fontFamily,
      fontFamilyFallback: [GoogleFonts.notoSansArabic().fontFamily!],
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE8E5EF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(height: 72),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    ).copyWith(primary: primary, surface: darkSurface, error: danger);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: darkBackground,
      fontFamily: GoogleFonts.inter().fontFamily,
      fontFamilyFallback: [GoogleFonts.notoSansArabic().fontFamily!],
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: darkBackground,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(height: 72),
    );
  }
}
