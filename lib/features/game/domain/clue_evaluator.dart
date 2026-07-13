import 'book_placement.dart';
import 'book_selector.dart';
import 'book_selector_resolver.dart';
import 'clue.dart';

class ClueEvaluator {
  const ClueEvaluator({this.selectorResolver = const BookSelectorResolver()});

  final BookSelectorResolver selectorResolver;

  bool evaluate({required Clue clue, required List<BookPlacement> placements}) {
    return switch (clue) {
      EdgePositionClue() => _evaluateEdgePosition(clue, placements),
      RelativeOrderClue() => _evaluateRelativeOrder(clue, placements),
      AdjacentClue() => _evaluateAdjacent(clue, placements),
    };
  }

  Set<String> evaluateAll({
    required List<Clue> clues,
    required List<BookPlacement> placements,
  }) {
    final satisfiedIds = <String>{};

    for (final clue in clues) {
      if (evaluate(clue: clue, placements: placements)) {
        satisfiedIds.add(clue.id);
      }
    }
    return Set.unmodifiable(satisfiedIds);
  }

  bool _evaluateEdgePosition(
    EdgePositionClue clue,
    List<BookPlacement> placements,
  ) {
    final subject = _resolveSingle(clue.subject, placements);
    if (subject == null || subject.position.tierIndex != clue.tierIndex) {
      return false;
    }

    final tierPlacements = placements
        .where((placement) => placement.position.tierIndex == clue.tierIndex)
        .toList();
    if (tierPlacements.isEmpty) {
      return false;
    }

    final edgeSlot = switch (clue.edge) {
      ShelfEdge.left => _minSlotIndex(tierPlacements),
      ShelfEdge.right => _maxSlotIndex(tierPlacements),
    };
    return subject.position.slotIndex == edgeSlot;
  }

  bool _evaluateRelativeOrder(
    RelativeOrderClue clue,
    List<BookPlacement> placements,
  ) {
    final subject = _resolveSingle(clue.subject, placements);
    final reference = _resolveSingle(clue.reference, placements);
    if (!_canCompare(subject, reference, clue.tierIndex)) {
      return false;
    }

    return switch (clue.relation) {
      HorizontalRelation.leftOf =>
        subject!.position.slotIndex < reference!.position.slotIndex,
      HorizontalRelation.rightOf =>
        subject!.position.slotIndex > reference!.position.slotIndex,
    };
  }

  bool _evaluateAdjacent(AdjacentClue clue, List<BookPlacement> placements) {
    final subject = _resolveSingle(clue.subject, placements);
    final reference = _resolveSingle(clue.reference, placements);
    if (!_canCompare(subject, reference, clue.tierIndex)) {
      return false;
    }

    return switch (clue.direction) {
      AdjacentDirection.immediatelyLeftOf =>
        subject!.position.slotIndex == reference!.position.slotIndex - 1,
      AdjacentDirection.immediatelyRightOf =>
        subject!.position.slotIndex == reference!.position.slotIndex + 1,
    };
  }

  BookPlacement? _resolveSingle(
    BookSelector selector,
    List<BookPlacement> placements,
  ) {
    final resolved = selectorResolver.resolve(
      selector: selector,
      placements: placements,
    );
    if (resolved.length != 1) {
      return null;
    }
    return resolved.single;
  }

  bool _canCompare(
    BookPlacement? subject,
    BookPlacement? reference,
    int tierIndex,
  ) {
    if (subject == null || reference == null) {
      return false;
    }
    if (subject.book.id == reference.book.id) {
      return false;
    }
    if (subject.position.tierIndex != tierIndex ||
        reference.position.tierIndex != tierIndex) {
      return false;
    }
    return subject.position.slotIndex != reference.position.slotIndex;
  }

  int _minSlotIndex(List<BookPlacement> placements) {
    return placements
        .map((placement) => placement.position.slotIndex)
        .reduce((value, element) => value < element ? value : element);
  }

  int _maxSlotIndex(List<BookPlacement> placements) {
    return placements
        .map((placement) => placement.position.slotIndex)
        .reduce((value, element) => value > element ? value : element);
  }
}
