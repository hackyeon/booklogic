import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_durations.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';

class ClearResultOverlay extends StatelessWidget {
  const ClearResultOverlay({
    required this.level,
    required this.moveCount,
    required this.onRetry,
    required this.onHome,
    required this.onNextLevel,
    super.key,
  });

  final int level;
  final int moveCount;
  final VoidCallback onRetry;
  final VoidCallback onHome;
  final VoidCallback onNextLevel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Positioned.fill(
      key: const Key('clear_result_overlay'),
      child: Material(
        color: AppColors.overlayScrim,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.screenPadding),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: AppDurations.resultOverlay,
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.scale(
                      scale: 0.96 + (0.04 * value),
                      child: child,
                    ),
                  );
                },
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppDimensions.resultCardMaxWidth,
                  ),
                  child: Container(
                    key: const Key('clear_result_card'),
                    padding: const EdgeInsets.all(AppDimensions.sectionSpacing),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(
                        AppDimensions.cardRadius,
                      ),
                      border: Border.all(color: AppColors.clearAccent),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x55000000),
                          blurRadius: 22,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          color: AppColors.clearAccent,
                          size: 48,
                        ),
                        const SizedBox(height: AppDimensions.mediumSpacing),
                        Text(
                          AppStrings.clearResultTitle,
                          key: const Key('clear_result_title'),
                          textAlign: TextAlign.center,
                          style: textTheme.headlineSmall?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.mediumSpacing),
                        Text(
                          'Level $level',
                          style: textTheme.titleMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.smallSpacing),
                        Text(
                          '${AppStrings.moveCountPrefix} $moveCount회',
                          style: textTheme.titleMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.sectionSpacing),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            key: const Key('clear_next_level_button'),
                            onPressed: onNextLevel,
                            child: const Text(AppStrings.nextLevelButton),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.smallSpacing),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            key: const Key('clear_retry_button'),
                            onPressed: onRetry,
                            child: const Text(AppStrings.retryButton),
                          ),
                        ),
                        TextButton(
                          key: const Key('clear_home_button'),
                          onPressed: onHome,
                          child: const Text(AppStrings.homeButton),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
