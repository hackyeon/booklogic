import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/book.dart';
import '../../domain/clue.dart';
import '../../tutorial/presentation/tutorial_target_registry.dart';
import '../../tutorial/presentation/tutorial_target_widget.dart';
import '../formatters/clue_text_formatter.dart';
import 'clue_card_widget.dart';

class CluePanelWidget extends StatelessWidget {
  const CluePanelWidget({
    required this.clues,
    required this.books,
    required this.satisfiedClueIds,
    this.highlightedClueId,
    this.onClueTap,
    this.tutorialTargetRegistry,
    this.formatter = const ClueTextFormatter(),
    super.key,
  });

  final List<Clue> clues;
  final List<Book> books;
  final Set<String> satisfiedClueIds;
  final String? highlightedClueId;
  final ValueChanged<String>? onClueTap;
  final TutorialTargetRegistry? tutorialTargetRegistry;
  final ClueTextFormatter formatter;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      key: const Key('clue_panel'),
      padding: const EdgeInsets.all(AppDimensions.mediumSpacing),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(AppStrings.clueTitle, style: textTheme.titleLarge),
              ),
              Text(
                '${satisfiedClueIds.length}/${clues.length}',
                style: textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.mediumSpacing),
          ClueCardListWidget(
            clues: clues,
            books: books,
            satisfiedClueIds: satisfiedClueIds,
            highlightedClueId: highlightedClueId,
            tutorialTargetRegistry: tutorialTargetRegistry,
            onClueTap: onClueTap,
            formatter: formatter,
          ),
        ],
      ),
    );
  }
}

class ClueCardListWidget extends StatelessWidget {
  const ClueCardListWidget({
    required this.clues,
    required this.books,
    required this.satisfiedClueIds,
    this.highlightedClueId,
    this.onClueTap,
    this.tutorialTargetRegistry,
    this.formatter = const ClueTextFormatter(),
    this.scrollable = false,
    this.padding = EdgeInsets.zero,
    this.listKey,
    super.key,
  });

  final List<Clue> clues;
  final List<Book> books;
  final Set<String> satisfiedClueIds;
  final String? highlightedClueId;
  final ValueChanged<String>? onClueTap;
  final TutorialTargetRegistry? tutorialTargetRegistry;
  final ClueTextFormatter formatter;
  final bool scrollable;
  final EdgeInsetsGeometry padding;
  final Key? listKey;

  @override
  Widget build(BuildContext context) {
    if (clues.isEmpty) {
      return Padding(
        padding: padding,
        child: Text(
          AppStrings.emptyClueList,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    if (scrollable) {
      return ListView.separated(
        key: listKey,
        padding: padding,
        shrinkWrap: true,
        itemCount: clues.length,
        separatorBuilder: (context, index) {
          return const SizedBox(height: AppDimensions.smallSpacing);
        },
        itemBuilder: (context, index) {
          return _buildClueCard(index, clues[index]);
        },
      );
    }

    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final indexedClue in clues.indexed) ...[
            if (indexedClue.$1 > 0)
              const SizedBox(height: AppDimensions.smallSpacing),
            _buildClueCard(indexedClue.$1, indexedClue.$2),
          ],
        ],
      ),
    );
  }

  Widget _buildClueCard(int index, Clue clue) {
    final card = ClueCardWidget(
      clue: clue,
      text: formatter.format(clue: clue, books: books),
      displayIndex: index + 1,
      isSatisfied: satisfiedClueIds.contains(clue.id),
      isHighlighted: highlightedClueId == clue.id,
      onTap: onClueTap == null ? null : () => onClueTap!(clue.id),
    );
    final registry = tutorialTargetRegistry;
    if (registry == null) {
      return card;
    }
    return TutorialTargetWidget(
      registry: registry,
      targetId: 'clue:${clue.id}',
      child: card,
    );
  }
}
