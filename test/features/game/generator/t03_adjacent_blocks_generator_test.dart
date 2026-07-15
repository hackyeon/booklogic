import 'package:flutter_test/flutter_test.dart';

import 'package:booklogic/features/game/application/game_controller.dart';
import 'package:booklogic/features/game/application/game_status.dart';
import 'package:booklogic/features/game/domain/book.dart';
import 'package:booklogic/features/game/domain/book_placement.dart';
import 'package:booklogic/features/game/domain/book_position.dart';
import 'package:booklogic/features/game/domain/book_selector.dart';
import 'package:booklogic/features/game/domain/clue.dart';
import 'package:booklogic/features/game/domain/clue_evaluator.dart';
import 'package:booklogic/features/game/generator/generated_stage.dart';
import 'package:booklogic/features/game/generator/generated_stage_validator.dart';
import 'package:booklogic/features/game/generator/puzzle_template_id.dart';
import 'package:booklogic/features/game/generator/puzzle_template_resolver.dart';
import 'package:booklogic/features/game/generator/stage_generator.dart';
import 'package:booklogic/features/game/generator/stage_generation_key.dart';
import 'package:booklogic/features/game/generator/stage_permutation_analyzer.dart';
import 'package:booklogic/features/game/generator/stage_spec.dart';
import 'package:booklogic/features/game/generator/stage_spec_factory.dart';
import 'package:booklogic/features/game/generator/t03_fallback_stage_factory.dart';
import 'package:booklogic/features/game/generator/t03_stage_attempt_builder.dart';
import 'package:booklogic/features/game/presentation/formatters/clue_text_formatter.dart';

void main() {
  group('PuzzleTemplateResolver', () {
    const specFactory = StageSpecFactory();
    const resolver = PuzzleTemplateResolver();

    test('maps generator v1 levels to fixed templates', () {
      for (var level = 1; level <= 20; level += 1) {
        expect(
          resolver.resolve(specFactory.create(level: level)),
          PuzzleTemplateId.t01AnchorChain,
          reason: 'level $level',
        );
      }

      for (var level = 21; level <= 50; level += 1) {
        final expected = resolver.isT03Level(level)
            ? PuzzleTemplateId.t03AdjacentBlocks
            : PuzzleTemplateId.t02EdgeSandwich;
        expect(
          resolver.resolve(specFactory.create(level: level)),
          expected,
          reason: 'level $level',
        );
      }

      expect(
        () => resolver.resolve(specFactory.create(level: 51)),
        throwsUnsupportedError,
      );
    });

    test('keeps the same template across repeated spec creation', () {
      final first = resolver.resolve(specFactory.create(level: 23));
      final second = resolver.resolve(specFactory.create(level: 23));

      expect(first, PuzzleTemplateId.t03AdjacentBlocks);
      expect(second, first);
    });
  });

  group('T03 group adjacent evaluation and text', () {
    const evaluator = ClueEvaluator();
    const formatter = ClueTextFormatter();
    final placements = _placements([
      _book('orange_leaf', BookColor.orange, BookSymbol.leaf),
      _book('purple_cloud', BookColor.purple, BookSymbol.cloud),
      _book('yellow_leaf', BookColor.yellow, BookSymbol.leaf),
      _book('green_drop_copy_01', BookColor.green, BookSymbol.drop),
      _book('green_drop_copy_02', BookColor.green, BookSymbol.drop),
      _book('blue_moon', BookColor.blue, BookSymbol.moon),
    ]);

    test('supports adjacent clues against a contiguous color group', () {
      const clue = AdjacentClue(
        id: 'blue_right_of_green_group',
        subject: BookIdSelector(bookId: 'blue_moon'),
        reference: BookColorSelector(color: BookColor.green),
        tierIndex: 0,
        direction: AdjacentDirection.immediatelyRightOf,
      );

      expect(evaluator.evaluate(clue: clue, placements: placements), isTrue);
      expect(
        formatter.format(
          clue: clue,
          books: placements.map((placement) => placement.book).toList(),
        ),
        '파란 달 책은 1단에서 두 초록 책 묶음 바로 오른쪽에 있다.',
      );
    });

    test('rejects non-contiguous and overlapping adjacent groups', () {
      const groupClue = AdjacentClue(
        id: 'blue_right_of_green_group',
        subject: BookIdSelector(bookId: 'blue_moon'),
        reference: BookColorSelector(color: BookColor.green),
        tierIndex: 0,
        direction: AdjacentDirection.immediatelyRightOf,
      );
      final nonContiguous = _placements([
        _book('orange_leaf', BookColor.orange, BookSymbol.leaf),
        _book('purple_cloud', BookColor.purple, BookSymbol.cloud),
        _book('green_drop_copy_01', BookColor.green, BookSymbol.drop),
        _book('yellow_leaf', BookColor.yellow, BookSymbol.leaf),
        _book('green_drop_copy_02', BookColor.green, BookSymbol.drop),
        _book('blue_moon', BookColor.blue, BookSymbol.moon),
      ]);

      expect(
        evaluator.evaluate(clue: groupClue, placements: nonContiguous),
        isFalse,
      );
      expect(
        evaluator.evaluate(
          clue: const AdjacentClue(
            id: 'green_overlap',
            subject: BookColorSelector(color: BookColor.green),
            reference: BookColorSelector(color: BookColor.green),
            tierIndex: 0,
            direction: AdjacentDirection.immediatelyRightOf,
          ),
          placements: placements,
        ),
        isFalse,
      );
    });
  });

  group('T03 generator golden values', () {
    const generator = StageGenerator();
    const formatter = ClueTextFormatter();
    const evaluator = ClueEvaluator();
    const analyzer = StagePermutationAnalyzer();
    const validator = GeneratedStageValidator();

    test('level 23 matches the generator v1 golden', () {
      final stage = generator.generate(level: 23);

      expect(stage.templateId, PuzzleTemplateId.t03AdjacentBlocks);
      expect(stage.stageSpec.seed, 2015127744);
      expect(stage.generationAttempt, 0);
      expect(stage.isFallback, isFalse);
      expect(stage.clueCount, 5);
      expect(stage.targetSwapCount, 4);
      expect(stage.scrambleSeed, 3132016373);
      expect(_ids(stage.targetPlacements), [
        'orange_leaf',
        'purple_cloud',
        'yellow_leaf',
        'green_drop_copy_01',
        'green_drop_copy_02',
        'blue_moon',
      ]);
      expect(_ids(stage.initialPlacements), [
        'blue_moon',
        'yellow_leaf',
        'orange_leaf',
        'purple_cloud',
        'green_drop_copy_02',
        'green_drop_copy_01',
      ]);
      expect(_clueIds(stage), [
        't03_c05_00_purple_cloud_immediately_right_of_orange_leaf',
        't03_c05_01_yellow_leaf_immediately_right_of_purple_cloud',
        't03_c05_02_blue_moon_immediately_right_of_green_group',
        't03_c04_03_yellow_leaf_left_of_green_group',
        't03_c04_04_orange_leaf_left_of_blue_moon',
      ]);
      expect(_clueTexts(stage, formatter), [
        '보라 구름 책은 1단에서 주황 잎 책 바로 오른쪽에 있다.',
        '노란 잎 책은 1단에서 보라 구름 책 바로 오른쪽에 있다.',
        '파란 달 책은 1단에서 두 초록 책 묶음 바로 오른쪽에 있다.',
        '노란 잎 책은 1단에서 모든 초록 책보다 왼쪽에 있다.',
        '주황 잎 책은 1단에서 파란 달 책보다 왼쪽에 있다.',
      ]);
      expect(_swapSlots(stage), [
        [0, 2],
        [0, 1],
        [0, 3],
        [0, 5],
      ]);
      expect(
        evaluator
            .evaluateAll(
              clues: stage.clues,
              placements: stage.initialPlacements,
            )
            .length,
        2,
      );
      expect(
        analyzer.minimumVisualSwapDistance(
          target: stage.targetPlacements,
          current: stage.initialPlacements,
        ),
        4,
      );
      expect(validator.validate(stage).isValid, isTrue);
    });

    test('levels 35 and 47 match fixed golden data', () {
      _expectGolden(
        generator.generate(level: 35),
        seed: 3114166711,
        scrambleSeed: 2066532226,
        targetSwapCount: 3,
        initialSatisfiedCount: 1,
        targetIds: [
          'yellow_moon',
          'blue_sun',
          'orange_key',
          'purple_key_copy_01',
          'purple_key_copy_02',
          'red_sun',
        ],
        initialIds: [
          'yellow_moon',
          'orange_key',
          'red_sun',
          'blue_sun',
          'purple_key_copy_02',
          'purple_key_copy_01',
        ],
        swapSlots: [
          [1, 3],
          [1, 5],
          [1, 2],
        ],
      );
      _expectGolden(
        generator.generate(level: 47),
        seed: 1193548230,
        scrambleSeed: 2241247219,
        targetSwapCount: 4,
        initialSatisfiedCount: 1,
        targetIds: [
          'red_moon',
          'green_cloud',
          'yellow_sun',
          'blue_key_copy_01',
          'blue_key_copy_02',
          'purple_sun',
        ],
        initialIds: [
          'yellow_sun',
          'purple_sun',
          'green_cloud',
          'blue_key_copy_01',
          'red_moon',
          'blue_key_copy_02',
        ],
        swapSlots: [
          [1, 2],
          [1, 0],
          [1, 4],
          [1, 5],
        ],
      );
    });

    test('levels 21 through 50 use the resolver-selected templates', () {
      const resolver = PuzzleTemplateResolver();
      for (var level = 21; level <= 50; level += 1) {
        final first = generator.generate(level: level);
        final second = generator.generate(level: level);
        final expected = resolver.isT03Level(level)
            ? PuzzleTemplateId.t03AdjacentBlocks
            : PuzzleTemplateId.t02EdgeSandwich;

        expect(first, second, reason: 'level $level');
        expect(first.templateId, expected, reason: 'level $level');
        expect(first.generationAttempt, 0, reason: 'level $level');
        expect(first.isFallback, isFalse, reason: 'level $level');
        expect(validator.validate(first).isValid, isTrue, reason: '$level');
      }
    });

    test('fallback keeps T03 target and scramble structure deterministic', () {
      final stage = const T03FallbackStageFactory().create(
        stageSpec: const StageSpecFactory().create(level: 23),
        fallbackAttempt: 8,
      );

      expect(stage.templateId, PuzzleTemplateId.t03AdjacentBlocks);
      expect(stage.isFallback, isTrue);
      expect(stage.generationAttempt, 8);
      expect(stage.generationAttemptSeed, 2149348696);
      expect(stage.scrambleSeed, 1118755693);
      expect(_ids(stage.targetPlacements), [
        'purple_moon',
        'orange_cloud',
        'blue_drop',
        'red_moon_copy_01',
        'red_moon_copy_02',
        'yellow_star',
      ]);
      expect(_ids(stage.initialPlacements), [
        'yellow_star',
        'purple_moon',
        'orange_cloud',
        'blue_drop',
        'red_moon_copy_02',
        'red_moon_copy_01',
      ]);
      expect(_swapSlots(stage), [
        [0, 1],
        [0, 2],
        [0, 3],
        [0, 5],
      ]);
      expect(
        analyzer.minimumVisualSwapDistance(
          target: stage.targetPlacements,
          current: stage.initialPlacements,
        ),
        4,
      );
      expect(validator.validate(stage).isValid, isTrue);
    });

    test('StageGenerator keeps T03 selected through retries and fallback', () {
      final builder = _FailingT03AttemptBuilder();
      final stage = StageGenerator(
        t03AttemptBuilder: builder,
      ).generate(level: 23);

      expect(builder.attempts, [0, 1, 2, 3, 4, 5, 6, 7]);
      expect(stage.templateId, PuzzleTemplateId.t03AdjacentBlocks);
      expect(stage.isFallback, isTrue);
      expect(stage.generationAttempt, 8);
      expect(stage.generationAttemptSeed, 2149348696);
      expect(_ids(stage.targetPlacements), [
        'purple_moon',
        'orange_cloud',
        'blue_drop',
        'red_moon_copy_01',
        'red_moon_copy_02',
        'yellow_star',
      ]);
      expect(validator.validate(stage).isValid, isTrue);
    });
  });

  group('Level 23 GameController', () {
    test('clears the T03 golden stage in four reverse swaps', () async {
      final stage = const StageGenerator().generate(level: 23);
      final controller = GameController.fromGeneratedStage(
        stage: stage,
        swapDuration: const Duration(milliseconds: 1),
        clueCompletionDelay: const Duration(seconds: 30),
        clearBookStepDuration: const Duration(seconds: 30),
        clearFinalGlowDuration: const Duration(seconds: 30),
      );
      addTearDown(controller.dispose);

      expect(controller.level, 23);
      expect(controller.placements, hasLength(6));
      expect(controller.moveCount, 0);
      expect(controller.status, GameStatus.idle);
      expect(controller.satisfiedClueCount, 2);
      expect(controller.clues, hasLength(5));

      await _swap(controller, 'blue_moon', 'green_drop_copy_01');
      await _swap(controller, 'green_drop_copy_01', 'purple_cloud');
      await _swap(controller, 'purple_cloud', 'yellow_leaf');
      await _swap(controller, 'yellow_leaf', 'orange_leaf');

      expect(_ids(controller.placements), _ids(stage.targetPlacements));
      expect(controller.satisfiedClueCount, 5);
      expect(controller.moveCount, 4);
      expect(controller.status, GameStatus.clearing);
    });
  });
}

void _expectGolden(
  GeneratedStage stage, {
  required int seed,
  required int scrambleSeed,
  required int targetSwapCount,
  required int initialSatisfiedCount,
  required List<String> targetIds,
  required List<String> initialIds,
  required List<List<int>> swapSlots,
}) {
  const evaluator = ClueEvaluator();
  const analyzer = StagePermutationAnalyzer();
  const validator = GeneratedStageValidator();

  expect(stage.templateId, PuzzleTemplateId.t03AdjacentBlocks);
  expect(stage.stageSpec.seed, seed);
  expect(stage.generationAttempt, 0);
  expect(stage.isFallback, isFalse);
  expect(stage.scrambleSeed, scrambleSeed);
  expect(stage.targetSwapCount, targetSwapCount);
  expect(_ids(stage.targetPlacements), targetIds);
  expect(_ids(stage.initialPlacements), initialIds);
  expect(_swapSlots(stage), swapSlots);
  expect(
    evaluator
        .evaluateAll(clues: stage.clues, placements: stage.initialPlacements)
        .length,
    initialSatisfiedCount,
  );
  expect(
    analyzer.minimumVisualSwapDistance(
      target: stage.targetPlacements,
      current: stage.initialPlacements,
    ),
    targetSwapCount,
  );
  expect(validator.validate(stage).isValid, isTrue);
}

Future<void> _swap(
  GameController controller,
  String firstId,
  String secondId,
) async {
  controller.handleBookTap(firstId);
  controller.handleBookTap(secondId);
  await Future<void>.delayed(const Duration(milliseconds: 5));
}

List<String> _ids(List<BookPlacement> placements) {
  return [for (final placement in _sorted(placements)) placement.book.id];
}

List<String> _clueIds(GeneratedStage stage) {
  return [for (final clue in stage.clues) clue.id];
}

List<String> _clueTexts(GeneratedStage stage, ClueTextFormatter formatter) {
  final books = [
    for (final placement in stage.targetPlacements) placement.book,
  ];
  return [
    for (final clue in stage.clues) formatter.format(clue: clue, books: books),
  ];
}

List<List<int>> _swapSlots(GeneratedStage stage) {
  return [
    for (final step in stage.swapHistory)
      [step.firstPosition.slotIndex, step.secondPosition.slotIndex],
  ];
}

List<BookPlacement> _placements(List<Book> books) {
  return [
    for (var slotIndex = 0; slotIndex < books.length; slotIndex += 1)
      BookPlacement(
        book: books[slotIndex],
        position: BookPosition(tierIndex: 0, slotIndex: slotIndex),
      ),
  ];
}

Book _book(String id, BookColor color, BookSymbol symbol) {
  return Book(id: id, color: color, symbol: symbol);
}

List<BookPlacement> _sorted(List<BookPlacement> placements) {
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

class _FailingT03AttemptBuilder extends T03StageAttemptBuilder {
  _FailingT03AttemptBuilder();

  final attempts = <int>[];

  @override
  bool supports(StageSpec stageSpec) {
    return true;
  }

  @override
  GeneratedStage build({
    required StageSpec stageSpec,
    required StageGenerationKey generationAttemptKey,
    required int generationAttemptSeed,
  }) {
    attempts.add(generationAttemptKey.attempt);
    throw StateError('forced T03 attempt failure');
  }
}
