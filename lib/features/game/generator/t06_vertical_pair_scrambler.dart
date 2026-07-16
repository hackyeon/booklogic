import '../domain/book.dart';
import '../domain/book_placement.dart';
import '../domain/book_position.dart';
import '../domain/clue.dart';
import '../domain/clue_evaluator.dart';
import 'book_code.dart';
import 'book_swap_step.dart';
import 'deterministic_random.dart';
import 'generator_config.dart';
import 'stage_permutation_analyzer.dart';
import 't06_layout_plan.dart';
import 't06_rule_profile_resolver.dart';
import 'template_scramble_result.dart';
import 'template_solution.dart';

class T06VerticalPairScrambler {
  const T06VerticalPairScrambler({
    this.profileResolver = const T06RuleProfileResolver(),
    this.clueEvaluator = const ClueEvaluator(),
    this.permutationAnalyzer = const StagePermutationAnalyzer(),
  });

  final T06RuleProfileResolver profileResolver;
  final ClueEvaluator clueEvaluator;
  final StagePermutationAnalyzer permutationAnalyzer;

  TemplateScrambleResult create({
    required TemplateSolution solution,
    required List<Clue> clues,
    required int generationSeed,
    List<List<int>> priorityCycles = const [],
  }) {
    if (generationSeed <= 0 || generationSeed > GeneratorConfig.uint32Mask) {
      throw ArgumentError.value(
        generationSeed,
        'generationSeed',
        '1부터 ${GeneratorConfig.uint32Mask} 사이여야 합니다.',
      );
    }
    final scrambleSeed = createScrambleSeed(generationSeed);
    final plan = T06LayoutPlan.fromStageSpec(solution.stageSpec);
    final seenCycles = <String>{};

    for (final cycle in priorityCycles) {
      final result = _tryCycle(
        solution: solution,
        clues: clues,
        plan: plan,
        scrambleSeed: scrambleSeed,
        cycle: cycle,
        seenCycles: seenCycles,
      );
      if (result != null) {
        return result;
      }
    }

    final shuffledFlatIndexes = DeterministicRandom(
      scrambleSeed,
    ).shuffled(List<int>.generate(solution.stageSpec.totalBookCount, (i) => i));

    for (final cycle in _circularCycles(
      shuffledFlatIndexes,
      solution.stageSpec.targetSwapCount + 1,
    )) {
      final result = _tryCycle(
        solution: solution,
        clues: clues,
        plan: plan,
        scrambleSeed: scrambleSeed,
        cycle: cycle,
        seenCycles: seenCycles,
      );
      if (result != null) {
        return result;
      }
    }
    for (final cycle in _combinationCycles(
      solution.stageSpec.totalBookCount,
      solution.stageSpec.targetSwapCount + 1,
    )) {
      final result = _tryCycle(
        solution: solution,
        clues: clues,
        plan: plan,
        scrambleSeed: scrambleSeed,
        cycle: cycle,
        seenCycles: seenCycles,
      );
      if (result != null) {
        return result;
      }
    }
    throw StateError('T06 could not find a valid scramble cycle.');
  }

  int createScrambleSeed(int generationSeed) {
    final value =
        (generationSeed ^ GeneratorConfig.t06ScrambleSalt) &
        GeneratorConfig.uint32Mask;
    return value == 0 ? GeneratorConfig.zeroSeedFallback : value;
  }

  TemplateScrambleResult? _tryCycle({
    required TemplateSolution solution,
    required List<Clue> clues,
    required T06LayoutPlan plan,
    required int scrambleSeed,
    required List<int> cycle,
    required Set<String> seenCycles,
  }) {
    final key = cycle.join(',');
    if (!seenCycles.add(key)) {
      return null;
    }
    final positions = [
      for (final flatIndex in cycle) plan.positionForFlatIndex(flatIndex),
    ];
    final pivot = positions.first;
    final working = _sorted(solution.targetPlacements);
    final steps = <BookSwapStep>[];

    for (var index = 1; index < positions.length; index += 1) {
      final second = positions[index];
      final firstBook = _bookAt(working, pivot);
      final secondBook = _bookAt(working, second);
      if (_visualKey(firstBook) == _visualKey(secondBook)) {
        return null;
      }
      steps.add(
        BookSwapStep(
          stepIndex: index - 1,
          firstPosition: pivot,
          secondPosition: second,
          firstBookIdBeforeSwap: firstBook.id,
          secondBookIdBeforeSwap: secondBook.id,
        ),
      );
      _swapBooks(working, pivot, second);
    }

    final result = TemplateScrambleResult(
      solution: solution,
      scrambleSeed: scrambleSeed,
      initialPlacements: working,
      swapHistory: steps,
    );
    return _passesQuality(solution: solution, clues: clues, result: result)
        ? result
        : null;
  }

  bool _passesQuality({
    required TemplateSolution solution,
    required List<Clue> clues,
    required TemplateScrambleResult result,
  }) {
    final profile = profileResolver.resolve(solution.level);
    if (result.swapHistory.length != solution.stageSpec.targetSwapCount) {
      return false;
    }
    final crossTierCount = result.swapHistory
        .where(
          (step) =>
              step.firstPosition.tierIndex != step.secondPosition.tierIndex,
        )
        .length;
    if (crossTierCount < profile.minimumCrossTierSwapCount) {
      return false;
    }
    if (permutationAnalyzer.hasSameVisualOrder(
      first: solution.targetPlacements,
      second: result.initialPlacements,
    )) {
      return false;
    }
    final initialSatisfied = clueEvaluator.evaluateAll(
      clues: clues,
      placements: result.initialPlacements,
    );
    final targetSatisfied = clueEvaluator.evaluateAll(
      clues: clues,
      placements: solution.targetPlacements,
    );
    if (targetSatisfied.length != clues.length ||
        initialSatisfied.length == clues.length ||
        clues.length - initialSatisfied.length <
            profile.minimumUnsatisfiedClueCount) {
      return false;
    }
    if (!_hasInitialFalse<VerticalRelationClue>(
      clues: clues,
      initialSatisfied: initialSatisfied,
    )) {
      return false;
    }
    if (profile.usesNotAtEdge &&
        !_hasInitialFalse<NotAtEdgeClue>(
          clues: clues,
          initialSatisfied: initialSatisfied,
        )) {
      return false;
    }
    if (profile.usesDistance &&
        !_hasInitialFalse<DistanceClue>(
          clues: clues,
          initialSatisfied: initialSatisfied,
        )) {
      return false;
    }
    final distance = permutationAnalyzer.minimumVisualSwapDistance(
      target: solution.targetPlacements,
      current: result.initialPlacements,
    );
    return distance == solution.stageSpec.targetSwapCount;
  }

  bool _hasInitialFalse<T extends Clue>({
    required List<Clue> clues,
    required Set<String> initialSatisfied,
  }) {
    for (final clue in clues) {
      if (clue is T && !initialSatisfied.contains(clue.id)) {
        return true;
      }
    }
    return false;
  }

  Iterable<List<int>> _circularCycles(List<int> shuffled, int length) sync* {
    for (var start = 0; start < shuffled.length; start += 1) {
      yield [
        for (var offset = 0; offset < length; offset += 1)
          shuffled[(start + offset) % shuffled.length],
      ];
    }
  }

  Iterable<List<int>> _combinationCycles(int valueCount, int length) sync* {
    final current = <int>[];
    Iterable<List<int>> search(int start) sync* {
      if (current.length == length) {
        yield List<int>.of(current);
        return;
      }
      final remaining = length - current.length;
      for (var value = start; value <= valueCount - remaining; value += 1) {
        current.add(value);
        yield* search(value + 1);
        current.removeLast();
      }
    }

    yield* search(0);
  }

  List<BookPlacement> _sorted(List<BookPlacement> placements) {
    final sorted = List<BookPlacement>.of(placements);
    sorted.sort((left, right) {
      final tier = left.position.tierIndex.compareTo(right.position.tierIndex);
      if (tier != 0) {
        return tier;
      }
      return left.position.slotIndex.compareTo(right.position.slotIndex);
    });
    return sorted;
  }

  Book _bookAt(List<BookPlacement> placements, BookPosition position) {
    return placements
        .firstWhere((placement) => placement.position == position)
        .book;
  }

  void _swapBooks(
    List<BookPlacement> placements,
    BookPosition first,
    BookPosition second,
  ) {
    final firstIndex = placements.indexWhere(
      (placement) => placement.position == first,
    );
    final secondIndex = placements.indexWhere(
      (placement) => placement.position == second,
    );
    final firstPlacement = placements[firstIndex];
    final secondPlacement = placements[secondIndex];
    placements[firstIndex] = firstPlacement.copyWith(
      book: secondPlacement.book,
    );
    placements[secondIndex] = secondPlacement.copyWith(
      book: firstPlacement.book,
    );
  }

  String _visualKey(Book book) {
    return BookCode.bookId(color: book.color, symbol: book.symbol);
  }
}
