import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_durations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/active_swap.dart';
import '../../domain/book_placement.dart';
import 'book_widget.dart';

class BookshelfWidget extends StatelessWidget {
  const BookshelfWidget({
    required this.placements,
    required this.selectedBookId,
    required this.onBookTap,
    required this.isAnimating,
    required this.activeSwap,
    required this.isInteractionLocked,
    required this.isClearing,
    required this.isCleared,
    required this.clearActiveBookId,
    super.key,
  });

  final List<BookPlacement> placements;
  final String? selectedBookId;
  final ValueChanged<String> onBookTap;
  final bool isAnimating;
  final ActiveSwap? activeSwap;
  final bool isInteractionLocked;
  final bool isClearing;
  final bool isCleared;
  final String? clearActiveBookId;

  @override
  Widget build(BuildContext context) {
    final paintPlacements = _paintOrderedPlacements();
    final isClearGlowActive = _isClearGlowActive();

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxAvailableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : AppDimensions.bookshelfMaxWidth;
        final shelfWidth = maxAvailableWidth > AppDimensions.bookshelfMaxWidth
            ? AppDimensions.bookshelfMaxWidth
            : maxAvailableWidth;
        final bookCount = placements.length;
        final spacingTotal = AppDimensions.bookSpacing * (bookCount - 1);
        final bookWidth = (shelfWidth - spacingTotal) / bookCount;
        final bookHeight = bookWidth / AppDimensions.bookAspectRatio;
        final shelfTop = AppDimensions.bookSelectionHeadroom + bookHeight;
        final totalHeight = shelfTop + AppDimensions.bookshelfShelfHeight;

        return Center(
          child: AnimatedContainer(
            key: isClearGlowActive ? const Key('bookshelf_clear_glow') : null,
            duration: AppDurations.clueStateChange,
            curve: Curves.easeOut,
            padding: isClearGlowActive
                ? const EdgeInsets.all(6)
                : EdgeInsets.zero,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimensions.smallSpacing),
              border: isClearGlowActive
                  ? Border.all(color: AppColors.clearAccent, width: 2)
                  : null,
              boxShadow: isClearGlowActive
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
              key: const Key('bookshelf_tier_0'),
              width: shelfWidth,
              height: totalHeight,
              child: IgnorePointer(
                ignoring: isInteractionLocked,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: shelfTop,
                      height: AppDimensions.bookshelfShelfHeight,
                      child: _ShelfBoard(),
                    ),
                    for (final placement in paintPlacements)
                      AnimatedPositioned(
                        key: ValueKey('positioned_${placement.book.id}'),
                        duration: AppDurations.bookSwap,
                        curve: Curves.easeInOutCubic,
                        left: _slotLeft(
                          placement.position.slotIndex,
                          bookWidth,
                        ),
                        top: AppDimensions.bookSelectionHeadroom,
                        width: bookWidth,
                        height: bookHeight,
                        child: BookWidget(
                          book: placement.book,
                          width: bookWidth,
                          height: bookHeight,
                          isSelected: placement.book.id == selectedBookId,
                          isClearActive: placement.book.id == clearActiveBookId,
                          onTap: () => onBookTap(placement.book.id),
                        ),
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

  double _slotLeft(int slotIndex, double bookWidth) {
    return slotIndex * (bookWidth + AppDimensions.bookSpacing);
  }

  List<BookPlacement> _paintOrderedPlacements() {
    final orderedPlacements = placements.toList()
      ..sort((left, right) => left.book.id.compareTo(right.book.id));
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

  bool _isClearGlowActive() {
    if (isCleared) {
      return true;
    }
    if (!isClearing || clearActiveBookId == null) {
      return false;
    }

    final sortedPlacements = placements.toList()
      ..sort((left, right) {
        final tierComparison = left.position.tierIndex.compareTo(
          right.position.tierIndex,
        );
        if (tierComparison != 0) {
          return tierComparison;
        }
        return left.position.slotIndex.compareTo(right.position.slotIndex);
      });
    return sortedPlacements.isNotEmpty &&
        sortedPlacements.last.book.id == clearActiveBookId;
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
