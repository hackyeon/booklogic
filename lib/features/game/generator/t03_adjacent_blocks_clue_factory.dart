import '../domain/book.dart';
import '../domain/book_placement.dart';
import '../domain/book_selector.dart';
import '../domain/clue.dart';
import '../domain/clue_evaluator.dart';
import 'book_code.dart';
import 'puzzle_template_id.dart';
import 'template_solution.dart';

class T03AdjacentBlocksClueFactory {
  const T03AdjacentBlocksClueFactory({
    this.clueEvaluator = const ClueEvaluator(),
  });

  final ClueEvaluator clueEvaluator;

  bool supports(TemplateSolution solution) {
    final spec = solution.stageSpec;
    final targetPlacements = solution.targetPlacements;

    if (solution.templateId != PuzzleTemplateId.t03AdjacentBlocks) {
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
    if (solution.templateId != PuzzleTemplateId.t03AdjacentBlocks) {
      return 0;
    }
    return 5;
  }

  List<Clue> create(TemplateSolution solution) {
    if (!supports(solution)) {
      throw StateError(
        'T03 Adjacent Blocks does not support this TemplateSolution.',
      );
    }

    final targetPlacements = _sortedTargetPlacements(solution);
    final shape = _targetShape(targetPlacements);
    if (shape == null) {
      throw StateError('T03 target structure is invalid.');
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

  List<Clue> _buildCandidates(_T03TargetShape shape) {
    final duplicateColorCode = BookCode.color(shape.duplicateColor);
    return [
      AdjacentClue(
        id: 't03_c05_00_${shape.blockAMiddle.id}_immediately_right_of_${shape.blockAFirst.id}',
        subject: BookIdSelector(bookId: shape.blockAMiddle.id),
        reference: BookIdSelector(bookId: shape.blockAFirst.id),
        tierIndex: 0,
        direction: AdjacentDirection.immediatelyRightOf,
      ),
      AdjacentClue(
        id: 't03_c05_01_${shape.blockALast.id}_immediately_right_of_${shape.blockAMiddle.id}',
        subject: BookIdSelector(bookId: shape.blockALast.id),
        reference: BookIdSelector(bookId: shape.blockAMiddle.id),
        tierIndex: 0,
        direction: AdjacentDirection.immediatelyRightOf,
      ),
      AdjacentClue(
        id: 't03_c05_02_${shape.blockBEnd.id}_immediately_right_of_${duplicateColorCode}_group',
        subject: BookIdSelector(bookId: shape.blockBEnd.id),
        reference: BookColorSelector(color: shape.duplicateColor),
        tierIndex: 0,
        direction: AdjacentDirection.immediatelyRightOf,
      ),
      RelativeOrderClue(
        id: 't03_c04_03_${shape.blockALast.id}_left_of_${duplicateColorCode}_group',
        subject: BookIdSelector(bookId: shape.blockALast.id),
        reference: BookColorSelector(color: shape.duplicateColor),
        tierIndex: 0,
        relation: HorizontalRelation.leftOf,
      ),
      RelativeOrderClue(
        id: 't03_c04_04_${shape.blockAFirst.id}_left_of_${shape.blockBEnd.id}',
        subject: BookIdSelector(bookId: shape.blockAFirst.id),
        reference: BookIdSelector(bookId: shape.blockBEnd.id),
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
      throw StateError('T03 generated an unexpected clue count.');
    }
    final clueIds = <String>{};
    for (final clue in clues) {
      if (!clueIds.add(clue.id)) {
        throw StateError('T03 generated duplicate clue id: ${clue.id}');
      }
      if (!RegExp(r'^[a-z0-9_]+$').hasMatch(clue.id)) {
        throw StateError('T03 generated an invalid clue id: ${clue.id}');
      }
      if (!clueEvaluator.evaluate(clue: clue, placements: targetPlacements)) {
        throw StateError('T03 generated an unsatisfied clue: ${clue.id}');
      }
    }

    for (var index = 0; index < clues.length; index += 1) {
      final clue = clues[index];
      if (index < 3 && clue is! AdjacentClue) {
        throw StateError('T03 first three clues must be AdjacentClue.');
      }
      if (index >= 3 && clue is! RelativeOrderClue) {
        throw StateError('T03 later clues must be RelativeOrderClue.');
      }
    }

    final satisfiedIds = clueEvaluator.evaluateAll(
      clues: clues,
      placements: targetPlacements,
    );
    if (satisfiedIds.length != clues.length) {
      throw StateError('T03 evaluateAll did not satisfy every generated clue.');
    }
  }

  _T03TargetShape? _targetShape(List<BookPlacement> placements) {
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

    final blockAFirst = sorted[0].book;
    final blockAMiddle = sorted[1].book;
    final blockALast = sorted[2].book;
    final duplicateCopy01 = sorted[3].book;
    final duplicateCopy02 = sorted[4].book;
    final blockBEnd = sorted[5].book;

    if (_visualKey(duplicateCopy01) != _visualKey(duplicateCopy02)) {
      return null;
    }
    final colors = {
      blockAFirst.color,
      blockAMiddle.color,
      blockALast.color,
      duplicateCopy01.color,
      blockBEnd.color,
    };
    if (colors.length != 5) {
      return null;
    }
    return _T03TargetShape(
      blockAFirst: blockAFirst,
      blockAMiddle: blockAMiddle,
      blockALast: blockALast,
      duplicateCopy01: duplicateCopy01,
      duplicateCopy02: duplicateCopy02,
      blockBEnd: blockBEnd,
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

class _T03TargetShape {
  const _T03TargetShape({
    required this.blockAFirst,
    required this.blockAMiddle,
    required this.blockALast,
    required this.duplicateCopy01,
    required this.duplicateCopy02,
    required this.blockBEnd,
  });

  final Book blockAFirst;
  final Book blockAMiddle;
  final Book blockALast;
  final Book duplicateCopy01;
  final Book duplicateCopy02;
  final Book blockBEnd;

  BookColor get duplicateColor => duplicateCopy01.color;
}
