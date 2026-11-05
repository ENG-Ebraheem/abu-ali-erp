import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Application theme configurations tailored for Arabic financial interfaces.
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
      ),
      fontFamily: null, // Uses system default Arabic-compatible font
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.darkNavy),
        titleTextStyle: TextStyle(
          color: AppColors.darkNavy,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardTheme(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
    );
  }

  /// Reusable card box shadow for clean financial UI elevation
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF1E293B).withValues(alpha: 0.05),
          blurRadius: 14,
          offset: const Offset(0, 4),
          spreadRadius: 0,
        ),
      ];

  /// Subtle header shadow
  static List<BoxShadow> get headerShadow => [
        BoxShadow(
          color: const Color(0xFF172554).withValues(alpha: 0.08),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];
}
