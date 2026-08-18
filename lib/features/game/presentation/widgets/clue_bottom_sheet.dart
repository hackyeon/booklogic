import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/book.dart';
import '../../domain/clue.dart';
import '../../tutorial/domain/tutorial_target.dart';
import '../../tutorial/domain/tutorial_step.dart';
import '../../tutorial/presentation/tutorial_coach_mark_overlay.dart';
import '../../tutorial/presentation/tutorial_target_registry.dart';
import '../formatters/clue_text_formatter.dart';
import 'clue_panel_widget.dart';

class ClueBottomSheet extends StatelessWidget {
  const ClueBottomSheet({
    required this.clues,
    required this.books,
    required this.satisfiedClueIds,
    required this.canSelectClue,
    this.highlightedClueId,
    this.tutorialTargetRegistry,
    this.tutorialStep,
    this.tutorialStepIndex = 0,
    this.tutorialStepCount = 0,
    this.onTutorialAcknowledge,
    this.onTutorialSkipConfirmed,
    this.formatter = const ClueTextFormatter(),
    super.key = const Key('clue_bottom_sheet'),
  });

  final List<Clue> clues;
  final List<Book> books;
  final Set<String> satisfiedClueIds;
  final String? highlightedClueId;
  final bool Function(String clueId) canSelectClue;
  final TutorialTargetRegistry? tutorialTargetRegistry;
  final TutorialStep? tutorialStep;
  final int tutorialStepIndex;
  final int tutorialStepCount;
  final VoidCallback? onTutorialAcknowledge;
  final VoidCallback? onTutorialSkipConfirmed;
  final ClueTextFormatter formatter;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.68;
    final textTheme = Theme.of(context).textTheme;
    final shouldShowTutorialOverlay =
        tutorialTargetRegistry != null &&
        tutorialStep != null &&
        tutorialStep!.target.type == TutorialTargetType.clueCard;

    return Stack(
      children: [
        SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: shouldShowTutorialOverlay ? maxHeight : 0,
              maxHeight: maxHeight,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: AppDimensions.smallSpacing),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.mediumSpacing,
                    AppDimensions.smallSpacing,
                    AppDimensions.smallSpacing,
                    AppDimensions.smallSpacing,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppStrings.clueTitle,
                          style: textTheme.titleLarge,
                        ),
                      ),
                      Text(
                        '${satisfiedClueIds.length} / ${clues.length}',
                        style: textTheme.titleMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: AppDimensions.smallSpacing),
                      IconButton(
                        key: const Key('clue_bottom_sheet_close_button'),
                        tooltip: '단서 닫기',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ClueCardListWidget(
                    clues: clues,
                    books: books,
                    satisfiedClueIds: satisfiedClueIds,
                    highlightedClueId: highlightedClueId,
                    tutorialTargetRegistry: tutorialTargetRegistry,
                    formatter: formatter,
                    scrollable: true,
                    listKey: const Key('clue_bottom_sheet_list'),
                    padding: const EdgeInsets.fromLTRB(
                      AppDimensions.mediumSpacing,
                      0,
                      AppDimensions.mediumSpacing,
                      AppDimensions.mediumSpacing,
                    ),
                    onClueTap: (clueId) {
                      if (!canSelectClue(clueId)) {
                        return;
                      }
                      Navigator.of(context).pop(clueId);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        if (shouldShowTutorialOverlay)
          TutorialCoachMarkOverlay(
            registry: tutorialTargetRegistry!,
            step: tutorialStep!,
            stepIndex: tutorialStepIndex,
            totalStepCount: tutorialStepCount,
            onAcknowledge: onTutorialAcknowledge ?? () {},
            onSkipConfirmed: onTutorialSkipConfirmed ?? () {},
            onTargetTap: () {
              final clueId = tutorialStep!.expectedClueId;
              if (clueId == null || !canSelectClue(clueId)) {
                return;
              }
              Navigator.of(context).pop(clueId);
            },
            blockBackgroundInteraction: true,
          ),
      ],
    );
  }
}
