import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:booklogic/core/theme/app_colors.dart';
import 'package:booklogic/core/theme/app_theme.dart';

void main() {
  test('light theme maps the warm puzzle palette to semantic colors', () {
    final theme = AppTheme.light();

    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(theme.colorScheme.surface, AppColors.surface);
    expect(theme.colorScheme.primary, AppColors.primary);
    expect(theme.colorScheme.primaryContainer, AppColors.primarySoft);
    expect(theme.colorScheme.secondary, AppColors.secondary);
    expect(theme.colorScheme.tertiary, AppColors.tertiary);
    expect(theme.colorScheme.onSurface, AppColors.textPrimary);
    expect(theme.colorScheme.onSurfaceVariant, AppColors.textSecondary);
  });

  test('light theme keeps Android system UI on the warm background', () {
    final theme = AppTheme.light();
    const style = AppTheme.systemUiOverlayStyle;

    expect(style.statusBarColor, Colors.transparent);
    expect(style.statusBarIconBrightness, Brightness.dark);
    expect(style.systemNavigationBarColor, AppColors.background);
    expect(style.systemNavigationBarDividerColor, AppColors.divider);
    expect(style.systemNavigationBarIconBrightness, Brightness.dark);
    expect(style.systemStatusBarContrastEnforced, isFalse);
    expect(style.systemNavigationBarContrastEnforced, isFalse);
    expect(theme.appBarTheme.systemOverlayStyle, style);
  });

  test('tutorial system UI follows the full-screen dim layer', () {
    final style = AppTheme.tutorialSystemUiOverlayStyle;

    expect(style.statusBarColor, Colors.transparent);
    expect(style.statusBarIconBrightness, Brightness.light);
    expect(
      style.systemNavigationBarColor,
      Color.alphaBlend(AppColors.tutorialScrim, AppColors.background),
    );
    expect(
      style.systemNavigationBarDividerColor,
      Color.alphaBlend(AppColors.tutorialScrim, AppColors.divider),
    );
    expect(style.systemNavigationBarIconBrightness, Brightness.light);
  });
}
