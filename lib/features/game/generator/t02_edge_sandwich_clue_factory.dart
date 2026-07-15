import '../domain/book.dart';
import '../domain/book_placement.dart';
import '../domain/book_selector.dart';
import '../domain/clue.dart';
import '../domain/clue_evaluator.dart';
import 'book_code.dart';
import 'puzzle_template_id.dart';
import 'template_solution.dart';

class T02EdgeSandwichClueFactory {
  const T02EdgeSandwichClueFactory({
    this.clueEvaluator = const ClueEvaluator(),
  });

  final ClueEvaluator clueEvaluator;

  bool supports(TemplateSolution solution) {
    final spec = solution.stageSpec;
    final targetPlacements = solution.targetPlacements;

    if (solution.templateId != PuzzleTemplateId.t02EdgeSandwich) {
      return false;
    }
    if (spec.tierCount != 1 ||
        spec.booksPerTier != 6 ||
        spec.totalBookCount != 6 ||
        spec.duplicateGroupCount != 1 ||
        spec.clueCount < 4 ||
        spec.clueCount > maxClueCount(solution)) {
      return false;
    }
    if (targetPlacements.length != 6) {
      return false;
    }
    return _targetShape(targetPlacements) != null;
  }

  int maxClueCount(TemplateSolution solution) {
    if (solution.templateId != PuzzleTemplateId.t02EdgeSandwich) {
      return 0;
    }
    return 5;
  }

  List<Clue> create(TemplateSolution solution) {
    if (!supports(solution)) {
      throw StateError(
        'T02 Edge Sandwich does not support this TemplateSolution.',
      );
    }

    final targetPlacements = _sortedTargetPlacements(solution);
    final shape = _targetShape(targetPlacements);
    if (shape == null) {
      throw StateError('T02 target structure is invalid.');
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

  List<Clue> _buildCandidates(_T02TargetShape shape) {
    final edgeColorCode = BookCode.color(shape.edgeLeft.color);
    final duplicateColorCode = BookCode.color(shape.duplicateCopy01.color);
    return [
      BothEdgesClue(
        id: 't02_c03_00_${edgeColorCode}_both_edges',
        subject: BookColorSelector(color: shape.edgeLeft.color),
        tierIndex: 0,
      ),
      BetweenClue(
        id: 't02_c06_01_${duplicateColorCode}_between_$edgeColorCode',
        subject: BookColorSelector(color: shape.duplicateCopy01.color),
        boundary: BookColorSelector(color: shape.edgeLeft.color),
        tierIndex: 0,
      ),
      AdjacentClue(
        id: 't02_c05_02_${shape.fillerB.id}_immediately_right_of_${shape.fillerA.id}',
        subject: BookIdSelector(bookId: shape.fillerB.id),
        reference: BookIdSelector(bookId: shape.fillerA.id),
        tierIndex: 0,
        direction: AdjacentDirection.immediatelyRightOf,
      ),
      RelativeOrderClue(
        id: 't02_c04_03_${shape.edgeLeft.id}_left_of_${shape.edgeRight.id}',
        subject: BookIdSelector(bookId: shape.edgeLeft.id),
        reference: BookIdSelector(bookId: shape.edgeRight.id),
        tierIndex: 0,
        relation: HorizontalRelation.leftOf,
      ),
      RelativeOrderClue(
        id: 't02_c04_04_${shape.fillerB.id}_left_of_${duplicateColorCode}_group',
        subject: BookIdSelector(bookId: shape.fillerB.id),
        reference: BookColorSelector(color: shape.duplicateCopy01.color),
        tierIndex: 0,
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
      throw StateError('T02 generated an unexpected clue count.');
    }
    final clueIds = <String>{};
    for (final clue in clues) {
      if (!clueIds.add(clue.id)) {
        throw StateError('T02 generated duplicate clue id: ${clue.id}');
      }
      if (!RegExp(r'^[a-z0-9_]+$').hasMatch(clue.id)) {
        throw StateError('T02 generated an invalid clue id: ${clue.id}');
      }
      if (!clueEvaluator.evaluate(clue: clue, placements: targetPlacements)) {
        throw StateError('T02 generated an unsatisfied clue: ${clue.id}');
      }
    }

    if (clues.isEmpty || clues.first is! BothEdgesClue) {
      throw StateError('T02 first clue must be BothEdgesClue.');
    }
    if (clues.length > 1 && clues[1] is! BetweenClue) {
      throw StateError('T02 second clue must be BetweenClue.');
    }
    if (clues.length > 2 && clues[2] is! AdjacentClue) {
      throw StateError('T02 third clue must be AdjacentClue.');
    }
    for (var index = 3; index < clues.length; index += 1) {
      if (clues[index] is! RelativeOrderClue) {
        throw StateError('T02 later clues must be RelativeOrderClue.');
      }
    }

    final satisfiedIds = clueEvaluator.evaluateAll(
      clues: clues,
      placements: targetPlacements,
    );
    if (satisfiedIds.length != clues.length) {
      throw StateError('T02 evaluateAll did not satisfy every generated clue.');
    }
  }

  _T02TargetShape? _targetShape(List<BookPlacement> placements) {
    final sorted = _sortedPlacements(placements);
    if (sorted.length != 6) {
      return null;
    }
    for (var index = 0; index < sorted.length; index += 1) {
      if (sorted[index].position.tierIndex != 0 ||
          sorted[index].position.slotIndex != index) {
        return null;
      }
    }

    final edgeLeft = sorted[0].book;
    final fillerA = sorted[1].book;
    final fillerB = sorted[2].book;
    final duplicateCopy01 = sorted[3].book;
    final duplicateCopy02 = sorted[4].book;
    final edgeRight = sorted[5].book;

    if (edgeLeft.color != edgeRight.color ||
        edgeLeft.symbol == edgeRight.symbol) {
      return null;
    }
    if (_visualKey(duplicateCopy01) != _visualKey(duplicateCopy02)) {
      return null;
    }
    if (duplicateCopy01.color == edgeLeft.color ||
        fillerA.color == edgeLeft.color ||
        fillerA.color == duplicateCopy01.color ||
        fillerB.color == edgeLeft.color ||
        fillerB.color == duplicateCopy01.color ||
        fillerB.color == fillerA.color) {
      return null;
    }
    return _T02TargetShape(
      edgeLeft: edgeLeft,
      fillerA: fillerA,
      fillerB: fillerB,
      duplicateCopy01: duplicateCopy01,
      duplicateCopy02: duplicateCopy02,
      edgeRight: edgeRight,
    );
  }

  List<BookPlacement> _sortedTargetPlacements(TemplateSolution solution) {
    return _sortedPlacements(solution.targetPlacements);
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

  String _visualKey(Book book) {
    return BookCode.bookId(color: book.color, symbol: book.symbol);
  }
}

class _T02TargetShape {
  const _T02TargetShape({
    required this.edgeLeft,
    required this.fillerA,
    required this.fillerB,
    required this.duplicateCopy01,
    required this.duplicateCopy02,
    required this.edgeRight,
  });

  final Book edgeLeft;
  final Book fillerA;
  final Book fillerB;
  final Book duplicateCopy01;
  final Book duplicateCopy02;
  final Book edgeRight;
}
