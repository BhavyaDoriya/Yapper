import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Pure Expedition 33 Colors
  static const Color _voidBlack = Color(0xFF070709); 
  static const Color _dustyGrey = Color(0xFF8A8A93); 
  static const Color _brightGlow = Color(0xFFE2E2E5); 
  static const Color _wireframe = Color(0xFF2A2A30); 

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    
    // FIX 1: Restores the dark background for your Dashboard/Hub
    scaffoldBackgroundColor: _voidBlack, 
    
    colorScheme: const ColorScheme.dark(
      surface: Colors.transparent,
      primary: _brightGlow, 
      onPrimary: _voidBlack, 
      secondary: _wireframe,
      onSurface: _brightGlow,
    ),
    
    textTheme: GoogleFonts.cormorantGaramondTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    ).copyWith(
      bodyMedium: GoogleFonts.cormorantGaramond(color: _brightGlow, fontSize: 18, fontWeight: FontWeight.w600),
      bodyLarge: GoogleFonts.cormorantGaramond(color: _brightGlow, fontSize: 20, fontWeight: FontWeight.bold),
    ),
    
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: _brightGlow,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.cinzel(color: _brightGlow, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 4.0),
    ),

    inputDecorationTheme: const InputDecorationTheme(
      filled: false,
      floatingLabelBehavior: FloatingLabelBehavior.always, 
      labelStyle: TextStyle(color: _dustyGrey, fontWeight: FontWeight.w600, letterSpacing: 2.0),
      isDense: true,
      contentPadding: EdgeInsets.symmetric(vertical: 8),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: _wireframe, width: 1.0),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: _brightGlow, width: 1.5),
      ),
    ),

    // FIX 2: Custom HUD Notification for the SnackBar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF161413), // Warm dark charcoal 
      contentTextStyle: GoogleFonts.cinzel(color: _brightGlow, fontWeight: FontWeight.bold, letterSpacing: 2.0),
      behavior: SnackBarBehavior.floating, // Floats above the bottom edge
      shape: const BeveledRectangleBorder(
        side: BorderSide(color: _wireframe, width: 1.5), // Sharp game border
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ),
  );
}