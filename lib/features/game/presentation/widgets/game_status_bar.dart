import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';

class GameStatusBar extends StatelessWidget {
  const GameStatusBar({
    required this.moveCount,
    required this.selectionText,
    required this.clueSummaryButton,
    super.key = const Key('game_status_bar'),
  });

  final int moveCount;
  final String selectionText;
  final Widget clueSummaryButton;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.mediumSpacing,
        vertical: AppDimensions.smallSpacing,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.swap_horiz_rounded, color: AppColors.primary),
              const SizedBox(width: AppDimensions.smallSpacing),
              Flexible(
                child: Text(
                  '${AppStrings.moveCountPrefix} $moveCount회',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Spacer(),
              clueSummaryButton,
            ],
          ),
          const SizedBox(height: AppDimensions.smallSpacing),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              selectionText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}
