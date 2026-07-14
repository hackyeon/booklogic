import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';

class GameGenerationErrorView extends StatelessWidget {
  const GameGenerationErrorView({
    required this.level,
    required this.isRetrying,
    required this.onRetry,
    required this.onHome,
    super.key,
  });

  final int level;
  final bool isRetrying;
  final VoidCallback onRetry;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.screenPadding),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimensions.resultCardMaxWidth,
            ),
            child: Container(
              key: const Key('game_generation_error'),
              padding: const EdgeInsets.all(AppDimensions.sectionSpacing),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.primary,
                    size: 48,
                  ),
                  const SizedBox(height: AppDimensions.mediumSpacing),
                  Text(
                    AppStrings.generationErrorTitle,
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.smallSpacing),
                  Text(
                    'Level $level을 생성하는 중 문제가 발생했습니다.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.sectionSpacing),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const Key('game_generation_retry_button'),
                      onPressed: isRetrying ? null : onRetry,
                      child: const Text(AppStrings.generationRetryButton),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.smallSpacing),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      key: const Key('game_generation_home_button'),
                      onPressed: onHome,
                      child: const Text(AppStrings.homeButton),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
