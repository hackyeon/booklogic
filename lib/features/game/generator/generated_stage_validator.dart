import '../domain/book.dart';
import '../domain/book_placement.dart';
import '../domain/book_position.dart';
import '../domain/book_selector.dart';
import '../domain/book_selector_resolver.dart';
import '../domain/clue.dart';
import '../domain/clue_evaluator.dart';
import 'book_code.dart';
import 'book_instance_code.dart';
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
      templateId: stage.templateId,
      issues: issues,
    );
    _validatePlacements(
      placements: stage.initialPlacements,
      expectedCount: stage.totalBookCount,
      code: StageValidationIssueCode.invalidInitialPlacements,
      label: 'initialPlacements',
      templateId: stage.templateId,
      issues: issues,
    );
    _validateBookUniqueness(
      stage.targetPlacements,
      issues,
      'target',
      stage.templateId,
    );
    _validateBookUniqueness(
      stage.initialPlacements,
      issues,
      'initial',
      stage.templateId,
    );
    _validateBookSet(stage, issues);
    _validateTemplateTargetStructure(stage, issues);
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
    switch (stage.templateId) {
      case PuzzleTemplateId.t01AnchorChain:
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
      case PuzzleTemplateId.t02EdgeSandwich:
        if (spec.level < 21 ||
            spec.level > 50 ||
            spec.generatorVersion < 1 ||
            spec.generationKey.attempt != 0 ||
            spec.tierCount != 1 ||
            spec.booksPerTier != 6 ||
            spec.totalBookCount != 6 ||
            spec.duplicateGroupCount != 1 ||
            spec.maxDuplicateCopies < 2 ||
            spec.clueCount < 4 ||
            spec.clueCount > 5 ||
            spec.targetSwapCount < 3 ||
            spec.targetSwapCount > 4) {
          _add(
            issues,
            StageValidationIssueCode.invalidStageSpec,
            'StageSpec is outside T02 generated stage constraints.',
          );
        }
      case PuzzleTemplateId.t03AdjacentBlocks:
        if (spec.level < 23 ||
            spec.level > 47 ||
            (spec.level - 23) % 4 != 0 ||
            spec.generatorVersion < 1 ||
            spec.generationKey.attempt != 0 ||
            spec.tierCount != 1 ||
            spec.booksPerTier != 6 ||
            spec.totalBookCount != 6 ||
            spec.duplicateGroupCount != 1 ||
            spec.maxDuplicateCopies < 2 ||
            spec.clueCount < 4 ||
            spec.clueCount > 5 ||
            spec.targetSwapCount < 3 ||
            spec.targetSwapCount > 4) {
          _add(
            issues,
            StageValidationIssueCode.invalidStageSpec,
            'StageSpec is outside T03 generated stage constraints.',
          );
        }
    }
  }

  void _validatePlacements({
    required List<BookPlacement> placements,
    required int expectedCount,
    required StageValidationIssueCode code,
    required String label,
    required PuzzleTemplateId templateId,
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
      } else if (!_bookIdMatchesTemplate(book, templateId)) {
        _add(
          issues,
          code,
          '$label contains a Book.id that does not match visual data.',
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
    PuzzleTemplateId templateId,
  ) {
    final ids = <String>{};
    final visualCounts = <String, int>{};
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
      visualCounts.update(visualKey, (count) => count + 1, ifAbsent: () => 1);
    }

    switch (templateId) {
      case PuzzleTemplateId.t01AnchorChain:
        for (final entry in visualCounts.entries) {
          if (entry.value > 1) {
            _add(
              issues,
              StageValidationIssueCode.duplicateVisualBook,
              '$label contains duplicate color + symbol.',
              entry.key,
            );
          }
        }
      case PuzzleTemplateId.t02EdgeSandwich:
      case PuzzleTemplateId.t03AdjacentBlocks:
        final duplicateGroups = visualCounts.entries
            .where((entry) => entry.value > 1)
            .toList();
        if (duplicateGroups.length != 1 || duplicateGroups.single.value != 2) {
          _add(
            issues,
            StageValidationIssueCode.invalidDuplicateStructure,
            '$label must contain exactly one duplicate visual pair.',
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
    final clueCountIsValid = switch (stage.templateId) {
      PuzzleTemplateId.t01AnchorChain =>
        stage.clues.length == stage.stageSpec.clueCount &&
            stage.clues.length >= 2 &&
            stage.clues.length <= stage.totalBookCount - 1,
      PuzzleTemplateId.t02EdgeSandwich =>
        stage.clues.length == stage.stageSpec.clueCount &&
            stage.clues.length >= 4 &&
            stage.clues.length <= 5,
      PuzzleTemplateId.t03AdjacentBlocks =>
        stage.clues.length == stage.stageSpec.clueCount &&
            stage.clues.length >= 4 &&
            stage.clues.length <= 5,
    };
    if (!clueCountIsValid) {
      _add(
        issues,
        StageValidationIssueCode.invalidClueCount,
        'Clue count is outside StageSpec or template bounds.',
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
      _validateClueStructure(
        stage: stage,
        index: index,
        clue: clue,
        issues: issues,
      );
      _validateClueSelectors(stage: stage, clue: clue, issues: issues);
    }
  }

  void _validateClueStructure({
    required GeneratedStage stage,
    required int index,
    required Clue clue,
    required List<StageValidationIssue> issues,
  }) {
    switch (stage.templateId) {
      case PuzzleTemplateId.t01AnchorChain:
        _validateT01ClueStructure(index: index, clue: clue, issues: issues);
      case PuzzleTemplateId.t02EdgeSandwich:
        _validateT02ClueStructure(
          stage: stage,
          index: index,
          clue: clue,
          issues: issues,
        );
      case PuzzleTemplateId.t03AdjacentBlocks:
        _validateT03ClueStructure(
          stage: stage,
          index: index,
          clue: clue,
          issues: issues,
        );
    }
  }

  void _validateT01ClueStructure({
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
      case BothEdgesClue():
        _add(
          issues,
          StageValidationIssueCode.invalidClueStructure,
          'T01 clues must not use BothEdgesClue.',
          clue.id,
        );
      case BetweenClue():
        _add(
          issues,
          StageValidationIssueCode.invalidClueStructure,
          'T01 clues must not use BetweenClue.',
          clue.id,
        );
    }
  }

  void _validateT02ClueStructure({
    required GeneratedStage stage,
    required int index,
    required Clue clue,
    required List<StageValidationIssue> issues,
  }) {
    final shape = _t02TargetShape(stage.targetPlacements);
    if (shape == null) {
      _add(
        issues,
        StageValidationIssueCode.invalidT02ClueStructure,
        'T02 clue structure cannot be validated without a valid target.',
        clue.id,
      );
      return;
    }

    if (_matchesT02Clue(index: index, clue: clue, shape: shape)) {
      return;
    }

    _add(
      issues,
      StageValidationIssueCode.invalidT02ClueStructure,
      'T02 clue does not match the fixed clue sequence.',
      clue.id,
    );
  }

  void _validateT03ClueStructure({
    required GeneratedStage stage,
    required int index,
    required Clue clue,
    required List<StageValidationIssue> issues,
  }) {
    final shape = _t03TargetShape(stage.targetPlacements);
    if (shape == null) {
      _add(
        issues,
        StageValidationIssueCode.invalidT03ClueStructure,
        'T03 clue structure cannot be validated without a valid target.',
        clue.id,
      );
      return;
    }

    if (_matchesT03Clue(index: index, clue: clue, shape: shape)) {
      return;
    }

    _add(
      issues,
      StageValidationIssueCode.invalidT03ClueStructure,
      'T03 clue does not match the fixed clue sequence.',
      clue.id,
    );
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
      if (!_selectorCardinalityIsAllowed(
        templateId: stage.templateId,
        clue: clue,
        selector: selector,
        targetCount: targetResolved.length,
        initialCount: initialResolved.length,
      )) {
        _add(
          issues,
          StageValidationIssueCode.unresolvedClueSelector,
          'Clue selector resolves an invalid number of books.',
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
    } else if (_hasSameTemplateOrder(stage)) {
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
    final expectedSeed = _expectedScrambleSeed(
      stage.generationAttemptSeed,
      stage.templateId,
    );
    if (stage.scrambleSeed < 1 ||
        stage.scrambleSeed > GeneratorConfig.uint32Mask ||
        stage.scrambleSeed != expectedSeed) {
      _add(
        issues,
        StageValidationIssueCode.invalidScrambleSeed,
        'Scramble seed does not match template seed rule.',
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
      final distance = switch (stage.templateId) {
        PuzzleTemplateId.t01AnchorChain =>
          permutationAnalyzer.minimumSwapDistance(
            target: stage.targetPlacements,
            current: stage.initialPlacements,
          ),
        PuzzleTemplateId.t02EdgeSandwich =>
          permutationAnalyzer.minimumVisualSwapDistance(
            target: stage.targetPlacements,
            current: stage.initialPlacements,
          ),
        PuzzleTemplateId.t03AdjacentBlocks =>
          permutationAnalyzer.minimumVisualSwapDistance(
            target: stage.targetPlacements,
            current: stage.initialPlacements,
          ),
      };
      if (distance != stage.targetSwapCount) {
        _add(
          issues,
          _minimumDistanceIssueCode(stage.templateId),
          'Minimum swap distance $distance does not match targetSwapCount '
          '${stage.targetSwapCount}.',
        );
      }
    } catch (error) {
      _add(
        issues,
        _minimumDistanceIssueCode(stage.templateId),
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
      BothEdgesClue(:final subject) => [subject],
      AdjacentClue(:final subject, :final reference) => [subject, reference],
      RelativeOrderClue(:final subject, :final reference) => [
        subject,
        reference,
      ],
      BetweenClue(:final subject, :final boundary) => [subject, boundary],
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

  bool _bookIdMatchesTemplate(Book book, PuzzleTemplateId templateId) {
    return switch (templateId) {
      PuzzleTemplateId.t01AnchorChain =>
        book.id == BookCode.bookId(color: book.color, symbol: book.symbol),
      PuzzleTemplateId.t02EdgeSandwich => BookInstanceCode.matchesBook(book),
      PuzzleTemplateId.t03AdjacentBlocks => BookInstanceCode.matchesBook(book),
    };
  }

  void _validateTemplateTargetStructure(
    GeneratedStage stage,
    List<StageValidationIssue> issues,
  ) {
    switch (stage.templateId) {
      case PuzzleTemplateId.t01AnchorChain:
        return;
      case PuzzleTemplateId.t02EdgeSandwich:
        if (_t02TargetShape(stage.targetPlacements) == null) {
          _add(
            issues,
            StageValidationIssueCode.invalidT02TargetStructure,
            'T02 target must match the Edge Sandwich structure.',
          );
        }
      case PuzzleTemplateId.t03AdjacentBlocks:
        if (_t03TargetShape(stage.targetPlacements) == null) {
          _add(
            issues,
            StageValidationIssueCode.invalidT03TargetStructure,
            'T03 target must match the Adjacent Blocks structure.',
          );
        }
    }
  }

  _T02TargetShape? _t02TargetShape(List<BookPlacement> placements) {
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
    if (duplicateCopy01.id !=
            BookInstanceCode.duplicateCopyId(
              color: duplicateCopy01.color,
              symbol: duplicateCopy01.symbol,
              copyNumber: 1,
            ) ||
        duplicateCopy02.id !=
            BookInstanceCode.duplicateCopyId(
              color: duplicateCopy02.color,
              symbol: duplicateCopy02.symbol,
              copyNumber: 2,
            )) {
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

  _T03TargetShape? _t03TargetShape(List<BookPlacement> placements) {
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

    if (blockAFirst.id !=
            BookCode.bookId(
              color: blockAFirst.color,
              symbol: blockAFirst.symbol,
            ) ||
        blockAMiddle.id !=
            BookCode.bookId(
              color: blockAMiddle.color,
              symbol: blockAMiddle.symbol,
            ) ||
        blockALast.id !=
            BookCode.bookId(
              color: blockALast.color,
              symbol: blockALast.symbol,
            ) ||
        blockBEnd.id !=
            BookCode.bookId(color: blockBEnd.color, symbol: blockBEnd.symbol)) {
      return null;
    }
    if (_visualKey(duplicateCopy01) != _visualKey(duplicateCopy02)) {
      return null;
    }
    if (duplicateCopy01.id !=
            BookInstanceCode.duplicateCopyId(
              color: duplicateCopy01.color,
              symbol: duplicateCopy01.symbol,
              copyNumber: 1,
            ) ||
        duplicateCopy02.id !=
            BookInstanceCode.duplicateCopyId(
              color: duplicateCopy02.color,
              symbol: duplicateCopy02.symbol,
              copyNumber: 2,
            )) {
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

  bool _matchesT02Clue({
    required int index,
    required Clue clue,
    required _T02TargetShape shape,
  }) {
    switch (index) {
      case 0:
        return clue is BothEdgesClue &&
            clue.tierIndex == 0 &&
            clue.subject == BookColorSelector(color: shape.edgeColor) &&
            clue.id ==
                't02_c03_00_${BookCode.color(shape.edgeColor)}_both_edges';
      case 1:
        return clue is BetweenClue &&
            clue.tierIndex == 0 &&
            clue.subject == BookColorSelector(color: shape.duplicateColor) &&
            clue.boundary == BookColorSelector(color: shape.edgeColor) &&
            clue.id ==
                't02_c06_01_${BookCode.color(shape.duplicateColor)}_between_${BookCode.color(shape.edgeColor)}';
      case 2:
        return clue is AdjacentClue &&
            clue.tierIndex == 0 &&
            clue.direction == AdjacentDirection.immediatelyRightOf &&
            clue.subject == BookIdSelector(bookId: shape.fillerB.id) &&
            clue.reference == BookIdSelector(bookId: shape.fillerA.id) &&
            clue.id ==
                't02_c05_02_${shape.fillerB.id}_immediately_right_of_${shape.fillerA.id}';
      case 3:
        return clue is RelativeOrderClue &&
            clue.tierIndex == 0 &&
            clue.relation == HorizontalRelation.leftOf &&
            clue.subject == BookIdSelector(bookId: shape.edgeLeft.id) &&
            clue.reference == BookIdSelector(bookId: shape.edgeRight.id) &&
            clue.id ==
                't02_c04_03_${shape.edgeLeft.id}_left_of_${shape.edgeRight.id}';
      case 4:
        return clue is RelativeOrderClue &&
            clue.tierIndex == 0 &&
            clue.relation == HorizontalRelation.leftOf &&
            clue.subject == BookIdSelector(bookId: shape.fillerB.id) &&
            clue.reference == BookColorSelector(color: shape.duplicateColor) &&
            clue.id ==
                't02_c04_04_${shape.fillerB.id}_left_of_${BookCode.color(shape.duplicateColor)}_group';
      default:
        return false;
    }
  }

  bool _matchesT03Clue({
    required int index,
    required Clue clue,
    required _T03TargetShape shape,
  }) {
    final duplicateColorCode = BookCode.color(shape.duplicateColor);
    switch (index) {
      case 0:
        return clue is AdjacentClue &&
            clue.tierIndex == 0 &&
            clue.direction == AdjacentDirection.immediatelyRightOf &&
            clue.subject == BookIdSelector(bookId: shape.blockAMiddle.id) &&
            clue.reference == BookIdSelector(bookId: shape.blockAFirst.id) &&
            clue.id ==
                't03_c05_00_${shape.blockAMiddle.id}_immediately_right_of_${shape.blockAFirst.id}';
      case 1:
        return clue is AdjacentClue &&
            clue.tierIndex == 0 &&
            clue.direction == AdjacentDirection.immediatelyRightOf &&
            clue.subject == BookIdSelector(bookId: shape.blockALast.id) &&
            clue.reference == BookIdSelector(bookId: shape.blockAMiddle.id) &&
            clue.id ==
                't03_c05_01_${shape.blockALast.id}_immediately_right_of_${shape.blockAMiddle.id}';
      case 2:
        return clue is AdjacentClue &&
            clue.tierIndex == 0 &&
            clue.direction == AdjacentDirection.immediatelyRightOf &&
            clue.subject == BookIdSelector(bookId: shape.blockBEnd.id) &&
            clue.reference == BookColorSelector(color: shape.duplicateColor) &&
            clue.id ==
                't03_c05_02_${shape.blockBEnd.id}_immediately_right_of_${duplicateColorCode}_group';
      case 3:
        return clue is RelativeOrderClue &&
            clue.tierIndex == 0 &&
            clue.relation == HorizontalRelation.leftOf &&
            clue.subject == BookIdSelector(bookId: shape.blockALast.id) &&
            clue.reference == BookColorSelector(color: shape.duplicateColor) &&
            clue.id ==
                't03_c04_03_${shape.blockALast.id}_left_of_${duplicateColorCode}_group';
      case 4:
        return clue is RelativeOrderClue &&
            clue.tierIndex == 0 &&
            clue.relation == HorizontalRelation.leftOf &&
            clue.subject == BookIdSelector(bookId: shape.blockAFirst.id) &&
            clue.reference == BookIdSelector(bookId: shape.blockBEnd.id) &&
            clue.id ==
                't03_c04_04_${shape.blockAFirst.id}_left_of_${shape.blockBEnd.id}';
      default:
        return false;
    }
  }

  bool _selectorCardinalityIsAllowed({
    required PuzzleTemplateId templateId,
    required Clue clue,
    required BookSelector selector,
    required int targetCount,
    required int initialCount,
  }) {
    if (targetCount == 0 || initialCount == 0) {
      return false;
    }
    switch (templateId) {
      case PuzzleTemplateId.t01AnchorChain:
        return targetCount == 1 && initialCount == 1;
      case PuzzleTemplateId.t02EdgeSandwich:
        if (selector is BookIdSelector) {
          return targetCount == 1 && initialCount == 1;
        }
        if (clue is BothEdgesClue && identical(selector, clue.subject)) {
          return targetCount == 2 && initialCount == 2;
        }
        if (clue is BetweenClue &&
            (identical(selector, clue.subject) ||
                identical(selector, clue.boundary))) {
          return targetCount == 2 && initialCount == 2;
        }
        if (clue is RelativeOrderClue &&
            identical(selector, clue.reference) &&
            selector is BookColorSelector) {
          return targetCount == 2 && initialCount == 2;
        }
        return false;
      case PuzzleTemplateId.t03AdjacentBlocks:
        if (selector is BookIdSelector) {
          return targetCount == 1 && initialCount == 1;
        }
        if (clue is AdjacentClue &&
            identical(selector, clue.reference) &&
            selector is BookColorSelector) {
          return targetCount == 2 && initialCount == 2;
        }
        if (clue is RelativeOrderClue &&
            identical(selector, clue.reference) &&
            selector is BookColorSelector) {
          return targetCount == 2 && initialCount == 2;
        }
        return false;
    }
  }

  bool _hasSameTemplateOrder(GeneratedStage stage) {
    return switch (stage.templateId) {
      PuzzleTemplateId.t01AnchorChain => permutationAnalyzer.hasSameBookOrder(
        first: stage.targetPlacements,
        second: stage.initialPlacements,
      ),
      PuzzleTemplateId.t02EdgeSandwich =>
        permutationAnalyzer.hasSameVisualOrder(
          first: stage.targetPlacements,
          second: stage.initialPlacements,
        ),
      PuzzleTemplateId.t03AdjacentBlocks =>
        permutationAnalyzer.hasSameVisualOrder(
          first: stage.targetPlacements,
          second: stage.initialPlacements,
        ),
    };
  }

  StageValidationIssueCode _minimumDistanceIssueCode(
    PuzzleTemplateId templateId,
  ) {
    return switch (templateId) {
      PuzzleTemplateId.t01AnchorChain =>
        StageValidationIssueCode.minimumSwapDistanceMismatch,
      PuzzleTemplateId.t02EdgeSandwich =>
        StageValidationIssueCode.minimumVisualSwapDistanceMismatch,
      PuzzleTemplateId.t03AdjacentBlocks =>
        StageValidationIssueCode.minimumVisualSwapDistanceMismatch,
    };
  }

  int _expectedScrambleSeed(int stageSeed, PuzzleTemplateId templateId) {
    final salt = switch (templateId) {
      PuzzleTemplateId.t01AnchorChain => GeneratorConfig.t01ScrambleSalt,
      PuzzleTemplateId.t02EdgeSandwich => GeneratorConfig.t02ScrambleSalt,
      PuzzleTemplateId.t03AdjacentBlocks => GeneratorConfig.t03ScrambleSalt,
    };
    final value = (stageSeed ^ salt) & GeneratorConfig.uint32Mask;
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

  BookColor get edgeColor => edgeLeft.color;

  BookColor get duplicateColor => duplicateCopy01.color;
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
