import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── DARK palette (WhatsApp dark) ─────────────────────────────────────────
  static const Color background     = Color(0xFF0B141A);
  static const Color surface        = Color(0xFF1F2C34);
  static const Color surfaceAlt     = Color(0xFF182229);
  static const Color inputBg        = Color(0xFF2A3942);
  static const Color border         = Color(0xFF2A3942);
  static const Color borderLight    = Color(0xFF3B4A54);

  // ── LIGHT palette ────────────────────────────────────────────────────────
  static const Color lightBackground  = Color(0xFFF0F2F5);
  static const Color lightSurface     = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt  = Color(0xFFEFEFEF);
  static const Color lightInputBg     = Color(0xFFF7F7F7);
  static const Color lightBorder      = Color(0xFFE0E0E0);

  // ── shared ───────────────────────────────────────────────────────────────
  static const Color accent         = Color(0xFF00A884);
  static const Color accentLight    = Color(0xFF25D366);
  static const Color accentDark     = Color(0xFF005C4B);

  static const Color bubbleMe       = Color(0xFF005C4B);
  static const Color bubbleMeLight  = Color(0xFFD9FDD3);
  static const Color bubbleOther    = Color(0xFF1F2C34);
  static const Color bubbleOtherLight = Color(0xFFFFFFFF);

  static const Color textPrimary    = Color(0xFFE9EDEF);
  static const Color textSecondary  = Color(0xFF8696A0);
  static const Color textMuted      = Color(0xFF667781);

  static const Color lightTextPrimary   = Color(0xFF111B21);
  static const Color lightTextSecondary = Color(0xFF667781);
  static const Color lightTextMuted     = Color(0xFFADB5BD);

  static const Color online         = Color(0xFF00A884);
  static const Color danger         = Color(0xFFFF2D55);
  static const Color unread         = Color(0xFF00A884);
  static const Color mentionBg      = Color(0xFF1C3829);
  static const Color mentionText    = Color(0xFF25D366);

  // ── DARK theme ───────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        surface: surface,
        primary: accent,
        secondary: accentLight,
        error: danger,
      ),
      textTheme: GoogleFonts.notoSansTextTheme(
        ThemeData.dark().textTheme.apply(
          bodyColor: textPrimary,
          displayColor: textPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          textStyle: GoogleFonts.notoSans(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      dividerColor: border,
      useMaterial3: true,
    );
  }

  // ── LIGHT theme ──────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: const ColorScheme.light(
        surface: lightSurface,
        primary: accent,
        secondary: accentLight,
        error: danger,
      ),
      textTheme: GoogleFonts.notoSansTextTheme(
        ThemeData.light().textTheme.apply(
          bodyColor: lightTextPrimary,
          displayColor: lightTextPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightInputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: lightTextMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          textStyle: GoogleFonts.notoSans(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      dividerColor: lightBorder,
      useMaterial3: true,
    );
  }

  // ── helpers: theme-aware colors ──────────────────────────────────────────
  static Color bgColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? background : lightBackground;

  static Color surfaceColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? surface : lightSurface;

  static Color surfaceAltColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? surfaceAlt : lightSurfaceAlt;

  static Color inputBgColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? inputBg : lightInputBg;

  static Color primaryText(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? textPrimary : lightTextPrimary;

  static Color secondaryText(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? textSecondary : lightTextSecondary;

  static Color borderColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? border : lightBorder;

  static Color bubbleMeColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? bubbleMe : bubbleMeLight;

  static Color bubbleOtherColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? bubbleOther : bubbleOtherLight;

  static Color bubbleMeTextColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFE9EDEF)
          : const Color(0xFF111B21);

  static Color bubbleOtherTextColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFE9EDEF)
          : const Color(0xFF111B21);
}
