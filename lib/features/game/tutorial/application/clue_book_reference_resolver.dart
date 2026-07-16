import 'dart:collection';

import '../../domain/book_placement.dart';
import '../../domain/book_selector.dart';
import '../../domain/book_selector_resolver.dart';
import '../../domain/clue.dart';

class ClueBookReferenceResolver {
  const ClueBookReferenceResolver({
    this.selectorResolver = const BookSelectorResolver(),
  });

  final BookSelectorResolver selectorResolver;

  List<String> resolveBookIds({
    required Clue clue,
    required List<BookPlacement> placements,
  }) {
    final selectors = switch (clue) {
      TierAssignmentClue(:final subject) => [subject],
      EdgePositionClue(:final subject) => [subject],
      BothEdgesClue(:final subject) => [subject],
      RelativeOrderClue(:final subject, :final reference) => [
        subject,
        reference,
      ],
      AdjacentClue(:final subject, :final reference) => [subject, reference],
      BetweenClue(:final subject, :final boundary) => [subject, boundary],
      SameTierClue(:final first, :final second) => [first, second],
      VerticalRelationClue(:final subject, :final reference) => [
        subject,
        reference,
      ],
      NotAtEdgeClue(:final subject) => [subject],
      DistanceClue(:final first, :final second) => [first, second],
    };

    final placementsByBookId = <String, BookPlacement>{};
    for (final selector in selectors) {
      _collectSelectorBooks(
        selector: selector,
        placements: placements,
        placementsByBookId: placementsByBookId,
      );
    }

    final orderedPlacements = placementsByBookId.values.toList()
      ..sort(_comparePlacementPosition);
    return UnmodifiableListView(
      orderedPlacements.map((placement) => placement.book.id).toList(),
    );
  }

  void _collectSelectorBooks({
    required BookSelector selector,
    required List<BookPlacement> placements,
    required Map<String, BookPlacement> placementsByBookId,
  }) {
    final resolvedPlacements = selectorResolver.resolve(
      selector: selector,
      placements: placements,
    );
    for (final placement in resolvedPlacements) {
      placementsByBookId.putIfAbsent(placement.book.id, () => placement);
    }
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
