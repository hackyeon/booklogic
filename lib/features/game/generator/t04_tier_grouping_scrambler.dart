import '../domain/book_placement.dart';
import '../domain/book_position.dart';
import '../domain/clue.dart';
import '../domain/clue_evaluator.dart';
import 'book_swap_step.dart';
import 'deterministic_random.dart';
import 'generator_config.dart';
import 'puzzle_template_id.dart';
import 'stage_permutation_analyzer.dart';
import 't04_tier_grouping_support.dart';
import 'template_scramble_result.dart';
import 'template_solution.dart';

class T04TierGroupingScrambler {
  const T04TierGroupingScrambler({
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
    if (solution.templateId != PuzzleTemplateId.t04TierGrouping) {
      return false;
    }
    if (spec.tierCount != 2 ||
        spec.booksPerTier != 4 ||
        spec.totalBookCount != 8 ||
        (spec.duplicateGroupCount != 0 && spec.duplicateGroupCount != 1) ||
        spec.clueCount < 4 ||
        spec.clueCount > 6 ||
        spec.targetSwapCount < 3 ||
        spec.targetSwapCount > 5) {
      return false;
    }
    if (!_hasValidPlacements(targetPlacements, spec.booksPerTier) ||
        T04TierGroupingShape.fromPlacements(
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
      throw StateError('T04 Tier Grouping cannot scramble this input.');
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

    for (var offset = 0; offset < sortedTargets.length; offset += 1) {
      final cycleFlatIndices = [
        for (
          var index = 0;
          index <= solution.stageSpec.targetSwapCount;
          index += 1
        )
          shuffledFlatIndices[(offset + index) % sortedTargets.length],
      ];
      final candidate = _applyCycle(
        solution: solution,
        targetPlacements: sortedTargets,
        scrambleSeed: scrambleSeed,
        cycleFlatIndices: cycleFlatIndices,
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

    throw StateError('T04 Tier Grouping could not find a valid scramble.');
  }

  int createScrambleSeed(int stageSeed) {
    final value =
        (stageSeed ^ GeneratorConfig.t04ScrambleSalt) &
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
      if (visualKey(firstBook) == visualKey(secondBook)) {
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
      throw StateError('T04 scramble seed is outside uint32 range.');
    }
    if (result.initialPlacements.length != sortedTargets.length) {
      throw StateError('T04 initial placement count does not match target.');
    }
    if (!_hasValidPlacements(
      result.initialPlacements,
      result.solution.stageSpec.booksPerTier,
    )) {
      throw StateError('T04 initial placements are invalid.');
    }
    if (permutationAnalyzer.hasSameVisualOrder(
      first: result.initialPlacements,
      second: sortedTargets,
    )) {
      throw StateError('T04 initial visual order matches target.');
    }
    if (!_hasCrossTierSwap(result.swapHistory)) {
      throw StateError('T04 swap history must contain a cross-tier swap.');
    }
    if (_allCluesSatisfied(
      clues: clues,
      placements: result.initialPlacements,
    )) {
      throw StateError('T04 initial placements already satisfy every clue.');
    }
    if (!_hasUnsatisfiedTierAssignment(
      clues: clues,
      placements: result.initialPlacements,
    )) {
      throw StateError('T04 initial placements must break a C01 clue.');
    }
    if (!_sameBookIdSet(sortedTargets, result.initialPlacements)) {
      throw StateError('T04 initial book ids do not match target ids.');
    }
    if (!_sameVisualMultiset(sortedTargets, result.initialPlacements)) {
      throw StateError('T04 initial visual books do not match target.');
    }
    final minimumSwapDistance = permutationAnalyzer.minimumVisualSwapDistance(
      target: sortedTargets,
      current: result.initialPlacements,
    );
    if (minimumSwapDistance != result.targetSwapCount) {
      throw StateError(
        'T04 visual minimum swap distance does not match targetSwapCount.',
      );
    }
    if (!permutationAnalyzer.hasSameBookOrder(
      first: permutationAnalyzer.replayForward(
        start: sortedTargets,
        swapHistory: result.swapHistory,
      ),
      second: result.initialPlacements,
    )) {
      throw StateError('T04 forward replay does not match initial placements.');
    }
    if (!permutationAnalyzer.hasSameBookOrder(
      first: permutationAnalyzer.replayReverse(
        start: result.initialPlacements,
        swapHistory: result.swapHistory,
      ),
      second: sortedTargets,
    )) {
      throw StateError('T04 reverse replay does not match target placements.');
    }
  }

  bool _hasValidPlacements(List<BookPlacement> placements, int booksPerTier) {
    final bookIds = <String>{};
    final positionKeys = <String>{};
    for (final placement in placements) {
      final book = placement.book;
      final position = placement.position;
      if (!bookIds.add(book.id)) {
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
    if (positionKeys.length != 8) {
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
          visualKey(firstBook) == visualKey(secondBook)) {
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
        visualKey(placement.book),
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
