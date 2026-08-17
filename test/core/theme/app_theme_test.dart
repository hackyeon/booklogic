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
}
