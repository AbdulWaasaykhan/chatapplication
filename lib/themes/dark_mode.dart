import 'package:flutter/material.dart';

ThemeData darkMode = ThemeData(
  brightness: Brightness.dark,
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFFFFFFFF),      // a lighter, desaturated purple for readability
    onPrimary: Colors.black,         // text on top of the primary color
    secondary: Color(0xFF65F420),    // a brighter amber for accents in dark mode
    onSecondary: Colors.black,       // text on top of the secondary color
    surface: Color(0xFF1E1E1E),      // cards and dialogs (slightly lighter than background)
    onSurface: Color(0xFFE6E1E5),    // main text color (off-white)
    background: Color(0xFF121212),   // deep dark gray for the page background
    onBackground: Color(0xFFE6E1E5), // text on the page background
    error: Color(0xFFCF6679),        // standard dark theme error color
    onError: Colors.black,
  ),
  scaffoldBackgroundColor: const Color(0xFF121212),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF121212), // match scaffold background
    foregroundColor: Color(0xFFE6E1E5),  // light text
    elevation: 0,
    scrolledUnderElevation: 0.5,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF1E1E1E),
    hintStyle: TextStyle(color: Colors.grey[600]),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF536FA6), // use primary color
      foregroundColor: Colors.black,           // use onPrimary color
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Color(0xFFE6E1E5)),
    bodyMedium: TextStyle(color: Color(0xFFCAC4D0)), // slightly darker white for secondary text
  ),
);