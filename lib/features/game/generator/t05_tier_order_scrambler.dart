import '../domain/book_placement.dart';
import '../domain/book_position.dart';
import '../domain/clue.dart';
import '../domain/clue_evaluator.dart';
import 'book_swap_step.dart';
import 'deterministic_random.dart';
import 'generator_config.dart';
import 'puzzle_template_id.dart';
import 'stage_permutation_analyzer.dart';
import 't05_tier_order_support.dart';
import 'template_scramble_result.dart';
import 'template_solution.dart';

class T05TierOrderScrambler {
  const T05TierOrderScrambler({
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
    if (solution.templateId != PuzzleTemplateId.t05TierOrder) {
      return false;
    }
    if (spec.tierCount != 2 ||
        spec.booksPerTier != 5 ||
        spec.totalBookCount != 10 ||
        (spec.duplicateGroupCount != 1 && spec.duplicateGroupCount != 2) ||
        spec.clueCount < 5 ||
        spec.clueCount > 7 ||
        spec.targetSwapCount < 4 ||
        spec.targetSwapCount > 6) {
      return false;
    }
    if (!_hasValidPlacements(targetPlacements, spec.booksPerTier) ||
        T05TierOrderShape.fromPlacements(
              targetPlacements,
              duplicateGroupCount: spec.duplicateGroupCount,
            ) ==
            null) {
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
      throw StateError('T05 Tier Order cannot scramble this input.');
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
    final shuffledFlatIndices = random.shuffled(
      List<int>.generate(sortedTargets.length, (index) => index),
    );
    final seenCycleKeys = <String>{};

    for (var offset = 0; offset < sortedTargets.length; offset += 1) {
      final cycleFlatIndices = [
        for (
          var index = 0;
          index <= solution.stageSpec.targetSwapCount;
          index += 1
        )
          shuffledFlatIndices[(offset + index) % sortedTargets.length],
      ];
      final candidate = _candidateForCycle(
        solution: solution,
        clues: clues,
        sortedTargets: sortedTargets,
        scrambleSeed: scrambleSeed,
        cycleFlatIndices: cycleFlatIndices,
        seenCycleKeys: seenCycleKeys,
      );
      if (candidate != null) {
        return candidate;
      }
    }

    final chooseCount = solution.stageSpec.targetSwapCount + 1;
    for (final combination in _combinationIndexes(
      valueCount: shuffledFlatIndices.length,
      chooseCount: chooseCount,
    )) {
      final cycleFlatIndices = [
        for (final index in combination) shuffledFlatIndices[index],
      ];
      final candidate = _candidateForCycle(
        solution: solution,
        clues: clues,
        sortedTargets: sortedTargets,
        scrambleSeed: scrambleSeed,
        cycleFlatIndices: cycleFlatIndices,
        seenCycleKeys: seenCycleKeys,
      );
      if (candidate != null) {
        return candidate;
      }
    }

    throw StateError('T05 Tier Order could not find a valid scramble.');
  }

  int createScrambleSeed(int stageSeed) {
    final value =
        (stageSeed ^ GeneratorConfig.t05ScrambleSalt) &
        GeneratorConfig.uint32Mask;
    if (value == 0) {
      return GeneratorConfig.zeroSeedFallback;
    }
    return value;
  }

  TemplateScrambleResult? _candidateForCycle({
    required TemplateSolution solution,
    required List<Clue> clues,
    required List<BookPlacement> sortedTargets,
    required int scrambleSeed,
    required List<int> cycleFlatIndices,
    required Set<String> seenCycleKeys,
  }) {
    final cycleKey = cycleFlatIndices.join(',');
    if (!seenCycleKeys.add(cycleKey)) {
      return null;
    }
    final candidate = _applyCycle(
      solution: solution,
      targetPlacements: sortedTargets,
      scrambleSeed: scrambleSeed,
      cycleFlatIndices: cycleFlatIndices,
    );
    if (candidate == null) {
      return null;
    }
    if (!_isValidCandidate(
      result: candidate,
      clues: clues,
      sortedTargets: sortedTargets,
    )) {
      return null;
    }
    _validateResult(
      result: candidate,
      clues: clues,
      sortedTargets: sortedTargets,
    );
    return candidate;
  }

  TemplateScrambleResult? _applyCycle({
    required TemplateSolution solution,
    required List<BookPlacement> targetPlacements,
    required int scrambleSeed,
    required List<int> cycleFlatIndices,
  }) {
    final booksPerTier = solution.stageSpec.booksPerTier;
    final workingBooks = [
      for (final placement in targetPlacements) placement.book,
    ];
    final swapHistory = <BookSwapStep>[];
    final pivotFlatIndex = cycleFlatIndices.first;

    for (var index = 1; index < cycleFlatIndices.length; index += 1) {
      final otherFlatIndex = cycleFlatIndices[index];
      final firstBook = workingBooks[pivotFlatIndex];
      final secondBook = workingBooks[otherFlatIndex];
      if (t05VisualKey(firstBook) == t05VisualKey(secondBook)) {
        return null;
      }
      swapHistory.add(
        BookSwapStep(
          stepIndex: swapHistory.length,
          firstPosition: _positionForFlatIndex(pivotFlatIndex, booksPerTier),
          secondPosition: _positionForFlatIndex(otherFlatIndex, booksPerTier),
          firstBookIdBeforeSwap: firstBook.id,
          secondBookIdBeforeSwap: secondBook.id,
        ),
      );
      workingBooks[pivotFlatIndex] = secondBook;
      workingBooks[otherFlatIndex] = firstBook;
    }

    final initialPlacements = [
      for (var flatIndex = 0; flatIndex < workingBooks.length; flatIndex += 1)
        BookPlacement(
          book: workingBooks[flatIndex],
          position: _positionForFlatIndex(flatIndex, booksPerTier),
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
    if (permutationAnalyzer.hasSameBookOrder(
      first: result.initialPlacements,
      second: sortedTargets,
    )) {
      return false;
    }
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
    if (!_hasCrossTierSwap(result.swapHistory)) {
      return false;
    }
    if (!_hasMeaningfulSwaps(
      result.swapHistory,
      sortedTargets,
      result.solution.stageSpec.booksPerTier,
    )) {
      return false;
    }
    if (_allCluesSatisfied(
      clues: clues,
      placements: result.initialPlacements,
    )) {
      return false;
    }
    if (!_hasUnsatisfiedTierAssignment(
      clues: clues,
      placements: result.initialPlacements,
    )) {
      return false;
    }
    if (!_hasUnsatisfiedTierOrder(
      clues: clues,
      placements: result.initialPlacements,
      firstIndex: 0,
      secondIndex: 1,
    )) {
      return false;
    }
    if (!_hasUnsatisfiedTierOrder(
      clues: clues,
      placements: result.initialPlacements,
      firstIndex: 2,
      secondIndex: 3,
    )) {
      return false;
    }
    if (!_sameBookIdSet(sortedTargets, result.initialPlacements)) {
      return false;
    }
    if (!_sameVisualMultiset(sortedTargets, result.initialPlacements)) {
      return false;
    }
    try {
      if (permutationAnalyzer.minimumVisualSwapDistance(
            target: sortedTargets,
            current: result.initialPlacements,
          ) !=
          result.targetSwapCount) {
        return false;
      }
      if (!permutationAnalyzer.hasSameBookOrder(
        first: permutationAnalyzer.replayForward(
          start: sortedTargets,
          swapHistory: result.swapHistory,
        ),
        second: result.initialPlacements,
      )) {
        return false;
      }
      if (!permutationAnalyzer.hasSameBookOrder(
        first: permutationAnalyzer.replayReverse(
          start: result.initialPlacements,
          swapHistory: result.swapHistory,
        ),
        second: sortedTargets,
      )) {
        return false;
      }
    } catch (_) {
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
      throw StateError('T05 scramble seed is outside uint32 range.');
    }
    if (result.initialPlacements.length != sortedTargets.length) {
      throw StateError('T05 initial placement count does not match target.');
    }
    if (!_hasValidPlacements(
      result.initialPlacements,
      result.solution.stageSpec.booksPerTier,
    )) {
      throw StateError('T05 initial placements are invalid.');
    }
    if (!_hasCrossTierSwap(result.swapHistory)) {
      throw StateError('T05 swap history must contain a cross-tier swap.');
    }
    if (_allCluesSatisfied(
      clues: clues,
      placements: result.initialPlacements,
    )) {
      throw StateError('T05 initial placements already satisfy every clue.');
    }
    if (!_hasUnsatisfiedTierAssignment(
      clues: clues,
      placements: result.initialPlacements,
    )) {
      throw StateError('T05 initial placements must break a C01 clue.');
    }
    if (!_hasUnsatisfiedTierOrder(
      clues: clues,
      placements: result.initialPlacements,
      firstIndex: 0,
      secondIndex: 1,
    )) {
      throw StateError('T05 top tier order clues are already complete.');
    }
    if (!_hasUnsatisfiedTierOrder(
      clues: clues,
      placements: result.initialPlacements,
      firstIndex: 2,
      secondIndex: 3,
    )) {
      throw StateError('T05 bottom tier order clues are already complete.');
    }
    if (!_sameBookIdSet(sortedTargets, result.initialPlacements)) {
      throw StateError('T05 initial book ids do not match target ids.');
    }
    if (!_sameVisualMultiset(sortedTargets, result.initialPlacements)) {
      throw StateError('T05 initial visual books do not match target.');
    }
    final minimumSwapDistance = permutationAnalyzer.minimumVisualSwapDistance(
      target: sortedTargets,
      current: result.initialPlacements,
    );
    if (minimumSwapDistance != result.targetSwapCount) {
      throw StateError(
        'T05 visual minimum swap distance does not match targetSwapCount.',
      );
    }
    if (!permutationAnalyzer.hasSameBookOrder(
      first: permutationAnalyzer.replayForward(
        start: sortedTargets,
        swapHistory: result.swapHistory,
      ),
      second: result.initialPlacements,
    )) {
      throw StateError('T05 forward replay does not match initial placements.');
    }
    if (!permutationAnalyzer.hasSameBookOrder(
      first: permutationAnalyzer.replayReverse(
        start: result.initialPlacements,
        swapHistory: result.swapHistory,
      ),
      second: sortedTargets,
    )) {
      throw StateError('T05 reverse replay does not match target placements.');
    }
  }

  Iterable<List<int>> _combinationIndexes({
    required int valueCount,
    required int chooseCount,
  }) sync* {
    if (chooseCount < 1 || chooseCount > valueCount) {
      return;
    }
    final indexes = List<int>.generate(chooseCount, (index) => index);
    var hasNext = true;
    while (hasNext) {
      yield List<int>.of(indexes);
      var pivot = chooseCount - 1;
      while (pivot >= 0 && indexes[pivot] == valueCount - chooseCount + pivot) {
        pivot -= 1;
      }
      if (pivot < 0) {
        hasNext = false;
      } else {
        indexes[pivot] += 1;
        for (var index = pivot + 1; index < chooseCount; index += 1) {
          indexes[index] = indexes[index - 1] + 1;
        }
      }
    }
  }

  bool _hasValidPlacements(List<BookPlacement> placements, int booksPerTier) {
    final bookIds = <String>{};
    final positionKeys = <String>{};
    for (final placement in placements) {
      final position = placement.position;
      if (!bookIds.add(placement.book.id)) {
        return false;
      }
      if (position.tierIndex < 0 ||
          position.tierIndex >= 2 ||
          position.slotIndex < 0 ||
          position.slotIndex >= booksPerTier) {
        return false;
      }
      if (!positionKeys.add('${position.tierIndex}:${position.slotIndex}')) {
        return false;
      }
    }
    if (positionKeys.length != 10) {
      return false;
    }
    for (var tierIndex = 0; tierIndex < 2; tierIndex += 1) {
      for (var slotIndex = 0; slotIndex < booksPerTier; slotIndex += 1) {
        if (!positionKeys.contains('$tierIndex:$slotIndex')) {
          return false;
        }
      }
    }
    return true;
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

  bool _hasUnsatisfiedTierAssignment({
    required List<Clue> clues,
    required List<BookPlacement> placements,
  }) {
    var hasTierAssignment = false;
    for (final clue in clues) {
      if (clue is! TierAssignmentClue) {
        continue;
      }
      hasTierAssignment = true;
      if (!clueEvaluator.evaluate(clue: clue, placements: placements)) {
        return true;
      }
    }
    return !hasTierAssignment;
  }

  bool _hasUnsatisfiedTierOrder({
    required List<Clue> clues,
    required List<BookPlacement> placements,
    required int firstIndex,
    required int secondIndex,
  }) {
    if (clues.length <= secondIndex) {
      return false;
    }
    final firstSatisfied = clueEvaluator.evaluate(
      clue: clues[firstIndex],
      placements: placements,
    );
    final secondSatisfied = clueEvaluator.evaluate(
      clue: clues[secondIndex],
      placements: placements,
    );
    return !(firstSatisfied && secondSatisfied);
  }

  bool _hasDistinctCyclePositions(List<BookSwapStep> swapHistory) {
    if (swapHistory.isEmpty) {
      return false;
    }
    final positions = <BookPosition>{swapHistory.first.firstPosition};
    for (final step in swapHistory) {
      if (step.firstPosition == step.secondPosition) {
        return false;
      }
      if (step.firstPosition != swapHistory.first.firstPosition) {
        return false;
      }
      if (!positions.add(step.secondPosition)) {
        return false;
      }
    }
    return positions.length == swapHistory.length + 1;
  }

  bool _hasCrossTierSwap(List<BookSwapStep> swapHistory) {
    for (final step in swapHistory) {
      if (step.firstPosition.tierIndex != step.secondPosition.tierIndex) {
        return true;
      }
    }
    return false;
  }

  bool _hasMeaningfulSwaps(
    List<BookSwapStep> swapHistory,
    List<BookPlacement> sortedTargets,
    int booksPerTier,
  ) {
    final workingBooks = [
      for (final placement in sortedTargets) placement.book,
    ];
    for (final step in swapHistory) {
      final firstIndex = _flatIndex(step.firstPosition, booksPerTier);
      final secondIndex = _flatIndex(step.secondPosition, booksPerTier);
      if (firstIndex == null || secondIndex == null) {
        return false;
      }
      final firstBook = workingBooks[firstIndex];
      final secondBook = workingBooks[secondIndex];
      if (firstBook.id == secondBook.id ||
          t05VisualKey(firstBook) == t05VisualKey(secondBook)) {
        return false;
      }
      if (step.firstBookIdBeforeSwap != firstBook.id ||
          step.secondBookIdBeforeSwap != secondBook.id) {
        return false;
      }
      workingBooks[firstIndex] = secondBook;
      workingBooks[secondIndex] = firstBook;
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

  BookPosition _positionForFlatIndex(int flatIndex, int booksPerTier) {
    return BookPosition(
      tierIndex: flatIndex ~/ booksPerTier,
      slotIndex: flatIndex % booksPerTier,
    );
  }

  int? _flatIndex(BookPosition position, int booksPerTier) {
    if (position.tierIndex < 0 ||
        position.tierIndex >= 2 ||
        position.slotIndex < 0 ||
        position.slotIndex >= booksPerTier) {
      return null;
    }
    return (position.tierIndex * booksPerTier) + position.slotIndex;
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
        t05VisualKey(placement.book),
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
}
