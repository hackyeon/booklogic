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
      BothEdgesClue() => _evaluateBothEdges(clue, placements),
      RelativeOrderClue() => _evaluateRelativeOrder(clue, placements),
      BetweenClue() => _evaluateBetween(clue, placements),
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
    final subjects = _resolveInTier(clue.subject, placements, clue.tierIndex);
    final references = _resolveInTier(
      clue.reference,
      placements,
      clue.tierIndex,
    );
    if (subjects.isEmpty || references.isEmpty) {
      return false;
    }

    final subjectSlots = [
      for (final placement in subjects) placement.position.slotIndex,
    ];
    final referenceSlots = [
      for (final placement in references) placement.position.slotIndex,
    ];

    return switch (clue.relation) {
      HorizontalRelation.leftOf =>
        _maxInt(subjectSlots) < _minInt(referenceSlots),
      HorizontalRelation.rightOf =>
        _minInt(subjectSlots) > _maxInt(referenceSlots),
    };
  }

  bool _evaluateBothEdges(BothEdgesClue clue, List<BookPlacement> placements) {
    final subjects = _resolveInTier(clue.subject, placements, clue.tierIndex);
    if (subjects.length != 2) {
      return false;
    }

    final tierPlacements = placements
        .where((placement) => placement.position.tierIndex == clue.tierIndex)
        .toList();
    if (tierPlacements.length < 2) {
      return false;
    }

    final edgeSlots = {
      _minSlotIndex(tierPlacements),
      _maxSlotIndex(tierPlacements),
    };
    final subjectSlots = {
      for (final placement in subjects) placement.position.slotIndex,
    };
    if (subjectSlots.length != 2) {
      return false;
    }
    return _setEquals(subjectSlots, edgeSlots);
  }

  bool _evaluateBetween(BetweenClue clue, List<BookPlacement> placements) {
    final subjects = _resolveInTier(clue.subject, placements, clue.tierIndex);
    final boundaries = _resolveInTier(
      clue.boundary,
      placements,
      clue.tierIndex,
    );
    if (subjects.isEmpty || boundaries.length != 2) {
      return false;
    }

    final boundarySlots = [
      for (final placement in boundaries) placement.position.slotIndex,
    ];
    if (boundarySlots.first == boundarySlots.last) {
      return false;
    }
    final leftBoundary = _minInt(boundarySlots);
    final rightBoundary = _maxInt(boundarySlots);
    for (final subject in subjects) {
      final slotIndex = subject.position.slotIndex;
      if (slotIndex <= leftBoundary || slotIndex >= rightBoundary) {
        return false;
      }
    }
    return true;
  }

  bool _evaluateAdjacent(AdjacentClue clue, List<BookPlacement> placements) {
    final subjects = _resolveInTier(clue.subject, placements, clue.tierIndex);
    final references = _resolveInTier(
      clue.reference,
      placements,
      clue.tierIndex,
    );
    if (subjects.isEmpty || references.isEmpty) {
      return false;
    }

    final subjectIds = {for (final placement in subjects) placement.book.id};
    for (final reference in references) {
      if (subjectIds.contains(reference.book.id)) {
        return false;
      }
    }

    final subjectSlots = [
      for (final placement in subjects) placement.position.slotIndex,
    ];
    final referenceSlots = [
      for (final placement in references) placement.position.slotIndex,
    ];
    if (!_hasUniqueSlots(subjectSlots) ||
        !_hasUniqueSlots(referenceSlots) ||
        !_isContiguous(subjectSlots) ||
        !_isContiguous(referenceSlots)) {
      return false;
    }

    return switch (clue.direction) {
      AdjacentDirection.immediatelyLeftOf =>
        _maxInt(subjectSlots) + 1 == _minInt(referenceSlots),
      AdjacentDirection.immediatelyRightOf =>
        _minInt(subjectSlots) == _maxInt(referenceSlots) + 1,
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

  List<BookPlacement> _resolveInTier(
    BookSelector selector,
    List<BookPlacement> placements,
    int tierIndex,
  ) {
    return selectorResolver
        .resolve(selector: selector, placements: placements)
        .where((placement) => placement.position.tierIndex == tierIndex)
        .toList(growable: false);
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

  int _minInt(List<int> values) {
    return values.reduce((value, element) => value < element ? value : element);
  }

  int _maxInt(List<int> values) {
    return values.reduce((value, element) => value > element ? value : element);
  }

  bool _hasUniqueSlots(List<int> values) {
    return values.toSet().length == values.length;
  }

  bool _isContiguous(List<int> values) {
    if (values.isEmpty) {
      return false;
    }
    final sorted = List<int>.of(values)..sort();
    for (var index = 0; index < sorted.length - 1; index += 1) {
      if (sorted[index] + 1 != sorted[index + 1]) {
        return false;
      }
    }
    return true;
  }

  bool _setEquals(Set<int> left, Set<int> right) {
    if (left.length != right.length) {
      return false;
    }
    for (final value in left) {
      if (!right.contains(value)) {
        return false;
      }
    }
    return true;
  }
}
