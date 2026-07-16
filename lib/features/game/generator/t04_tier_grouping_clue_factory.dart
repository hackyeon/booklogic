import '../domain/book_placement.dart';
import '../domain/book_selector.dart';
import '../domain/book_selector_resolver.dart';
import '../domain/clue.dart';
import '../domain/clue_evaluator.dart';
import 'book_code.dart';
import 'puzzle_template_id.dart';
import 't04_tier_grouping_support.dart';
import 'template_solution.dart';

class T04TierGroupingClueFactory {
  const T04TierGroupingClueFactory({
    this.clueEvaluator = const ClueEvaluator(),
    this.selectorResolver = const BookSelectorResolver(),
  });

  final ClueEvaluator clueEvaluator;
  final BookSelectorResolver selectorResolver;

  bool supports(TemplateSolution solution) {
    final spec = solution.stageSpec;
    if (solution.templateId != PuzzleTemplateId.t04TierGrouping) {
      return false;
    }
    if (spec.tierCount != 2 ||
        spec.booksPerTier != 4 ||
        spec.totalBookCount != 8 ||
        (spec.duplicateGroupCount != 0 && spec.duplicateGroupCount != 1) ||
        spec.clueCount < 4 ||
        spec.clueCount > maxClueCount(solution)) {
      return false;
    }
    return T04TierGroupingShape.fromPlacements(
          solution.targetPlacements,
          duplicateGroupCount: spec.duplicateGroupCount,
        ) !=
        null;
  }

  int maxClueCount(TemplateSolution solution) {
    if (solution.templateId != PuzzleTemplateId.t04TierGrouping) {
      return 0;
    }
    return 6;
  }

  List<Clue> create(TemplateSolution solution) {
    if (!supports(solution)) {
      throw StateError(
        'T04 Tier Grouping does not support this TemplateSolution.',
      );
    }

    final targetPlacements = _sortedPlacements(solution.targetPlacements);
    final shape = T04TierGroupingShape.fromPlacements(
      targetPlacements,
      duplicateGroupCount: solution.stageSpec.duplicateGroupCount,
    );
    if (shape == null) {
      throw StateError('T04 target structure is invalid.');
    }

    final candidates = _buildCandidates(shape);
    final selectedClues = candidates
        .take(solution.stageSpec.clueCount)
        .toList(growable: false);
    _validateGeneratedClues(
      clues: selectedClues,
      targetPlacements: targetPlacements,
      expectedClueCount: solution.stageSpec.clueCount,
    );
    return List<Clue>.unmodifiable(selectedClues);
  }

  List<Clue> _buildCandidates(T04TierGroupingShape shape) {
    final topEdgeColorCode = BookCode.color(shape.topEdgeColor);
    final topMiddleColorCode = BookCode.color(shape.topMiddleColor);
    final bottomEdgeColorCode = BookCode.color(shape.bottomEdgeColor);
    return [
      TierAssignmentClue(
        id: 't04_c01_00_${topEdgeColorCode}_tier_0',
        subject: BookColorSelector(color: shape.topEdgeColor),
        tierIndex: 0,
      ),
      TierAssignmentClue(
        id: 't04_c01_01_${bottomEdgeColorCode}_tier_1',
        subject: BookColorSelector(color: shape.bottomEdgeColor),
        tierIndex: 1,
      ),
      BothEdgesClue(
        id: 't04_c03_02_${topEdgeColorCode}_both_edges_tier_0',
        subject: BookColorSelector(color: shape.topEdgeColor),
        tierIndex: 0,
      ),
      BetweenClue(
        id: 't04_c06_03_${topMiddleColorCode}_between_${topEdgeColorCode}_tier_0',
        subject: BookColorSelector(color: shape.topMiddleColor),
        boundary: BookColorSelector(color: shape.topEdgeColor),
        tierIndex: 0,
      ),
      SameTierClue(
        id: 't04_c07_04_${shape.bottomInnerLeft.id}_same_tier_as_${shape.bottomInnerRight.id}',
        first: BookIdSelector(bookId: shape.bottomInnerLeft.id),
        second: BookIdSelector(bookId: shape.bottomInnerRight.id),
      ),
      RelativeOrderClue(
        id: 't04_c04_05_${shape.bottomInnerLeft.id}_left_of_${shape.bottomInnerRight.id}_tier_1',
        subject: BookIdSelector(bookId: shape.bottomInnerLeft.id),
        reference: BookIdSelector(bookId: shape.bottomInnerRight.id),
        tierIndex: 1,
        relation: HorizontalRelation.leftOf,
      ),
    ];
  }

  void _validateGeneratedClues({
    required List<Clue> clues,
    required List<BookPlacement> targetPlacements,
    required int expectedClueCount,
  }) {
    if (clues.length != expectedClueCount) {
      throw StateError('T04 generated an unexpected clue count.');
    }
    final clueIds = <String>{};
    for (var index = 0; index < clues.length; index += 1) {
      final clue = clues[index];
      if (!clueIds.add(clue.id)) {
        throw StateError('T04 generated duplicate clue id: ${clue.id}');
      }
      if (!RegExp(r'^[a-z0-9_]+$').hasMatch(clue.id)) {
        throw StateError('T04 generated an invalid clue id: ${clue.id}');
      }
      if (!clueEvaluator.evaluate(clue: clue, placements: targetPlacements)) {
        throw StateError('T04 generated an unsatisfied clue: ${clue.id}');
      }
      if (!_matchesExpectedType(index: index, clue: clue)) {
        throw StateError('T04 generated an invalid clue sequence.');
      }
      _validateSelectorCounts(clue: clue, targetPlacements: targetPlacements);
    }

    final satisfiedIds = clueEvaluator.evaluateAll(
      clues: clues,
      placements: targetPlacements,
    );
    if (satisfiedIds.length != clues.length) {
      throw StateError('T04 evaluateAll did not satisfy every generated clue.');
    }
  }

  bool _matchesExpectedType({required int index, required Clue clue}) {
    return switch (index) {
      0 => clue is TierAssignmentClue,
      1 => clue is TierAssignmentClue,
      2 => clue is BothEdgesClue,
      3 => clue is BetweenClue,
      4 => clue is SameTierClue,
      5 => clue is RelativeOrderClue,
      _ => false,
    };
  }

  void _validateSelectorCounts({
    required Clue clue,
    required List<BookPlacement> targetPlacements,
  }) {
    switch (clue) {
      case TierAssignmentClue(:final subject):
        _expectResolveCount(subject, targetPlacements, 2, clue.id);
      case BothEdgesClue(:final subject):
        _expectResolveCount(subject, targetPlacements, 2, clue.id);
      case BetweenClue(:final subject, :final boundary):
        _expectResolveCount(subject, targetPlacements, 2, clue.id);
        _expectResolveCount(boundary, targetPlacements, 2, clue.id);
      case SameTierClue(:final first, :final second):
        _expectResolveCount(first, targetPlacements, 1, clue.id);
        _expectResolveCount(second, targetPlacements, 1, clue.id);
      case RelativeOrderClue(:final subject, :final reference):
        _expectResolveCount(subject, targetPlacements, 1, clue.id);
        _expectResolveCount(reference, targetPlacements, 1, clue.id);
      case EdgePositionClue():
      case AdjacentClue():
      case VerticalRelationClue():
      case NotAtEdgeClue():
      case DistanceClue():
        throw StateError('T04 generated an unsupported clue type: ${clue.id}');
    }
  }

  void _expectResolveCount(
    BookSelector selector,
    List<BookPlacement> placements,
    int expectedCount,
    String clueId,
  ) {
    final resolved = selectorResolver.resolve(
      selector: selector,
      placements: placements,
    );
    if (resolved.length != expectedCount) {
      throw StateError('T04 selector count mismatch for clue $clueId.');
    }
  }

  List<BookPlacement> _sortedPlacements(List<BookPlacement> placements) {
    final sorted = List<BookPlacement>.of(placements);
    sorted.sort(_comparePlacementPosition);
    return sorted;
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
