import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';

class GameStatusBar extends StatelessWidget {
  const GameStatusBar({
    required this.moveCount,
    required this.selectionText,
    required this.clueSummaryButton,
    required this.onRestart,
    required this.restartEnabled,
    super.key = const Key('game_status_bar'),
  });

  final int moveCount;
  final String selectionText;
  final Widget clueSummaryButton;
  final VoidCallback onRestart;
  final bool restartEnabled;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final useStackedControls =
            constraints.maxWidth < 300 || textScale > 1.3;
        final moveStatus = _MoveStatus(moveCount: moveCount);
        final restartButton = Semantics(
          button: true,
          enabled: restartEnabled,
          label: '현재 레벨 다시 시작',
          excludeSemantics: true,
          child: IconButton(
            key: const Key('game_restart_button'),
            tooltip: '현재 레벨 다시 시작',
            onPressed: restartEnabled ? onRestart : null,
            icon: const Icon(Icons.restart_alt_rounded),
            color: AppColors.primaryStrong,
            disabledColor: AppColors.textSecondary,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            padding: EdgeInsets.zero,
          ),
        );

        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.mediumSpacing,
            vertical: AppDimensions.smallSpacing,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppDimensions.statusBarRadius),
            border: Border.all(color: AppColors.divider),
            boxShadow: const [
              BoxShadow(
                color: AppColors.bookShadow,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (useStackedControls) ...[
                Row(
                  children: [
                    restartButton,
                    const SizedBox(width: AppDimensions.smallSpacing),
                    Expanded(child: moveStatus),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: clueSummaryButton,
                ),
              ] else
                Row(
                  children: [
                    restartButton,
                    const SizedBox(width: AppDimensions.smallSpacing),
                    Expanded(child: moveStatus),
                    const SizedBox(width: AppDimensions.smallSpacing),
                    clueSummaryButton,
                  ],
                ),
              const Divider(height: AppDimensions.smallSpacing),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  selectionText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MoveStatus extends StatelessWidget {
  const _MoveStatus({required this.moveCount});

  final int moveCount;

  @override
  Widget build(BuildContext context) {
    final label = '${AppStrings.moveCountPrefix} $moveCount회';
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.swap_horiz_rounded, color: AppColors.primary),
          const SizedBox(width: AppDimensions.smallSpacing),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
