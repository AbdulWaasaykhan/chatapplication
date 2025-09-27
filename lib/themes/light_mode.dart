import 'package:flutter/material.dart';

ThemeData lightMode = ThemeData(
  brightness: Brightness.light,
  colorScheme: const ColorScheme.light(
    primary: Color(0xFF000000),      // a vibrant, deep purple for main elements
    onPrimary: Colors.white,         // text on top of the primary color
    secondary: Color(0xFFFFAB00),    // a warm amber for accents
    onSecondary: Colors.black,       // text on top of the secondary color
    surface: Color(0xFFEEEEEE),      //rR card and dialog backgrounds
    onSurface: Color(0xFF1C1B1F),    // main text color (dark gray)
    background: Color(0xFFFFFFFF),   // slightly off-white page background
    onBackground: Color(0xFF1C1B1F), // text on the page background
    error: Color(0xFFB00020),        // standard error color
    onError: Colors.white,
  ),
  scaffoldBackgroundColor: const Color(0xFFFFFFFF),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFFFFFFFF), // match scaffold background
    foregroundColor: Color(0xFF1C1B1F),  // dark text
    elevation: 0,
    scrolledUnderElevation: 0.5,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    hintStyle: TextStyle(color: Colors.grey[500]),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF000000), // use primary color
      foregroundColor: Colors.white,           // use onPrimary color
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Color(0xFF1C1B1F)),
    bodyMedium: TextStyle(color: Color(0xFF49454F)), // slightly lighter gray for secondary text
  ),
);