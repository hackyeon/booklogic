import '../domain/book_placement.dart';
import '../domain/book_selector.dart';
import '../domain/book_selector_resolver.dart';
import '../domain/clue.dart';
import '../domain/clue_evaluator.dart';
import 'book_code.dart';
import 'puzzle_template_id.dart';
import 't05_tier_order_support.dart';
import 'template_solution.dart';

class T05TierOrderClueFactory {
  const T05TierOrderClueFactory({
    this.clueEvaluator = const ClueEvaluator(),
    this.selectorResolver = const BookSelectorResolver(),
  });

  final ClueEvaluator clueEvaluator;
  final BookSelectorResolver selectorResolver;

  bool supports(TemplateSolution solution) {
    final spec = solution.stageSpec;
    if (solution.templateId != PuzzleTemplateId.t05TierOrder) {
      return false;
    }
    if (spec.tierCount != 2 ||
        spec.booksPerTier != 5 ||
        spec.totalBookCount != 10 ||
        (spec.duplicateGroupCount != 1 && spec.duplicateGroupCount != 2) ||
        spec.clueCount < 5 ||
        spec.clueCount > maxClueCount(solution)) {
      return false;
    }
    return T05TierOrderShape.fromPlacements(
          solution.targetPlacements,
          duplicateGroupCount: spec.duplicateGroupCount,
        ) !=
        null;
  }

  int maxClueCount(TemplateSolution solution) {
    if (solution.templateId != PuzzleTemplateId.t05TierOrder) {
      return 0;
    }
    return 7;
  }

  List<Clue> create(TemplateSolution solution) {
    if (!supports(solution)) {
      throw StateError(
        'T05 Tier Order does not support this TemplateSolution.',
      );
    }

    final targetPlacements = _sortedPlacements(solution.targetPlacements);
    final shape = T05TierOrderShape.fromPlacements(
      targetPlacements,
      duplicateGroupCount: solution.stageSpec.duplicateGroupCount,
    );
    if (shape == null) {
      throw StateError('T05 target structure is invalid.');
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

  List<Clue> _buildCandidates(T05TierOrderShape shape) {
    final topEdgeColorCode = BookCode.color(shape.topEdgeColor);
    final topBlockColorCode = BookCode.color(shape.topBlockColor);
    final bottomEdgeColorCode = BookCode.color(shape.bottomEdgeColor);
    final bottomBlockColorCode = BookCode.color(shape.bottomBlockColor);
    return [
      BothEdgesClue(
        id: 't05_c03_00_${topEdgeColorCode}_both_edges_tier_0',
        subject: BookColorSelector(color: shape.topEdgeColor),
        tierIndex: 0,
      ),
      AdjacentClue(
        id: 't05_c05_01_${shape.topCenter.id}_immediately_right_of_${topBlockColorCode}_group_tier_0',
        subject: BookIdSelector(bookId: shape.topCenter.id),
        reference: BookColorSelector(color: shape.topBlockColor),
        tierIndex: 0,
        direction: AdjacentDirection.immediatelyRightOf,
      ),
      BothEdgesClue(
        id: 't05_c03_02_${bottomEdgeColorCode}_both_edges_tier_1',
        subject: BookColorSelector(color: shape.bottomEdgeColor),
        tierIndex: 1,
      ),
      AdjacentClue(
        id: 't05_c05_03_${shape.bottomCenter.id}_immediately_right_of_${bottomBlockColorCode}_group_tier_1',
        subject: BookIdSelector(bookId: shape.bottomCenter.id),
        reference: BookColorSelector(color: shape.bottomBlockColor),
        tierIndex: 1,
        direction: AdjacentDirection.immediatelyRightOf,
      ),
      TierAssignmentClue(
        id: 't05_c01_04_${topBlockColorCode}_tier_0',
        subject: BookColorSelector(color: shape.topBlockColor),
        tierIndex: 0,
      ),
      TierAssignmentClue(
        id: 't05_c01_05_${bottomBlockColorCode}_tier_1',
        subject: BookColorSelector(color: shape.bottomBlockColor),
        tierIndex: 1,
      ),
      RelativeOrderClue(
        id: 't05_c04_06_${bottomBlockColorCode}_group_left_of_${shape.bottomCenter.id}_tier_1',
        subject: BookColorSelector(color: shape.bottomBlockColor),
        reference: BookIdSelector(bookId: shape.bottomCenter.id),
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
      throw StateError('T05 generated an unexpected clue count.');
    }
    final clueIds = <String>{};
    for (var index = 0; index < clues.length; index += 1) {
      final clue = clues[index];
      if (!clueIds.add(clue.id)) {
        throw StateError('T05 generated duplicate clue id: ${clue.id}');
      }
      if (!RegExp(r'^[a-z0-9_]+$').hasMatch(clue.id)) {
        throw StateError('T05 generated an invalid clue id: ${clue.id}');
      }
      if (!clueEvaluator.evaluate(clue: clue, placements: targetPlacements)) {
        throw StateError('T05 generated an unsatisfied clue: ${clue.id}');
      }
      if (!_matchesExpectedType(index: index, clue: clue)) {
        throw StateError('T05 generated an invalid clue sequence.');
      }
      _validateSelectorCounts(clue: clue, targetPlacements: targetPlacements);
    }

    final satisfiedIds = clueEvaluator.evaluateAll(
      clues: clues,
      placements: targetPlacements,
    );
    if (satisfiedIds.length != clues.length) {
      throw StateError('T05 evaluateAll did not satisfy every generated clue.');
    }
  }

  bool _matchesExpectedType({required int index, required Clue clue}) {
    return switch (index) {
      0 => clue is BothEdgesClue,
      1 => clue is AdjacentClue,
      2 => clue is BothEdgesClue,
      3 => clue is AdjacentClue,
      4 => clue is TierAssignmentClue,
      5 => clue is TierAssignmentClue,
      6 => clue is RelativeOrderClue,
      _ => false,
    };
  }

  void _validateSelectorCounts({
    required Clue clue,
    required List<BookPlacement> targetPlacements,
  }) {
    switch (clue) {
      case BothEdgesClue(:final subject):
        _expectResolveCount(subject, targetPlacements, 2, clue.id);
      case AdjacentClue(:final subject, :final reference):
        _expectResolveCount(subject, targetPlacements, 1, clue.id);
        _expectResolveCount(reference, targetPlacements, 2, clue.id);
      case TierAssignmentClue(:final subject):
        _expectResolveCount(subject, targetPlacements, 2, clue.id);
      case RelativeOrderClue(:final subject, :final reference):
        _expectResolveCount(subject, targetPlacements, 2, clue.id);
        _expectResolveCount(reference, targetPlacements, 1, clue.id);
      case EdgePositionClue():
      case BetweenClue():
      case SameTierClue():
      case VerticalRelationClue():
      case NotAtEdgeClue():
      case DistanceClue():
        throw StateError('T05 generated an unsupported clue type: ${clue.id}');
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
      throw StateError('T05 selector count mismatch for clue $clueId.');
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
