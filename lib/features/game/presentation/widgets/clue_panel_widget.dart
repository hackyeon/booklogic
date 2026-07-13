import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/book.dart';
import '../../domain/clue.dart';
import '../formatters/clue_text_formatter.dart';
import 'clue_card_widget.dart';

class CluePanelWidget extends StatelessWidget {
  const CluePanelWidget({
    required this.clues,
    required this.books,
    required this.satisfiedClueIds,
    this.formatter = const ClueTextFormatter(),
    super.key,
  });

  final List<Clue> clues;
  final List<Book> books;
  final Set<String> satisfiedClueIds;
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
          if (clues.isEmpty)
            Text(AppStrings.emptyClueList, style: textTheme.bodyLarge)
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final indexedClue in clues.indexed) ...[
                  if (indexedClue.$1 > 0)
                    const SizedBox(height: AppDimensions.smallSpacing),
                  ClueCardWidget(
                    clue: indexedClue.$2,
                    text: formatter.format(clue: indexedClue.$2, books: books),
                    displayIndex: indexedClue.$1 + 1,
                    isSatisfied: satisfiedClueIds.contains(indexedClue.$2.id),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}
