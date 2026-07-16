import '../domain/book_position.dart';
import 'stage_spec.dart';

class T06LayoutPlan {
  T06LayoutPlan._({
    required this.tierCount,
    required this.booksPerTier,
    required List<BookPosition> duplicatePositionPairs,
    required List<int> verticalAnchorColumns,
  }) : canonicalPositions = List<BookPosition>.unmodifiable([
         for (var tierIndex = 0; tierIndex < tierCount; tierIndex += 1)
           for (var slotIndex = 0; slotIndex < booksPerTier; slotIndex += 1)
             BookPosition(tierIndex: tierIndex, slotIndex: slotIndex),
       ]),
       duplicatePositionPairs = List<BookPosition>.unmodifiable(
         duplicatePositionPairs,
       ),
       verticalAnchorColumns = List<int>.unmodifiable(verticalAnchorColumns);

  final int tierCount;
  final int booksPerTier;
  final List<BookPosition> canonicalPositions;
  final List<BookPosition> duplicatePositionPairs;
  final List<int> verticalAnchorColumns;

  static T06LayoutPlan fromStageSpec(StageSpec spec) {
    return forLayout(
      tierCount: spec.tierCount,
      booksPerTier: spec.booksPerTier,
      duplicateGroupCount: spec.duplicateGroupCount,
    );
  }

  static T06LayoutPlan forLayout({
    required int tierCount,
    required int booksPerTier,
    required int duplicateGroupCount,
  }) {
    if (duplicateGroupCount < 1 || duplicateGroupCount > 3) {
      throw ArgumentError.value(
        duplicateGroupCount,
        'duplicateGroupCount',
        '1부터 3 사이여야 합니다.',
      );
    }
    final candidates = switch ((tierCount, booksPerTier)) {
      (2, 6) => const [(0, 1, 0, 2), (1, 1, 1, 2), (1, 3, 1, 4)],
      (3, 4) => const [(0, 1, 0, 2), (1, 1, 1, 2), (2, 1, 2, 2)],
      _ => throw UnsupportedError('T06 supports only 2x6 and 3x4 layouts.'),
    };
    final anchors = switch ((tierCount, booksPerTier)) {
      (2, 6) => const [0, 5],
      (3, 4) => const [0, 3],
      _ => throw UnsupportedError('T06 supports only 2x6 and 3x4 layouts.'),
    };
    return T06LayoutPlan._(
      tierCount: tierCount,
      booksPerTier: booksPerTier,
      duplicatePositionPairs: [
        for (final candidate in candidates.take(duplicateGroupCount)) ...[
          BookPosition(tierIndex: candidate.$1, slotIndex: candidate.$2),
          BookPosition(tierIndex: candidate.$3, slotIndex: candidate.$4),
        ],
      ],
      verticalAnchorColumns: anchors,
    );
  }

  bool isFirstDuplicatePosition(BookPosition position) {
    for (var index = 0; index < duplicatePositionPairs.length; index += 2) {
      if (duplicatePositionPairs[index] == position) {
        return true;
      }
    }
    return false;
  }

  bool isSecondDuplicatePosition(BookPosition position) {
    for (var index = 1; index < duplicatePositionPairs.length; index += 2) {
      if (duplicatePositionPairs[index] == position) {
        return true;
      }
    }
    return false;
  }

  BookPosition duplicatePairSecond(BookPosition first) {
    for (var index = 0; index < duplicatePositionPairs.length; index += 2) {
      if (duplicatePositionPairs[index] == first) {
        return duplicatePositionPairs[index + 1];
      }
    }
    throw StateError('Position is not the first duplicate position.');
  }

  int flatIndex(BookPosition position) {
    return position.tierIndex * booksPerTier + position.slotIndex;
  }

  BookPosition positionForFlatIndex(int flatIndex) {
    if (flatIndex < 0 || flatIndex >= canonicalPositions.length) {
      throw ArgumentError.value(flatIndex, 'flatIndex', 'out of range.');
    }
    return BookPosition(
      tierIndex: flatIndex ~/ booksPerTier,
      slotIndex: flatIndex % booksPerTier,
    );
  }
}
