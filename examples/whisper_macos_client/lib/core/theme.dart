import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const Color background = Color(0xFF0D0D14);
  static const Color surface = Color(0xFF1A1A24);
  static const Color surfaceAlt = Color(0xFF22222E);
  static const Color border = Color(0xFF2A2A3C);
  static const Color borderLight = Color(0xFF3A3A50);

  static const Color accent = Color(0xFF5B8DEF);
  static const Color accentGlow = Color(0x3D5B8DEF);
  static const Color accentSoft = Color(0x1A5B8DEF);
  static const Color accentDim = Color(0xFF3D6FC7);

  static const Color green = Color(0xFF34D399);
  static const Color greenSoft = Color(0x1A34D399);
  static const Color red = Color(0xFFEF4444);
  static const Color redSoft = Color(0x1AEF4444);
  static const Color yellow = Color(0xFFFBBF24);
  static const Color yellowSoft = Color(0x1AFBBF24);

  static const Color textPrimary = Color(0xFFF1F1F6);
  static const Color textSecondary = Color(0xFFA0A0B8);
  static const Color textMuted = Color(0xFF60607A);

  static const Color glassFill = Color(0xCC12121C);
  static const Color glassBorder = Color(0x28FFFFFF);
  static const Color glassHighlight = Color(0x12FFFFFF);
  static const Color glassShadow = Color(0x66000000);
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      secondary: AppColors.green,
      error: AppColors.red,
      surface: AppColors.surface,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
      ),
      headlineMedium: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.3,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.4,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textMuted,
      ),
      labelLarge: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: 0.3,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.textMuted,
        letterSpacing: 0.5,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.red),
      ),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      hintStyle: const TextStyle(color: AppColors.textMuted),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceAlt,
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      textStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
    ),
  );
}
