import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Mool (मूल) Design System
/// Perfectly aligned with the Mool Web Portal:
/// - Linen: warm organic paper canvas (#F6F3EC)
/// - Moss: grounding forest and leaf tones (#5F7A5E)
/// - Dusk: calming evening blue-slate (#2E4452)
/// - Sandrose: warm clay and terracotta (#C98B76)
/// - Ink: natural deep charcoal typography (#2B2B28)
/// - Signal: rich brick red reserved for emergency alerts (#B3543F)
class MoolPalette {
  // Brand Moss - matching web site
  static const moss = Color(0xFF5F7A5E);
  static const mossLight = Color(0xFF728F71);
  static const mossDark = Color(0xFF4B624A);
  static const mossSoft = Color(0xFFEAF0E9);

  // Natural Linen Canvas - matching web site
  static const linen = Color(0xFFF6F3EC);
  static const mist = Color(0xFFE4E0D5);
  static const mistLight = Color(0xFFEFECE4);
  static const mistDark = Color(0xFFD5CFBF);

  // Ink & Typography - matching web site
  static const ink = Color(0xFF2B2B28);
  static const slate = Color(0xFF595952); // ink-muted
  static const inkFaint = Color(0xFF8C8C83);

  // Dusk - matching web site
  static const dusk = Color(0xFF2E4452);
  static const duskLight = Color(0xFF3C5668);
  static const duskDark = Color(0xFF1F303B);
  static const duskSoft = Color(0xFFE7ECF0);

  // Sandrose / Terracotta - matching web site
  static const sandrose = Color(0xFFC98B76);
  static const sandroseLight = Color(0xFFDDA28F);
  static const sandroseSoft = Color(0xFFF8EFEA);

  // Signal / Emergency - matching web site
  static const signal = Color(0xFFB3543F);
  static const ember = Color(0xFFB3543F); // alias for backward-compatibility
  static const signalSoft = Color(0xFFF9ECE9);

  // Dark mode surfaces
  static const night = Color(0xFF1B1D1B);
  static const nightSurface = Color(0xFF232622);
  static const nightRaised = Color(0xFF2D302B);

  // Backward-compatibility aliases
  static const sage = mossLight;
  static const sageMist = mossSoft;
}

class MoolTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: MoolPalette.moss,
      brightness: Brightness.light,
    ).copyWith(
      primary: MoolPalette.moss,
      onPrimary: Colors.white,
      primaryContainer: MoolPalette.mossSoft,
      onPrimaryContainer: MoolPalette.mossDark,
      secondary: MoolPalette.sandrose,
      onSecondary: Colors.white,
      secondaryContainer: MoolPalette.sandroseSoft,
      onSecondaryContainer: MoolPalette.ink,
      tertiary: MoolPalette.dusk,
      onTertiary: Colors.white,
      tertiaryContainer: MoolPalette.duskSoft,
      onTertiaryContainer: MoolPalette.duskDark,
      error: MoolPalette.signal,
      onError: Colors.white,
      surface: Colors.white,
      onSurface: MoolPalette.ink,
      onSurfaceVariant: MoolPalette.slate,
      outline: MoolPalette.mistDark,
      outlineVariant: MoolPalette.mist,
    );
    return _base(scheme, MoolPalette.linen);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: MoolPalette.moss,
      brightness: Brightness.dark,
    ).copyWith(
      primary: MoolPalette.mossLight,
      onPrimary: MoolPalette.night,
      primaryContainer: MoolPalette.nightRaised,
      onPrimaryContainer: MoolPalette.mossLight,
      secondary: MoolPalette.sandroseLight,
      onSecondary: MoolPalette.night,
      secondaryContainer: MoolPalette.nightRaised,
      tertiary: MoolPalette.duskLight,
      error: const Color(0xFFF2B8B5),
      surface: MoolPalette.nightSurface,
      onSurface: const Color(0xFFEBE7DE),
      onSurfaceVariant: const Color(0xFFA5ABA3),
      outline: const Color(0xFF3E423B),
      outlineVariant: const Color(0xFF2E322D),
    );
    return _base(scheme, MoolPalette.night);
  }

  static ThemeData _base(ColorScheme scheme, Color canvas) {
    final ink = scheme.onSurface;
    final isDark = scheme.brightness == Brightness.dark;

    final text = TextTheme(
      headlineLarge: GoogleFonts.inter(
        fontSize: 32,
        height: 1.2,
        fontWeight: FontWeight.w800,
        color: ink,
        letterSpacing: -0.7,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 26,
        height: 1.25,
        fontWeight: FontWeight.w800,
        color: ink,
        letterSpacing: -0.5,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 22,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: ink,
        letterSpacing: -0.4,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 19,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: ink,
        letterSpacing: -0.3,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: ink,
        letterSpacing: -0.2,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14.5,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 15.5,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: ink,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: ink,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12.5,
        height: 1.4,
        fontWeight: FontWeight.w400,
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: GoogleFonts.inter().fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: ink,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? const Color(0xFF3E433C) : const Color(0xFFCDC6B8),
            width: 1.3,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: MoolPalette.moss,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(64, 52),
          side: BorderSide(color: isDark ? const Color(0xFF3E423B) : MoolPalette.mistDark),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(48, 48),
          textStyle: text.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: MoolPalette.moss, width: 2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? MoolPalette.nightSurface : Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: isDark ? MoolPalette.nightRaised : MoolPalette.mossSoft,
        height: 68,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: isDark ? MoolPalette.mossLight : MoolPalette.moss);
          }
          return IconThemeData(color: scheme.onSurfaceVariant);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              color: isDark ? MoolPalette.mossLight : MoolPalette.moss,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            );
          }
          return GoogleFonts.inter(
            color: scheme.onSurfaceVariant,
            fontSize: 12,
          );
        }),
      ),
      listTileTheme: const ListTileThemeData(minVerticalPadding: 12),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
