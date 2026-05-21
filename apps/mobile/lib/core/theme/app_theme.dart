import 'package:flutter/material.dart';

const Color _primaryBlue = Color(0xFF2EA8FF);
const Color _accentSky = Color(0xFF8AD8FF);
const Color _pearlBackground = Color(0xFFF6F7FB);
const Color _surface = Color(0xFFFFFFFF);
const Color _surfaceSoft = Color(0xFFF0F3FA);
const Color _surfaceGlass = Color(0xCCFFFFFF);
const Color _outline = Color(0x1A0D1B2A);
const Color _textPrimary = Color(0xFF0D1B2A);
const Color _textSecondary = Color(0xFF5E6B7F);

final ThemeData vibeloopTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  fontFamily: 'SF Pro Display',
  colorScheme: const ColorScheme.light(
    primary: _primaryBlue,
    secondary: _accentSky,
    tertiary: _accentSky,
    surface: _surface,
    onPrimary: Colors.white,
    onSecondary: _textPrimary,
    onTertiary: _textPrimary,
    onSurface: _textPrimary,
    onSurfaceVariant: _textSecondary,
    outline: _outline,
  ),
  scaffoldBackgroundColor: _pearlBackground,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: _textPrimary,
    elevation: 0,
    centerTitle: true,
    toolbarHeight: 56,
    surfaceTintColor: Colors.transparent,
    titleTextStyle: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: _textPrimary,
      letterSpacing: -0.2,
    ),
  ),
  cardTheme: CardThemeData(
    color: _surfaceGlass,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(28),
      side: const BorderSide(color: _outline, width: 0.7),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: _surfaceSoft,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: const BorderSide(color: _outline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: _primaryBlue,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(54),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: _primaryBlue,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(54),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: _primaryBlue,
      side: const BorderSide(color: _accentSky, width: 1.2),
      minimumSize: const Size.fromHeight(54),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: _accentSky,
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
  chipTheme: ChipThemeData(
    backgroundColor: _surfaceSoft,
    selectedColor: _primaryBlue,
    disabledColor: _surface,
    labelStyle: const TextStyle(color: _textPrimary),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    side: BorderSide.none,
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: _surface,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: _surface,
    contentTextStyle: const TextStyle(color: _textPrimary),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    behavior: SnackBarBehavior.floating,
  ),
);
