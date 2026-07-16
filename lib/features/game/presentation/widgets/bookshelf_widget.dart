import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_durations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/active_swap.dart';
import '../../domain/book_placement.dart';
import '../layout/bookshelf_layout_metrics.dart';
import 'book_widget.dart';

class BookshelfWidget extends StatelessWidget {
  const BookshelfWidget({
    required this.placements,
    required this.tierCount,
    required this.booksPerTier,
    required this.selectedBookId,
    required this.onBookTap,
    required this.onEmptyTap,
    required this.isAnimating,
    required this.activeSwap,
    required this.isInteractionLocked,
    required this.isClearing,
    required this.isCleared,
    required this.clearActiveBookId,
    required this.isShelfGlowing,
    super.key,
  });

  final List<BookPlacement> placements;
  final int tierCount;
  final int booksPerTier;
  final String? selectedBookId;
  final ValueChanged<String> onBookTap;
  final VoidCallback onEmptyTap;
  final bool isAnimating;
  final ActiveSwap? activeSwap;
  final bool isInteractionLocked;
  final bool isClearing;
  final bool isCleared;
  final String? clearActiveBookId;
  final bool isShelfGlowing;

  @override
  Widget build(BuildContext context) {
    _validateInput();
    final paintPlacements = _paintOrderedPlacements();

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxAvailableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : AppDimensions.bookshelfMaxWidth;
        final shelfWidth = maxAvailableWidth > AppDimensions.bookshelfMaxWidth
            ? AppDimensions.bookshelfMaxWidth
            : maxAvailableWidth;
        final shelfHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : BookshelfLayoutMetrics.preferredHeightFor(tierCount);
        final metrics = BookshelfLayoutMetrics(
          size: Size(shelfWidth, shelfHeight),
          tierCount: tierCount,
          booksPerTier: booksPerTier,
        );

        return Center(
          child: AnimatedContainer(
            key: isShelfGlowing ? const Key('bookshelf_clear_glow') : null,
            duration: AppDurations.clueStateChange,
            curve: Curves.easeOut,
            padding: isShelfGlowing ? const EdgeInsets.all(6) : EdgeInsets.zero,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimensions.smallSpacing),
              border: isShelfGlowing
                  ? Border.all(color: AppColors.clearAccent, width: 2)
                  : null,
              boxShadow: isShelfGlowing
                  ? const [
                      BoxShadow(
                        color: AppColors.clearGlow,
                        blurRadius: 18,
                        offset: Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: SizedBox(
              width: shelfWidth,
              height: shelfHeight,
              child: IgnorePointer(
                ignoring: isInteractionLocked,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        key: const Key('bookshelf_empty_tap_area'),
                        behavior: HitTestBehavior.opaque,
                        onTap: onEmptyTap,
                      ),
                    ),
                    for (var tierIndex = 0; tierIndex < tierCount; tierIndex++)
                      _TierBackground(
                        metrics: metrics,
                        tierIndex: tierIndex,
                        onEmptyTap: onEmptyTap,
                      ),
                    for (final placement in paintPlacements)
                      _PositionedBook(
                        placement: placement,
                        metrics: metrics,
                        selectedBookId: selectedBookId,
                        clearActiveBookId: clearActiveBookId,
                        onBookTap: onBookTap,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _validateInput() {
    if (tierCount < 1 || tierCount > 3) {
      throw ArgumentError.value(tierCount, 'tierCount', '1부터 3 사이여야 합니다.');
    }
    if (booksPerTier < 1 || booksPerTier > 6) {
      throw ArgumentError.value(
        booksPerTier,
        'booksPerTier',
        '1부터 6 사이여야 합니다.',
      );
    }
    if (placements.length != tierCount * booksPerTier) {
      throw ArgumentError.value(
        placements.length,
        'placements',
        'placements length must match tierCount * booksPerTier.',
      );
    }

    final bookIds = <String>{};
    final positionKeys = <String>{};
    for (final placement in placements) {
      if (!bookIds.add(placement.book.id)) {
        throw ArgumentError.value(
          placement.book.id,
          'placements',
          'Book.id must be unique.',
        );
      }
      final position = placement.position;
      if (position.tierIndex < 0 || position.tierIndex >= tierCount) {
        throw ArgumentError.value(
          position.tierIndex,
          'tierIndex',
          'tierIndex is outside the shelf layout.',
        );
      }
      if (position.slotIndex < 0 || position.slotIndex >= booksPerTier) {
        throw ArgumentError.value(
          position.slotIndex,
          'slotIndex',
          'slotIndex is outside the shelf layout.',
        );
      }
      final positionKey = '${position.tierIndex}:${position.slotIndex}';
      if (!positionKeys.add(positionKey)) {
        throw ArgumentError.value(
          positionKey,
          'placements',
          'BookPosition must be unique.',
        );
      }
    }

    for (var tierIndex = 0; tierIndex < tierCount; tierIndex += 1) {
      for (var slotIndex = 0; slotIndex < booksPerTier; slotIndex += 1) {
        if (!positionKeys.contains('$tierIndex:$slotIndex')) {
          throw ArgumentError.value(
            '$tierIndex:$slotIndex',
            'placements',
            'All tier and slot positions must be filled.',
          );
        }
      }
    }
  }

  List<BookPlacement> _paintOrderedPlacements() {
    final orderedPlacements = _canonicalPlacements(placements);
    final swap = activeSwap;
    if (swap == null) {
      return orderedPlacements;
    }

    BookPlacement? firstPlacement;
    BookPlacement? secondPlacement;
    final otherPlacements = <BookPlacement>[];

    for (final placement in orderedPlacements) {
      if (placement.book.id == swap.firstBookId) {
        firstPlacement = placement;
      } else if (placement.book.id == swap.secondBookId) {
        secondPlacement = placement;
      } else {
        otherPlacements.add(placement);
      }
    }

    return [...otherPlacements, ?secondPlacement, ?firstPlacement];
  }

  List<BookPlacement> _canonicalPlacements(List<BookPlacement> source) {
    return List<BookPlacement>.of(source)..sort((left, right) {
      final tierComparison = left.position.tierIndex.compareTo(
        right.position.tierIndex,
      );
      if (tierComparison != 0) {
        return tierComparison;
      }
      return left.position.slotIndex.compareTo(right.position.slotIndex);
    });
  }
}

class _TierBackground extends StatelessWidget {
  const _TierBackground({
    required this.metrics,
    required this.tierIndex,
    required this.onEmptyTap,
  });

  final BookshelfLayoutMetrics metrics;
  final int tierIndex;
  final VoidCallback onEmptyTap;

  @override
  Widget build(BuildContext context) {
    final tierRect = metrics.tierRect(tierIndex);
    final labelRect = metrics.tierLabelRect(tierIndex);
    final plankRect = metrics.shelfPlankRect(tierIndex);

    return Positioned(
      left: tierRect.left,
      top: tierRect.top,
      width: tierRect.width,
      height: tierRect.height,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onEmptyTap,
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                key: Key('bookshelf_tier_$tierIndex'),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(
                    AppDimensions.smallSpacing,
                  ),
                  border: Border.all(color: AppColors.divider),
                ),
              ),
            ),
            Positioned(
              left: labelRect.left - tierRect.left,
              top: 0,
              width: labelRect.width,
              height: labelRect.height,
              child: Center(
                child: Semantics(
                  label: '${tierIndex + 1}단',
                  child: Text(
                    '${tierIndex + 1}단',
                    key: Key('bookshelf_tier_label_$tierIndex'),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: plankRect.left - tierRect.left,
              top: plankRect.top - tierRect.top,
              width: plankRect.width,
              height: plankRect.height,
              child: const _ShelfBoard(),
            ),
          ],
        ),
      ),
    );
  }
}

class _PositionedBook extends StatelessWidget {
  const _PositionedBook({
    required this.placement,
    required this.metrics,
    required this.selectedBookId,
    required this.clearActiveBookId,
    required this.onBookTap,
  });

  final BookPlacement placement;
  final BookshelfLayoutMetrics metrics;
  final String? selectedBookId;
  final String? clearActiveBookId;
  final ValueChanged<String> onBookTap;

  @override
  Widget build(BuildContext context) {
    final bookRect = metrics.bookRectFor(placement.position);
    final book = placement.book;
    return AnimatedPositioned(
      key: ValueKey('positioned_${book.id}'),
      duration: AppDurations.bookSwap,
      curve: Curves.easeInOutCubic,
      left: bookRect.left,
      top: bookRect.top,
      width: bookRect.width,
      height: bookRect.height,
      child: BookWidget(
        key: ValueKey(book.id),
        book: book,
        width: bookRect.width,
        height: bookRect.height,
        isSelected: book.id == selectedBookId,
        isClearActive: book.id == clearActiveBookId,
        semanticsValue:
            '${placement.position.tierIndex + 1}단 ${placement.position.slotIndex + 1}번째 칸',
        onTap: () => onBookTap(book.id),
      ),
    );
  }
}

class _ShelfBoard extends StatelessWidget {
  const _ShelfBoard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bookshelfBrown,
        borderRadius: BorderRadius.circular(AppDimensions.smallSpacing),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
    );
  }
}
