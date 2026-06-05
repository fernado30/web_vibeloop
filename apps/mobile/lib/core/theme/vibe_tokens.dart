import 'package:flutter/material.dart';

class VibeColors {
  static const primaryDeepBlue = Color(0xFF171A4A);
  static const primaryViolet = Color(0xFF6D4CFF);
  static const electricBlue = Color(0xFF397BFF);
  static const coralPink = Color(0xFFFF4F93);
  static const softPink = Color(0xFFFFD6E9);
  static const cyan = Color(0xFF34D5FF);
  static const successGreen = Color(0xFF25D366);
  static const softGreen = Color(0xFFE8F8EF);
  static const warningAmber = Color(0xFFFFB020);
  static const dangerRed = Color(0xFFFF3B5C);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF667085);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSoft = Color(0xFFF7F7FB);
  static const strokeSoft = Color(0xFFEAECF0);
  static const glassWhite = Color(0xC7FFFFFF);
  static const darkSurface = Color(0xFF0D1324);
  static const darkSurfaceSoft = Color(0xFF131C31);
  static const darkStroke = Color(0x334C5C80);
}

class VibeGradients {
  static const hero = LinearGradient(
    colors: [
      VibeColors.electricBlue,
      VibeColors.primaryViolet,
      VibeColors.coralPink,
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const story = LinearGradient(
    colors: [
      Color(0xFF4B7BFF),
      Color(0xFF7B4DFF),
      Color(0xFFFF5CA8),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const cyanViolet = LinearGradient(
    colors: [VibeColors.cyan, VibeColors.primaryViolet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const coralAmber = LinearGradient(
    colors: [VibeColors.coralPink, VibeColors.warningAmber],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const safeGreen = LinearGradient(
    colors: [VibeColors.softGreen, VibeColors.surface],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

class VibeRadii {
  static const card = 30.0;
  static const cardSmall = 24.0;
  static const button = 22.0;
  static const pill = 999.0;
  static const navigation = 34.0;
}

class VibeShadows {
  static List<BoxShadow> get soft => [
        BoxShadow(
          color: VibeColors.primaryDeepBlue.withValues(alpha: 0.10),
          blurRadius: 32,
          offset: const Offset(0, 16),
        ),
      ];

  static List<BoxShadow> get subtle => [
        BoxShadow(
          color: VibeColors.primaryDeepBlue.withValues(alpha: 0.06),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];
}
