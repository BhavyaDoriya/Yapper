import 'package:flutter/material.dart';

class AppTheme {
  // Matte Black & Gold Palette
  static const Color _matteBlack = Color(0xFF121212); // Deep graphite, not harsh black
  static const Color _darkSurface = Color(0xFF1E1E1E); // Slightly lighter for cards
  static const Color _matteGold = Color(0xFFD4AF37); // Classic luxury gold
  static const Color _offWhite = Color(0xFFE0E0E0); // Softer on the eyes than pure white

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: _matteBlack,
    colorScheme: const ColorScheme.dark(
      surface: _darkSurface,
      primary: _matteGold,
      onPrimary: _matteBlack, // Black text on gold buttons
      secondary: _darkSurface,
      onSurface: _offWhite,
    ),
    textTheme: const TextTheme(
      displaySmall: TextStyle(color: _matteGold, fontWeight: FontWeight.bold),
      bodyMedium: TextStyle(color: _offWhite),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: _matteBlack,
      foregroundColor: _matteGold,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: const CardTheme(
      color: _darkSurface,
      elevation: 0, // 0 elevation = Matte/Flat finish
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(28)),
        side: BorderSide(color: _matteGold, width: 1.0), // Thin gold border
      ),
    ),
  );
}