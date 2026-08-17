import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

import 'package:booklogic/features/game/domain/book_position.dart';
import 'package:booklogic/features/game/presentation/layout/bookshelf_layout_metrics.dart';

void main() {
  group('BookshelfLayoutMetrics', () {
    test(
      'moves right as slotIndex increases and down as tierIndex increases',
      () {
        final metrics = BookshelfLayoutMetrics(
          size: const Size(420, 360),
          tierCount: 3,
          booksPerTier: 4,
        );

        final first = metrics.bookRectFor(
          const BookPosition(tierIndex: 0, slotIndex: 0),
        );
        final secondSlot = metrics.bookRectFor(
          const BookPosition(tierIndex: 0, slotIndex: 1),
        );
        final secondTier = metrics.bookRectFor(
          const BookPosition(tierIndex: 1, slotIndex: 0),
        );

        expect(secondSlot.left, greaterThan(first.left));
        expect(secondTier.top, greaterThan(first.top));
        expect(secondSlot, isNot(first));
        expect(secondTier, isNot(first));
      },
    );

    test('keeps every book rect inside the given size', () {
      final metrics = BookshelfLayoutMetrics(
        size: const Size(420, 420),
        tierCount: 3,
        booksPerTier: 6,
      );

      for (var tierIndex = 0; tierIndex < 3; tierIndex += 1) {
        for (var slotIndex = 0; slotIndex < 6; slotIndex += 1) {
          final rect = metrics.bookRectFor(
            BookPosition(tierIndex: tierIndex, slotIndex: slotIndex),
          );
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(metrics.size.width));
          expect(rect.bottom, lessThanOrEqualTo(metrics.size.height));
          expect(rect.width, greaterThan(0));
          expect(rect.height, greaterThan(0));
        }
      }
    });

    test('does not overlap books in one-tier layouts', () {
      for (final booksPerTier in [4, 6]) {
        final metrics = BookshelfLayoutMetrics(
          size: const Size(420, 240),
          tierCount: 1,
          booksPerTier: booksPerTier,
        );

        _expectNoRectOverlap([
          for (var slotIndex = 0; slotIndex < booksPerTier; slotIndex += 1)
            metrics.bookRectFor(
              BookPosition(tierIndex: 0, slotIndex: slotIndex),
            ),
        ]);
      }
    });

    test('does not overlap tiers in multi-tier layouts', () {
      final twoTier = BookshelfLayoutMetrics(
        size: const Size(420, 320),
        tierCount: 2,
        booksPerTier: 4,
      );
      final threeTier = BookshelfLayoutMetrics(
        size: const Size(420, 420),
        tierCount: 3,
        booksPerTier: 6,
      );

      expect(
        twoTier.bookRectFor(const BookPosition(tierIndex: 1, slotIndex: 0)).top,
        greaterThan(
          twoTier
              .bookRectFor(const BookPosition(tierIndex: 0, slotIndex: 0))
              .bottom,
        ),
      );
      _expectNoRectOverlap([
        for (var tierIndex = 0; tierIndex < 3; tierIndex += 1)
          for (var slotIndex = 0; slotIndex < 6; slotIndex += 1)
            threeTier.bookRectFor(
              BookPosition(tierIndex: tierIndex, slotIndex: slotIndex),
            ),
      ]);
    });

    test('rejects out-of-range layout and positions', () {
      expect(
        () => BookshelfLayoutMetrics(
          size: const Size(420, 240),
          tierCount: 0,
          booksPerTier: 4,
        ),
        throwsArgumentError,
      );
      expect(
        () => BookshelfLayoutMetrics(
          size: const Size(420, 240),
          tierCount: 1,
          booksPerTier: 7,
        ),
        throwsArgumentError,
      );

      final metrics = BookshelfLayoutMetrics(
        size: const Size(420, 240),
        tierCount: 1,
        booksPerTier: 4,
      );
      expect(
        () =>
            metrics.bookRectFor(const BookPosition(tierIndex: 1, slotIndex: 0)),
        throwsRangeError,
      );
      expect(
        () =>
            metrics.bookRectFor(const BookPosition(tierIndex: 0, slotIndex: 4)),
        throwsRangeError,
      );
    });

    test('small sizes never produce negative dimensions', () {
      final metrics = BookshelfLayoutMetrics(
        size: const Size(64, 48),
        tierCount: 3,
        booksPerTier: 6,
      );
      final rect = metrics.bookRectFor(
        const BookPosition(tierIndex: 2, slotIndex: 5),
      );

      expect(rect.width, greaterThanOrEqualTo(0));
      expect(rect.height, greaterThanOrEqualTo(0));
    });

    test('uses a tier-driven content size instead of all available height', () {
      const availableSize = Size(420, 700);
      final oneTier = BookshelfLayoutMetrics.contentSizeFor(
        availableSize: availableSize,
        tierCount: 1,
        booksPerTier: 4,
      );
      final twoTier = BookshelfLayoutMetrics.contentSizeFor(
        availableSize: availableSize,
        tierCount: 2,
        booksPerTier: 4,
      );
      final threeTier = BookshelfLayoutMetrics.contentSizeFor(
        availableSize: availableSize,
        tierCount: 3,
        booksPerTier: 4,
      );

      expect(oneTier.height, lessThan(twoTier.height));
      expect(twoTier.height, lessThan(threeTier.height));
      expect(threeTier.height, lessThan(availableSize.height));
      expect(oneTier.width, lessThan(availableSize.width));
    });

    test('aligns every book bottom with its own shelf plank', () {
      for (final configuration in [
        (size: const Size(320, 180), tiers: 1, books: 4),
        (size: const Size(360, 320), tiers: 2, books: 5),
        (size: const Size(320, 300), tiers: 3, books: 6),
      ]) {
        final metrics = BookshelfLayoutMetrics(
          size: configuration.size,
          tierCount: configuration.tiers,
          booksPerTier: configuration.books,
        );

        for (var tierIndex = 0; tierIndex < configuration.tiers; tierIndex++) {
          final plank = metrics.shelfPlankRect(tierIndex);
          for (
            var slotIndex = 0;
            slotIndex < configuration.books;
            slotIndex++
          ) {
            final book = metrics.bookRectFor(
              BookPosition(tierIndex: tierIndex, slotIndex: slotIndex),
            );
            expect((book.bottom - plank.top).abs(), lessThanOrEqualTo(0.001));
          }
        }
      }
    });
  });
}

void _expectNoRectOverlap(List<Rect> rects) {
  for (var leftIndex = 0; leftIndex < rects.length; leftIndex += 1) {
    for (
      var rightIndex = leftIndex + 1;
      rightIndex < rects.length;
      rightIndex += 1
    ) {
      expect(
        rects[leftIndex].overlaps(rects[rightIndex]),
        isFalse,
        reason: '$leftIndex overlaps $rightIndex',
      );
    }
  }
}
