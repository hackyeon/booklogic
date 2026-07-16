import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_durations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/clue.dart';

class ClueCardWidget extends StatelessWidget {
  const ClueCardWidget({
    required this.clue,
    required this.text,
    required this.displayIndex,
    required this.isSatisfied,
    this.isHighlighted = false,
    this.onTap,
    super.key,
  });

  final Clue clue;
  final String text;
  final int displayIndex;
  final bool isSatisfied;
  final bool isHighlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final statusText = isSatisfied ? '충족' : '미충족';
    final backgroundColor = isSatisfied
        ? AppColors.clueSatisfiedBackground
        : AppColors.cluePaper;
    final borderColor = isSatisfied
        ? AppColors.clueSatisfiedBorder
        : isHighlighted
        ? Theme.of(context).colorScheme.primary
        : AppColors.divider;
    final numberBackgroundColor = isSatisfied
        ? AppColors.clueSatisfiedNumberBackground
        : AppColors.clueNumberBackground;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: onTap,
      child: Semantics(
        container: true,
        button: true,
        selected: isHighlighted,
        label: '단서 $displayIndex. $text $statusText',
        value: isHighlighted
            ? '$statusText, 관련 책 강조 중'
            : isSatisfied
            ? '만족됨'
            : '아직 만족되지 않음',
        hint: '탭하면 관련 책을 강조합니다.',
        child: AnimatedContainer(
          key: Key('clue_${clue.id}'),
          duration: AppDurations.clueStateChange,
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(AppDimensions.mediumSpacing),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(AppDimensions.smallSpacing),
            border: Border.all(color: borderColor),
            boxShadow: isHighlighted
                ? [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.22),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                width: 32,
                height: 32,
                duration: AppDurations.clueStateChange,
                curve: Curves.easeOut,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: numberBackgroundColor,
                  borderRadius: BorderRadius.circular(
                    AppDimensions.smallSpacing,
                  ),
                ),
                child: Text(
                  '$displayIndex',
                  style: textTheme.titleMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.mediumSpacing),
              Expanded(
                child: Text(
                  text,
                  softWrap: true,
                  style: textTheme.bodyLarge?.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.smallSpacing),
              SizedBox(
                width: AppDimensions.iconSize,
                height: AppDimensions.iconSize,
                child: AnimatedSwitcher(
                  duration: AppDurations.clueStateChange,
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(scale: animation, child: child),
                    );
                  },
                  child: isSatisfied
                      ? Icon(
                          Icons.check_circle_rounded,
                          key: Key('clue_check_${clue.id}'),
                          color: AppColors.clueSatisfiedIcon,
                          size: AppDimensions.iconSize,
                        )
                      : const SizedBox.shrink(key: ValueKey('empty_check')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
