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
    this.isPreparingNextLevel = false,
    this.nextLevelErrorMessage,
    this.isProgressSaveError = false,
    super.key,
  });

  final int level;
  final int moveCount;
  final VoidCallback onRetry;
  final VoidCallback onHome;
  final VoidCallback onNextLevel;
  final bool isPreparingNextLevel;
  final String? nextLevelErrorMessage;
  final bool isProgressSaveError;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final canUseButtons = !isPreparingNextLevel;

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
                        if (nextLevelErrorMessage != null) ...[
                          const SizedBox(height: AppDimensions.mediumSpacing),
                          Semantics(
                            liveRegion: true,
                            child: Container(
                              key: Key(
                                isProgressSaveError
                                    ? 'clear_progress_save_error'
                                    : 'clear_next_level_error',
                              ),
                              width: double.infinity,
                              padding: const EdgeInsets.all(
                                AppDimensions.mediumSpacing,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.errorContainer,
                                borderRadius: BorderRadius.circular(
                                  AppDimensions.cardRadius,
                                ),
                              ),
                              child: Text(
                                nextLevelErrorMessage!,
                                textAlign: TextAlign.center,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: AppDimensions.sectionSpacing),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            key: const Key('clear_next_level_button'),
                            onPressed: canUseButtons ? onNextLevel : null,
                            child: _NextLevelButtonContent(
                              isPreparing: isPreparingNextLevel,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.smallSpacing),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            key: const Key('clear_retry_button'),
                            onPressed: canUseButtons ? onRetry : null,
                            child: const Text(AppStrings.retryButton),
                          ),
                        ),
                        TextButton(
                          key: const Key('clear_home_button'),
                          onPressed: canUseButtons ? onHome : null,
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

class _NextLevelButtonContent extends StatelessWidget {
  const _NextLevelButtonContent({required this.isPreparing});

  final bool isPreparing;

  @override
  Widget build(BuildContext context) {
    if (!isPreparing) {
      return const Text(AppStrings.nextLevelButton);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          key: Key('clear_next_level_progress'),
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: AppDimensions.smallSpacing),
        Flexible(
          child: Text(
            AppStrings.preparingNextLevelButton,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
