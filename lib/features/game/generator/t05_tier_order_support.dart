import '../domain/book.dart';
import '../domain/book_placement.dart';
import 'book_code.dart';
import 'book_instance_code.dart';

class T05TierOrderShape {
  const T05TierOrderShape({
    required this.topEdgeLeft,
    required this.topBlockLeft,
    required this.topBlockRight,
    required this.topCenter,
    required this.topEdgeRight,
    required this.bottomEdgeLeft,
    required this.bottomBlockLeft,
    required this.bottomBlockRight,
    required this.bottomCenter,
    required this.bottomEdgeRight,
    required this.duplicateVisualGroupCount,
  });

  final Book topEdgeLeft;
  final Book topBlockLeft;
  final Book topBlockRight;
  final Book topCenter;
  final Book topEdgeRight;
  final Book bottomEdgeLeft;
  final Book bottomBlockLeft;
  final Book bottomBlockRight;
  final Book bottomCenter;
  final Book bottomEdgeRight;
  final int duplicateVisualGroupCount;

  BookColor get topEdgeColor => topEdgeLeft.color;

  BookColor get topBlockColor => topBlockLeft.color;

  BookColor get topCenterColor => topCenter.color;

  BookColor get bottomEdgeColor => bottomEdgeLeft.color;

  BookColor get bottomBlockColor => bottomBlockLeft.color;

  BookColor get bottomCenterColor => bottomCenter.color;

  static T05TierOrderShape? fromPlacements(
    List<BookPlacement> placements, {
    int? duplicateGroupCount,
  }) {
    final sorted = List<BookPlacement>.of(placements)
      ..sort(_comparePlacementPosition);
    if (sorted.length != 10) {
      return null;
    }
    for (var tierIndex = 0; tierIndex < 2; tierIndex += 1) {
      for (var slotIndex = 0; slotIndex < 5; slotIndex += 1) {
        final flatIndex = (tierIndex * 5) + slotIndex;
        final position = sorted[flatIndex].position;
        if (position.tierIndex != tierIndex ||
            position.slotIndex != slotIndex) {
          return null;
        }
      }
    }

    final topEdgeLeft = sorted[0].book;
    final topBlockLeft = sorted[1].book;
    final topBlockRight = sorted[2].book;
    final topCenter = sorted[3].book;
    final topEdgeRight = sorted[4].book;
    final bottomEdgeLeft = sorted[5].book;
    final bottomBlockLeft = sorted[6].book;
    final bottomBlockRight = sorted[7].book;
    final bottomCenter = sorted[8].book;
    final bottomEdgeRight = sorted[9].book;

    final expectedDuplicateGroupCount = duplicateGroupCount;
    if (expectedDuplicateGroupCount != null &&
        expectedDuplicateGroupCount != 1 &&
        expectedDuplicateGroupCount != 2) {
      return null;
    }

    if (topEdgeLeft.color != topEdgeRight.color ||
        topEdgeLeft.symbol == topEdgeRight.symbol) {
      return null;
    }
    if (topBlockLeft.color != topBlockRight.color ||
        t05VisualKey(topBlockLeft) != t05VisualKey(topBlockRight) ||
        topBlockLeft.id == topBlockRight.id) {
      return null;
    }
    if (!_matchesDuplicateCopies(topBlockLeft, topBlockRight)) {
      return null;
    }
    if (bottomEdgeLeft.color != bottomEdgeRight.color ||
        bottomEdgeLeft.symbol == bottomEdgeRight.symbol) {
      return null;
    }
    if (bottomBlockLeft.color != bottomBlockRight.color) {
      return null;
    }

    final colors = {
      topEdgeLeft.color,
      topBlockLeft.color,
      topCenter.color,
      bottomEdgeLeft.color,
      bottomBlockLeft.color,
      bottomCenter.color,
    };
    if (colors.length != 6) {
      return null;
    }

    final bookIds = <String>{};
    final visualCounts = <String, int>{};
    for (final placement in sorted) {
      final book = placement.book;
      if (!bookIds.add(book.id) || !BookInstanceCode.matchesBook(book)) {
        return null;
      }
      visualCounts.update(
        t05VisualKey(book),
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    final duplicateEntries = visualCounts.entries
        .where((entry) => entry.value > 1)
        .toList(growable: false);
    if (duplicateEntries.any((entry) => entry.value != 2)) {
      return null;
    }
    if (expectedDuplicateGroupCount != null &&
        duplicateEntries.length != expectedDuplicateGroupCount) {
      return null;
    }

    final topBlockVisual = t05VisualKey(topBlockLeft);
    final bottomBlockVisual = t05VisualKey(bottomBlockLeft);
    if (!duplicateEntries.any((entry) => entry.key == topBlockVisual)) {
      return null;
    }

    if (expectedDuplicateGroupCount == 1) {
      if (t05VisualKey(bottomBlockLeft) == t05VisualKey(bottomBlockRight) ||
          bottomBlockLeft.symbol == bottomBlockRight.symbol ||
          bottomBlockLeft.id != _canonicalId(bottomBlockLeft) ||
          bottomBlockRight.id != _canonicalId(bottomBlockRight)) {
        return null;
      }
    } else if (expectedDuplicateGroupCount == 2) {
      if (t05VisualKey(bottomBlockLeft) != t05VisualKey(bottomBlockRight) ||
          bottomBlockLeft.id == bottomBlockRight.id ||
          !_matchesDuplicateCopies(bottomBlockLeft, bottomBlockRight) ||
          !duplicateEntries.any((entry) => entry.key == bottomBlockVisual)) {
        return null;
      }
    }

    if (duplicateEntries.length == 1 &&
        duplicateEntries.single.key != topBlockVisual) {
      return null;
    }
    if (duplicateEntries.length == 2) {
      final duplicateKeys = {for (final entry in duplicateEntries) entry.key};
      if (!duplicateKeys.contains(topBlockVisual) ||
          !duplicateKeys.contains(bottomBlockVisual)) {
        return null;
      }
    }

    return T05TierOrderShape(
      topEdgeLeft: topEdgeLeft,
      topBlockLeft: topBlockLeft,
      topBlockRight: topBlockRight,
      topCenter: topCenter,
      topEdgeRight: topEdgeRight,
      bottomEdgeLeft: bottomEdgeLeft,
      bottomBlockLeft: bottomBlockLeft,
      bottomBlockRight: bottomBlockRight,
      bottomCenter: bottomCenter,
      bottomEdgeRight: bottomEdgeRight,
      duplicateVisualGroupCount: duplicateEntries.length,
    );
  }

  static bool _matchesDuplicateCopies(Book left, Book right) {
    final expectedLeft = BookInstanceCode.duplicateCopyId(
      color: left.color,
      symbol: left.symbol,
      copyNumber: 1,
    );
    final expectedRight = BookInstanceCode.duplicateCopyId(
      color: right.color,
      symbol: right.symbol,
      copyNumber: 2,
    );
    return left.id == expectedLeft && right.id == expectedRight;
  }

  static String _canonicalId(Book book) {
    return BookCode.bookId(color: book.color, symbol: book.symbol);
  }

  static int _comparePlacementPosition(
    BookPlacement left,
    BookPlacement right,
  ) {
    final tierComparison = left.position.tierIndex.compareTo(
      right.position.tierIndex,
    );
    if (tierComparison != 0) {
      return tierComparison;
    }
    return left.position.slotIndex.compareTo(right.position.slotIndex);
  }
}

String t05VisualKey(Book book) {
  return BookCode.bookId(color: book.color, symbol: book.symbol);
}
