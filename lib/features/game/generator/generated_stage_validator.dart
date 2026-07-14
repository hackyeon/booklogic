import '../domain/book.dart';
import '../domain/book_placement.dart';
import '../domain/book_position.dart';
import '../domain/book_selector.dart';
import '../domain/book_selector_resolver.dart';
import '../domain/clue.dart';
import '../domain/clue_evaluator.dart';
import 'book_code.dart';
import 'book_swap_step.dart';
import 'generated_stage.dart';
import 'generator_config.dart';
import 'puzzle_template_id.dart';
import 'stage_permutation_analyzer.dart';
import 'stage_seed_factory.dart';
import 'stage_validation_issue.dart';
import 'stage_validation_result.dart';

class GeneratedStageValidator {
  const GeneratedStageValidator({
    this.clueEvaluator = const ClueEvaluator(),
    this.selectorResolver = const BookSelectorResolver(),
    this.permutationAnalyzer = const StagePermutationAnalyzer(),
    this.stageSeedFactory = const StageSeedFactory(),
  });

  final ClueEvaluator clueEvaluator;
  final BookSelectorResolver selectorResolver;
  final StagePermutationAnalyzer permutationAnalyzer;
  final StageSeedFactory stageSeedFactory;

  StageValidationResult validate(GeneratedStage stage) {
    final issues = <StageValidationIssue>[];

    _validateTemplateAndSpec(stage, issues);
    _validateGenerationAttempt(stage, issues);
    _validatePlacements(
      placements: stage.targetPlacements,
      expectedCount: stage.totalBookCount,
      code: StageValidationIssueCode.invalidTargetPlacements,
      label: 'targetPlacements',
      issues: issues,
    );
    _validatePlacements(
      placements: stage.initialPlacements,
      expectedCount: stage.totalBookCount,
      code: StageValidationIssueCode.invalidInitialPlacements,
      label: 'initialPlacements',
      issues: issues,
    );
    _validateBookUniqueness(stage.targetPlacements, issues, 'target');
    _validateBookUniqueness(stage.initialPlacements, issues, 'initial');
    _validateBookSet(stage, issues);
    _validateClues(stage, issues);
    _validateTargetSatisfaction(stage, issues);
    _validateInitialIncomplete(stage, issues);
    _validateScrambleSeed(stage, issues);
    _validateSwapHistory(stage, issues);
    _validateReplay(stage, issues);
    _validateMinimumSwapDistance(stage, issues);

    return StageValidationResult(issues: issues);
  }

  void _validateGenerationAttempt(
    GeneratedStage stage,
    List<StageValidationIssue> issues,
  ) {
    final key = stage.generationAttemptKey;
    if (key.generatorVersion != stage.stageSpec.generatorVersion ||
        key.level != stage.stageSpec.level ||
        key.attempt < 0) {
      _add(
        issues,
        StageValidationIssueCode.invalidGenerationAttemptKey,
        'generationAttemptKey does not match StageSpec.',
      );
    }

    try {
      final expectedSeed = stageSeedFactory.create(key);
      if (stage.generationAttemptSeed < 1 ||
          stage.generationAttemptSeed > GeneratorConfig.uint32Mask ||
          stage.generationAttemptSeed != expectedSeed) {
        _add(
          issues,
          StageValidationIssueCode.invalidGenerationAttemptSeed,
          'generationAttemptSeed does not match generationAttemptKey.',
          stage.generationAttemptSeed.toString(),
        );
      }
    } on ArgumentError catch (error) {
      _add(
        issues,
        StageValidationIssueCode.invalidGenerationAttemptSeed,
        'generationAttemptSeed could not be validated: $error',
      );
    }

    if (stage.isFallback && key.attempt == 0) {
      _add(
        issues,
        StageValidationIssueCode.invalidFallbackMetadata,
        'Fallback stages must use generation attempt 1 or greater.',
      );
    }
  }

  void _validateTemplateAndSpec(
    GeneratedStage stage,
    List<StageValidationIssue> issues,
  ) {
    final spec = stage.stageSpec;
    if (stage.templateId != PuzzleTemplateId.t01AnchorChain) {
      _add(
        issues,
        StageValidationIssueCode.unsupportedTemplate,
        'Only T01 Anchor Chain is supported.',
      );
    }
    if (spec.level < 1 ||
        spec.generatorVersion < 1 ||
        spec.generationKey.attempt != 0 ||
        spec.tierCount != 1 ||
        spec.totalBookCount < 4 ||
        spec.totalBookCount > 6 ||
        spec.duplicateGroupCount != 0 ||
        spec.targetSwapCount < 1 ||
        spec.targetSwapCount > spec.totalBookCount - 1) {
      _add(
        issues,
        StageValidationIssueCode.invalidStageSpec,
        'StageSpec is outside T01 generated stage constraints.',
      );
    }
  }

  void _validatePlacements({
    required List<BookPlacement> placements,
    required int expectedCount,
    required StageValidationIssueCode code,
    required String label,
    required List<StageValidationIssue> issues,
  }) {
    if (placements.length != expectedCount) {
      _add(issues, code, '$label length does not match StageSpec.');
    }

    final positionKeys = <String>{};
    final slots = <int>{};
    for (var index = 0; index < placements.length; index += 1) {
      final placement = placements[index];
      final book = placement.book;
      final position = placement.position;
      if (position.tierIndex != 0) {
        _add(issues, code, '$label contains a non-zero tier.', book.id);
      }
      if (position.slotIndex != index) {
        _add(issues, code, '$label is not stored in slot order.', book.id);
      }
      if (!positionKeys.add('${position.tierIndex}:${position.slotIndex}')) {
        _add(issues, code, '$label contains duplicate positions.', book.id);
      }
      slots.add(position.slotIndex);
      if (book.id.isEmpty) {
        _add(issues, code, '$label contains an empty Book.id.');
      } else if (book.id !=
          BookCode.bookId(color: book.color, symbol: book.symbol)) {
        _add(
          issues,
          code,
          '$label contains a Book.id that does not match BookCode.',
          book.id,
        );
      }
    }

    for (var slotIndex = 0; slotIndex < placements.length; slotIndex += 1) {
      if (!slots.contains(slotIndex)) {
        _add(issues, code, '$label is missing slot $slotIndex.');
      }
    }
  }

  void _validateBookUniqueness(
    List<BookPlacement> placements,
    List<StageValidationIssue> issues,
    String label,
  ) {
    final ids = <String>{};
    final visuals = <String>{};
    for (final placement in placements) {
      final book = placement.book;
      if (!ids.add(book.id)) {
        _add(
          issues,
          StageValidationIssueCode.duplicateBookId,
          '$label contains duplicate Book.id.',
          book.id,
        );
      }
      final visualKey = _visualKey(book);
      if (!visuals.add(visualKey)) {
        _add(
          issues,
          StageValidationIssueCode.duplicateVisualBook,
          '$label contains duplicate color + symbol.',
          visualKey,
        );
      }
    }
  }

  void _validateBookSet(
    GeneratedStage stage,
    List<StageValidationIssue> issues,
  ) {
    final targetBooks = _bookMap(stage.targetPlacements);
    final initialBooks = _bookMap(stage.initialPlacements);
    var matches = targetBooks.length == initialBooks.length;
    for (final entry in targetBooks.entries) {
      final initialBook = initialBooks[entry.key];
      if (initialBook == null ||
          initialBook.color != entry.value.color ||
          initialBook.symbol != entry.value.symbol) {
        matches = false;
        break;
      }
    }
    if (!matches) {
      _add(
        issues,
        StageValidationIssueCode.mismatchedBookSet,
        'Target and initial placements do not contain the same books.',
      );
    }
  }

  void _validateClues(GeneratedStage stage, List<StageValidationIssue> issues) {
    if (stage.clues.length != stage.stageSpec.clueCount ||
        stage.clues.length < 2 ||
        stage.clues.length > stage.totalBookCount - 1) {
      _add(
        issues,
        StageValidationIssueCode.invalidClueCount,
        'Clue count is outside StageSpec or T01 bounds.',
      );
    }

    final clueIds = <String>{};
    for (var index = 0; index < stage.clues.length; index += 1) {
      final clue = stage.clues[index];
      if (clue.id.isEmpty || !RegExp(r'^[a-z0-9_]+$').hasMatch(clue.id)) {
        _add(
          issues,
          StageValidationIssueCode.invalidClueId,
          'Clue.id has an invalid format.',
          clue.id,
        );
      }
      if (!clueIds.add(clue.id)) {
        _add(
          issues,
          StageValidationIssueCode.duplicateClueId,
          'Clue.id is duplicated.',
          clue.id,
        );
      }
      _validateClueStructure(index: index, clue: clue, issues: issues);
      _validateClueSelectors(stage: stage, clue: clue, issues: issues);
    }
  }

  void _validateClueStructure({
    required int index,
    required Clue clue,
    required List<StageValidationIssue> issues,
  }) {
    switch (clue) {
      case EdgePositionClue(:final subject, :final tierIndex, :final edge):
        if (index != 0 || tierIndex != 0 || edge != ShelfEdge.left) {
          _add(
            issues,
            StageValidationIssueCode.invalidClueStructure,
            'T01 first clue must be a left edge clue.',
            clue.id,
          );
        }
        _validateBookIdSelector(subject, clue.id, issues);
      case AdjacentClue(
        :final subject,
        :final reference,
        :final tierIndex,
        :final direction,
      ):
        if (index != 1 ||
            tierIndex != 0 ||
            direction != AdjacentDirection.immediatelyRightOf) {
          _add(
            issues,
            StageValidationIssueCode.invalidClueStructure,
            'T01 second clue must be an immediately-right-of clue.',
            clue.id,
          );
        }
        _validateBookIdSelector(subject, clue.id, issues);
        _validateBookIdSelector(reference, clue.id, issues);
      case RelativeOrderClue(
        :final subject,
        :final reference,
        :final tierIndex,
        :final relation,
      ):
        if (index < 2 ||
            tierIndex != 0 ||
            relation != HorizontalRelation.leftOf) {
          _add(
            issues,
            StageValidationIssueCode.invalidClueStructure,
            'T01 later clues must be left-of relative order clues.',
            clue.id,
          );
        }
        _validateBookIdSelector(subject, clue.id, issues);
        _validateBookIdSelector(reference, clue.id, issues);
    }
  }

  void _validateBookIdSelector(
    BookSelector selector,
    String clueId,
    List<StageValidationIssue> issues,
  ) {
    if (selector is! BookIdSelector) {
      _add(
        issues,
        StageValidationIssueCode.invalidClueStructure,
        'T01 clues must use BookIdSelector.',
        clueId,
      );
    }
  }

  void _validateClueSelectors({
    required GeneratedStage stage,
    required Clue clue,
    required List<StageValidationIssue> issues,
  }) {
    for (final selector in _selectorsFor(clue)) {
      final targetResolved = selectorResolver.resolve(
        selector: selector,
        placements: stage.targetPlacements,
      );
      final initialResolved = selectorResolver.resolve(
        selector: selector,
        placements: stage.initialPlacements,
      );
      if (targetResolved.length != 1 || initialResolved.length != 1) {
        _add(
          issues,
          StageValidationIssueCode.unresolvedClueSelector,
          'Clue selector must resolve exactly one book in target and initial.',
          clue.id,
        );
      }
    }
  }

  void _validateTargetSatisfaction(
    GeneratedStage stage,
    List<StageValidationIssue> issues,
  ) {
    if (!_allCluesSatisfied(
      clues: stage.clues,
      placements: stage.targetPlacements,
    )) {
      _add(
        issues,
        StageValidationIssueCode.targetDoesNotSatisfyAllClues,
        'Target placements do not satisfy every clue.',
      );
    }
  }

  void _validateInitialIncomplete(
    GeneratedStage stage,
    List<StageValidationIssue> issues,
  ) {
    if (_allCluesSatisfied(
      clues: stage.clues,
      placements: stage.initialPlacements,
    )) {
      _add(
        issues,
        StageValidationIssueCode.initialAlreadySatisfiesAllClues,
        'Initial placements already satisfy every clue.',
      );
    } else if (permutationAnalyzer.hasSameBookOrder(
      first: stage.targetPlacements,
      second: stage.initialPlacements,
    )) {
      _add(
        issues,
        StageValidationIssueCode.initialAlreadySatisfiesAllClues,
        'Initial placements match target placements.',
      );
    }
  }

  void _validateScrambleSeed(
    GeneratedStage stage,
    List<StageValidationIssue> issues,
  ) {
    final expectedSeed = _expectedScrambleSeed(stage.generationAttemptSeed);
    if (stage.scrambleSeed < 1 ||
        stage.scrambleSeed > GeneratorConfig.uint32Mask ||
        stage.scrambleSeed != expectedSeed) {
      _add(
        issues,
        StageValidationIssueCode.invalidScrambleSeed,
        'Scramble seed does not match T01 seed rule.',
        stage.scrambleSeed.toString(),
      );
    }
  }

  void _validateSwapHistory(
    GeneratedStage stage,
    List<StageValidationIssue> issues,
  ) {
    if (stage.swapHistory.length != stage.targetSwapCount ||
        stage.swapHistory.isEmpty) {
      _add(
        issues,
        StageValidationIssueCode.invalidSwapHistoryCount,
        'swapHistory length does not match targetSwapCount.',
      );
    }

    for (var index = 0; index < stage.swapHistory.length; index += 1) {
      final step = stage.swapHistory[index];
      if (step.stepIndex != index) {
        _add(
          issues,
          StageValidationIssueCode.invalidSwapStep,
          'swapHistory stepIndex must be stored in 0-based order.',
          step.stepIndex.toString(),
        );
      }
      if (!_isValidSwapPosition(step.firstPosition, stage.totalBookCount) ||
          !_isValidSwapPosition(step.secondPosition, stage.totalBookCount) ||
          step.firstPosition == step.secondPosition) {
        _add(
          issues,
          StageValidationIssueCode.invalidSwapStep,
          'swapHistory contains an invalid swap position.',
          step.stepIndex.toString(),
        );
      }
    }

    _validateSwapBookRecords(stage, issues);
  }

  void _validateSwapBookRecords(
    GeneratedStage stage,
    List<StageValidationIssue> issues,
  ) {
    final sortedTarget = _sortedPlacements(stage.targetPlacements);
    final positions = [
      for (final placement in sortedTarget) placement.position,
    ];
    final workingBooks = [for (final placement in sortedTarget) placement.book];
    final sortedSteps = List<BookSwapStep>.of(stage.swapHistory)
      ..sort((left, right) => left.stepIndex.compareTo(right.stepIndex));

    for (final step in sortedSteps) {
      final firstIndex = _positionIndex(positions, step.firstPosition);
      final secondIndex = _positionIndex(positions, step.secondPosition);
      if (firstIndex == null ||
          secondIndex == null ||
          firstIndex == secondIndex) {
        continue;
      }
      final firstBook = workingBooks[firstIndex];
      final secondBook = workingBooks[secondIndex];
      if (firstBook.id != step.firstBookIdBeforeSwap ||
          secondBook.id != step.secondBookIdBeforeSwap) {
        _add(
          issues,
          StageValidationIssueCode.swapHistoryBookMismatch,
          'swapHistory Book ID record does not match replay state.',
          step.stepIndex.toString(),
        );
      }
      if (_visualKey(firstBook) == _visualKey(secondBook)) {
        _add(
          issues,
          StageValidationIssueCode.identicalVisualBookSwap,
          'swapHistory swaps visually identical books.',
          step.stepIndex.toString(),
        );
      }
      workingBooks[firstIndex] = secondBook;
      workingBooks[secondIndex] = firstBook;
    }
  }

  void _validateReplay(
    GeneratedStage stage,
    List<StageValidationIssue> issues,
  ) {
    try {
      final forward = permutationAnalyzer.replayForward(
        start: stage.targetPlacements,
        swapHistory: stage.swapHistory,
      );
      if (!permutationAnalyzer.hasSameBookOrder(
        first: forward,
        second: stage.initialPlacements,
      )) {
        _add(
          issues,
          StageValidationIssueCode.forwardReplayMismatch,
          'Forward replay does not match initial placements.',
        );
      }
    } catch (error) {
      _add(
        issues,
        StageValidationIssueCode.forwardReplayMismatch,
        'Forward replay failed: $error',
      );
    }

    try {
      final reverse = permutationAnalyzer.replayReverse(
        start: stage.initialPlacements,
        swapHistory: stage.swapHistory,
      );
      if (!permutationAnalyzer.hasSameBookOrder(
        first: reverse,
        second: stage.targetPlacements,
      )) {
        _add(
          issues,
          StageValidationIssueCode.reverseReplayMismatch,
          'Reverse replay does not match target placements.',
        );
      }
    } catch (error) {
      _add(
        issues,
        StageValidationIssueCode.reverseReplayMismatch,
        'Reverse replay failed: $error',
      );
    }
  }

  void _validateMinimumSwapDistance(
    GeneratedStage stage,
    List<StageValidationIssue> issues,
  ) {
    try {
      final distance = permutationAnalyzer.minimumSwapDistance(
        target: stage.targetPlacements,
        current: stage.initialPlacements,
      );
      if (distance != stage.targetSwapCount) {
        _add(
          issues,
          StageValidationIssueCode.minimumSwapDistanceMismatch,
          'Minimum swap distance $distance does not match targetSwapCount '
          '${stage.targetSwapCount}.',
        );
      }
    } catch (error) {
      _add(
        issues,
        StageValidationIssueCode.minimumSwapDistanceMismatch,
        'Minimum swap distance failed: $error',
      );
    }
  }

  bool _allCluesSatisfied({
    required List<Clue> clues,
    required List<BookPlacement> placements,
  }) {
    final satisfiedIds = clueEvaluator.evaluateAll(
      clues: clues,
      placements: placements,
    );
    if (satisfiedIds.length != clues.length) {
      return false;
    }
    for (final clue in clues) {
      if (!satisfiedIds.contains(clue.id)) {
        return false;
      }
    }
    return true;
  }

  List<BookSelector> _selectorsFor(Clue clue) {
    return switch (clue) {
      EdgePositionClue(:final subject) => [subject],
      AdjacentClue(:final subject, :final reference) => [subject, reference],
      RelativeOrderClue(:final subject, :final reference) => [
        subject,
        reference,
      ],
    };
  }

  bool _isValidSwapPosition(BookPosition position, int totalBookCount) {
    return position.tierIndex == 0 &&
        position.slotIndex >= 0 &&
        position.slotIndex < totalBookCount;
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

  int? _positionIndex(List<BookPosition> positions, BookPosition position) {
    for (var index = 0; index < positions.length; index += 1) {
      if (positions[index] == position) {
        return index;
      }
    }
    return null;
  }

  Map<String, Book> _bookMap(List<BookPlacement> placements) {
    final result = <String, Book>{};
    for (final placement in placements) {
      result[placement.book.id] = placement.book;
    }
    return result;
  }

  String _visualKey(Book book) {
    return BookCode.bookId(color: book.color, symbol: book.symbol);
  }

  int _expectedScrambleSeed(int stageSeed) {
    final value =
        (stageSeed ^ GeneratorConfig.t01ScrambleSalt) &
        GeneratorConfig.uint32Mask;
    if (value == 0) {
      return GeneratorConfig.zeroSeedFallback;
    }
    return value;
  }

  void _add(
    List<StageValidationIssue> issues,
    StageValidationIssueCode code,
    String message, [
    String? relatedId,
  ]) {
    issues.add(
      StageValidationIssue(code: code, message: message, relatedId: relatedId),
    );
  }
}
