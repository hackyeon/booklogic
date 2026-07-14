import 'package:flutter_test/flutter_test.dart';

import 'package:booklogic/features/game/domain/book.dart';
import 'package:booklogic/features/game/domain/book_placement.dart';
import 'package:booklogic/features/game/domain/book_position.dart';
import 'package:booklogic/features/game/domain/book_selector.dart';
import 'package:booklogic/features/game/domain/clue.dart';
import 'package:booklogic/features/game/domain/clue_evaluator.dart';
import 'package:booklogic/features/game/generator/book_catalog.dart';
import 'package:booklogic/features/game/generator/book_swap_step.dart';
import 'package:booklogic/features/game/generator/deterministic_random.dart';
import 'package:booklogic/features/game/generator/difficulty_profile.dart';
import 'package:booklogic/features/game/generator/generator_config.dart';
import 'package:booklogic/features/game/generator/puzzle_template_id.dart';
import 'package:booklogic/features/game/generator/stage_generation_key.dart';
import 'package:booklogic/features/game/generator/stage_layout.dart';
import 'package:booklogic/features/game/generator/stage_spec.dart';
import 'package:booklogic/features/game/generator/stage_spec_factory.dart';
import 'package:booklogic/features/game/generator/t01_anchor_chain_clue_factory.dart';
import 'package:booklogic/features/game/generator/t01_anchor_chain_scrambler.dart';
import 'package:booklogic/features/game/generator/t01_anchor_chain_solution_factory.dart';
import 'package:booklogic/features/game/generator/template_scramble_result.dart';
import 'package:booklogic/features/game/generator/template_solution.dart';

void main() {
  group('BookSwapStep', () {
    test('stores fields, compares values, and prints debugging data', () {
      const first = BookPosition(tierIndex: 0, slotIndex: 2);
      const second = BookPosition(tierIndex: 0, slotIndex: 1);
      const step = BookSwapStep(
        stepIndex: 0,
        firstPosition: first,
        secondPosition: second,
        firstBookIdBeforeSwap: 'blue_leaf',
        secondBookIdBeforeSwap: 'blue_moon',
      );

      expect(step.stepIndex, 0);
      expect(step.firstPosition, first);
      expect(step.secondPosition, second);
      expect(step.firstBookIdBeforeSwap, 'blue_leaf');
      expect(step.secondBookIdBeforeSwap, 'blue_moon');
      expect(
        step,
        const BookSwapStep(
          stepIndex: 0,
          firstPosition: first,
          secondPosition: second,
          firstBookIdBeforeSwap: 'blue_leaf',
          secondBookIdBeforeSwap: 'blue_moon',
        ),
      );
      expect(
        step,
        isNot(
          const BookSwapStep(
            stepIndex: 1,
            firstPosition: first,
            secondPosition: second,
            firstBookIdBeforeSwap: 'blue_leaf',
            secondBookIdBeforeSwap: 'blue_moon',
          ),
        ),
      );
      expect(
        step,
        isNot(
          const BookSwapStep(
            stepIndex: 0,
            firstPosition: BookPosition(tierIndex: 0, slotIndex: 3),
            secondPosition: second,
            firstBookIdBeforeSwap: 'blue_leaf',
            secondBookIdBeforeSwap: 'blue_moon',
          ),
        ),
      );
      expect(
        step,
        isNot(
          const BookSwapStep(
            stepIndex: 0,
            firstPosition: first,
            secondPosition: second,
            firstBookIdBeforeSwap: 'yellow_leaf',
            secondBookIdBeforeSwap: 'blue_moon',
          ),
        ),
      );
      expect(step.toString(), contains('stepIndex: 0'));
      expect(step.toString(), contains('blue_leaf'));
      expect(step.toString(), contains('blue_moon'));
    });
  });

  group('TemplateScrambleResult', () {
    test(
      'stores fields, exposes getters, compares values, and protects lists',
      () {
        final solution = _solutionForIds(_ids4, targetSwapCount: 2);
        final initial = _placementsForIds([
          'red_key',
          'blue_leaf',
          'yellow_leaf',
          'blue_moon',
        ]);
        final history = [
          const BookSwapStep(
            stepIndex: 0,
            firstPosition: BookPosition(tierIndex: 0, slotIndex: 2),
            secondPosition: BookPosition(tierIndex: 0, slotIndex: 1),
            firstBookIdBeforeSwap: 'blue_leaf',
            secondBookIdBeforeSwap: 'blue_moon',
          ),
          const BookSwapStep(
            stepIndex: 1,
            firstPosition: BookPosition(tierIndex: 0, slotIndex: 2),
            secondPosition: BookPosition(tierIndex: 0, slotIndex: 3),
            firstBookIdBeforeSwap: 'blue_moon',
            secondBookIdBeforeSwap: 'yellow_leaf',
          ),
        ];
        final result = TemplateScrambleResult(
          solution: solution,
          scrambleSeed: 1556238703,
          initialPlacements: initial,
          swapHistory: history,
        );
        final same = TemplateScrambleResult(
          solution: solution,
          scrambleSeed: 1556238703,
          initialPlacements: _placementsForIds([
            'red_key',
            'blue_leaf',
            'yellow_leaf',
            'blue_moon',
          ]),
          swapHistory: List<BookSwapStep>.of(history),
        );

        initial.add(
          BookPlacement(
            book: _catalogBook('green_key'),
            position: const BookPosition(tierIndex: 0, slotIndex: 4),
          ),
        );
        history.removeLast();

        expect(result.solution, solution);
        expect(result.scrambleSeed, 1556238703);
        expect(_placementIds(result.initialPlacements), [
          'red_key',
          'blue_leaf',
          'yellow_leaf',
          'blue_moon',
        ]);
        expect(result.swapHistory, hasLength(2));
        expect(result.targetPlacements, solution.targetPlacements);
        expect(result.level, solution.stageSpec.level);
        expect(result.targetSwapCount, 2);
        expect(result.totalBookCount, 4);
        expect(result, same);
        expect(
          result,
          isNot(
            TemplateScrambleResult(
              solution: solution,
              scrambleSeed: 1556238703,
              initialPlacements: _placementsForIds([
                'red_key',
                'blue_moon',
                'blue_leaf',
                'yellow_leaf',
              ]),
              swapHistory: same.swapHistory,
            ),
          ),
        );
        expect(
          result,
          isNot(
            TemplateScrambleResult(
              solution: solution,
              scrambleSeed: 1556238703,
              initialPlacements: same.initialPlacements,
              swapHistory: same.swapHistory.take(1).toList(),
            ),
          ),
        );
        expect(result.toString(), contains('scrambleSeed: 1556238703'));
        expect(
          () => result.initialPlacements.add(result.initialPlacements.first),
          throwsUnsupportedError,
        );
        expect(
          () => result.initialPlacements.remove(result.initialPlacements.first),
          throwsUnsupportedError,
        );
        expect(() => result.initialPlacements.clear(), throwsUnsupportedError);
        expect(
          () => result.initialPlacements.sort(
            (left, right) => left.book.id.compareTo(right.book.id),
          ),
          throwsUnsupportedError,
        );
        expect(
          () => result.initialPlacements.shuffle(),
          throwsUnsupportedError,
        );
        expect(
          () => result.swapHistory.add(result.swapHistory.first),
          throwsUnsupportedError,
        );
        expect(
          () => result.swapHistory.remove(result.swapHistory.first),
          throwsUnsupportedError,
        );
        expect(() => result.swapHistory.clear(), throwsUnsupportedError);
        expect(
          () => result.swapHistory.sort(
            (left, right) => left.stepIndex.compareTo(right.stepIndex),
          ),
          throwsUnsupportedError,
        );
        expect(() => result.swapHistory.shuffle(), throwsUnsupportedError);
      },
    );
  });

  group('T01AnchorChainScrambler supports', () {
    const scrambler = T01AnchorChainScrambler();

    test(
      'supports generated level 1, 6, and 20 solutions with generated clues',
      () {
        for (final level in [1, 6, 20]) {
          final fixture = _fixture(level);
          expect(
            scrambler.supports(
              solution: fixture.solution,
              clues: fixture.clues,
            ),
            isTrue,
            reason: 'level $level',
          );
        }
      },
    );

    test('rejects invalid solutions and clue lists', () {
      final fixture = _fixture(1);
      expect(
        scrambler.supports(
          solution: _solutionForIds(_ids4, tierCount: 2, targetSwapCount: 2),
          clues: fixture.clues,
        ),
        isFalse,
      );
      expect(
        scrambler.supports(
          solution: _solutionForIds(
            _ids4,
            targetSwapCount: 2,
            duplicateGroupCount: 1,
            maxDuplicateCopies: 2,
          ),
          clues: fixture.clues,
        ),
        isFalse,
      );
      expect(() => _customSpec(targetSwapCount: 0), throwsAssertionError);
      expect(
        scrambler.supports(
          solution: _solutionForIds(_ids4, targetSwapCount: 4),
          clues: fixture.clues,
        ),
        isFalse,
      );
      expect(
        scrambler.supports(
          solution: _solutionForIds(
            _ids4.take(3).toList(),
            booksPerTier: 4,
            targetSwapCount: 2,
          ),
          clues: fixture.clues,
        ),
        isFalse,
      );
      expect(
        scrambler.supports(
          solution: _solutionForIds(
            _ids4,
            targetSwapCount: 2,
            slotIndexes: [0, 1, 2, 4],
          ),
          clues: fixture.clues,
        ),
        isFalse,
      );
      expect(
        scrambler.supports(
          solution: _solutionFromPlacements([
            _placement(_catalogBook('red_key'), slotIndex: 0),
            _placement(_catalogBook('red_key'), slotIndex: 1),
            _placement(_catalogBook('blue_leaf'), slotIndex: 2),
            _placement(_catalogBook('yellow_leaf'), slotIndex: 3),
          ], targetSwapCount: 2),
          clues: fixture.clues,
        ),
        isFalse,
      );
      expect(
        scrambler.supports(
          solution: _solutionFromPlacements([
            _placement(_catalogBook('red_key'), slotIndex: 0),
            _placement(_catalogBook('blue_moon'), slotIndex: 1),
            _placement(
              const Book(
                id: 'blue_moon_copy',
                color: BookColor.blue,
                symbol: BookSymbol.moon,
              ),
              slotIndex: 2,
            ),
            _placement(_catalogBook('yellow_leaf'), slotIndex: 3),
          ], targetSwapCount: 2),
          clues: fixture.clues,
        ),
        isFalse,
      );
      expect(
        scrambler.supports(
          solution: fixture.solution,
          clues: fixture.clues.take(2).toList(),
        ),
        isFalse,
      );
      expect(
        scrambler.supports(
          solution: fixture.solution,
          clues: [fixture.clues.first, fixture.clues.first, fixture.clues.last],
        ),
        isFalse,
      );
      expect(
        scrambler.supports(
          solution: fixture.solution,
          clues: [
            EdgePositionClue(
              id: 'false_left_edge',
              subject: BookIdSelector(
                bookId: fixture.solution.targetPlacements[1].book.id,
              ),
              tierIndex: 0,
              edge: ShelfEdge.left,
            ),
            ...fixture.clues.skip(1),
          ],
        ),
        isFalse,
      );
    });
  });

  group('T01AnchorChainScrambler seeds and golden results', () {
    const scrambler = T01AnchorChainScrambler();

    test('scramble seed is derived by fixed XOR salt', () {
      expect(GeneratorConfig.t01ScrambleSalt, 0x9E3779B9);
      expect(scrambler.createScrambleSeed(3270846678), 1556238703);
      expect(scrambler.createScrambleSeed(651865735), 3102594878);
      expect(scrambler.createScrambleSeed(279833785), 2392495360);
      expect(scrambler.createScrambleSeed(3270846678), 1556238703);
      expect(
        scrambler.createScrambleSeed(3270846678),
        isNot(scrambler.createScrambleSeed(651865735)),
      );
      expect(
        scrambler.createScrambleSeed(3270846678),
        inInclusiveRange(0, GeneratorConfig.uint32Mask),
      );
      expect(
        scrambler.createScrambleSeed(GeneratorConfig.t01ScrambleSalt),
        GeneratorConfig.zeroSeedFallback,
      );
    });

    test('level 1 golden scramble remains stable', () {
      final fixture = _fixture(1);
      final result = scrambler.create(
        solution: fixture.solution,
        clues: fixture.clues,
      );

      expect(fixture.spec.seed, 3270846678);
      expect(fixture.spec.targetSwapCount, 2);
      expect(result.scrambleSeed, 1556238703);
      expect(_shuffledSlotIndices(fixture.spec.seed, 4), [2, 1, 3, 0]);
      expect(_placementIds(fixture.solution.targetPlacements), _ids4);
      expect(_placementIds(result.initialPlacements), [
        'red_key',
        'blue_leaf',
        'yellow_leaf',
        'blue_moon',
      ]);
      _expectSwapStep(
        result.swapHistory[0],
        stepIndex: 0,
        firstSlot: 2,
        secondSlot: 1,
        firstBookId: 'blue_leaf',
        secondBookId: 'blue_moon',
      );
      _expectSwapStep(
        result.swapHistory[1],
        stepIndex: 1,
        firstSlot: 2,
        secondSlot: 3,
        firstBookId: 'blue_moon',
        secondBookId: 'yellow_leaf',
      );
      _expectScrambleIntegrity(fixture, result);
    });

    test('level 6 golden scramble remains stable', () {
      final fixture = _fixture(6);
      final result = scrambler.create(
        solution: fixture.solution,
        clues: fixture.clues,
      );

      expect(fixture.spec.seed, 651865735);
      expect(fixture.spec.targetSwapCount, 2);
      expect(result.scrambleSeed, 3102594878);
      expect(_shuffledSlotIndices(fixture.spec.seed, 5), [0, 3, 1, 2, 4]);
      expect(_placementIds(result.initialPlacements), [
        'yellow_drop',
        'yellow_moon',
        'blue_leaf',
        'orange_moon',
        'yellow_star',
      ]);
      _expectSwapStep(
        result.swapHistory[0],
        stepIndex: 0,
        firstSlot: 0,
        secondSlot: 3,
        firstBookId: 'orange_moon',
        secondBookId: 'yellow_moon',
      );
      _expectSwapStep(
        result.swapHistory[1],
        stepIndex: 1,
        firstSlot: 0,
        secondSlot: 1,
        firstBookId: 'yellow_moon',
        secondBookId: 'yellow_drop',
      );
      _expectScrambleIntegrity(fixture, result);
    });

    test('level 20 golden scramble remains stable', () {
      final fixture = _fixture(20);
      final result = scrambler.create(
        solution: fixture.solution,
        clues: fixture.clues,
      );

      expect(fixture.spec.seed, 279833785);
      expect(fixture.spec.targetSwapCount, 3);
      expect(result.scrambleSeed, 2392495360);
      expect(_shuffledSlotIndices(fixture.spec.seed, 5), [1, 4, 2, 0, 3]);
      expect(_placementIds(result.initialPlacements), [
        'yellow_moon',
        'red_drop',
        'green_key',
        'blue_star',
        'yellow_sun',
      ]);
      _expectSwapStep(
        result.swapHistory[0],
        stepIndex: 0,
        firstSlot: 1,
        secondSlot: 4,
        firstBookId: 'yellow_sun',
        secondBookId: 'green_key',
      );
      _expectSwapStep(
        result.swapHistory[1],
        stepIndex: 1,
        firstSlot: 1,
        secondSlot: 2,
        firstBookId: 'green_key',
        secondBookId: 'yellow_moon',
      );
      _expectSwapStep(
        result.swapHistory[2],
        stepIndex: 2,
        firstSlot: 1,
        secondSlot: 0,
        firstBookId: 'yellow_moon',
        secondBookId: 'red_drop',
      );
      _expectScrambleIntegrity(fixture, result);
    });

    test('level 15 uses deterministic circular window fallback', () {
      final fixture = _fixture(15);
      final firstWindowInitial = _applyCycle(
        fixture.solution.targetPlacements,
        [2, 3, 4],
      );
      final firstSatisfied = const ClueEvaluator().evaluateAll(
        clues: fixture.clues,
        placements: firstWindowInitial,
      );
      final result = scrambler.create(
        solution: fixture.solution,
        clues: fixture.clues,
      );

      expect(_placementIds(fixture.solution.targetPlacements), [
        'red_sun',
        'orange_moon',
        'yellow_diamond',
        'blue_moon',
        'blue_key',
      ]);
      expect(fixture.spec.seed, 765167081);
      expect(result.scrambleSeed, 3014458448);
      expect(_shuffledSlotIndices(fixture.spec.seed, 5), [2, 3, 4, 0, 1]);
      expect(firstSatisfied, hasLength(fixture.clues.length));
      expect(_placementIds(result.initialPlacements), [
        'blue_key',
        'orange_moon',
        'yellow_diamond',
        'red_sun',
        'blue_moon',
      ]);
      expect(result.swapHistory.first.firstPosition.slotIndex, 3);
      expect(result.swapHistory.first.secondPosition.slotIndex, 4);
      _expectScrambleIntegrity(fixture, result);
    });
  });

  group('T01AnchorChainScrambler level integrity and determinism', () {
    const scrambler = T01AnchorChainScrambler();

    test('levels 1 through 20 produce valid scrambles', () {
      for (var level = 1; level <= 20; level += 1) {
        final fixture = _fixture(level);
        final result = scrambler.create(
          solution: fixture.solution,
          clues: fixture.clues,
        );

        expect(
          scrambler.supports(solution: fixture.solution, clues: fixture.clues),
          isTrue,
          reason: 'level $level',
        );
        _expectScrambleIntegrity(fixture, result);
      }
    });

    test('same inputs produce the same result without app state', () {
      final fixture = _fixture(1);
      final expected = scrambler.create(
        solution: fixture.solution,
        clues: fixture.clues,
      );

      for (var index = 0; index < 100; index += 1) {
        expect(
          scrambler.create(solution: fixture.solution, clues: fixture.clues),
          expected,
        );
      }
      expect(
        const T01AnchorChainScrambler().create(
          solution: fixture.solution,
          clues: fixture.clues,
        ),
        expected,
      );
      expect(
        scrambler.create(
          solution: fixture.solution,
          clues: List<Clue>.of(fixture.clues),
        ),
        expected,
      );
      final reversedSolution = TemplateSolution(
        stageSpec: fixture.solution.stageSpec,
        templateId: fixture.solution.templateId,
        targetPlacements: fixture.solution.targetPlacements.reversed.toList(),
      );
      final reversedResult = scrambler.create(
        solution: reversedSolution,
        clues: fixture.clues,
      );
      expect(
        _placementIds(reversedResult.initialPlacements),
        _placementIds(expected.initialPlacements),
      );
      expect(reversedResult.swapHistory, expected.swapHistory);
      expect(reversedResult.scrambleSeed, expected.scrambleSeed);
    });

    test('does not mutate solution, clues, or catalog data', () {
      final catalog = const BookCatalog();
      final catalogBefore = _bookIds(catalog.books);
      final fixture = _fixture(6);
      final solutionBefore = _placementSignature(
        fixture.solution.targetPlacements,
      );
      final clueIdsBefore = _clueIds(fixture.clues);
      final result = scrambler.create(
        solution: fixture.solution,
        clues: fixture.clues,
      );

      expect(result, isA<TemplateScrambleResult>());
      expect(
        _placementSignature(fixture.solution.targetPlacements),
        solutionBefore,
      );
      expect(_clueIds(fixture.clues), clueIdsBefore);
      expect(_bookIds(catalog.books), catalogBefore);
    });

    test('throws StateError for unsupported create inputs', () {
      final fixture = _fixture(1);
      expect(
        () => scrambler.create(
          solution: _solutionForIds(_ids4, tierCount: 2, targetSwapCount: 2),
          clues: fixture.clues,
        ),
        throwsStateError,
      );
      expect(
        () => scrambler.create(
          solution: _solutionForIds(_ids4, targetSwapCount: 4),
          clues: fixture.clues,
        ),
        throwsStateError,
      );
      expect(
        () => scrambler.create(
          solution: fixture.solution,
          clues: fixture.clues.take(2).toList(),
        ),
        throwsStateError,
      );
      expect(
        () => scrambler.create(
          solution: fixture.solution,
          clues: [fixture.clues.first, fixture.clues.first, fixture.clues.last],
        ),
        throwsStateError,
      );
      expect(
        () => scrambler.create(
          solution: fixture.solution,
          clues: [
            EdgePositionClue(
              id: 'false_left_edge',
              subject: BookIdSelector(
                bookId: fixture.solution.targetPlacements[1].book.id,
              ),
              tierIndex: 0,
              edge: ShelfEdge.left,
            ),
            ...fixture.clues.skip(1),
          ],
        ),
        throwsStateError,
      );
      expect(
        () => scrambler.create(
          solution: _solutionForIds(
            _ids4,
            targetSwapCount: 2,
            slotIndexes: [0, 0, 1, 2],
          ),
          clues: fixture.clues,
        ),
        throwsStateError,
      );
      expect(
        () => scrambler.create(
          solution: _solutionForIds(
            _ids4,
            targetSwapCount: 2,
            slotIndexes: [0, 1, 2, 4],
          ),
          clues: fixture.clues,
        ),
        throwsStateError,
      );
      expect(
        () => scrambler.create(
          solution: _solutionForIds(
            _ids4.take(3).toList(),
            booksPerTier: 4,
            targetSwapCount: 2,
          ),
          clues: fixture.clues,
        ),
        throwsStateError,
      );
    });
  });
}

const _ids4 = ['red_key', 'blue_moon', 'blue_leaf', 'yellow_leaf'];

class _Fixture {
  const _Fixture({
    required this.spec,
    required this.solution,
    required this.clues,
  });

  final StageSpec spec;
  final TemplateSolution solution;
  final List<Clue> clues;
}

_Fixture _fixture(int level) {
  const specFactory = StageSpecFactory();
  const solutionFactory = T01AnchorChainSolutionFactory();
  const clueFactory = T01AnchorChainClueFactory();
  final spec = specFactory.create(level: level);
  final solution = solutionFactory.create(spec);
  final clues = clueFactory.create(solution);
  return _Fixture(spec: spec, solution: solution, clues: clues);
}

StageSpec _customSpec({
  int tierCount = 1,
  int booksPerTier = 4,
  int clueCount = 3,
  int targetSwapCount = 2,
  int duplicateGroupCount = 0,
  int maxDuplicateCopies = 1,
}) {
  return StageSpec(
    generationKey: const StageGenerationKey(generatorVersion: 1, level: 999),
    seed: 123456789,
    profileId: DifficultyProfileId.intro,
    layout: StageLayout(tierCount: tierCount, booksPerTier: booksPerTier),
    clueCount: clueCount,
    targetSwapCount: targetSwapCount,
    duplicateGroupCount: duplicateGroupCount,
    maxDuplicateCopies: maxDuplicateCopies,
  );
}

TemplateSolution _solutionForIds(
  List<String> ids, {
  int tierCount = 1,
  int? booksPerTier,
  int targetSwapCount = 2,
  int duplicateGroupCount = 0,
  int maxDuplicateCopies = 1,
  List<int>? slotIndexes,
}) {
  return _solutionFromPlacements(
    [
      for (var index = 0; index < ids.length; index += 1)
        _placement(
          _catalogBook(ids[index]),
          slotIndex: slotIndexes?[index] ?? index,
        ),
    ],
    tierCount: tierCount,
    booksPerTier: booksPerTier ?? ids.length,
    targetSwapCount: targetSwapCount,
    duplicateGroupCount: duplicateGroupCount,
    maxDuplicateCopies: maxDuplicateCopies,
  );
}

TemplateSolution _solutionFromPlacements(
  List<BookPlacement> placements, {
  int tierCount = 1,
  int? booksPerTier,
  int targetSwapCount = 2,
  int duplicateGroupCount = 0,
  int maxDuplicateCopies = 1,
}) {
  return TemplateSolution(
    stageSpec: _customSpec(
      tierCount: tierCount,
      booksPerTier: booksPerTier ?? placements.length,
      targetSwapCount: targetSwapCount,
      duplicateGroupCount: duplicateGroupCount,
      maxDuplicateCopies: maxDuplicateCopies,
    ),
    templateId: PuzzleTemplateId.t01AnchorChain,
    targetPlacements: placements,
  );
}

List<BookPlacement> _placementsForIds(List<String> ids) {
  return [
    for (var index = 0; index < ids.length; index += 1)
      _placement(_catalogBook(ids[index]), slotIndex: index),
  ];
}

BookPlacement _placement(Book book, {required int slotIndex}) {
  return BookPlacement(
    book: book,
    position: BookPosition(tierIndex: 0, slotIndex: slotIndex),
  );
}

Book _catalogBook(String id) {
  return const BookCatalog().books.firstWhere((book) => book.id == id);
}

List<String> _bookIds(List<Book> books) {
  return [for (final book in books) book.id];
}

List<String> _clueIds(List<Clue> clues) {
  return [for (final clue in clues) clue.id];
}

List<String> _placementIds(List<BookPlacement> placements) {
  final sorted = List<BookPlacement>.of(placements);
  sorted.sort((left, right) {
    final tierComparison = left.position.tierIndex.compareTo(
      right.position.tierIndex,
    );
    if (tierComparison != 0) {
      return tierComparison;
    }
    return left.position.slotIndex.compareTo(right.position.slotIndex);
  });
  return [for (final placement in sorted) placement.book.id];
}

List<int> _shuffledSlotIndices(int stageSeed, int bookCount) {
  const scrambler = T01AnchorChainScrambler();
  return DeterministicRandom(
    scrambler.createScrambleSeed(stageSeed),
  ).shuffled(List<int>.generate(bookCount, (index) => index));
}

List<BookPlacement> _applyCycle(
  List<BookPlacement> targetPlacements,
  List<int> cycleSlots,
) {
  final sorted = List<BookPlacement>.of(targetPlacements);
  sorted.sort(
    (left, right) =>
        left.position.slotIndex.compareTo(right.position.slotIndex),
  );
  final workingBooks = [for (final placement in sorted) placement.book];
  final pivotSlot = cycleSlots.first;
  for (var index = 1; index < cycleSlots.length; index += 1) {
    final otherSlot = cycleSlots[index];
    final temporary = workingBooks[pivotSlot];
    workingBooks[pivotSlot] = workingBooks[otherSlot];
    workingBooks[otherSlot] = temporary;
  }
  return [
    for (var slotIndex = 0; slotIndex < workingBooks.length; slotIndex += 1)
      _placement(workingBooks[slotIndex], slotIndex: slotIndex),
  ];
}

void _expectSwapStep(
  BookSwapStep step, {
  required int stepIndex,
  required int firstSlot,
  required int secondSlot,
  required String firstBookId,
  required String secondBookId,
}) {
  expect(step.stepIndex, stepIndex);
  expect(step.firstPosition, BookPosition(tierIndex: 0, slotIndex: firstSlot));
  expect(
    step.secondPosition,
    BookPosition(tierIndex: 0, slotIndex: secondSlot),
  );
  expect(step.firstBookIdBeforeSwap, firstBookId);
  expect(step.secondBookIdBeforeSwap, secondBookId);
}

void _expectScrambleIntegrity(_Fixture fixture, TemplateScrambleResult result) {
  const evaluator = ClueEvaluator();
  final targetIds = _placementIds(fixture.solution.targetPlacements);
  final initialIds = _placementIds(result.initialPlacements);
  final targetSatisfied = evaluator.evaluateAll(
    clues: fixture.clues,
    placements: fixture.solution.targetPlacements,
  );
  final initialSatisfied = evaluator.evaluateAll(
    clues: fixture.clues,
    placements: result.initialPlacements,
  );

  expect(result.initialPlacements, hasLength(fixture.spec.totalBookCount));
  expect(result.swapHistory, hasLength(fixture.spec.targetSwapCount));
  expect(initialIds, isNot(targetIds));
  expect(initialIds.toSet(), targetIds.toSet());
  expect(initialIds.toSet(), hasLength(initialIds.length));
  expect(
    result.initialPlacements.map(
      (placement) =>
          '${placement.position.tierIndex}:${placement.position.slotIndex}',
    ),
    [
      '0',
      '1',
      '2',
      '3',
      '4',
      '5',
    ].take(result.initialPlacements.length).map((slot) => '0:$slot'),
  );
  expect(targetSatisfied, hasLength(fixture.clues.length));
  expect(initialSatisfied.length, lessThan(fixture.clues.length));
  expect(
    _minimumSwapDistance(
      target: fixture.solution.targetPlacements,
      initial: result.initialPlacements,
    ),
    fixture.spec.targetSwapCount,
  );
  expect(
    _placementIds(
      _replayForward(fixture.solution.targetPlacements, result.swapHistory),
    ),
    initialIds,
  );
  expect(
    _placementIds(_replayReverse(result.initialPlacements, result.swapHistory)),
    targetIds,
  );
}

List<BookPlacement> _replayForward(
  List<BookPlacement> targetPlacements,
  List<BookSwapStep> swapHistory,
) {
  return _replay(targetPlacements, swapHistory);
}

List<BookPlacement> _replayReverse(
  List<BookPlacement> initialPlacements,
  List<BookSwapStep> swapHistory,
) {
  return _replay(initialPlacements, swapHistory.reversed.toList());
}

List<BookPlacement> _replay(
  List<BookPlacement> sourcePlacements,
  List<BookSwapStep> swapHistory,
) {
  final workingBooks = [
    for (final placement in _sortedPlacements(sourcePlacements)) placement.book,
  ];
  for (final step in swapHistory) {
    final firstSlot = step.firstPosition.slotIndex;
    final secondSlot = step.secondPosition.slotIndex;
    final temporary = workingBooks[firstSlot];
    workingBooks[firstSlot] = workingBooks[secondSlot];
    workingBooks[secondSlot] = temporary;
  }
  return [
    for (var slotIndex = 0; slotIndex < workingBooks.length; slotIndex += 1)
      _placement(workingBooks[slotIndex], slotIndex: slotIndex),
  ];
}

List<BookPlacement> _sortedPlacements(List<BookPlacement> placements) {
  final sorted = List<BookPlacement>.of(placements);
  sorted.sort((left, right) {
    final tierComparison = left.position.tierIndex.compareTo(
      right.position.tierIndex,
    );
    if (tierComparison != 0) {
      return tierComparison;
    }
    return left.position.slotIndex.compareTo(right.position.slotIndex);
  });
  return sorted;
}

int _minimumSwapDistance({
  required List<BookPlacement> target,
  required List<BookPlacement> initial,
}) {
  final targetIndexes = <String, int>{};
  final sortedTarget = _sortedPlacements(target);
  final sortedInitial = _sortedPlacements(initial);
  for (var index = 0; index < sortedTarget.length; index += 1) {
    targetIndexes[sortedTarget[index].book.id] = index;
  }
  final permutation = [
    for (final placement in sortedInitial) targetIndexes[placement.book.id]!,
  ];
  final visited = List<bool>.filled(permutation.length, false);
  var cycleCount = 0;
  for (var index = 0; index < permutation.length; index += 1) {
    if (visited[index]) {
      continue;
    }
    cycleCount += 1;
    var current = index;
    while (!visited[current]) {
      visited[current] = true;
      current = permutation[current];
    }
  }
  return permutation.length - cycleCount;
}

String _placementSignature(List<BookPlacement> placements) {
  return [
    for (final placement in placements)
      [
        placement.book.id,
        placement.book.color,
        placement.book.symbol,
        placement.position.tierIndex,
        placement.position.slotIndex,
      ].join(':'),
  ].join('|');
}
