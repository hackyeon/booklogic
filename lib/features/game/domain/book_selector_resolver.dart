import 'book_placement.dart';
import 'book_selector.dart';

class BookSelectorResolver {
  const BookSelectorResolver();

  List<BookPlacement> resolve({
    required BookSelector selector,
    required List<BookPlacement> placements,
  }) {
    final resolved = switch (selector) {
      BookIdSelector(:final bookId) =>
        placements.where((placement) => placement.book.id == bookId).toList(),
      BookColorSelector(:final color) =>
        placements.where((placement) => placement.book.color == color).toList(),
      BookSymbolSelector(:final symbol) =>
        placements
            .where((placement) => placement.book.symbol == symbol)
            .toList(),
    };

    resolved.sort(_comparePlacementPosition);
    return resolved;
  }

  int _comparePlacementPosition(BookPlacement left, BookPlacement right) {
    final tierComparison = left.position.tierIndex.compareTo(
      right.position.tierIndex,
    );
    if (tierComparison != 0) {
      return tierComparison;
    }
    return left.position.slotIndex.compareTo(right.position.slotIndex);
  }
}
