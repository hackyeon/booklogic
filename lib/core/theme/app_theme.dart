import 'package:flutter/material.dart';

import '../constants/app_dimensions.dart';
import 'app_colors.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: AppColors.onStrongColor,
          primaryContainer: AppColors.primarySoft,
          onPrimaryContainer: AppColors.primaryStrong,
          secondary: AppColors.secondary,
          tertiary: AppColors.tertiary,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
          onSurfaceVariant: AppColors.textSecondary,
          outline: AppColors.primary,
          outlineVariant: AppColors.divider,
          error: AppColors.error,
          errorContainer: AppColors.errorContainer,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamilyFallback: const ['Apple SD Gothic Neo', 'Noto Sans CJK KR'],
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        centerTitle: true,
        elevation: 0,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.w800,
        ),
        titleLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 16,
          height: 1.4,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onStrongColor,
          disabledBackgroundColor: AppColors.divider,
          disabledForegroundColor: AppColors.textSecondary,
          minimumSize: const Size.fromHeight(AppDimensions.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryStrong,
          minimumSize: const Size.fromHeight(AppDimensions.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
          ),
          side: const BorderSide(color: AppColors.primary),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
