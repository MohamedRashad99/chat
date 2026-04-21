import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // WhatsApp dark palette
  static const Color background     = Color(0xFF0B141A); // main bg
  static const Color surface        = Color(0xFF1F2C34); // panels
  static const Color surfaceAlt     = Color(0xFF182229); // sidebar bg
  static const Color cardBg         = Color(0xFF1F2C34); // cards
  static const Color inputBg        = Color(0xFF2A3942); // input fields
  static const Color border         = Color(0xFF2A3942);
  static const Color borderLight    = Color(0xFF3B4A54);

  static const Color accent         = Color(0xFF00A884); // WA green
  static const Color accentLight    = Color(0xFF25D366); // bright green
  static const Color accentDark     = Color(0xFF005C4B); // dark green (my bubbles)
  static const Color accentSoft     = Color(0xFF1C3829); // very soft green

  static const Color bubbleMe       = Color(0xFF005C4B); // my message bubble
  static const Color bubbleOther    = Color(0xFF1F2C34); // other message bubble
  static const Color bubbleMeText   = Color(0xFFE9EDEF);
  static const Color bubbleOtherText= Color(0xFFE9EDEF);

  static const Color textPrimary    = Color(0xFFE9EDEF);
  static const Color textSecondary  = Color(0xFF8696A0);
  static const Color textMuted      = Color(0xFF667781);
  static const Color textLink       = Color(0xFF53BDEB);

  static const Color online         = Color(0xFF00A884);
  static const Color danger         = Color(0xFFFF2D55);
  static const Color unread         = Color(0xFF00A884);

  static const Color mentionBg      = Color(0xFF1C3829);
  static const Color mentionText    = Color(0xFF25D366);

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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
          textStyle: GoogleFonts.notoSans(
            fontSize: 15, fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dividerColor: border,
      useMaterial3: true,
    );
  }
}
