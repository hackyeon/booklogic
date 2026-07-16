import 'package:flutter_test/flutter_test.dart';

import 'package:booklogic/features/game/domain/book_placement.dart';
import 'package:booklogic/features/game/domain/book_position.dart';
import 'package:booklogic/features/game/domain/clue.dart';
import 'package:booklogic/features/game/domain/clue_evaluator.dart';
import 'package:booklogic/features/game/generator/generated_stage.dart';
import 'package:booklogic/features/game/generator/generated_stage_validator.dart';
import 'package:booklogic/features/game/generator/puzzle_template_id.dart';
import 'package:booklogic/features/game/generator/puzzle_template_resolver.dart';
import 'package:booklogic/features/game/generator/quality/generator_v1_quality_manifest.dart';
import 'package:booklogic/features/game/generator/stage_candidate_builder_router.dart';
import 'package:booklogic/features/game/generator/stage_generator.dart';
import 'package:booklogic/features/game/generator/stage_permutation_analyzer.dart';
import 'package:booklogic/features/game/generator/stage_spec_factory.dart';
import 'package:booklogic/features/game/generator/t04_tier_grouping_clue_factory.dart';
import 'package:booklogic/features/game/generator/t04_tier_grouping_scrambler.dart';
import 'package:booklogic/features/game/generator/t04_tier_grouping_solution_factory.dart';
import 'package:booklogic/features/game/presentation/formatters/clue_text_formatter.dart';

void main() {
  group('PuzzleTemplateResolver T04 policy', () {
    const resolver = PuzzleTemplateResolver();
    const specFactory = StageSpecFactory();

    test('maps levels 51 through 100 to T04 only', () {
      expect(
        resolver.resolve(specFactory.create(level: 50)),
        PuzzleTemplateId.t02EdgeSandwich,
      );
      for (final level in [51, 52, 53, 75, 100]) {
        expect(
          resolver.resolve(specFactory.create(level: level)),
          PuzzleTemplateId.t04TierGrouping,
          reason: 'level $level',
        );
      }
      expect(
        resolver.resolve(specFactory.create(level: 101)),
        PuzzleTemplateId.t05TierOrder,
      );
      for (final level in [23, 27, 31, 35, 39, 43, 47]) {
        expect(
          resolver.resolve(specFactory.create(level: level)),
          PuzzleTemplateId.t03AdjacentBlocks,
          reason: 'level $level',
        );
      }
    });
  });

  group('T04 factories', () {
    const specFactory = StageSpecFactory();
    const solutionFactory = T04TierGroupingSolutionFactory();
    const clueFactory = T04TierGroupingClueFactory();
    const scrambler = T04TierGroupingScrambler();
    const formatter = ClueTextFormatter();
    const evaluator = ClueEvaluator();

    test('creates the level 51 golden solution, clues, and scramble', () {
      final spec = specFactory.create(level: 51);
      final solution = solutionFactory.create(spec);
      final clues = clueFactory.create(solution);
      final scramble = scrambler.create(solution: solution, clues: clues);

      expect(spec.seed, 3935744153);
      expect(spec.tierCount, 2);
      expect(spec.booksPerTier, 4);
      expect(spec.totalBookCount, 8);
      expect(spec.clueCount, 4);
      expect(spec.targetSwapCount, 3);
      expect(spec.duplicateGroupCount, 0);
      expect(_ids(solution.targetPlacements), [
        'blue_star',
        'red_diamond',
        'red_cloud',
        'blue_sun',
        'yellow_diamond',
        'purple_sun',
        'green_leaf',
        'yellow_sun',
      ]);
      expect(_clueIds(clues), [
        't04_c01_00_blue_tier_0',
        't04_c01_01_yellow_tier_1',
        't04_c03_02_blue_both_edges_tier_0',
        't04_c06_03_red_between_blue_tier_0',
      ]);
      expect(
        [
          for (final clue in clues)
            formatter.format(clue: clue, books: solution.books),
        ],
        [
          '모든 파란 책은 1단에 있다.',
          '모든 노란 책은 2단에 있다.',
          '두 파란 책은 1단의 양 끝에 있다.',
          '모든 빨간 책은 1단에서 두 파란 책 사이에 있다.',
        ],
      );
      expect(scramble.scrambleSeed, 3443678134);
      expect(_ids(scramble.initialPlacements), [
        'red_cloud',
        'blue_star',
        'yellow_sun',
        'blue_sun',
        'yellow_diamond',
        'purple_sun',
        'green_leaf',
        'red_diamond',
      ]);
      expect(_swapSignatures(scramble.swapHistory), [
        '0:2<->0:0:red_cloud<->blue_star',
        '0:2<->0:1:blue_star<->red_diamond',
        '0:2<->1:3:red_diamond<->yellow_sun',
      ]);
      expect(
        evaluator.evaluateAll(
          clues: clues,
          placements: solution.targetPlacements,
        ),
        hasLength(4),
      );
      expect(
        evaluator.evaluateAll(
          clues: clues,
          placements: scramble.initialPlacements,
        ),
        {'t04_c01_00_blue_tier_0'},
      );
      expect(
        _minimumVisualDistance(
          solution.targetPlacements,
          scramble.initialPlacements,
        ),
        3,
      );
      expect(() => solution.targetPlacements.clear(), throwsUnsupportedError);
      expect(() => clues.clear(), throwsUnsupportedError);
      expect(() => scramble.initialPlacements.clear(), throwsUnsupportedError);
    });

    test('creates the level 53 duplicate golden stage', () {
      final stage = _attemptStage(level: 53);

      expect(stage.stageSpec.seed, 4281197523);
      expect(stage.stageSpec.duplicateGroupCount, 1);
      expect(stage.targetSwapCount, 5);
      expect(_ids(stage.targetPlacements), [
        'orange_key',
        'blue_key_copy_01',
        'blue_key_copy_02',
        'orange_drop',
        'red_drop',
        'purple_key',
        'yellow_moon',
        'red_star',
      ]);
      expect(stage.scrambleSeed, 3640199420);
      expect(_ids(stage.initialPlacements), [
        'purple_key',
        'blue_key_copy_01',
        'orange_drop',
        'yellow_moon',
        'orange_key',
        'blue_key_copy_02',
        'red_drop',
        'red_star',
      ]);
      final copy01 = _placementById(
        stage.initialPlacements,
        'blue_key_copy_01',
      );
      final copy02 = _placementById(
        stage.initialPlacements,
        'blue_key_copy_02',
      );
      expect(copy01.position, const BookPosition(tierIndex: 0, slotIndex: 1));
      expect(copy02.position, const BookPosition(tierIndex: 1, slotIndex: 1));
      expect(copy01.book.color, copy02.book.color);
      expect(copy01.book.symbol, copy02.book.symbol);
      expect(
        _minimumVisualDistance(stage.targetPlacements, stage.initialPlacements),
        5,
      );
      expect(const GeneratedStageValidator().validate(stage).isValid, isTrue);
    });

    test('creates the level 100 golden stage', () {
      final stage = _attemptStage(level: 100);

      expect(stage.stageSpec.seed, 2956496806);
      expect(stage.clueCount, 6);
      expect(stage.targetSwapCount, 5);
      expect(stage.stageSpec.duplicateGroupCount, 0);
      expect(_ids(stage.targetPlacements), [
        'blue_sun',
        'green_moon',
        'green_cloud',
        'blue_key',
        'yellow_star',
        'purple_sun',
        'red_key',
        'yellow_diamond',
      ]);
      expect(_clueIds(stage.clues), [
        't04_c01_00_blue_tier_0',
        't04_c01_01_yellow_tier_1',
        't04_c03_02_blue_both_edges_tier_0',
        't04_c06_03_green_between_blue_tier_0',
        't04_c07_04_purple_sun_same_tier_as_red_key',
        't04_c04_05_purple_sun_left_of_red_key_tier_1',
      ]);
      expect(stage.scrambleSeed, 2548851849);
      expect(_ids(stage.initialPlacements), [
        'yellow_star',
        'blue_sun',
        'blue_key',
        'red_key',
        'green_cloud',
        'purple_sun',
        'green_moon',
        'yellow_diamond',
      ]);
      expect(
        const ClueEvaluator().evaluateAll(
          clues: stage.clues,
          placements: stage.initialPlacements,
        ),
        hasLength(1),
      );
      expect(
        _minimumVisualDistance(stage.targetPlacements, stage.initialPlacements),
        5,
      );
      expect(const GeneratedStageValidator().validate(stage).isValid, isTrue);
    });
  });

  group('StageGenerator T04 integration', () {
    const generator = StageGenerator();
    const validator = GeneratedStageValidator();
    const evaluator = ClueEvaluator();

    test('generates deterministic valid level 51 through 100 stages', () {
      for (var level = 51; level <= 100; level += 1) {
        final first = generator.generate(level: level);
        final second = generator.generate(level: level);

        expect(first, second, reason: 'level $level');
        expect(
          first.templateId,
          PuzzleTemplateId.t04TierGrouping,
          reason: 'level $level',
        );
        expect(
          first.generationAttempt,
          GeneratorV1QualityManifest.preferredAttemptByLevel[level],
          reason: 'level $level',
        );
        expect(first.isFallback, isFalse, reason: 'level $level');
        expect(first.tierCount, 2, reason: 'level $level');
        expect(first.booksPerTier, 4, reason: 'level $level');
        expect(first.totalBookCount, 8, reason: 'level $level');
        expect(first.clueCount, inInclusiveRange(4, 6), reason: 'level $level');
        expect(
          first.targetSwapCount,
          inInclusiveRange(3, 5),
          reason: 'level $level',
        );
        expect(
          first.stageSpec.duplicateGroupCount,
          anyOf(0, 1),
          reason: 'level $level',
        );
        expect(
          evaluator.evaluateAll(
            clues: first.clues,
            placements: first.targetPlacements,
          ),
          hasLength(first.clueCount),
          reason: 'level $level',
        );
        expect(
          evaluator.evaluateAll(
            clues: first.clues,
            placements: first.initialPlacements,
          ),
          isNot(hasLength(first.clueCount)),
          reason: 'level $level',
        );
        expect(_hasCrossTierSwap(first), isTrue, reason: 'level $level');
        expect(
          _hasUnsatisfiedTierAssignment(first),
          isTrue,
          reason: 'level $level',
        );
        expect(
          _minimumVisualDistance(
            first.targetPlacements,
            first.initialPlacements,
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

    test('leaves level 101 to the T05 template', () {
      expect(
        generator.generate(level: 101).templateId,
        PuzzleTemplateId.t05TierOrder,
      );
    });
  });
}

GeneratedStage _attemptStage({required int level, int attempt = 0}) {
  const specFactory = StageSpecFactory();
  const router = StageCandidateBuilderRouter();
  return router.buildAttempt(
    stageSpec: specFactory.create(level: level),
    generationAttempt: attempt,
  );
}

List<String> _ids(List<BookPlacement> placements) {
  final sorted = List<BookPlacement>.of(placements)
    ..sort(_comparePlacementPosition);
  return [for (final placement in sorted) placement.book.id];
}

List<String> _clueIds(List<Clue> clues) {
  return [for (final clue in clues) clue.id];
}

List<String> _swapSignatures(List<dynamic> swapHistory) {
  return [
    for (final step in swapHistory)
      '${step.firstPosition.tierIndex}:${step.firstPosition.slotIndex}'
          '<->${step.secondPosition.tierIndex}:${step.secondPosition.slotIndex}'
          ':${step.firstBookIdBeforeSwap}<->${step.secondBookIdBeforeSwap}',
  ];
}

BookPlacement _placementById(List<BookPlacement> placements, String bookId) {
  return placements.singleWhere((placement) => placement.book.id == bookId);
}

int _minimumVisualDistance(
  List<BookPlacement> target,
  List<BookPlacement> initial,
) {
  return const StagePermutationAnalyzer().minimumVisualSwapDistance(
    target: target,
    current: initial,
  );
}

bool _hasCrossTierSwap(GeneratedStage stage) {
  return stage.swapHistory.any(
    (step) => step.firstPosition.tierIndex != step.secondPosition.tierIndex,
  );
}

bool _hasUnsatisfiedTierAssignment(GeneratedStage stage) {
  const evaluator = ClueEvaluator();
  return stage.clues.whereType<TierAssignmentClue>().any(
    (clue) =>
        !evaluator.evaluate(clue: clue, placements: stage.initialPlacements),
  );
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
