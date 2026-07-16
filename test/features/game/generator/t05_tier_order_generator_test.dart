import 'package:flutter_test/flutter_test.dart';

import 'package:booklogic/features/game/domain/book_placement.dart';
import 'package:booklogic/features/game/domain/clue.dart';
import 'package:booklogic/features/game/domain/clue_evaluator.dart';
import 'package:booklogic/features/game/generator/generated_stage.dart';
import 'package:booklogic/features/game/generator/generated_stage_validator.dart';
import 'package:booklogic/features/game/generator/puzzle_template_id.dart';
import 'package:booklogic/features/game/generator/puzzle_template_resolver.dart';
import 'package:booklogic/features/game/generator/quality/generator_v1_quality_manifest.dart';
import 'package:booklogic/features/game/generator/stage_generation_key.dart';
import 'package:booklogic/features/game/generator/stage_generator.dart';
import 'package:booklogic/features/game/generator/stage_permutation_analyzer.dart';
import 'package:booklogic/features/game/generator/stage_spec.dart';
import 'package:booklogic/features/game/generator/stage_spec_factory.dart';
import 'package:booklogic/features/game/generator/t05_stage_attempt_builder.dart';
import 'package:booklogic/features/game/generator/t05_tier_order_clue_factory.dart';
import 'package:booklogic/features/game/generator/t05_tier_order_scrambler.dart';
import 'package:booklogic/features/game/generator/t05_tier_order_solution_factory.dart';
import 'package:booklogic/features/game/presentation/formatters/clue_text_formatter.dart';

void main() {
  group('PuzzleTemplateResolver T05 policy', () {
    const resolver = PuzzleTemplateResolver();
    const specFactory = StageSpecFactory();

    test('maps generator v1 levels through 200 and rejects 201', () {
      expect(
        resolver.resolve(specFactory.create(level: 1)),
        PuzzleTemplateId.t01AnchorChain,
      );
      expect(
        resolver.resolve(specFactory.create(level: 20)),
        PuzzleTemplateId.t01AnchorChain,
      );
      expect(
        resolver.resolve(specFactory.create(level: 21)),
        PuzzleTemplateId.t02EdgeSandwich,
      );
      expect(
        resolver.resolve(specFactory.create(level: 23)),
        PuzzleTemplateId.t03AdjacentBlocks,
      );
      expect(
        resolver.resolve(specFactory.create(level: 50)),
        PuzzleTemplateId.t02EdgeSandwich,
      );
      expect(
        resolver.resolve(specFactory.create(level: 51)),
        PuzzleTemplateId.t04TierGrouping,
      );
      expect(
        resolver.resolve(specFactory.create(level: 100)),
        PuzzleTemplateId.t04TierGrouping,
      );
      expect(
        resolver.resolve(specFactory.create(level: 101)),
        PuzzleTemplateId.t05TierOrder,
      );
      expect(
        resolver.resolve(specFactory.create(level: 150)),
        PuzzleTemplateId.t05TierOrder,
      );
      expect(
        resolver.resolve(specFactory.create(level: 200)),
        PuzzleTemplateId.t05TierOrder,
      );
      expect(
        () => resolver.resolve(specFactory.create(level: 201)),
        throwsUnsupportedError,
      );
    });
  });

  group('T05 factories and golden stages', () {
    const specFactory = StageSpecFactory();
    const solutionFactory = T05TierOrderSolutionFactory();
    const clueFactory = T05TierOrderClueFactory();
    const scrambler = T05TierOrderScrambler();
    const formatter = ClueTextFormatter();
    const evaluator = ClueEvaluator();

    test('creates the level 101 golden solution, clues, and scramble', () {
      final spec = specFactory.create(level: 101);
      final solution = solutionFactory.create(spec);
      final clues = clueFactory.create(solution);
      final scramble = scrambler.create(solution: solution, clues: clues);

      expect(solutionFactory.supports(spec), isTrue);
      expect(spec.seed, 710837801);
      expect(spec.tierCount, 2);
      expect(spec.booksPerTier, 5);
      expect(spec.totalBookCount, 10);
      expect(spec.clueCount, 7);
      expect(spec.targetSwapCount, 6);
      expect(spec.duplicateGroupCount, 1);
      expect(solution.templateId, PuzzleTemplateId.t05TierOrder);
      expect(_ids(solution.targetPlacements), [
        'red_drop',
        'green_drop_copy_01',
        'green_drop_copy_02',
        'yellow_cloud',
        'red_star',
        'purple_moon',
        'blue_cloud',
        'blue_sun',
        'orange_sun',
        'purple_diamond',
      ]);
      expect(_clueIds(clues), [
        't05_c03_00_red_both_edges_tier_0',
        't05_c05_01_yellow_cloud_immediately_right_of_green_group_tier_0',
        't05_c03_02_purple_both_edges_tier_1',
        't05_c05_03_orange_sun_immediately_right_of_blue_group_tier_1',
        't05_c01_04_green_tier_0',
        't05_c01_05_blue_tier_1',
        't05_c04_06_blue_group_left_of_orange_sun_tier_1',
      ]);
      expect(
        [
          for (final clue in clues)
            formatter.format(clue: clue, books: solution.books),
        ],
        [
          '두 빨간 책은 1단의 양 끝에 있다.',
          '노란 구름 책은 1단에서 두 초록 책 묶음 바로 오른쪽에 있다.',
          '두 보라 책은 2단의 양 끝에 있다.',
          '주황 태양 책은 2단에서 두 파란 책 묶음 바로 오른쪽에 있다.',
          '모든 초록 책은 1단에 있다.',
          '모든 파란 책은 2단에 있다.',
          '모든 파란 책은 2단에서 주황 태양 책보다 왼쪽에 있다.',
        ],
      );
      expect(scramble.scrambleSeed, 1007215000);
      expect(_ids(scramble.initialPlacements), [
        'red_drop',
        'green_drop_copy_01',
        'yellow_cloud',
        'purple_moon',
        'purple_diamond',
        'red_star',
        'green_drop_copy_02',
        'blue_sun',
        'blue_cloud',
        'orange_sun',
      ]);
      expect(_swapSignatures(scramble.swapHistory), [
        '0:0:2<->1:1:green_drop_copy_02<->blue_cloud',
        '1:0:2<->1:3:blue_cloud<->orange_sun',
        '2:0:2<->1:4:orange_sun<->purple_diamond',
        '3:0:2<->0:4:purple_diamond<->red_star',
        '4:0:2<->1:0:red_star<->purple_moon',
        '5:0:2<->0:3:purple_moon<->yellow_cloud',
      ]);
      expect(
        evaluator.evaluateAll(
          clues: clues,
          placements: solution.targetPlacements,
        ),
        hasLength(7),
      );
      expect(
        evaluator.evaluateAll(
          clues: clues,
          placements: scramble.initialPlacements,
        ),
        {
          't05_c05_03_orange_sun_immediately_right_of_blue_group_tier_1',
          't05_c01_05_blue_tier_1',
          't05_c04_06_blue_group_left_of_orange_sun_tier_1',
        },
      );
      expect(
        _minimumVisualDistance(
          solution.targetPlacements,
          scramble.initialPlacements,
        ),
        6,
      );
      expect(_crossTierSwapCount(scramble.swapHistory), 4);
      expect(() => solution.targetPlacements.clear(), throwsUnsupportedError);
      expect(() => clues.clear(), throwsUnsupportedError);
      expect(() => scramble.initialPlacements.clear(), throwsUnsupportedError);
    });

    test('uses deterministic subset fallback for level 110', () {
      final stage = const StageGenerator().generate(level: 110);

      expect(stage.stageSpec.seed, 4230247431);
      expect(stage.clueCount, 5);
      expect(stage.targetSwapCount, 4);
      expect(stage.stageSpec.duplicateGroupCount, 1);
      expect(stage.scrambleSeed, 3933344694);
      expect(_ids(stage.targetPlacements), [
        'blue_star',
        'red_drop_copy_01',
        'red_drop_copy_02',
        'green_drop',
        'blue_drop',
        'yellow_sun',
        'purple_star',
        'purple_cloud',
        'orange_cloud',
        'yellow_star',
      ]);
      expect(_ids(stage.initialPlacements), [
        'blue_star',
        'red_drop_copy_01',
        'blue_drop',
        'green_drop',
        'purple_cloud',
        'red_drop_copy_02',
        'purple_star',
        'orange_cloud',
        'yellow_sun',
        'yellow_star',
      ]);
      expect(_swapSlots(stage), [
        '0:2<->1:0',
        '0:2<->1:3',
        '0:2<->1:2',
        '0:2<->0:4',
      ]);
      expect(_satisfiedCount(stage), 0);
      expect(
        _minimumVisualDistance(stage.targetPlacements, stage.initialPlacements),
        4,
      );
      expect(const GeneratedStageValidator().validate(stage).isValid, isTrue);
    });

    test('creates the level 200 duplicate two-group golden stage', () {
      final stage = const StageGenerator().generate(level: 200);

      expect(stage.stageSpec.seed, 4186017979);
      expect(stage.clueCount, 5);
      expect(stage.targetSwapCount, 5);
      expect(stage.stageSpec.duplicateGroupCount, 2);
      expect(stage.scrambleSeed, 4023908106);
      expect(_ids(stage.targetPlacements), [
        'purple_star',
        'green_leaf_copy_01',
        'green_leaf_copy_02',
        'red_moon',
        'purple_cloud',
        'orange_key',
        'yellow_cloud_copy_01',
        'yellow_cloud_copy_02',
        'blue_leaf',
        'orange_moon',
      ]);
      expect(_ids(stage.initialPlacements), [
        'purple_star',
        'yellow_cloud_copy_01',
        'green_leaf_copy_02',
        'purple_cloud',
        'blue_leaf',
        'red_moon',
        'orange_key',
        'yellow_cloud_copy_02',
        'green_leaf_copy_01',
        'orange_moon',
      ]);
      expect(_swapSlots(stage), [
        '1:0<->1:1',
        '1:0<->0:1',
        '1:0<->1:3',
        '1:0<->0:4',
        '1:0<->0:3',
      ]);
      expect(_satisfiedCount(stage), 0);
      expect(
        _minimumVisualDistance(stage.targetPlacements, stage.initialPlacements),
        5,
      );
      expect(const GeneratedStageValidator().validate(stage).isValid, isTrue);
    });
  });

  group('StageGenerator T05 integration', () {
    const generator = StageGenerator();
    const validator = GeneratedStageValidator();
    const evaluator = ClueEvaluator();

    test('generates deterministic valid level 101 through 200 stages', () {
      for (var level = 101; level <= 200; level += 1) {
        final first = generator.generate(level: level);
        final second = generator.generate(level: level);

        expect(first, second, reason: 'level $level');
        expect(first.templateId, PuzzleTemplateId.t05TierOrder);
        expect(
          first.generationAttempt,
          GeneratorV1QualityManifest.preferredAttemptByLevel[level],
          reason: 'level $level',
        );
        expect(first.isFallback, isFalse, reason: 'level $level');
        expect(first.tierCount, 2, reason: 'level $level');
        expect(first.booksPerTier, 5, reason: 'level $level');
        expect(first.totalBookCount, 10, reason: 'level $level');
        expect(first.clueCount, inInclusiveRange(5, 7));
        expect(first.targetSwapCount, inInclusiveRange(4, 6));
        expect(first.stageSpec.duplicateGroupCount, anyOf(1, 2));
        expect(
          evaluator.evaluateAll(
            clues: first.clues,
            placements: first.targetPlacements,
          ),
          hasLength(first.clueCount),
          reason: 'level $level target',
        );
        expect(
          evaluator.evaluateAll(
            clues: first.clues,
            placements: first.initialPlacements,
          ),
          isNot(hasLength(first.clueCount)),
          reason: 'level $level initial',
        );
        expect(_hasCrossTierSwap(first), isTrue, reason: 'level $level');
        expect(_hasUnsatisfiedTierAssignment(first), isTrue);
        expect(_hasUnsatisfiedTierOrder(first, 0, 1), isTrue);
        expect(_hasUnsatisfiedTierOrder(first, 2, 3), isTrue);
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

    test('retries T05 without changing template', () {
      final builder = _RetryT05AttemptBuilder(failAttempts: {3, 0});
      final stage = StageGenerator(
        t05AttemptBuilder: builder,
      ).generate(level: 101);

      expect(builder.attempts, [3, 0, 1]);
      expect(stage.templateId, PuzzleTemplateId.t05TierOrder);
      expect(stage.generationAttempt, 1);
      expect(stage.isFallback, isFalse);
      expect(validator.validate(stage).isValid, isTrue);
    });

    test('uses T05 fallback after all T05 attempts fail', () {
      final stage = const StageGenerator(
        t05AttemptBuilder: _AlwaysFailingT05AttemptBuilder(),
      ).generate(level: 101);

      expect(stage.templateId, PuzzleTemplateId.t05TierOrder);
      expect(stage.isFallback, isTrue);
      expect(stage.generationAttempt, 8);
      expect(stage.generationAttemptSeed, 845058753);
      expect(stage.scrambleSeed, 604566896);
      expect(_ids(stage.targetPlacements), [
        'green_star',
        'purple_leaf_copy_01',
        'purple_leaf_copy_02',
        'orange_cloud',
        'green_cloud',
        'blue_star',
        'red_sun',
        'red_diamond',
        'yellow_drop',
        'blue_cloud',
      ]);
      expect(_ids(stage.initialPlacements), [
        'green_cloud',
        'blue_star',
        'purple_leaf_copy_02',
        'red_sun',
        'yellow_drop',
        'green_star',
        'purple_leaf_copy_01',
        'red_diamond',
        'orange_cloud',
        'blue_cloud',
      ]);
      expect(_satisfiedCount(stage), 0);
      expect(
        _minimumVisualDistance(stage.targetPlacements, stage.initialPlacements),
        6,
      );
      expect(validator.validate(stage).isValid, isTrue);
    });

    test('rejects level 201 without changing progress ceiling', () {
      expect(() => generator.generate(level: 201), throwsUnsupportedError);
    });
  });
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
      '${step.stepIndex}:${step.firstPosition.tierIndex}:'
          '${step.firstPosition.slotIndex}<->'
          '${step.secondPosition.tierIndex}:'
          '${step.secondPosition.slotIndex}:'
          '${step.firstBookIdBeforeSwap}<->'
          '${step.secondBookIdBeforeSwap}',
  ];
}

List<String> _swapSlots(GeneratedStage stage) {
  return [
    for (final step in stage.swapHistory)
      '${step.firstPosition.tierIndex}:${step.firstPosition.slotIndex}<->'
          '${step.secondPosition.tierIndex}:${step.secondPosition.slotIndex}',
  ];
}

int _satisfiedCount(GeneratedStage stage) {
  return const ClueEvaluator()
      .evaluateAll(clues: stage.clues, placements: stage.initialPlacements)
      .length;
}

bool _hasCrossTierSwap(GeneratedStage stage) {
  return stage.swapHistory.any(
    (step) => step.firstPosition.tierIndex != step.secondPosition.tierIndex,
  );
}

int _crossTierSwapCount(List<dynamic> swapHistory) {
  return swapHistory
      .where(
        (step) => step.firstPosition.tierIndex != step.secondPosition.tierIndex,
      )
      .length;
}

bool _hasUnsatisfiedTierAssignment(GeneratedStage stage) {
  for (final clue in stage.clues) {
    if (clue is TierAssignmentClue &&
        !const ClueEvaluator().evaluate(
          clue: clue,
          placements: stage.initialPlacements,
        )) {
      return true;
    }
  }
  return false;
}

bool _hasUnsatisfiedTierOrder(
  GeneratedStage stage,
  int firstIndex,
  int secondIndex,
) {
  final evaluator = const ClueEvaluator();
  return !(evaluator.evaluate(
        clue: stage.clues[firstIndex],
        placements: stage.initialPlacements,
      ) &&
      evaluator.evaluate(
        clue: stage.clues[secondIndex],
        placements: stage.initialPlacements,
      ));
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

int _comparePlacementPosition(BookPlacement left, BookPlacement right) {
  final tierComparison = left.position.tierIndex.compareTo(
    right.position.tierIndex,
  );
  if (tierComparison != 0) {
    return tierComparison;
  }
  return left.position.slotIndex.compareTo(right.position.slotIndex);
}

class _AlwaysFailingT05AttemptBuilder extends T05StageAttemptBuilder {
  const _AlwaysFailingT05AttemptBuilder();

  @override
  GeneratedStage build({
    required StageSpec stageSpec,
    required StageGenerationKey generationAttemptKey,
    required int generationAttemptSeed,
  }) {
    throw StateError('forced T05 failure');
  }
}

class _RetryT05AttemptBuilder extends T05StageAttemptBuilder {
  _RetryT05AttemptBuilder({required this.failAttempts});

  final Set<int> failAttempts;
  final List<int> attempts = [];

  @override
  GeneratedStage build({
    required StageSpec stageSpec,
    required StageGenerationKey generationAttemptKey,
    required int generationAttemptSeed,
  }) {
    attempts.add(generationAttemptKey.attempt);
    if (failAttempts.contains(generationAttemptKey.attempt)) {
      throw StateError('forced T05 failure');
    }
    return super.build(
      stageSpec: stageSpec,
      generationAttemptKey: generationAttemptKey,
      generationAttemptSeed: generationAttemptSeed,
    );
  }
}
