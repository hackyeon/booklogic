import '../domain/book.dart';
import '../domain/book_placement.dart';
import '../domain/book_selector.dart';
import '../domain/clue.dart';
import '../domain/clue_evaluator.dart';
import 'book_code.dart';
import 'puzzle_template_id.dart';
import 'template_solution.dart';

class T01AnchorChainClueFactory {
  const T01AnchorChainClueFactory({this.clueEvaluator = const ClueEvaluator()});

  final ClueEvaluator clueEvaluator;

  bool supports(TemplateSolution solution) {
    final spec = solution.stageSpec;
    final targetPlacements = solution.targetPlacements;

    if (solution.templateId != PuzzleTemplateId.t01AnchorChain) {
      return false;
    }
    if (spec.tierCount != 1) {
      return false;
    }
    if (spec.booksPerTier < 4 || spec.booksPerTier > 6) {
      return false;
    }
    if (spec.totalBookCount < 4 || spec.totalBookCount > 6) {
      return false;
    }
    if (spec.duplicateGroupCount != 0) {
      return false;
    }
    if (targetPlacements.length != spec.totalBookCount) {
      return false;
    }
    if (spec.clueCount < 2 || spec.clueCount > maxClueCount(solution)) {
      return false;
    }

    final bookIds = <String>{};
    final visualKeys = <String>{};
    final slotIndexes = <int>{};
    for (final placement in targetPlacements) {
      final book = placement.book;
      final position = placement.position;
      if (position.tierIndex != 0) {
        return false;
      }
      if (!bookIds.add(book.id)) {
        return false;
      }
      if (!visualKeys.add(_visualKey(book))) {
        return false;
      }
      if (book.id != BookCode.bookId(color: book.color, symbol: book.symbol)) {
        return false;
      }
      if (!slotIndexes.add(position.slotIndex)) {
        return false;
      }
    }

    for (
      var slotIndex = 0;
      slotIndex < targetPlacements.length;
      slotIndex += 1
    ) {
      if (!slotIndexes.contains(slotIndex)) {
        return false;
      }
    }
    return true;
  }

  int maxClueCount(TemplateSolution solution) {
    final targetCount = solution.targetPlacements.length;
    if (targetCount == 0) {
      return 0;
    }
    return targetCount - 1;
  }

  List<Clue> create(TemplateSolution solution) {
    if (!supports(solution)) {
      throw StateError(
        'T01 Anchor Chain does not support this TemplateSolution.',
      );
    }

    final targetPlacements = _sortedTargetPlacements(solution);
    final candidates = _buildCandidates(targetPlacements);
    if (candidates.length < solution.stageSpec.clueCount) {
      throw StateError(
        'T01 clue candidates are fewer than StageSpec.clueCount.',
      );
    }

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

  List<BookPlacement> _sortedTargetPlacements(TemplateSolution solution) {
    final targetPlacements = List<BookPlacement>.of(solution.targetPlacements);
    targetPlacements.sort(_comparePlacementPosition);
    return targetPlacements;
  }

  List<Clue> _buildCandidates(List<BookPlacement> targetPlacements) {
    final candidates = <Clue>[
      EdgePositionClue(
        id: _edgeClueId(targetPlacements.first.book),
        subject: BookIdSelector(bookId: targetPlacements.first.book.id),
        tierIndex: 0,
        edge: ShelfEdge.left,
      ),
      AdjacentClue(
        id: _adjacentClueId(
          subject: targetPlacements[1].book,
          reference: targetPlacements[0].book,
        ),
        subject: BookIdSelector(bookId: targetPlacements[1].book.id),
        reference: BookIdSelector(bookId: targetPlacements[0].book.id),
        tierIndex: 0,
        direction: AdjacentDirection.immediatelyRightOf,
      ),
    ];

    for (var index = 2; index < targetPlacements.length - 1; index += 1) {
      final subject = targetPlacements[index].book;
      final reference = targetPlacements[index + 1].book;
      candidates.add(
        RelativeOrderClue(
          id: _relativeOrderClueId(
            index: index,
            subject: subject,
            reference: reference,
          ),
          subject: BookIdSelector(bookId: subject.id),
          reference: BookIdSelector(bookId: reference.id),
          tierIndex: 0,
          relation: HorizontalRelation.leftOf,
        ),
      );
    }
    return candidates;
  }

  void _validateGeneratedClues({
    required List<Clue> clues,
    required List<BookPlacement> targetPlacements,
    required int expectedClueCount,
  }) {
    if (clues.length != expectedClueCount) {
      throw StateError('T01 generated an unexpected clue count.');
    }

    final clueIds = <String>{};
    final clueSet = <Clue>{};
    for (final clue in clues) {
      if (!clueIds.add(clue.id)) {
        throw StateError('T01 generated duplicate clue id: ${clue.id}');
      }
      if (!clueSet.add(clue)) {
        throw StateError('T01 generated duplicate clues.');
      }
      if (!_hasStableClueId(clue.id)) {
        throw StateError('T01 generated an invalid clue id: ${clue.id}');
      }
      _validateClueShape(clue: clue, targetPlacements: targetPlacements);
      final satisfied = clueEvaluator.evaluate(
        clue: clue,
        placements: targetPlacements,
      );
      if (!satisfied) {
        throw StateError('T01 generated an unsatisfied clue: ${clue.id}');
      }
    }

    if (clues.isNotEmpty && clues.first is! EdgePositionClue) {
      throw StateError('T01 first clue must be EdgePositionClue.');
    }
    if (clues.length > 1 && clues[1] is! AdjacentClue) {
      throw StateError('T01 second clue must be AdjacentClue.');
    }
    for (var index = 2; index < clues.length; index += 1) {
      if (clues[index] is! RelativeOrderClue) {
        throw StateError('T01 later clues must be RelativeOrderClue.');
      }
    }

    final satisfiedIds = clueEvaluator.evaluateAll(
      clues: clues,
      placements: targetPlacements,
    );
    if (satisfiedIds.length != clues.length) {
      throw StateError('T01 evaluateAll did not satisfy every generated clue.');
    }
    for (final clue in clues) {
      if (!satisfiedIds.contains(clue.id)) {
        throw StateError('T01 evaluateAll missed generated clue: ${clue.id}');
      }
    }
  }

  void _validateClueShape({
    required Clue clue,
    required List<BookPlacement> targetPlacements,
  }) {
    switch (clue) {
      case EdgePositionClue(:final subject, :final tierIndex, :final edge):
        if (tierIndex != 0 || edge != ShelfEdge.left) {
          throw StateError('T01 edge clue has invalid direction data.');
        }
        _validateSelector(subject, targetPlacements);
      case AdjacentClue(
        :final subject,
        :final reference,
        :final tierIndex,
        :final direction,
      ):
        if (tierIndex != 0 ||
            direction != AdjacentDirection.immediatelyRightOf) {
          throw StateError('T01 adjacent clue has invalid direction data.');
        }
        _validateSelector(subject, targetPlacements);
        _validateSelector(reference, targetPlacements);
      case RelativeOrderClue(
        :final subject,
        :final reference,
        :final tierIndex,
        :final relation,
      ):
        if (tierIndex != 0 || relation != HorizontalRelation.leftOf) {
          throw StateError(
            'T01 relative order clue has invalid direction data.',
          );
        }
        _validateSelector(subject, targetPlacements);
        _validateSelector(reference, targetPlacements);
      case BothEdgesClue():
        throw StateError('T01 clue shape must not use BothEdgesClue.');
      case BetweenClue():
        throw StateError('T01 clue shape must not use BetweenClue.');
      case TierAssignmentClue():
        throw StateError('T01 clue shape must not use TierAssignmentClue.');
      case SameTierClue():
        throw StateError('T01 clue shape must not use SameTierClue.');
      case VerticalRelationClue():
      case NotAtEdgeClue():
      case DistanceClue():
        throw StateError('T01 clue shape must not use T06-only clue types.');
    }
  }

  void _validateSelector(
    BookSelector selector,
    List<BookPlacement> targetPlacements,
  ) {
    if (selector is! BookIdSelector) {
      throw StateError('T01 generated a non-BookIdSelector.');
    }
    final resolved = clueEvaluator.selectorResolver.resolve(
      selector: selector,
      placements: targetPlacements,
    );
    if (resolved.length != 1) {
      throw StateError(
        'T01 generated a selector that does not resolve once: '
        '${selector.bookId}',
      );
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

  String _edgeClueId(Book book) {
    return 't01_c02_00_${book.id}_left_edge';
  }

  String _adjacentClueId({required Book subject, required Book reference}) {
    return 't01_c05_01_${subject.id}_immediately_right_of_${reference.id}';
  }

  String _relativeOrderClueId({
    required int index,
    required Book subject,
    required Book reference,
  }) {
    return 't01_c04_${_twoDigit(index)}_${subject.id}_left_of_${reference.id}';
  }

  String _twoDigit(int value) {
    return value.toString().padLeft(2, '0');
  }

  String _visualKey(Book book) {
    return '${BookCode.color(book.color)}_${BookCode.symbol(book.symbol)}';
  }

  bool _hasStableClueId(String clueId) {
    return RegExp(r'^[a-z0-9_]+$').hasMatch(clueId);
  }
}
