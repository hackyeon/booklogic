import '../domain/book.dart';
import '../domain/book_placement.dart';
import '../domain/book_position.dart';
import '../domain/clue.dart';
import '../domain/clue_evaluator.dart';
import 'book_code.dart';
import 'book_swap_step.dart';
import 'deterministic_random.dart';
import 'generator_config.dart';
import 'puzzle_template_id.dart';
import 'stage_permutation_analyzer.dart';
import 'template_scramble_result.dart';
import 'template_solution.dart';

class T02EdgeSandwichScrambler {
  const T02EdgeSandwichScrambler({
    this.clueEvaluator = const ClueEvaluator(),
    this.permutationAnalyzer = const StagePermutationAnalyzer(),
  });

  final ClueEvaluator clueEvaluator;
  final StagePermutationAnalyzer permutationAnalyzer;

  bool supports({
    required TemplateSolution solution,
    required List<Clue> clues,
  }) {
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
        spec.clueCount > 5 ||
        spec.targetSwapCount < 3 ||
        spec.targetSwapCount > 4) {
      return false;
    }
    if (targetPlacements.length != 6 ||
        !_hasValidPlacements(targetPlacements)) {
      return false;
    }
    if (!_hasT02DuplicateStructure(targetPlacements)) {
      return false;
    }
    if (clues.length != spec.clueCount || !_hasUniqueClueIds(clues)) {
      return false;
    }
    return _allCluesSatisfied(clues: clues, placements: targetPlacements);
  }

  TemplateScrambleResult create({
    required TemplateSolution solution,
    required List<Clue> clues,
    int? generationSeed,
  }) {
    if (!supports(solution: solution, clues: clues)) {
      throw StateError('T02 Edge Sandwich cannot scramble this input.');
    }

    final sortedTargets = _sortedPlacements(solution.targetPlacements);
    final effectiveSeed = generationSeed ?? solution.stageSpec.seed;
    if (effectiveSeed <= 0 || effectiveSeed > GeneratorConfig.uint32Mask) {
      throw ArgumentError.value(
        effectiveSeed,
        'generationSeed',
        '1부터 ${GeneratorConfig.uint32Mask} 사이여야 합니다.',
      );
    }

    final scrambleSeed = createScrambleSeed(effectiveSeed);
    final random = DeterministicRandom(scrambleSeed);
    final shuffledSlotIndices = random.shuffled(
      List<int>.generate(sortedTargets.length, (index) => index),
    );

    for (var offset = 0; offset < sortedTargets.length; offset += 1) {
      final cycleSlots = [
        for (
          var index = 0;
          index <= solution.stageSpec.targetSwapCount;
          index += 1
        )
          shuffledSlotIndices[(offset + index) % sortedTargets.length],
      ];
      final candidate = _applyCycle(
        solution: solution,
        targetPlacements: sortedTargets,
        scrambleSeed: scrambleSeed,
        cycleSlots: cycleSlots,
      );
      if (candidate == null) {
        continue;
      }

      if (_isValidCandidate(
        result: candidate,
        clues: clues,
        sortedTargets: sortedTargets,
      )) {
        _validateResult(
          result: candidate,
          clues: clues,
          sortedTargets: sortedTargets,
        );
        return candidate;
      }
    }

    throw StateError('T02 Edge Sandwich could not find a valid scramble.');
  }

  int createScrambleSeed(int stageSeed) {
    final value =
        (stageSeed ^ GeneratorConfig.t02ScrambleSalt) &
        GeneratorConfig.uint32Mask;
    if (value == 0) {
      return GeneratorConfig.zeroSeedFallback;
    }
    return value;
  }

  TemplateScrambleResult? _applyCycle({
    required TemplateSolution solution,
    required List<BookPlacement> targetPlacements,
    required int scrambleSeed,
    required List<int> cycleSlots,
  }) {
    final workingBooks = [
      for (final placement in targetPlacements) placement.book,
    ];
    final swapHistory = <BookSwapStep>[];
    final pivotSlot = cycleSlots.first;

    for (var index = 1; index < cycleSlots.length; index += 1) {
      final otherSlot = cycleSlots[index];
      final firstBook = workingBooks[pivotSlot];
      final secondBook = workingBooks[otherSlot];
      if (_visualKey(firstBook) == _visualKey(secondBook)) {
        return null;
      }
      swapHistory.add(
        BookSwapStep(
          stepIndex: swapHistory.length,
          firstPosition: BookPosition(tierIndex: 0, slotIndex: pivotSlot),
          secondPosition: BookPosition(tierIndex: 0, slotIndex: otherSlot),
          firstBookIdBeforeSwap: firstBook.id,
          secondBookIdBeforeSwap: secondBook.id,
        ),
      );
      workingBooks[pivotSlot] = secondBook;
      workingBooks[otherSlot] = firstBook;
    }

    final initialPlacements = [
      for (var slotIndex = 0; slotIndex < workingBooks.length; slotIndex += 1)
        BookPlacement(
          book: workingBooks[slotIndex],
          position: BookPosition(tierIndex: 0, slotIndex: slotIndex),
        ),
    ];
    return TemplateScrambleResult(
      solution: solution,
      scrambleSeed: scrambleSeed,
      initialPlacements: initialPlacements,
      swapHistory: swapHistory,
    );
  }

  bool _isValidCandidate({
    required TemplateScrambleResult result,
    required List<Clue> clues,
    required List<BookPlacement> sortedTargets,
  }) {
    if (permutationAnalyzer.hasSameVisualOrder(
      first: result.initialPlacements,
      second: sortedTargets,
    )) {
      return false;
    }
    if (result.swapHistory.length != result.targetSwapCount) {
      return false;
    }
    if (!_hasDistinctCyclePositions(result.swapHistory)) {
      return false;
    }
    if (!_hasMeaningfulSwaps(result.swapHistory, sortedTargets)) {
      return false;
    }
    if (_allCluesSatisfied(
      clues: clues,
      placements: result.initialPlacements,
    )) {
      return false;
    }
    if (!_sameBookIdSet(sortedTargets, result.initialPlacements)) {
      return false;
    }
    if (!_sameVisualMultiset(sortedTargets, result.initialPlacements)) {
      return false;
    }
    if (permutationAnalyzer.minimumVisualSwapDistance(
          target: sortedTargets,
          current: result.initialPlacements,
        ) !=
        result.targetSwapCount) {
      return false;
    }
    return true;
  }

  void _validateResult({
    required TemplateScrambleResult result,
    required List<Clue> clues,
    required List<BookPlacement> sortedTargets,
  }) {
    if (result.scrambleSeed < 1 ||
        result.scrambleSeed > GeneratorConfig.uint32Mask) {
      throw StateError('T02 scramble seed is outside uint32 range.');
    }
    if (result.initialPlacements.length != sortedTargets.length) {
      throw StateError('T02 initial placement count does not match target.');
    }
    if (permutationAnalyzer.hasSameVisualOrder(
      first: result.initialPlacements,
      second: sortedTargets,
    )) {
      throw StateError('T02 initial visual order matches target.');
    }
    if (result.swapHistory.length != result.targetSwapCount) {
      throw StateError(
        'T02 swap history length does not match targetSwapCount.',
      );
    }
    if (!_hasValidPlacements(result.initialPlacements)) {
      throw StateError('T02 initial placements are invalid.');
    }
    if (!_sameBookIdSet(sortedTargets, result.initialPlacements)) {
      throw StateError('T02 initial book ids do not match target ids.');
    }
    if (!_sameVisualMultiset(sortedTargets, result.initialPlacements)) {
      throw StateError('T02 initial visual books do not match target.');
    }
    if (_allCluesSatisfied(
      clues: clues,
      placements: result.initialPlacements,
    )) {
      throw StateError('T02 initial placements already satisfy every clue.');
    }
    final minimumSwapDistance = permutationAnalyzer.minimumVisualSwapDistance(
      target: sortedTargets,
      current: result.initialPlacements,
    );
    if (minimumSwapDistance != result.targetSwapCount) {
      throw StateError(
        'T02 visual minimum swap distance does not match targetSwapCount.',
      );
    }
    if (!permutationAnalyzer.hasSameBookOrder(
      first: permutationAnalyzer.replayForward(
        start: sortedTargets,
        swapHistory: result.swapHistory,
      ),
      second: result.initialPlacements,
    )) {
      throw StateError('T02 forward replay does not match initial placements.');
    }
    if (!permutationAnalyzer.hasSameBookOrder(
      first: permutationAnalyzer.replayReverse(
        start: result.initialPlacements,
        swapHistory: result.swapHistory,
      ),
      second: sortedTargets,
    )) {
      throw StateError('T02 reverse replay does not match target placements.');
    }
  }

  bool _hasValidPlacements(List<BookPlacement> placements) {
    final bookIds = <String>{};
    final slotIndexes = <int>{};
    final positionKeys = <String>{};

    for (final placement in placements) {
      final book = placement.book;
      final position = placement.position;
      if (position.tierIndex != 0) {
        return false;
      }
      if (!bookIds.add(book.id)) {
        return false;
      }
      if (!slotIndexes.add(position.slotIndex)) {
        return false;
      }
      if (!positionKeys.add('${position.tierIndex}:${position.slotIndex}')) {
        return false;
      }
    }

    for (var slotIndex = 0; slotIndex < placements.length; slotIndex += 1) {
      if (!slotIndexes.contains(slotIndex)) {
        return false;
      }
    }
    return true;
  }

  bool _hasT02DuplicateStructure(List<BookPlacement> placements) {
    final counts = _visualCounts(placements);
    final duplicateCounts = counts.values.where((count) => count > 1).toList();
    return duplicateCounts.length == 1 && duplicateCounts.single == 2;
  }

  bool _hasUniqueClueIds(List<Clue> clues) {
    final ids = <String>{};
    for (final clue in clues) {
      if (!ids.add(clue.id)) {
        return false;
      }
    }
    return true;
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

  bool _hasDistinctCyclePositions(List<BookSwapStep> swapHistory) {
    if (swapHistory.isEmpty) {
      return false;
    }
    final slots = <int>{swapHistory.first.firstPosition.slotIndex};
    for (final step in swapHistory) {
      if (step.firstPosition.tierIndex != 0 ||
          step.secondPosition.tierIndex != 0) {
        return false;
      }
      if (step.firstPosition == step.secondPosition) {
        return false;
      }
      if (step.firstPosition != swapHistory.first.firstPosition) {
        return false;
      }
      if (!slots.add(step.secondPosition.slotIndex)) {
        return false;
      }
    }
    return slots.length == swapHistory.length + 1;
  }

  bool _hasMeaningfulSwaps(
    List<BookSwapStep> swapHistory,
    List<BookPlacement> sortedTargets,
  ) {
    final workingBooks = [
      for (final placement in sortedTargets) placement.book,
    ];
    for (final step in swapHistory) {
      final firstSlot = step.firstPosition.slotIndex;
      final secondSlot = step.secondPosition.slotIndex;
      final firstBook = workingBooks[firstSlot];
      final secondBook = workingBooks[secondSlot];
      if (firstBook.id == secondBook.id) {
        return false;
      }
      if (_visualKey(firstBook) == _visualKey(secondBook)) {
        return false;
      }
      if (step.firstBookIdBeforeSwap != firstBook.id ||
          step.secondBookIdBeforeSwap != secondBook.id) {
        return false;
      }
      workingBooks[firstSlot] = secondBook;
      workingBooks[secondSlot] = firstBook;
    }
    return true;
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

  bool _sameBookIdSet(List<BookPlacement> target, List<BookPlacement> initial) {
    return _setEquals(_bookIdSet(target), _bookIdSet(initial));
  }

  bool _sameVisualMultiset(
    List<BookPlacement> target,
    List<BookPlacement> initial,
  ) {
    return _mapEquals(_visualCounts(target), _visualCounts(initial));
  }

  Set<String> _bookIdSet(List<BookPlacement> placements) {
    return {for (final placement in placements) placement.book.id};
  }

  Map<String, int> _visualCounts(List<BookPlacement> placements) {
    final counts = <String, int>{};
    for (final placement in placements) {
      counts.update(
        _visualKey(placement.book),
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    return counts;
  }

  bool _setEquals(Set<String> left, Set<String> right) {
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

  bool _mapEquals(Map<String, int> left, Map<String, int> right) {
    if (left.length != right.length) {
      return false;
    }
    for (final entry in left.entries) {
      if (right[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  String _visualKey(Book book) {
    return BookCode.bookId(color: book.color, symbol: book.symbol);
  }
}
