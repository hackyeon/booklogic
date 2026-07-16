import '../domain/book.dart';
import '../domain/book_placement.dart';
import '../domain/book_selector.dart';
import '../domain/book_selector_resolver.dart';
import '../domain/clue.dart';
import '../domain/clue_evaluator.dart';
import 'book_code.dart';
import 't06_rule_profile_resolver.dart';
import 'template_solution.dart';

class T06VerticalPairClueFactory {
  const T06VerticalPairClueFactory({
    this.profileResolver = const T06RuleProfileResolver(),
    this.clueEvaluator = const ClueEvaluator(),
    this.selectorResolver = const BookSelectorResolver(),
  });

  final T06RuleProfileResolver profileResolver;
  final ClueEvaluator clueEvaluator;
  final BookSelectorResolver selectorResolver;

  List<Clue> create(TemplateSolution solution) {
    final profile = profileResolver.resolve(solution.level);
    final sorted = _sorted(solution.targetPlacements);
    final verticalPairs = _verticalPairs(sorted);
    final interiorGroups = _interiorGroups(sorted);
    final adjacentPairs = _adjacentPairs(sorted);
    final distancePairs = _distancePairs(sorted);
    final candidates = switch (profile.id) {
      var id when id == T06RuleProfileResolver.verticalIntro2x6.id =>
        _verticalIntroCandidates(
          sorted: sorted,
          verticalPairs: verticalPairs,
          adjacentPairs: adjacentPairs,
        ),
      var id when id == T06RuleProfileResolver.verticalNegative2x6.id =>
        _verticalNegativeCandidates(
          sorted: sorted,
          verticalPairs: verticalPairs,
          interiorGroups: interiorGroups,
          adjacentPairs: adjacentPairs,
        ),
      var id when id == T06RuleProfileResolver.verticalThreeTier3x4.id =>
        _verticalThreeTierCandidates(
          sorted: sorted,
          verticalPairs: verticalPairs,
          interiorGroups: interiorGroups,
        ),
      _ => _fullAdvancedCandidates(
        sorted: sorted,
        verticalPairs: verticalPairs,
        interiorGroups: interiorGroups,
        distancePairs: distancePairs,
      ),
    };
    if (candidates.length < solution.stageSpec.clueCount) {
      throw StateError('T06 clue candidate count is insufficient.');
    }
    final clues = List<Clue>.unmodifiable(
      candidates.take(solution.stageSpec.clueCount),
    );
    _validateClues(solution: solution, clues: clues);
    return clues;
  }

  List<Clue> _verticalIntroCandidates({
    required List<BookPlacement> sorted,
    required List<_VerticalPair> verticalPairs,
    required List<_BookPair> adjacentPairs,
  }) {
    final topLeft = _at(sorted, 0, 0);
    final topRight = _at(sorted, 0, 5);
    return [
      _verticalClue(0, verticalPairs[0]),
      _verticalClue(1, verticalPairs[1]),
      SameTierClue(
        id: 't06_c07_02_${topLeft.book.id}_same_tier_as_${topRight.book.id}',
        first: BookIdSelector(bookId: topLeft.book.id),
        second: BookIdSelector(bookId: topRight.book.id),
      ),
      RelativeOrderClue(
        id: 't06_c04_03_${topLeft.book.id}_left_of_${topRight.book.id}_tier_0',
        subject: BookIdSelector(bookId: topLeft.book.id),
        reference: BookIdSelector(bookId: topRight.book.id),
        tierIndex: 0,
        relation: HorizontalRelation.leftOf,
      ),
      _adjacentClue(4, adjacentPairs.first),
      TierAssignmentClue(
        id: 't06_c01_05_${topLeft.book.id}_tier_0',
        subject: BookIdSelector(bookId: topLeft.book.id),
        tierIndex: 0,
      ),
    ];
  }

  List<Clue> _verticalNegativeCandidates({
    required List<BookPlacement> sorted,
    required List<_VerticalPair> verticalPairs,
    required List<_InteriorGroup> interiorGroups,
    required List<_BookPair> adjacentPairs,
  }) {
    final topLeft = _at(sorted, 0, 0);
    final topRight = _at(sorted, 0, 5);
    return [
      _verticalClue(0, verticalPairs[0]),
      _verticalClue(1, verticalPairs[1]),
      _notAtEdgeClue(2, interiorGroups.first),
      SameTierClue(
        id: 't06_c07_03_${topLeft.book.id}_same_tier_as_${topRight.book.id}',
        first: BookIdSelector(bookId: topLeft.book.id),
        second: BookIdSelector(bookId: topRight.book.id),
      ),
      RelativeOrderClue(
        id: 't06_c04_04_${topLeft.book.id}_left_of_${topRight.book.id}_tier_0',
        subject: BookIdSelector(bookId: topLeft.book.id),
        reference: BookIdSelector(bookId: topRight.book.id),
        tierIndex: 0,
        relation: HorizontalRelation.leftOf,
      ),
      _adjacentClue(5, adjacentPairs.first),
      TierAssignmentClue(
        id: 't06_c01_06_${topLeft.book.id}_tier_0',
        subject: BookIdSelector(bookId: topLeft.book.id),
        tierIndex: 0,
      ),
    ];
  }

  List<Clue> _verticalThreeTierCandidates({
    required List<BookPlacement> sorted,
    required List<_VerticalPair> verticalPairs,
    required List<_InteriorGroup> interiorGroups,
  }) {
    final topLeft = _at(sorted, 0, 0);
    final topRight = _at(sorted, 0, 3);
    final bottomLeft = _at(sorted, 2, 0);
    final bottomRight = _at(sorted, 2, 3);
    return [
      _verticalClue(0, verticalPairs[0]),
      _verticalClue(1, verticalPairs[1]),
      _verticalClue(2, verticalPairs[2]),
      _verticalClue(3, verticalPairs[3]),
      _notAtEdgeClue(4, interiorGroups.first),
      RelativeOrderClue(
        id: 't06_c04_05_${topLeft.book.id}_left_of_${topRight.book.id}_tier_0',
        subject: BookIdSelector(bookId: topLeft.book.id),
        reference: BookIdSelector(bookId: topRight.book.id),
        tierIndex: 0,
        relation: HorizontalRelation.leftOf,
      ),
      SameTierClue(
        id: 't06_c07_06_${bottomLeft.book.id}_same_tier_as_${bottomRight.book.id}',
        first: BookIdSelector(bookId: bottomLeft.book.id),
        second: BookIdSelector(bookId: bottomRight.book.id),
      ),
    ];
  }

  List<Clue> _fullAdvancedCandidates({
    required List<BookPlacement> sorted,
    required List<_VerticalPair> verticalPairs,
    required List<_InteriorGroup> interiorGroups,
    required List<_DistancePair> distancePairs,
  }) {
    final topLeft = _at(sorted, 0, 0);
    final topRight = _at(sorted, 0, 3);
    final bottomLeft = _at(sorted, 2, 0);
    final bottomRight = _at(sorted, 2, 3);
    return [
      _verticalClue(0, verticalPairs[0]),
      _verticalClue(1, verticalPairs[1]),
      _verticalClue(2, verticalPairs[2]),
      _verticalClue(3, verticalPairs[3]),
      _notAtEdgeClue(4, interiorGroups.first),
      _distanceClue(5, distancePairs.first),
      RelativeOrderClue(
        id: 't06_c04_06_${topLeft.book.id}_left_of_${topRight.book.id}_tier_0',
        subject: BookIdSelector(bookId: topLeft.book.id),
        reference: BookIdSelector(bookId: topRight.book.id),
        tierIndex: 0,
        relation: HorizontalRelation.leftOf,
      ),
      SameTierClue(
        id: 't06_c07_07_${bottomLeft.book.id}_same_tier_as_${bottomRight.book.id}',
        first: BookIdSelector(bookId: bottomLeft.book.id),
        second: BookIdSelector(bookId: bottomRight.book.id),
      ),
    ];
  }

  VerticalRelationClue _verticalClue(int index, _VerticalPair pair) {
    return VerticalRelationClue(
      id: 't06_c08_${_index(index)}_${pair.above.book.id}_immediately_above_${pair.below.book.id}',
      subject: BookIdSelector(bookId: pair.above.book.id),
      reference: BookIdSelector(bookId: pair.below.book.id),
      relation: VerticalRelation.immediatelyAbove,
    );
  }

  NotAtEdgeClue _notAtEdgeClue(int index, _InteriorGroup group) {
    final selector = group.selector;
    final selectorCode = switch (selector) {
      BookVisualSelector(:final color, :final symbol) =>
        'visual_${BookCode.color(color)}_${BookCode.symbol(symbol)}',
      BookIdSelector(:final bookId) => bookId,
      _ => throw StateError('T06 C09 uses unsupported selector.'),
    };
    return NotAtEdgeClue(
      id: 't06_c09_${_index(index)}_${selectorCode}_not_at_edge_tier_${group.tierIndex}',
      subject: selector,
      tierIndex: group.tierIndex,
    );
  }

  AdjacentClue _adjacentClue(int index, _BookPair pair) {
    return AdjacentClue(
      id: 't06_c05_${_index(index)}_${pair.left.book.id}_immediately_left_of_${pair.right.book.id}_tier_${pair.left.position.tierIndex}',
      subject: BookIdSelector(bookId: pair.left.book.id),
      reference: BookIdSelector(bookId: pair.right.book.id),
      tierIndex: pair.left.position.tierIndex,
      direction: AdjacentDirection.immediatelyLeftOf,
    );
  }

  DistanceClue _distanceClue(int index, _DistancePair pair) {
    return DistanceClue(
      id: 't06_c10_${_index(index)}_${pair.first.book.id}_${pair.booksBetween}_between_${pair.second.book.id}_tier_${pair.first.position.tierIndex}',
      first: BookIdSelector(bookId: pair.first.book.id),
      second: BookIdSelector(bookId: pair.second.book.id),
      tierIndex: pair.first.position.tierIndex,
      booksBetween: pair.booksBetween,
    );
  }

  List<_VerticalPair> _verticalPairs(List<BookPlacement> placements) {
    final visualCounts = _visualCounts(placements);
    final result = <_VerticalPair>[];
    for (final above in placements) {
      final below = _maybeAt(
        placements,
        above.position.tierIndex + 1,
        above.position.slotIndex,
      );
      if (below == null) {
        continue;
      }
      if ((visualCounts[_visualKey(above.book)] ?? 0) == 1 &&
          (visualCounts[_visualKey(below.book)] ?? 0) == 1) {
        result.add(_VerticalPair(above: above, below: below));
      }
    }
    result.sort((left, right) {
      final leftAnchor = _verticalAnchorRank(left);
      final rightAnchor = _verticalAnchorRank(right);
      if (leftAnchor != rightAnchor) {
        return leftAnchor.compareTo(rightAnchor);
      }
      final tier = left.above.position.tierIndex.compareTo(
        right.above.position.tierIndex,
      );
      if (tier != 0) {
        return tier;
      }
      return left.above.position.slotIndex.compareTo(
        right.above.position.slotIndex,
      );
    });
    return result;
  }

  int _verticalAnchorRank(_VerticalPair pair) {
    final slot = pair.above.position.slotIndex;
    if (pair.above.position.tierIndex == 0 && slot == 0) {
      return 0;
    }
    if (pair.above.position.tierIndex == 1 && slot == 0) {
      return 1;
    }
    if (pair.above.position.tierIndex == 0 && (slot == 3 || slot == 5)) {
      return 2;
    }
    if (pair.above.position.tierIndex == 1 && (slot == 3 || slot == 5)) {
      return 3;
    }
    return 10 + pair.above.position.slotIndex;
  }

  List<_InteriorGroup> _interiorGroups(List<BookPlacement> placements) {
    final byVisual = <String, List<BookPlacement>>{};
    for (final placement in placements) {
      byVisual.putIfAbsent(_visualKey(placement.book), () => []).add(placement);
    }
    final groups = <_InteriorGroup>[];
    for (final group in byVisual.values) {
      final tier = group.first.position.tierIndex;
      if (group.any((placement) => placement.position.tierIndex != tier)) {
        continue;
      }
      final maxSlot = placements
          .where((placement) => placement.position.tierIndex == tier)
          .map((placement) => placement.position.slotIndex)
          .reduce((left, right) => left > right ? left : right);
      if (group.any(
        (placement) =>
            placement.position.slotIndex <= 0 ||
            placement.position.slotIndex >= maxSlot,
      )) {
        continue;
      }
      final first = group.first.book;
      final selector = group.length > 1
          ? BookVisualSelector(color: first.color, symbol: first.symbol)
          : BookIdSelector(bookId: first.id);
      groups.add(
        _InteriorGroup(
          selector: selector,
          tierIndex: tier,
          minSlotIndex: group
              .map((placement) => placement.position.slotIndex)
              .reduce((left, right) => left < right ? left : right),
        ),
      );
    }
    groups.sort((left, right) {
      final tier = left.tierIndex.compareTo(right.tierIndex);
      if (tier != 0) {
        return tier;
      }
      final slot = left.minSlotIndex.compareTo(right.minSlotIndex);
      if (slot != 0) {
        return slot;
      }
      return _selectorCode(
        left.selector,
      ).compareTo(_selectorCode(right.selector));
    });
    return groups;
  }

  List<_BookPair> _adjacentPairs(List<BookPlacement> placements) {
    final visualCounts = _visualCounts(placements);
    final result = <_BookPair>[];
    for (final left in placements) {
      final right = _maybeAt(
        placements,
        left.position.tierIndex,
        left.position.slotIndex + 1,
      );
      if (right == null) {
        continue;
      }
      if ((visualCounts[_visualKey(left.book)] ?? 0) == 1 &&
          (visualCounts[_visualKey(right.book)] ?? 0) == 1) {
        result.add(_BookPair(left: left, right: right));
      }
    }
    return result;
  }

  List<_DistancePair> _distancePairs(List<BookPlacement> placements) {
    final visualCounts = _visualCounts(placements);
    final result = <_DistancePair>[];
    for (final first in placements) {
      if ((visualCounts[_visualKey(first.book)] ?? 0) != 1) {
        continue;
      }
      for (final second in placements) {
        if (second.position.tierIndex != first.position.tierIndex ||
            second.position.slotIndex <= first.position.slotIndex ||
            (visualCounts[_visualKey(second.book)] ?? 0) != 1) {
          continue;
        }
        final booksBetween =
            second.position.slotIndex - first.position.slotIndex - 1;
        if (booksBetween >= 1) {
          result.add(
            _DistancePair(
              first: first,
              second: second,
              booksBetween: booksBetween,
            ),
          );
        }
      }
    }
    return result;
  }

  void _validateClues({
    required TemplateSolution solution,
    required List<Clue> clues,
  }) {
    if (clues.length != solution.stageSpec.clueCount) {
      throw StateError('T06 clue count does not match StageSpec.');
    }
    final ids = <String>{};
    for (final clue in clues) {
      if (!ids.add(clue.id) ||
          !RegExp(r'^[a-z0-9_]+$').hasMatch(clue.id) ||
          !clueEvaluator.evaluate(
            clue: clue,
            placements: solution.targetPlacements,
          )) {
        throw StateError('T06 generated an invalid clue: ${clue.id}');
      }
      for (final selector in _selectorsFor(clue)) {
        if (selectorResolver
            .resolve(selector: selector, placements: solution.targetPlacements)
            .isEmpty) {
          throw StateError('T06 clue selector did not resolve: ${clue.id}');
        }
      }
    }
  }

  List<BookSelector> _selectorsFor(Clue clue) {
    return switch (clue) {
      EdgePositionClue(:final subject) => [subject],
      BothEdgesClue(:final subject) => [subject],
      RelativeOrderClue(:final subject, :final reference) => [
        subject,
        reference,
      ],
      BetweenClue(:final subject, :final boundary) => [subject, boundary],
      TierAssignmentClue(:final subject) => [subject],
      SameTierClue(:final first, :final second) => [first, second],
      AdjacentClue(:final subject, :final reference) => [subject, reference],
      VerticalRelationClue(:final subject, :final reference) => [
        subject,
        reference,
      ],
      NotAtEdgeClue(:final subject) => [subject],
      DistanceClue(:final first, :final second) => [first, second],
    };
  }

  BookPlacement _at(List<BookPlacement> placements, int tier, int slot) {
    return placements.firstWhere(
      (placement) =>
          placement.position.tierIndex == tier &&
          placement.position.slotIndex == slot,
    );
  }

  BookPlacement? _maybeAt(List<BookPlacement> placements, int tier, int slot) {
    for (final placement in placements) {
      if (placement.position.tierIndex == tier &&
          placement.position.slotIndex == slot) {
        return placement;
      }
    }
    return null;
  }

  List<BookPlacement> _sorted(List<BookPlacement> placements) {
    final sorted = List<BookPlacement>.of(placements);
    sorted.sort((left, right) {
      final tier = left.position.tierIndex.compareTo(right.position.tierIndex);
      if (tier != 0) {
        return tier;
      }
      return left.position.slotIndex.compareTo(right.position.slotIndex);
    });
    return sorted;
  }

  Map<String, int> _visualCounts(List<BookPlacement> placements) {
    final counts = <String, int>{};
    for (final placement in placements) {
      counts.update(
        _visualKey(placement.book),
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    return counts;
  }

  String _visualKey(Book book) {
    return BookCode.bookId(color: book.color, symbol: book.symbol);
  }

  String _selectorCode(BookSelector selector) {
    return switch (selector) {
      BookIdSelector(:final bookId) => bookId,
      BookColorSelector(:final color) => BookCode.color(color),
      BookSymbolSelector(:final symbol) => BookCode.symbol(symbol),
      BookVisualSelector(:final color, :final symbol) =>
        'visual_${BookCode.color(color)}_${BookCode.symbol(symbol)}',
    };
  }

  String _index(int index) {
    return index.toString().padLeft(2, '0');
  }
}

class _VerticalPair {
  const _VerticalPair({required this.above, required this.below});

  final BookPlacement above;
  final BookPlacement below;
}

class _BookPair {
  const _BookPair({required this.left, required this.right});

  final BookPlacement left;
  final BookPlacement right;
}

class _InteriorGroup {
  const _InteriorGroup({
    required this.selector,
    required this.tierIndex,
    required this.minSlotIndex,
  });

  final BookSelector selector;
  final int tierIndex;
  final int minSlotIndex;
}

class _DistancePair {
  const _DistancePair({
    required this.first,
    required this.second,
    required this.booksBetween,
  });

  final BookPlacement first;
  final BookPlacement second;
  final int booksBetween;
}
