import 'package:flutter/material.dart';

class AppColors {
  // Brand Colors
  static const brandDeepGold = Color(0xFFB18958);
  static const brandWarmOrange = Color(0xFFD97706);

  // Neutral Colors
  static const neutralLightGray = Color(0xFFF3F4F6);
  static const neutralDarkGray = Color(0xFF374151);

  // Dark Theme Colors
  static const darkBg = Color(0xFF1B1B1B);
  static const bgGlass = Color(0xE61B1B1B);

  // Text Colors
  static const textPrimary = Color(0xFFF8F9FA);
  static const textDark = Color(0xFF2D2D2D);

  // Accent Colors
  static const neonCyan = Color(0xFF00F3FF);
  static const neonPurple = Color(0xFFBC00FF);

  // Card Colors
  static const darkBgCard = Color(0x1A00F3FF);
}

class AppTheme {
  static ThemeData get lightTheme => ThemeData(
        primaryColor: AppColors.brandDeepGold,
        colorScheme: const ColorScheme.light(
          primary: AppColors.brandDeepGold,
          secondary: AppColors.brandWarmOrange,
          surface: AppColors.neutralLightGray,
          onPrimary: AppColors.textPrimary,
          onSecondary: AppColors.textPrimary,
          onSurface: AppColors.textDark,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: AppColors.neutralLightGray,
          selectedItemColor: AppColors.brandWarmOrange,
          unselectedItemColor: AppColors.neutralDarkGray.withOpacity(0.5),
          elevation: 0,
        ),
      );

  static ThemeData get darkTheme => ThemeData(
        primaryColor: AppColors.neonCyan,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.neonCyan,
          secondary: AppColors.neonPurple,
          surface: AppColors.darkBg,
          onPrimary: AppColors.textPrimary,
          onSecondary: AppColors.textPrimary,
          onSurface: AppColors.textPrimary,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: AppColors.darkBg,
          selectedItemColor: AppColors.neonCyan,
          unselectedItemColor: AppColors.textPrimary.withOpacity(0.5),
          elevation: 0,
        ),
      );
}