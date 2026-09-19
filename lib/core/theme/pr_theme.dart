import 'package:flutter/material.dart';

abstract final class PrColors {
  // Pink + White
  static const Color pinkPrimary = Color(0xFFFF3F83);
  static const Color pinkSecondary = Color(0xFFFF8EB4);
  static const Color pinkSoft = Color(0xFFFFE4EF);

  static const Color pearlWhite = Color(0xFFFFFBFD);
  static const Color warmWhite = Color(0xFFFFF5F9);

  static const Color lightText = Color(0xFF21141A);
  static const Color lightMuted = Color(0xFF78616B);

  // Black + Gold
  static const Color goldPrimary = Color(0xFFDDBB58);
  static const Color goldBright = Color(0xFFF6DA81);
  static const Color goldDeep = Color(0xFF9A7221);

  static const Color obsidian = Color(0xFF080809);
  static const Color carbon = Color(0xFF101012);
  static const Color graphite = Color(0xFF18181B);

  static const Color darkText = Color(0xFFFFF9E9);
  static const Color darkMuted = Color(0xFFB9B09C);
}

abstract final class PrTheme {
  static ThemeData pinkWhite() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: PrColors.pinkPrimary,
      onPrimary: Colors.white,
      secondary: PrColors.pinkSecondary,
      onSecondary: PrColors.lightText,
      error: Color(0xFFD92D20),
      onError: Colors.white,
      surface: Colors.white,
      onSurface: PrColors.lightText,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: PrColors.pearlWhite,
      splashColor: PrColors.pinkPrimary.withAlpha(22),
      highlightColor: PrColors.pinkPrimary.withAlpha(12),
      dividerColor: PrColors.pinkPrimary.withAlpha(20),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withAlpha(235),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: PrColors.pinkPrimary.withAlpha(28)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: PrColors.pinkPrimary.withAlpha(28)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: PrColors.pinkPrimary, width: 1.5),
        ),
      ),
    );
  }

  static ThemeData blackGold() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: PrColors.goldPrimary,
      onPrimary: PrColors.obsidian,
      secondary: PrColors.goldBright,
      onSecondary: PrColors.obsidian,
      error: Color(0xFFFF625F),
      onError: Colors.black,
      surface: PrColors.carbon,
      onSurface: PrColors.darkText,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: PrColors.obsidian,
      splashColor: PrColors.goldPrimary.withAlpha(25),
      highlightColor: PrColors.goldPrimary.withAlpha(14),
      dividerColor: PrColors.goldPrimary.withAlpha(25),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PrColors.graphite.withAlpha(235),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: PrColors.goldPrimary.withAlpha(45)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: PrColors.goldPrimary.withAlpha(45)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: PrColors.goldPrimary, width: 1.5),
        ),
      ),
    );
  }

  static bool isBlackGold(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static Color accent(BuildContext context) {
    return isBlackGold(context) ? PrColors.goldPrimary : PrColors.pinkPrimary;
  }

  static Color secondaryAccent(BuildContext context) {
    return isBlackGold(context) ? PrColors.goldBright : PrColors.pinkSecondary;
  }
}
