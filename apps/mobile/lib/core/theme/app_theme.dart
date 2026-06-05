import 'package:flutter/material.dart';

import 'vibe_tokens.dart';

final ThemeData vibeloopTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  fontFamily: 'SF Pro Display',
  colorScheme: const ColorScheme.light(
    primary: VibeColors.electricBlue,
    secondary: VibeColors.primaryViolet,
    tertiary: VibeColors.coralPink,
    surface: VibeColors.surface,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onTertiary: Colors.white,
    onSurface: VibeColors.textPrimary,
    onSurfaceVariant: VibeColors.textSecondary,
    outline: VibeColors.strokeSoft,
    error: VibeColors.dangerRed,
  ),
  scaffoldBackgroundColor: VibeColors.surfaceSoft,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: VibeColors.textPrimary,
    elevation: 0,
    centerTitle: true,
    toolbarHeight: 60,
    surfaceTintColor: Colors.transparent,
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w800,
      color: VibeColors.textPrimary,
      letterSpacing: -0.3,
    ),
  ),
  cardTheme: CardThemeData(
    color: VibeColors.glassWhite,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(VibeRadii.card),
      side: const BorderSide(color: VibeColors.strokeSoft, width: 1),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    labelStyle: const TextStyle(color: VibeColors.textSecondary, fontWeight: FontWeight.w600),
    hintStyle: const TextStyle(color: VibeColors.textSecondary),
    filled: true,
    fillColor: VibeColors.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: const BorderSide(color: VibeColors.strokeSoft),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: const BorderSide(color: VibeColors.primaryViolet, width: 1.6),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: VibeColors.electricBlue,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(56),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VibeRadii.button)),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: VibeColors.electricBlue,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(56),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VibeRadii.button)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: VibeColors.primaryDeepBlue,
      side: const BorderSide(color: VibeColors.strokeSoft, width: 1.2),
      minimumSize: const Size.fromHeight(56),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VibeRadii.button)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: VibeColors.primaryViolet,
    ),
  ),
  textTheme: const TextTheme(
    displayLarge: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, height: 1.05),
    displayMedium: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, height: 1.08),
    displaySmall: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, height: 1.1),
    headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.12),
    headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.16),
    headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.2),
    titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.2),
    titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.24),
    titleSmall: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.24),
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, height: 1.45),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.45),
    bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.35),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.2),
    labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, height: 1.2),
    labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, height: 1.2),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: VibeColors.surface,
    selectedColor: VibeColors.softPink,
    disabledColor: VibeColors.surfaceSoft,
    labelStyle: const TextStyle(color: VibeColors.textPrimary, fontWeight: FontWeight.w600),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VibeRadii.pill)),
    side: const BorderSide(color: VibeColors.strokeSoft),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: VibeColors.surface,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: VibeColors.surface,
    contentTextStyle: const TextStyle(color: VibeColors.textPrimary, fontWeight: FontWeight.w600),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    behavior: SnackBarBehavior.floating,
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected) ? VibeColors.surface : VibeColors.textSecondary,
    ),
    trackColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? VibeColors.primaryViolet.withValues(alpha: 0.85)
          : VibeColors.strokeSoft,
    ),
  ),
);

final ThemeData vibeloopDarkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  fontFamily: 'SF Pro Display',
  colorScheme: const ColorScheme.dark(
    primary: VibeColors.cyan,
    secondary: VibeColors.primaryViolet,
    tertiary: VibeColors.coralPink,
    surface: VibeColors.darkSurface,
    onPrimary: VibeColors.textPrimary,
    onSecondary: Colors.white,
    onTertiary: Colors.white,
    onSurface: Colors.white,
    onSurfaceVariant: Color(0xFFB5C0D4),
    outline: VibeColors.darkStroke,
    error: VibeColors.dangerRed,
  ),
  scaffoldBackgroundColor: VibeColors.darkSurface,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
    toolbarHeight: 60,
    surfaceTintColor: Colors.transparent,
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w800,
      color: Colors.white,
      letterSpacing: -0.3,
    ),
  ),
  cardTheme: CardThemeData(
    color: VibeColors.darkSurfaceSoft.withValues(alpha: 0.90),
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(VibeRadii.card),
      side: const BorderSide(color: VibeColors.darkStroke, width: 1),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    labelStyle: const TextStyle(color: Color(0xFFB5C0D4), fontWeight: FontWeight.w600),
    hintStyle: const TextStyle(color: Color(0xFFB5C0D4)),
    filled: true,
    fillColor: VibeColors.darkSurfaceSoft,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: const BorderSide(color: VibeColors.darkStroke),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: const BorderSide(color: VibeColors.cyan, width: 1.6),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: VibeColors.cyan,
      foregroundColor: VibeColors.textPrimary,
      minimumSize: const Size.fromHeight(56),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VibeRadii.button)),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: VibeColors.cyan,
      foregroundColor: VibeColors.textPrimary,
      minimumSize: const Size.fromHeight(56),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VibeRadii.button)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: const BorderSide(color: VibeColors.darkStroke, width: 1.2),
      minimumSize: const Size.fromHeight(56),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VibeRadii.button)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: VibeColors.cyan,
    ),
  ),
  textTheme: vibeloopTheme.textTheme.apply(
    bodyColor: Colors.white,
    displayColor: Colors.white,
  ),
  chipTheme: ChipThemeData(
    backgroundColor: VibeColors.darkSurfaceSoft,
    selectedColor: VibeColors.primaryViolet.withValues(alpha: 0.35),
    disabledColor: VibeColors.darkSurfaceSoft,
    labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VibeRadii.pill)),
    side: const BorderSide(color: VibeColors.darkStroke),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: VibeColors.darkSurfaceSoft,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: VibeColors.darkSurfaceSoft,
    contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    behavior: SnackBarBehavior.floating,
  ),
);
