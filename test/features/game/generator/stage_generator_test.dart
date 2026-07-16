import 'package:flutter_test/flutter_test.dart';

import 'package:booklogic/features/game/domain/book_placement.dart';
import 'package:booklogic/features/game/generator/generated_stage.dart';
import 'package:booklogic/features/game/generator/generated_stage_factory.dart';
import 'package:booklogic/features/game/generator/generated_stage_validator.dart';
import 'package:booklogic/features/game/generator/generator_config.dart';
import 'package:booklogic/features/game/generator/quality/generator_v1_quality_manifest.dart';
import 'package:booklogic/features/game/generator/stage_generation_attempt_failure.dart';
import 'package:booklogic/features/game/generator/stage_generation_exception.dart';
import 'package:booklogic/features/game/generator/stage_generation_key.dart';
import 'package:booklogic/features/game/generator/stage_candidate_builder_router.dart';
import 'package:booklogic/features/game/generator/stage_generator.dart';
import 'package:booklogic/features/game/generator/stage_seed_factory.dart';
import 'package:booklogic/features/game/generator/stage_spec.dart';
import 'package:booklogic/features/game/generator/stage_spec_factory.dart';
import 'package:booklogic/features/game/generator/stage_validation_issue.dart';
import 'package:booklogic/features/game/generator/t01_anchor_chain_clue_factory.dart';
import 'package:booklogic/features/game/generator/t01_anchor_chain_scrambler.dart';
import 'package:booklogic/features/game/generator/t01_anchor_chain_solution_factory.dart';
import 'package:booklogic/features/game/generator/t01_fallback_stage_factory.dart';
import 'package:booklogic/features/game/generator/t01_stage_attempt_builder.dart';

void main() {
  group('StageGenerationAttemptFailure', () {
    test('stores attempt failure metadata as a value object', () {
      const failure = StageGenerationAttemptFailure(
        attempt: 2,
        seed: 3237291440,
        message: 'StateError: forced',
      );

      expect(failure.attempt, 2);
      expect(failure.seed, 3237291440);
      expect(failure.message, 'StateError: forced');
      expect(
        failure,
        const StageGenerationAttemptFailure(
          attempt: 2,
          seed: 3237291440,
          message: 'StateError: forced',
        ),
      );
      expect(failure.hashCode, failure.hashCode);
      expect(failure.toString(), contains('attempt: 2'));
      expect(failure.toString(), contains('3237291440'));
    });
  });

  group('StageGenerationException', () {
    test('stores failures immutably and prints useful context', () {
      final failures = [
        const StageGenerationAttemptFailure(
          attempt: 0,
          seed: 3270846678,
          message: 'StateError: first',
        ),
      ];
      final exception = StageGenerationException(
        level: 1,
        generatorVersion: 1,
        failures: failures,
        fallbackMessage: 'StateError: fallback',
      );

      failures.clear();

      expect(exception.level, 1);
      expect(exception.generatorVersion, 1);
      expect(exception.failures, hasLength(1));
      expect(exception.failures.first.attempt, 0);
      expect(exception.fallbackMessage, 'StateError: fallback');
      expect(() => exception.failures.clear(), throwsUnsupportedError);
      expect(exception.toString(), contains('level: 1'));
      expect(exception.toString(), contains('failureCount: 1'));
      expect(exception.toString(), contains('fallback'));
    });
  });

  group('StageSeedFactory attempt seeds', () {
    const seedFactory = StageSeedFactory();

    test('keeps level 1 attempt golden seeds stable', () {
      expect(_seed(seedFactory, 1, 0), 3270846678);
      expect(_seed(seedFactory, 1, 1), 3287624297);
      expect(_seed(seedFactory, 1, 2), 3237291440);
      expect(_seed(seedFactory, 1, 7), 3321179535);
      expect(_seed(seedFactory, 1, 8), 3405067630);
    });
  });

  group('T01 factories with generation attempt seeds', () {
    test('default attempt 0 preserves the existing manual pipeline', () {
      final defaultStage = _manualStage(level: 1);
      final explicitAttemptZero = _manualStage(
        level: 1,
        generationAttemptKey: const StageGenerationKey(
          generatorVersion: 1,
          level: 1,
        ),
        generationAttemptSeed: 3270846678,
      );

      expect(explicitAttemptZero, defaultStage);
      expect(defaultStage.generationAttempt, 0);
      expect(defaultStage.generationAttemptSeed, 3270846678);
      expect(defaultStage.isFallback, isFalse);
      expect(_placementIds(defaultStage.targetPlacements), [
        'red_key',
        'blue_moon',
        'blue_leaf',
        'yellow_leaf',
      ]);
      expect(_placementIds(defaultStage.initialPlacements), [
        'red_key',
        'blue_leaf',
        'yellow_leaf',
        'blue_moon',
      ]);
    });

    test(
      'override seed drives both solution and scramble deterministically',
      () {
        const key = StageGenerationKey(
          generatorVersion: 1,
          level: 1,
          attempt: 1,
        );
        const seed = 3287624297;
        final attemptOne = _manualStage(
          level: 1,
          generationAttemptKey: key,
          generationAttemptSeed: seed,
        );
        final repeated = _manualStage(
          level: 1,
          generationAttemptKey: key,
          generationAttemptSeed: seed,
        );

        expect(attemptOne, repeated);
        expect(attemptOne, isNot(_manualStage(level: 1)));
        expect(attemptOne.generationAttemptKey, key);
        expect(attemptOne.generationAttemptSeed, seed);
        expect(attemptOne.scrambleSeed, _expectedScrambleSeed(seed));
        expect(
          const GeneratedStageValidator().validate(attemptOne).isValid,
          isTrue,
        );
      },
    );
  });

  group('GeneratedStage generation metadata validation', () {
    const validator = GeneratedStageValidator();

    test(
      'accepts non-zero attempt metadata when key, seed, and scramble match',
      () {
        const key = StageGenerationKey(
          generatorVersion: 1,
          level: 1,
          attempt: 2,
        );
        final stage = _manualStage(
          level: 1,
          generationAttemptKey: key,
          generationAttemptSeed: 3237291440,
        );

        expect(stage.generationAttempt, 2);
        expect(stage.generationAttemptSeed, 3237291440);
        expect(validator.validate(stage).isValid, isTrue);
      },
    );

    test('rejects metadata key that does not match StageSpec', () {
      final fixture = _manualStage(level: 1);
      final badStage = GeneratedStage(
        scrambleResult: fixture.scrambleResult,
        clues: fixture.clues,
        generationAttemptKey: const StageGenerationKey(
          generatorVersion: 1,
          level: 2,
          attempt: 0,
        ),
        generationAttemptSeed: 1253005621,
      );

      final result = validator.validate(badStage);

      expect(
        result.containsCode(
          StageValidationIssueCode.invalidGenerationAttemptKey,
        ),
        isTrue,
      );
      expect(
        () => const GeneratedStageFactory().create(
          scrambleResult: badStage.scrambleResult,
          clues: badStage.clues,
          generationAttemptKey: badStage.generationAttemptKey,
          generationAttemptSeed: badStage.generationAttemptSeed,
        ),
        throwsStateError,
      );
    });

    test('rejects metadata seed that does not match attempt key', () {
      final fixture = _manualStage(level: 1);
      final badStage = GeneratedStage(
        scrambleResult: fixture.scrambleResult,
        clues: fixture.clues,
        generationAttemptKey: fixture.generationAttemptKey,
        generationAttemptSeed: fixture.generationAttemptSeed + 1,
      );

      expect(
        validator
            .validate(badStage)
            .containsCode(
              StageValidationIssueCode.invalidGenerationAttemptSeed,
            ),
        isTrue,
      );
    });

    test('rejects fallback metadata on attempt 0', () {
      final fixture = _manualStage(level: 1);
      final badStage = GeneratedStage(
        scrambleResult: fixture.scrambleResult,
        clues: fixture.clues,
        generationAttemptKey: fixture.generationAttemptKey,
        generationAttemptSeed: fixture.generationAttemptSeed,
        isFallback: true,
      );

      expect(
        validator
            .validate(badStage)
            .containsCode(StageValidationIssueCode.invalidFallbackMetadata),
        isTrue,
      );
    });
  });

  group('T01StageAttemptBuilder', () {
    const stageSpecFactory = StageSpecFactory();
    const builder = T01StageAttemptBuilder();

    test('builds a generated stage with explicit attempt metadata', () {
      final spec = stageSpecFactory.create(level: 1);
      const key = StageGenerationKey(generatorVersion: 1, level: 1, attempt: 2);
      const seed = 3237291440;
      final stage = builder.build(
        stageSpec: spec,
        generationAttemptKey: key,
        generationAttemptSeed: seed,
      );

      expect(stage.generationAttemptKey, key);
      expect(stage.generationAttemptSeed, seed);
      expect(stage.scrambleSeed, _expectedScrambleSeed(seed));
      expect(const GeneratedStageValidator().validate(stage).isValid, isTrue);
    });

    test('rejects mismatched keys, invalid seeds, and unsupported specs', () {
      final spec = stageSpecFactory.create(level: 1);
      expect(
        () => builder.build(
          stageSpec: spec,
          generationAttemptKey: const StageGenerationKey(
            generatorVersion: 1,
            level: 2,
          ),
          generationAttemptSeed: 1253005621,
        ),
        throwsArgumentError,
      );
      expect(
        () => builder.build(
          stageSpec: spec,
          generationAttemptKey: spec.generationKey,
          generationAttemptSeed: 0,
        ),
        throwsArgumentError,
      );
      expect(builder.supports(stageSpecFactory.create(level: 21)), isFalse);
      expect(
        () => builder.build(
          stageSpec: stageSpecFactory.create(level: 21),
          generationAttemptKey: const StageGenerationKey(
            generatorVersion: 1,
            level: 21,
          ),
          generationAttemptSeed: 1306301279,
        ),
        throwsUnsupportedError,
      );
    });
  });

  group('T01FallbackStageFactory', () {
    const specFactory = StageSpecFactory();
    const fallbackFactory = T01FallbackStageFactory();
    const validator = GeneratedStageValidator();

    test('supports only one-tier unique T01 specs with four or five books', () {
      expect(fallbackFactory.supports(specFactory.create(level: 1)), isTrue);
      expect(fallbackFactory.supports(specFactory.create(level: 6)), isTrue);
      expect(fallbackFactory.supports(specFactory.create(level: 20)), isTrue);
      expect(fallbackFactory.supports(specFactory.create(level: 21)), isFalse);
    });

    test('creates the level 1 deterministic fallback golden stage', () {
      final stage = fallbackFactory.create(
        stageSpec: specFactory.create(level: 1),
        fallbackAttempt: 8,
      );

      expect(stage.isFallback, isTrue);
      expect(stage.generationAttempt, 8);
      expect(stage.generationAttemptSeed, 3405067630);
      expect(stage.scrambleSeed, 1422019799);
      expect(_placementIds(stage.targetPlacements), [
        'orange_sun',
        'orange_diamond',
        'blue_moon',
        'blue_star',
      ]);
      expect(_placementIds(stage.initialPlacements), [
        'blue_moon',
        'orange_sun',
        'orange_diamond',
        'blue_star',
      ]);
      expect(_clueIds(stage), [
        't01_c02_00_orange_sun_left_edge',
        't01_c05_01_orange_diamond_immediately_right_of_orange_sun',
        't01_c04_02_blue_moon_left_of_blue_star',
      ]);
      expect(validator.validate(stage).isValid, isTrue);
    });

    test('rejects invalid attempts and unsupported fallback specs', () {
      expect(
        () => fallbackFactory.create(
          stageSpec: specFactory.create(level: 1),
          fallbackAttempt: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => fallbackFactory.create(
          stageSpec: specFactory.create(level: 21),
          fallbackAttempt: 1,
        ),
        throwsUnsupportedError,
      );
    });
  });

  group('StageGenerator', () {
    const generator = StageGenerator();
    const validator = GeneratedStageValidator();

    test('uses manifest-selected final stages for golden levels', () {
      final levelOne = generator.generate(level: 1);
      final expectedLevelOne = _routerStage(level: 1);

      expect(levelOne, expectedLevelOne);
      expect(levelOne.generationAttempt, 5);
      expect(levelOne.generationAttemptSeed, 3354734773);
      expect(levelOne.isFallback, isFalse);
      expect(levelOne.targetSwapCount, 2);
      expect(validator.validate(levelOne).isValid, isTrue);

      for (final level in [6, 20]) {
        final stage = generator.generate(level: level);
        expect(stage, _routerStage(level: level), reason: 'level $level');
        expect(
          stage.generationAttempt,
          GeneratorV1QualityManifest.preferredAttemptByLevel[level],
        );
        expect(validator.validate(stage).isValid, isTrue);
      }
    });

    test('keeps levels 1 through 20 deterministic and valid', () {
      for (var level = 1; level <= 20; level += 1) {
        final first = generator.generate(level: level);
        final second = generator.generate(level: level);

        expect(first, second, reason: 'level $level');
        expect(
          first.generationAttempt,
          GeneratorV1QualityManifest.preferredAttemptByLevel[level],
          reason: 'level $level',
        );
        expect(first.isFallback, isFalse, reason: 'level $level');
        expect(
          validator.validate(first).isValid,
          isTrue,
          reason: 'level $level',
        );
      }
    });

    test(
      'creates StageSpec once and retries with attempt seeds until success',
      () {
        final specFactory = _CountingStageSpecFactory();
        final builder = _FailingAttemptBuilder(failAttempts: {5, 0});
        final stage = StageGenerator(
          stageSpecFactory: specFactory,
          attemptBuilder: builder,
          fallbackFactory: const _ThrowingFallbackStageFactory(),
        ).generate(level: 1);

        expect(specFactory.createCount, 1);
        expect(builder.attempts, [5, 0, 1]);
        expect(builder.seeds, [3354734773, 3270846678, 3287624297]);
        expect(
          builder.stageSpecs.every(
            (stageSpec) => identical(stageSpec, specFactory.createdSpec),
          ),
          isTrue,
        );
        expect(stage.generationAttempt, 1);
        expect(stage.generationAttemptSeed, 3287624297);
        expect(stage.isFallback, isFalse);
        expect(validator.validate(stage).isValid, isTrue);
      },
    );

    test('uses fallback once after all attempts fail', () {
      final builder = _FailingAttemptBuilder(alwaysFail: true);
      final stage = StageGenerator(
        attemptBuilder: builder,
        maxAttempts: 8,
      ).generate(level: 1);

      expect(builder.attempts, [5, 0, 1, 2, 3, 4, 6, 7]);
      expect(stage.isFallback, isTrue);
      expect(stage.generationAttempt, 8);
      expect(stage.generationAttemptSeed, 3405067630);
      expect(stage.scrambleSeed, 1422019799);
      expect(_placementIds(stage.targetPlacements), [
        'orange_sun',
        'orange_diamond',
        'blue_moon',
        'blue_star',
      ]);
      expect(_placementIds(stage.initialPlacements), [
        'blue_moon',
        'orange_sun',
        'orange_diamond',
        'blue_star',
      ]);
      expect(validator.validate(stage).isValid, isTrue);
    });

    test('passes maxAttempts as the fallback attempt', () {
      final builder = _FailingAttemptBuilder(alwaysFail: true);
      final fallbackFactory = _RecordingFallbackStageFactory();
      final stage = StageGenerator(
        attemptBuilder: builder,
        fallbackFactory: fallbackFactory,
        maxAttempts: 3,
      ).generate(level: 1);

      expect(builder.attempts, [0, 1, 2]);
      expect(fallbackFactory.fallbackAttempts, [3]);
      expect(stage.isFallback, isTrue);
      expect(stage.generationAttempt, 3);
    });

    test('throws StageGenerationException when fallback also fails', () {
      final builder = _FailingAttemptBuilder(alwaysFail: true);

      expect(
        () => StageGenerator(
          attemptBuilder: builder,
          fallbackFactory: const _ThrowingFallbackStageFactory(),
          maxAttempts: 3,
        ).generate(level: 1),
        throwsA(
          isA<StageGenerationException>()
              .having((error) => error.level, 'level', 1)
              .having((error) => error.generatorVersion, 'generatorVersion', 1)
              .having((error) => error.failures, 'failures', hasLength(3))
              .having(
                (error) => [
                  for (final failure in error.failures) failure.attempt,
                ],
                'attempts',
                [0, 1, 2],
              )
              .having(
                (error) => error.fallbackMessage,
                'fallbackMessage',
                contains('forced fallback failure'),
              ),
        ),
      );
    });

    test('does not call fallback when an attempt succeeds', () {
      final builder = _FailingAttemptBuilder();
      final fallbackFactory = _RecordingFallbackStageFactory();

      final stage = StageGenerator(
        attemptBuilder: builder,
        fallbackFactory: fallbackFactory,
      ).generate(level: 1);

      expect(builder.attempts, [5]);
      expect(fallbackFactory.fallbackAttempts, isEmpty);
      expect(stage.isFallback, isFalse);
    });

    test('rejects unsupported specs before attempts or fallback', () {
      final builder = _UnsupportedAttemptBuilder();
      final fallbackFactory = _RecordingFallbackStageFactory();

      expect(
        () => StageGenerator(
          attemptBuilder: builder,
          fallbackFactory: fallbackFactory,
        ).generate(level: 201),
        throwsUnsupportedError,
      );
      expect(builder.supportChecks, 0);
      expect(builder.attempts, isEmpty);
      expect(fallbackFactory.fallbackAttempts, isEmpty);
    });

    test('validates generation inputs', () {
      expect(() => generator.generate(level: 0), throwsArgumentError);
      expect(
        () => generator.generate(level: 1, generatorVersion: 0),
        throwsArgumentError,
      );
      expect(
        () => const StageGenerator(maxAttempts: 0).generate(level: 1),
        throwsArgumentError,
      );
    });
  });
}

GeneratedStage _routerStage({required int level}) {
  const specFactory = StageSpecFactory();
  const router = StageCandidateBuilderRouter();
  final attempt = GeneratorV1QualityManifest.preferredAttemptByLevel[level]!;
  return router.buildAttempt(
    stageSpec: specFactory.create(level: level),
    generationAttempt: attempt,
  );
}

int _seed(StageSeedFactory seedFactory, int level, int attempt) {
  return seedFactory.create(
    StageGenerationKey(
      generatorVersion: GeneratorConfig.currentVersion,
      level: level,
      attempt: attempt,
    ),
  );
}

GeneratedStage _manualStage({
  required int level,
  StageGenerationKey? generationAttemptKey,
  int? generationAttemptSeed,
}) {
  const specFactory = StageSpecFactory();
  const solutionFactory = T01AnchorChainSolutionFactory();
  const clueFactory = T01AnchorChainClueFactory();
  const scrambler = T01AnchorChainScrambler();
  const factory = GeneratedStageFactory();
  final spec = specFactory.create(level: level);
  final seed = generationAttemptSeed ?? spec.seed;
  final solution = solutionFactory.create(spec, generationSeed: seed);
  final clues = clueFactory.create(solution);
  final scrambleResult = scrambler.create(
    solution: solution,
    clues: clues,
    generationSeed: seed,
  );
  return factory.create(
    scrambleResult: scrambleResult,
    clues: clues,
    generationAttemptKey: generationAttemptKey,
    generationAttemptSeed: generationAttemptSeed,
  );
}

int _expectedScrambleSeed(int generationSeed) {
  final value =
      (generationSeed ^ GeneratorConfig.t01ScrambleSalt) &
      GeneratorConfig.uint32Mask;
  if (value == 0) {
    return GeneratorConfig.zeroSeedFallback;
  }
  return value;
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

List<String> _clueIds(GeneratedStage stage) {
  return [for (final clue in stage.clues) clue.id];
}

class _CountingStageSpecFactory extends StageSpecFactory {
  _CountingStageSpecFactory();

  final StageSpecFactory _delegate = const StageSpecFactory();
  int createCount = 0;
  StageSpec? createdSpec;

  @override
  StageSpec create({
    required int level,
    int generatorVersion = GeneratorConfig.currentVersion,
  }) {
    createCount += 1;
    createdSpec = _delegate.create(
      level: level,
      generatorVersion: generatorVersion,
    );
    return createdSpec!;
  }
}

class _FailingAttemptBuilder extends T01StageAttemptBuilder {
  _FailingAttemptBuilder({
    this.failAttempts = const {},
    this.alwaysFail = false,
  });

  final Set<int> failAttempts;
  final bool alwaysFail;
  final T01StageAttemptBuilder _delegate = const T01StageAttemptBuilder();
  final attempts = <int>[];
  final seeds = <int>[];
  final stageSpecs = <StageSpec>[];

  @override
  bool supports(StageSpec stageSpec) {
    return _delegate.supports(stageSpec);
  }

  @override
  GeneratedStage build({
    required StageSpec stageSpec,
    required StageGenerationKey generationAttemptKey,
    required int generationAttemptSeed,
  }) {
    attempts.add(generationAttemptKey.attempt);
    seeds.add(generationAttemptSeed);
    stageSpecs.add(stageSpec);
    if (alwaysFail || failAttempts.contains(generationAttemptKey.attempt)) {
      throw StateError('forced attempt ${generationAttemptKey.attempt}');
    }
    return _delegate.build(
      stageSpec: stageSpec,
      generationAttemptKey: generationAttemptKey,
      generationAttemptSeed: generationAttemptSeed,
    );
  }
}

class _UnsupportedAttemptBuilder extends T01StageAttemptBuilder {
  final attempts = <int>[];
  int supportChecks = 0;

  @override
  bool supports(StageSpec stageSpec) {
    supportChecks += 1;
    return false;
  }

  @override
  GeneratedStage build({
    required StageSpec stageSpec,
    required StageGenerationKey generationAttemptKey,
    required int generationAttemptSeed,
  }) {
    attempts.add(generationAttemptKey.attempt);
    throw StateError('should not build');
  }
}

class _RecordingFallbackStageFactory extends T01FallbackStageFactory {
  _RecordingFallbackStageFactory();

  final T01FallbackStageFactory _delegate = const T01FallbackStageFactory();
  final fallbackAttempts = <int>[];

  @override
  GeneratedStage create({
    required StageSpec stageSpec,
    required int fallbackAttempt,
  }) {
    fallbackAttempts.add(fallbackAttempt);
    return _delegate.create(
      stageSpec: stageSpec,
      fallbackAttempt: fallbackAttempt,
    );
  }
}

class _ThrowingFallbackStageFactory extends T01FallbackStageFactory {
  const _ThrowingFallbackStageFactory();

  @override
  GeneratedStage create({
    required StageSpec stageSpec,
    required int fallbackAttempt,
  }) {
    throw StateError('forced fallback failure');
  }
}
