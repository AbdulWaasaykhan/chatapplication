import 'package:flutter/material.dart';

ThemeData lightMode = ThemeData(
  brightness: Brightness.light,
  colorScheme: ColorScheme.light(
    primary: Color(0xFF4A90E2),      // blue for buttons, highlights
    onPrimary: Colors.white,         // text/icons on primary
    secondary: Color(0xFF50E3C2),    // teal for accents
    onSecondary: Colors.white,
    surface: Colors.white,           // scaffold and card backgrounds
    onSurface: Colors.black,         // text/icons on surfaces
    background: Color(0xFFF5F5F5),   // page background
    onBackground: Colors.black,
    error: Color(0xFFE53935),        // error messages
    onError: Colors.white,
  ),
  scaffoldBackgroundColor: Color(0xFFF5F5F5),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFFFFFFFF),
    foregroundColor: Colors.black,
    elevation: 0,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: Color(0xFF4A90E2),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Colors.black),
    bodyMedium: TextStyle(color: Colors.black87),
  ),
);
