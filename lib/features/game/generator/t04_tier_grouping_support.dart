import '../domain/book.dart';
import '../domain/book_placement.dart';
import 'book_code.dart';
import 'book_instance_code.dart';

class T04TierGroupingShape {
  const T04TierGroupingShape({
    required this.topEdgeLeft,
    required this.topMiddleLeft,
    required this.topMiddleRight,
    required this.topEdgeRight,
    required this.bottomEdgeLeft,
    required this.bottomInnerLeft,
    required this.bottomInnerRight,
    required this.bottomEdgeRight,
    required this.duplicateVisualGroupCount,
  });

  final Book topEdgeLeft;
  final Book topMiddleLeft;
  final Book topMiddleRight;
  final Book topEdgeRight;
  final Book bottomEdgeLeft;
  final Book bottomInnerLeft;
  final Book bottomInnerRight;
  final Book bottomEdgeRight;
  final int duplicateVisualGroupCount;

  BookColor get topEdgeColor => topEdgeLeft.color;

  BookColor get topMiddleColor => topMiddleLeft.color;

  BookColor get bottomEdgeColor => bottomEdgeLeft.color;

  static T04TierGroupingShape? fromPlacements(
    List<BookPlacement> placements, {
    int? duplicateGroupCount,
  }) {
    final sorted = List<BookPlacement>.of(placements)
      ..sort(_comparePlacementPosition);
    if (sorted.length != 8) {
      return null;
    }
    for (var tierIndex = 0; tierIndex < 2; tierIndex += 1) {
      for (var slotIndex = 0; slotIndex < 4; slotIndex += 1) {
        final flatIndex = (tierIndex * 4) + slotIndex;
        final position = sorted[flatIndex].position;
        if (position.tierIndex != tierIndex ||
            position.slotIndex != slotIndex) {
          return null;
        }
      }
    }

    final topEdgeLeft = sorted[0].book;
    final topMiddleLeft = sorted[1].book;
    final topMiddleRight = sorted[2].book;
    final topEdgeRight = sorted[3].book;
    final bottomEdgeLeft = sorted[4].book;
    final bottomInnerLeft = sorted[5].book;
    final bottomInnerRight = sorted[6].book;
    final bottomEdgeRight = sorted[7].book;

    if (topEdgeLeft.color != topEdgeRight.color ||
        topEdgeLeft.symbol == topEdgeRight.symbol) {
      return null;
    }
    if (topMiddleLeft.color != topMiddleRight.color) {
      return null;
    }
    if (bottomEdgeLeft.color != bottomEdgeRight.color ||
        bottomEdgeLeft.symbol == bottomEdgeRight.symbol) {
      return null;
    }
    if (bottomInnerLeft.color == bottomInnerRight.color) {
      return null;
    }

    final colors = {
      topEdgeLeft.color,
      topMiddleLeft.color,
      bottomEdgeLeft.color,
      bottomInnerLeft.color,
      bottomInnerRight.color,
    };
    if (colors.length != 5) {
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
        visualKey(book),
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    final duplicateEntries = visualCounts.entries
        .where((entry) => entry.value > 1)
        .toList(growable: false);
    if (duplicateGroupCount != null &&
        duplicateEntries.length != duplicateGroupCount) {
      return null;
    }

    if (duplicateGroupCount == 0) {
      if (topMiddleLeft.symbol == topMiddleRight.symbol) {
        return null;
      }
    } else if (duplicateGroupCount == 1) {
      if (duplicateEntries.length != 1 || duplicateEntries.single.value != 2) {
        return null;
      }
      if (visualKey(topMiddleLeft) != visualKey(topMiddleRight) ||
          topMiddleLeft.id == topMiddleRight.id) {
        return null;
      }
      final expectedCopy01 = BookInstanceCode.duplicateCopyId(
        color: topMiddleLeft.color,
        symbol: topMiddleLeft.symbol,
        copyNumber: 1,
      );
      final expectedCopy02 = BookInstanceCode.duplicateCopyId(
        color: topMiddleRight.color,
        symbol: topMiddleRight.symbol,
        copyNumber: 2,
      );
      if (topMiddleLeft.id != expectedCopy01 ||
          topMiddleRight.id != expectedCopy02) {
        return null;
      }
    } else if (duplicateGroupCount != null) {
      return null;
    }

    if (duplicateEntries.any((entry) => entry.value != 2)) {
      return null;
    }
    if (duplicateEntries.isNotEmpty &&
        (duplicateEntries.length != 1 ||
            duplicateEntries.single.key != visualKey(topMiddleLeft))) {
      return null;
    }

    return T04TierGroupingShape(
      topEdgeLeft: topEdgeLeft,
      topMiddleLeft: topMiddleLeft,
      topMiddleRight: topMiddleRight,
      topEdgeRight: topEdgeRight,
      bottomEdgeLeft: bottomEdgeLeft,
      bottomInnerLeft: bottomInnerLeft,
      bottomInnerRight: bottomInnerRight,
      bottomEdgeRight: bottomEdgeRight,
      duplicateVisualGroupCount: duplicateEntries.length,
    );
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

String visualKey(Book book) {
  return BookCode.bookId(color: book.color, symbol: book.symbol);
}
