import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// KASHFLIP design system — "Neon Glass"
/// Deep-black surfaces, neon-lime hero accents, soft glass cards,
/// pill geometry and calm typography. Inspired by Revolut <18.
class AppTheme {
  // ── Core palette ────────────────────────────────────────────────
  /// Neon lime — the signature accent.
  static const Color primaryColor = Color(0xFFD7F53C);
  static const Color secondaryColor = Color(0xFF17181B);
  static const Color accentColor = Color(0xFFD7F53C);

  /// Softer lime tint used for gradients / glows.
  static const Color limeSoft = Color(0xFFE9FF7A);
  static const Color limeDeep = Color(0xFFB8D62B);

  // ── Backgrounds ────────────────────────────────────────────────
  static const Color darkBackground = Color(0xFF0A0A0C);
  static const Color cardDarkBackground = Color(0xFF141417);
  static const Color cardLightBackground = Color(0xFF1E1F24);
  static const Color glassStroke = Color(0x14FFFFFF); // 8% white hairline

  // ── Text ───────────────────────────────────────────────────────
  static const Color textWhite = Color(0xFFF7F7F5);
  static const Color textGrey = Color(0xFF8A8F98);
  static const Color textLightGrey = Color(0xFFC2C6CE);

  /// Ink used on top of lime surfaces.
  static const Color onLime = Color(0xFF0D0F04);

  // ── Signals ────────────────────────────────────────────────────
  static const Color priceUp = Color(0xFF35D07F);
  static const Color priceDown = Color(0xFFFF5C5C);

  // ── Charts ─────────────────────────────────────────────────────
  static const Color chartLine = Color(0xFFD7F53C);
  static const Color chartGradientStart = Color(0x55D7F53C);
  static const Color chartGradientEnd = Color(0x00D7F53C);

  // ── Geometry ───────────────────────────────────────────────────
  static const double rCard = 24;
  static const double rHero = 28;
  static const double rPill = 100;
  static const double rInput = 16;

  /// Neon hero surface (balance / feature cards).
  static BoxDecoration heroCard = BoxDecoration(
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [limeSoft, primaryColor, limeDeep],
    ),
    borderRadius: BorderRadius.circular(rHero),
    boxShadow: [
      BoxShadow(
        color: primaryColor.withOpacity(0.25),
        blurRadius: 40,
        offset: const Offset(0, 12),
      ),
    ],
  );

  /// Soft glass tile used for lists, sheets and secondary cards.
  static BoxDecoration glassCard = BoxDecoration(
    color: const Color(0xFF141417),
    borderRadius: BorderRadius.circular(rCard),
    border: Border.all(color: glassStroke),
  );

  // ── Theme ──────────────────────────────────────────────────────
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: darkBackground,
    splashFactory: InkSparkle.splashFactory,
    highlightColor: Colors.white.withOpacity(0.04),
    splashColor: primaryColor.withOpacity(0.10),
    colorScheme: const ColorScheme.dark(
      primary: primaryColor,
      onPrimary: onLime,
      secondary: secondaryColor,
      surface: cardDarkBackground,
    ),
    textTheme: GoogleFonts.interTextTheme(
      ThemeData.dark().textTheme.copyWith(
        // Large numerals — tight, confident, slightly compressed.
        displayLarge: GoogleFonts.spaceGrotesk(
          color: textWhite,
          fontSize: 40,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.2,
          height: 1.05,
        ),
        displayMedium: GoogleFonts.spaceGrotesk(
          color: textWhite,
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
        ),
        displaySmall: GoogleFonts.spaceGrotesk(
          color: textWhite,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        headlineMedium: const TextStyle(
          color: textWhite,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        headlineSmall: const TextStyle(
          color: textWhite,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        titleLarge: const TextStyle(
          color: textWhite,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        bodyLarge: const TextStyle(
          color: textWhite,
          fontSize: 16,
          letterSpacing: -0.1,
        ),
        bodyMedium: const TextStyle(
          color: textLightGrey,
          fontSize: 14,
          letterSpacing: -0.1,
        ),
        labelLarge: const TextStyle(
          color: textWhite,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: textWhite,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
      iconTheme: IconThemeData(color: textWhite, size: 22),
    ),
    cardTheme: CardThemeData(
      color: cardDarkBackground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(rCard),
        side: const BorderSide(color: glassStroke),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: onLime,
      unselectedLabelColor: textGrey,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      indicator: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(rPill),
      ),
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xF20E0E10),
      selectedItemColor: primaryColor,
      unselectedItemColor: textGrey,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      fillColor: cardLightBackground,
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(rInput),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(rInput),
        borderSide: const BorderSide(color: glassStroke),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(rInput),
        borderSide: const BorderSide(color: primaryColor, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      hintStyle: const TextStyle(color: textGrey),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: onLime,
        disabledBackgroundColor: cardLightBackground,
        disabledForegroundColor: textGrey,
        minimumSize: const Size(double.infinity, 56),
        elevation: 0,
        shadowColor: Colors.transparent,
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rPill),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryColor,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: textWhite,
        side: const BorderSide(color: Color(0x29FFFFFF)),
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rPill),
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0x14FFFFFF),
      thickness: 1,
      space: 1,
    ),
  );
}
