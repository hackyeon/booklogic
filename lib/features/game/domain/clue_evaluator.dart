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
      TierAssignmentClue() => _evaluateTierAssignment(clue, placements),
      SameTierClue() => _evaluateSameTier(clue, placements),
      AdjacentClue() => _evaluateAdjacent(clue, placements),
      VerticalRelationClue() => _evaluateVerticalRelation(clue, placements),
      NotAtEdgeClue() => _evaluateNotAtEdge(clue, placements),
      DistanceClue() => _evaluateDistance(clue, placements),
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
    final subjects = selectorResolver.resolve(
      selector: clue.subject,
      placements: placements,
    );
    final references = selectorResolver.resolve(
      selector: clue.reference,
      placements: placements,
    );
    if (subjects.isEmpty || references.isEmpty) {
      return false;
    }
    if (!_allInTier(subjects, clue.tierIndex) ||
        !_allInTier(references, clue.tierIndex)) {
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
    final subjects = selectorResolver.resolve(
      selector: clue.subject,
      placements: placements,
    );
    if (subjects.length != 2) {
      return false;
    }
    if (!_allInTier(subjects, clue.tierIndex)) {
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
    final subjects = selectorResolver.resolve(
      selector: clue.subject,
      placements: placements,
    );
    final boundaries = selectorResolver.resolve(
      selector: clue.boundary,
      placements: placements,
    );
    if (subjects.isEmpty || boundaries.length != 2) {
      return false;
    }
    if (!_allInTier(subjects, clue.tierIndex) ||
        !_allInTier(boundaries, clue.tierIndex)) {
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

  bool _evaluateTierAssignment(
    TierAssignmentClue clue,
    List<BookPlacement> placements,
  ) {
    final subjects = selectorResolver.resolve(
      selector: clue.subject,
      placements: placements,
    );
    if (subjects.isEmpty) {
      return false;
    }
    return _allInTier(subjects, clue.tierIndex);
  }

  bool _evaluateSameTier(SameTierClue clue, List<BookPlacement> placements) {
    final first = selectorResolver.resolve(
      selector: clue.first,
      placements: placements,
    );
    final second = selectorResolver.resolve(
      selector: clue.second,
      placements: placements,
    );
    if (first.isEmpty || second.isEmpty) {
      return false;
    }

    final firstIds = {for (final placement in first) placement.book.id};
    for (final placement in second) {
      if (firstIds.contains(placement.book.id)) {
        return false;
      }
    }

    final tierIndexes = <int>{};
    for (final placement in first) {
      tierIndexes.add(placement.position.tierIndex);
    }
    for (final placement in second) {
      tierIndexes.add(placement.position.tierIndex);
    }
    return tierIndexes.length == 1;
  }

  bool _evaluateAdjacent(AdjacentClue clue, List<BookPlacement> placements) {
    final subjects = selectorResolver.resolve(
      selector: clue.subject,
      placements: placements,
    );
    final references = selectorResolver.resolve(
      selector: clue.reference,
      placements: placements,
    );
    if (subjects.isEmpty || references.isEmpty) {
      return false;
    }
    if (!_allInTier(subjects, clue.tierIndex) ||
        !_allInTier(references, clue.tierIndex)) {
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

  bool _evaluateVerticalRelation(
    VerticalRelationClue clue,
    List<BookPlacement> placements,
  ) {
    final subject = _resolveSingle(clue.subject, placements);
    final reference = _resolveSingle(clue.reference, placements);
    if (subject == null || reference == null) {
      return false;
    }
    if (subject.book.id == reference.book.id ||
        subject.position.slotIndex != reference.position.slotIndex) {
      return false;
    }
    return switch (clue.relation) {
      VerticalRelation.immediatelyAbove =>
        subject.position.tierIndex + 1 == reference.position.tierIndex,
      VerticalRelation.immediatelyBelow =>
        subject.position.tierIndex == reference.position.tierIndex + 1,
    };
  }

  bool _evaluateNotAtEdge(NotAtEdgeClue clue, List<BookPlacement> placements) {
    final subjects = selectorResolver.resolve(
      selector: clue.subject,
      placements: placements,
    );
    if (subjects.isEmpty || !_allInTier(subjects, clue.tierIndex)) {
      return false;
    }
    final tierPlacements = placements
        .where((placement) => placement.position.tierIndex == clue.tierIndex)
        .toList();
    if (tierPlacements.length < 3) {
      return false;
    }
    final lastSlotIndex = _maxSlotIndex(tierPlacements);
    for (final subject in subjects) {
      final slotIndex = subject.position.slotIndex;
      if (slotIndex <= 0 || slotIndex >= lastSlotIndex) {
        return false;
      }
    }
    return true;
  }

  bool _evaluateDistance(DistanceClue clue, List<BookPlacement> placements) {
    final first = _resolveSingle(clue.first, placements);
    final second = _resolveSingle(clue.second, placements);
    if (first == null ||
        second == null ||
        first.book.id == second.book.id ||
        first.position.tierIndex != clue.tierIndex ||
        second.position.tierIndex != clue.tierIndex) {
      return false;
    }
    final distance =
        (first.position.slotIndex - second.position.slotIndex).abs() - 1;
    return distance == clue.booksBetween;
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

  bool _allInTier(List<BookPlacement> placements, int tierIndex) {
    for (final placement in placements) {
      if (placement.position.tierIndex != tierIndex) {
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
