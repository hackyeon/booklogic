import 'package:flutter_test/flutter_test.dart';

import 'package:booklogic/features/game/application/game_controller.dart';
import 'package:booklogic/features/game/application/game_status.dart';
import 'package:booklogic/features/game/domain/book.dart';
import 'package:booklogic/features/game/domain/book_placement.dart';
import 'package:booklogic/features/game/domain/book_position.dart';
import 'package:booklogic/features/game/domain/book_selector.dart';
import 'package:booklogic/features/game/domain/clue.dart';
import 'package:booklogic/features/game/domain/clue_evaluator.dart';
import 'package:booklogic/features/game/generator/book_instance_code.dart';
import 'package:booklogic/features/game/generator/generated_stage.dart';
import 'package:booklogic/features/game/generator/generated_stage_validator.dart';
import 'package:booklogic/features/game/generator/puzzle_template_id.dart';
import 'package:booklogic/features/game/generator/puzzle_template_resolver.dart';
import 'package:booklogic/features/game/generator/stage_generator.dart';
import 'package:booklogic/features/game/generator/stage_permutation_analyzer.dart';
import 'package:booklogic/features/game/generator/stage_validation_issue.dart';
import 'package:booklogic/features/game/generator/stage_spec_factory.dart';
import 'package:booklogic/features/game/generator/t02_fallback_stage_factory.dart';
import 'package:booklogic/features/game/generator/template_scramble_result.dart';
import 'package:booklogic/features/game/generator/template_solution.dart';
import 'package:booklogic/features/game/presentation/formatters/clue_text_formatter.dart';

void main() {
  group('BookInstanceCode', () {
    test('builds and validates duplicate copy ids', () {
      expect(
        BookInstanceCode.duplicateCopyId(
          color: BookColor.orange,
          symbol: BookSymbol.cloud,
          copyNumber: 1,
        ),
        'orange_cloud_copy_01',
      );
      expect(
        BookInstanceCode.duplicateCopyId(
          color: BookColor.orange,
          symbol: BookSymbol.cloud,
          copyNumber: 2,
        ),
        'orange_cloud_copy_02',
      );
      expect(
        BookInstanceCode.duplicateCopyId(
          color: BookColor.orange,
          symbol: BookSymbol.cloud,
          copyNumber: 9,
        ),
        'orange_cloud_copy_09',
      );
      expect(
        BookInstanceCode.duplicateCopyId(
          color: BookColor.orange,
          symbol: BookSymbol.cloud,
          copyNumber: 10,
        ),
        'orange_cloud_copy_10',
      );
      expect(
        () => BookInstanceCode.duplicateCopyId(
          color: BookColor.orange,
          symbol: BookSymbol.cloud,
          copyNumber: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => BookInstanceCode.duplicateCopyId(
          color: BookColor.orange,
          symbol: BookSymbol.cloud,
          copyNumber: 100,
        ),
        throwsArgumentError,
      );
      expect(
        BookInstanceCode.matchesBook(
          const Book(
            id: 'orange_cloud_copy_01',
            color: BookColor.orange,
            symbol: BookSymbol.cloud,
          ),
        ),
        isTrue,
      );
      expect(
        BookInstanceCode.matchesBook(
          const Book(
            id: 'orange_cloud_copy_01',
            color: BookColor.orange,
            symbol: BookSymbol.sun,
          ),
        ),
        isFalse,
      );
    });
  });

  group('T02 clue evaluation and text', () {
    const evaluator = ClueEvaluator();
    const formatter = ClueTextFormatter();
    final placements = _placements([
      _book('red_star', BookColor.red, BookSymbol.star),
      _book('purple_diamond', BookColor.purple, BookSymbol.diamond),
      _book('blue_leaf', BookColor.blue, BookSymbol.leaf),
      _book('orange_cloud_copy_01', BookColor.orange, BookSymbol.cloud),
      _book('orange_cloud_copy_02', BookColor.orange, BookSymbol.cloud),
      _book('red_sun', BookColor.red, BookSymbol.sun),
    ]);

    test('supports both-edges and between clues', () {
      const bothEdges = BothEdgesClue(
        id: 'red_edges',
        subject: BookColorSelector(color: BookColor.red),
        tierIndex: 0,
      );
      const between = BetweenClue(
        id: 'orange_between_red',
        subject: BookColorSelector(color: BookColor.orange),
        boundary: BookColorSelector(color: BookColor.red),
        tierIndex: 0,
      );

      expect(
        evaluator.evaluate(clue: bothEdges, placements: placements),
        isTrue,
      );
      expect(evaluator.evaluate(clue: between, placements: placements), isTrue);
      expect(
        evaluator.evaluate(
          clue: const BothEdgesClue(
            id: 'blue_edges',
            subject: BookColorSelector(color: BookColor.blue),
            tierIndex: 0,
          ),
          placements: placements,
        ),
        isFalse,
      );
      expect(
        evaluator.evaluate(
          clue: const BetweenClue(
            id: 'red_between_orange',
            subject: BookColorSelector(color: BookColor.red),
            boundary: BookColorSelector(color: BookColor.orange),
            tierIndex: 0,
          ),
          placements: placements,
        ),
        isFalse,
      );
      expect(
        formatter.format(
          clue: bothEdges,
          books: placements.map((placement) => placement.book).toList(),
        ),
        '두 빨간 책은 1단의 양 끝에 있다.',
      );
      expect(
        formatter.format(
          clue: between,
          books: placements.map((placement) => placement.book).toList(),
        ),
        '모든 주황 책은 1단에서 두 빨간 책 사이에 있다.',
      );
    });

    test('supports group relative-order references', () {
      const clue = RelativeOrderClue(
        id: 'blue_left_of_orange',
        subject: BookIdSelector(bookId: 'blue_leaf'),
        reference: BookColorSelector(color: BookColor.orange),
        tierIndex: 0,
        relation: HorizontalRelation.leftOf,
      );
      expect(evaluator.evaluate(clue: clue, placements: placements), isTrue);
      expect(
        formatter.format(
          clue: clue,
          books: placements.map((placement) => placement.book).toList(),
        ),
        '파란 잎 책은 1단에서 모든 주황 책보다 왼쪽에 있다.',
      );

      final falsePlacements = _placements([
        _book('red_star', BookColor.red, BookSymbol.star),
        _book('purple_diamond', BookColor.purple, BookSymbol.diamond),
        _book('orange_cloud_copy_01', BookColor.orange, BookSymbol.cloud),
        _book('blue_leaf', BookColor.blue, BookSymbol.leaf),
        _book('orange_cloud_copy_02', BookColor.orange, BookSymbol.cloud),
        _book('red_sun', BookColor.red, BookSymbol.sun),
      ]);
      expect(
        evaluator.evaluate(clue: clue, placements: falsePlacements),
        isFalse,
      );
    });
  });

  group('T02 generator golden values', () {
    const generator = StageGenerator();
    const formatter = ClueTextFormatter();
    const evaluator = ClueEvaluator();
    const analyzer = StagePermutationAnalyzer();
    const validator = GeneratedStageValidator();

    test('level 21 matches the generator v1 golden', () {
      final stage = generator.generate(level: 21);

      expect(stage.templateId, PuzzleTemplateId.t02EdgeSandwich);
      expect(stage.stageSpec.seed, 2758664950);
      expect(stage.generationAttempt, 0);
      expect(stage.isFallback, isFalse);
      expect(stage.clueCount, 4);
      expect(stage.targetSwapCount, 4);
      expect(stage.scrambleSeed, 562440349);
      expect(_ids(stage.targetPlacements), [
        'red_star',
        'purple_diamond',
        'blue_leaf',
        'orange_cloud_copy_01',
        'orange_cloud_copy_02',
        'red_sun',
      ]);
      expect(_ids(stage.initialPlacements), [
        'purple_diamond',
        'blue_leaf',
        'orange_cloud_copy_02',
        'orange_cloud_copy_01',
        'red_sun',
        'red_star',
      ]);
      expect(_clueIds(stage), [
        't02_c03_00_red_both_edges',
        't02_c06_01_orange_between_red',
        't02_c05_02_blue_leaf_immediately_right_of_purple_diamond',
        't02_c04_03_red_star_left_of_red_sun',
      ]);
      expect(_clueTexts(stage, formatter), [
        '두 빨간 책은 1단의 양 끝에 있다.',
        '모든 주황 책은 1단에서 두 빨간 책 사이에 있다.',
        '파란 잎 책은 1단에서 보라 다이아몬드 책 바로 오른쪽에 있다.',
        '빨간 별 책은 1단에서 빨간 태양 책보다 왼쪽에 있다.',
      ]);
      expect(_swapSlots(stage), [
        [1, 0],
        [1, 5],
        [1, 4],
        [1, 2],
      ]);
      expect(
        evaluator
            .evaluateAll(
              clues: stage.clues,
              placements: stage.initialPlacements,
            )
            .length,
        1,
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

    test('level 22, 25, 50, and fallback match fixed golden data', () {
      _expectGolden(
        generator.generate(level: 22),
        seed: 1752334835,
        scrambleSeed: 3986246552,
        targetSwapCount: 4,
        targetIds: [
          'blue_moon',
          'red_moon',
          'purple_cloud',
          'yellow_leaf_copy_01',
          'yellow_leaf_copy_02',
          'blue_leaf',
        ],
        initialIds: [
          'blue_leaf',
          'yellow_leaf_copy_02',
          'blue_moon',
          'yellow_leaf_copy_01',
          'purple_cloud',
          'red_moon',
        ],
        clueIds: [
          't02_c03_00_blue_both_edges',
          't02_c06_01_yellow_between_blue',
          't02_c05_02_purple_cloud_immediately_right_of_red_moon',
          't02_c04_03_blue_moon_left_of_blue_leaf',
          't02_c04_04_purple_cloud_left_of_yellow_group',
        ],
        swapSlots: [
          [2, 4],
          [2, 1],
          [2, 5],
          [2, 0],
        ],
      );
      _expectGolden(
        generator.generate(level: 25),
        seed: 4123276330,
        scrambleSeed: 1882193473,
        targetSwapCount: 3,
        targetIds: [
          'yellow_diamond',
          'purple_leaf',
          'green_cloud',
          'orange_sun_copy_01',
          'orange_sun_copy_02',
          'yellow_star',
        ],
        initialIds: [
          'yellow_diamond',
          'green_cloud',
          'orange_sun_copy_01',
          'yellow_star',
          'orange_sun_copy_02',
          'purple_leaf',
        ],
        clueIds: [
          't02_c03_00_yellow_both_edges',
          't02_c06_01_orange_between_yellow',
          't02_c05_02_green_cloud_immediately_right_of_purple_leaf',
          't02_c04_03_yellow_diamond_left_of_yellow_star',
        ],
        swapSlots: [
          [5, 3],
          [5, 2],
          [5, 1],
        ],
      );
      _expectGolden(
        generator.generate(level: 50),
        seed: 2470398806,
        scrambleSeed: 383025469,
        targetSwapCount: 3,
        targetIds: [
          'yellow_leaf',
          'purple_cloud',
          'red_diamond',
          'orange_drop_copy_01',
          'orange_drop_copy_02',
          'yellow_drop',
        ],
        initialIds: [
          'purple_cloud',
          'orange_drop_copy_02',
          'red_diamond',
          'orange_drop_copy_01',
          'yellow_drop',
          'yellow_leaf',
        ],
        clueIds: [
          't02_c03_00_yellow_both_edges',
          't02_c06_01_orange_between_yellow',
          't02_c05_02_red_diamond_immediately_right_of_purple_cloud',
          't02_c04_03_yellow_leaf_left_of_yellow_drop',
        ],
        swapSlots: [
          [1, 0],
          [1, 5],
          [1, 4],
        ],
      );

      final fallback = const T02FallbackStageFactory().create(
        stageSpec: const StageSpecFactory().create(level: 21),
        fallbackAttempt: 8,
      );
      expect(fallback.isFallback, isTrue);
      expect(fallback.generationAttempt, 8);
      expect(fallback.generationAttemptSeed, 2892885902);
      expect(fallback.scrambleSeed, 696657381);
      expect(_ids(fallback.targetPlacements), [
        'yellow_diamond',
        'purple_moon',
        'orange_sun',
        'green_drop_copy_01',
        'green_drop_copy_02',
        'yellow_moon',
      ]);
      expect(_ids(fallback.initialPlacements), [
        'yellow_moon',
        'yellow_diamond',
        'purple_moon',
        'orange_sun',
        'green_drop_copy_02',
        'green_drop_copy_01',
      ]);
      expect(_swapSlots(fallback), [
        [0, 1],
        [0, 2],
        [0, 3],
        [0, 5],
      ]);
      expect(validator.validate(fallback).isValid, isTrue);
    });

    test('levels 21 through 50 are deterministic valid T02 stages', () {
      const templateResolver = PuzzleTemplateResolver();
      for (var level = 21; level <= 50; level += 1) {
        if (templateResolver.isT03Level(level)) {
          continue;
        }
        final first = generator.generate(level: level);
        final second = generator.generate(level: level);

        expect(first, second, reason: 'level $level');
        expect(first.templateId, PuzzleTemplateId.t02EdgeSandwich);
        expect(first.generationAttempt, 0, reason: 'level $level');
        expect(first.isFallback, isFalse, reason: 'level $level');
        expect(first.tierCount, 1);
        expect(first.booksPerTier, 6);
        expect(first.totalBookCount, 6);
        expect(first.clueCount, inInclusiveRange(4, 5));
        expect(first.targetSwapCount, inInclusiveRange(3, 4));
        expect(_visualDuplicateGroupCount(first.targetPlacements), 1);
        expect(
          evaluator
              .evaluateAll(
                clues: first.clues,
                placements: first.targetPlacements,
              )
              .length,
          first.clues.length,
          reason: 'level $level target',
        );
        expect(
          evaluator
              .evaluateAll(
                clues: first.clues,
                placements: first.initialPlacements,
              )
              .length,
          isNot(first.clues.length),
          reason: 'level $level initial',
        );
        expect(
          analyzer.minimumVisualSwapDistance(
            target: first.targetPlacements,
            current: first.initialPlacements,
          ),
          first.targetSwapCount,
          reason: 'level $level',
        );
        expect(
          validator.validate(first).isValid,
          isTrue,
          reason: 'level $level',
        );
      }
    });

    test('level 51 remains unsupported', () {
      expect(() => generator.generate(level: 51), throwsUnsupportedError);
    });

    test('visual distance treats duplicate copies as interchangeable', () {
      final stage = generator.generate(level: 21);
      final copySwapped = _placements([
        stage.targetPlacements[0].book,
        stage.targetPlacements[1].book,
        stage.targetPlacements[2].book,
        stage.targetPlacements[4].book,
        stage.targetPlacements[3].book,
        stage.targetPlacements[5].book,
      ]);

      expect(
        analyzer.hasSameVisualOrder(
          first: stage.targetPlacements,
          second: copySwapped,
        ),
        isTrue,
      );
      expect(
        analyzer.minimumVisualSwapDistance(
          target: stage.targetPlacements,
          current: copySwapped,
        ),
        0,
      );
      expect(
        analyzer.minimumSwapDistance(
          target: stage.targetPlacements,
          current: copySwapped,
        ),
        1,
      );
      expect(
        () => analyzer.minimumVisualSwapDistance(
          target: stage.targetPlacements,
          current: _placements([
            stage.targetPlacements[0].book,
            stage.targetPlacements[1].book,
            stage.targetPlacements[2].book,
            _book('green_key', BookColor.green, BookSymbol.key),
            stage.targetPlacements[4].book,
            stage.targetPlacements[5].book,
          ]),
        ),
        throwsStateError,
      );
    });

    test(
      'validator reports T02 duplicate structure issues without throwing',
      () {
        final stage = generator.generate(level: 21);
        final badTarget = _placements([
          stage.targetPlacements[0].book,
          stage.targetPlacements[1].book,
          stage.targetPlacements[2].book,
          stage.targetPlacements[3].book,
          _book('green_key', BookColor.green, BookSymbol.key),
          stage.targetPlacements[5].book,
        ]);
        final badSolution = TemplateSolution(
          stageSpec: stage.stageSpec,
          templateId: stage.templateId,
          targetPlacements: badTarget,
        );
        final badScramble = TemplateScrambleResult(
          solution: badSolution,
          scrambleSeed: stage.scrambleSeed,
          initialPlacements: stage.initialPlacements,
          swapHistory: stage.swapHistory,
        );
        final badStage = GeneratedStage(
          scrambleResult: badScramble,
          clues: stage.clues,
          generationAttemptKey: stage.generationAttemptKey,
          generationAttemptSeed: stage.generationAttemptSeed,
        );
        final result = validator.validate(badStage);

        expect(result.isInvalid, isTrue);
        expect(
          result.containsCode(
            StageValidationIssueCode.invalidDuplicateStructure,
          ),
          isTrue,
        );
        expect(
          result.containsCode(
            StageValidationIssueCode.invalidT02TargetStructure,
          ),
          isTrue,
        );
      },
    );
  });

  group('Level 21 GameController', () {
    test(
      'ignores visually identical duplicate swaps and clears in four moves',
      () async {
        final stage = const StageGenerator().generate(level: 21);
        final controller = GameController.fromGeneratedStage(
          stage: stage,
          swapDuration: const Duration(milliseconds: 1),
          clueCompletionDelay: const Duration(seconds: 30),
          clearBookStepDuration: const Duration(seconds: 30),
          clearFinalGlowDuration: const Duration(seconds: 30),
        );
        addTearDown(controller.dispose);

        expect(controller.level, 21);
        expect(controller.placements, hasLength(6));
        expect(controller.moveCount, 0);
        expect(controller.status, GameStatus.idle);
        expect(controller.satisfiedClueCount, 1);
        expect(controller.clues, hasLength(4));

        final initialOrder = _ids(controller.placements);
        controller.handleBookTap('orange_cloud_copy_01');
        controller.handleBookTap('orange_cloud_copy_02');
        expect(controller.moveCount, 0);
        expect(controller.selectedBookId, isNull);
        expect(controller.status, GameStatus.idle);
        expect(_ids(controller.placements), initialOrder);

        await _swap(controller, 'blue_leaf', 'orange_cloud_copy_02');
        await _swap(controller, 'orange_cloud_copy_02', 'red_sun');
        await _swap(controller, 'red_sun', 'red_star');
        await _swap(controller, 'red_star', 'purple_diamond');

        expect(_ids(controller.placements), _ids(stage.targetPlacements));
        expect(controller.satisfiedClueCount, 4);
        expect(controller.moveCount, 4);
        expect(controller.status, GameStatus.clearing);
      },
    );
  });
}

void _expectGolden(
  GeneratedStage stage, {
  required int seed,
  required int scrambleSeed,
  required int targetSwapCount,
  required List<String> targetIds,
  required List<String> initialIds,
  required List<String> clueIds,
  required List<List<int>> swapSlots,
}) {
  const analyzer = StagePermutationAnalyzer();
  const validator = GeneratedStageValidator();

  expect(stage.stageSpec.seed, seed);
  expect(stage.scrambleSeed, scrambleSeed);
  expect(stage.targetSwapCount, targetSwapCount);
  expect(_ids(stage.targetPlacements), targetIds);
  expect(_ids(stage.initialPlacements), initialIds);
  expect(_clueIds(stage), clueIds);
  expect(_swapSlots(stage), swapSlots);
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

int _visualDuplicateGroupCount(List<BookPlacement> placements) {
  final counts = <String, int>{};
  for (final placement in placements) {
    counts.update(
      '${placement.book.color}:${placement.book.symbol}',
      (count) => count + 1,
      ifAbsent: () => 1,
    );
  }
  return counts.values.where((count) => count > 1).length;
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
