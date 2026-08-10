import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimensions.dart';

class ClueSummaryButton extends StatelessWidget {
  const ClueSummaryButton({
    required this.satisfiedCount,
    required this.totalCount,
    required this.onPressed,
    this.enabled = true,
    super.key = const Key('clue_summary_button'),
  });

  final int satisfiedCount;
  final int totalCount;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = enabled ? onPressed : null;
    return Semantics(
      button: true,
      label: '단서',
      value: '$totalCount개 중 $satisfiedCount개 만족',
      hint: '두 번 탭하여 단서 목록을 엽니다.',
      child: TextButton(
        onPressed: effectiveOnPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(88, 44),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.smallSpacing,
            vertical: AppDimensions.smallSpacing,
          ),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '단서 $satisfiedCount/$totalCount',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(width: 2),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
