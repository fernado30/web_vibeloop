import 'package:flutter/material.dart';

const Color _primaryPurple = Color(0xFF7C3AED);
const Color _accentViolet = Color(0xFFA78BFA);
const Color _background = Color(0xFF0F0F0F);
const Color _surface = Color(0xFF1A1A1A);

final ThemeData vibeloopDarkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: const ColorScheme.dark(
    primary: _primaryPurple,
    secondary: _accentViolet,
    surface: _surface,
    onPrimary: Colors.white,
    onSecondary: Colors.black,
    onSurface: Colors.white,
  ),
  scaffoldBackgroundColor: _background,
  appBarTheme: const AppBarTheme(
    backgroundColor: _background,
    foregroundColor: Colors.white,
    elevation: 0,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: _surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Colors.white12),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: _accentViolet, width: 1.5),
    ),
  ),
  textTheme: const TextTheme(
    displayLarge: TextStyle(fontSize: 57, fontWeight: FontWeight.w700, height: 1.05),
    displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.w700, height: 1.05),
    displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, height: 1.1),
    headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, height: 1.15),
    headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, height: 1.15),
    headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, height: 1.2),
    titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.25),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.25),
    titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.25),
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.45),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.45),
    bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 1.35),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.2),
    labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.2),
    labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, height: 1.2),
  ),
);
