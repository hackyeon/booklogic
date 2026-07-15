import 'generated_stage.dart';
import 'generator_config.dart';
import 'puzzle_template_id.dart';
import 'puzzle_template_resolver.dart';
import 'stage_generation_attempt_failure.dart';
import 'stage_generation_exception.dart';
import 'stage_generation_key.dart';
import 'stage_seed_factory.dart';
import 'stage_spec.dart';
import 'stage_spec_factory.dart';
import 't01_fallback_stage_factory.dart';
import 't01_stage_attempt_builder.dart';
import 't02_fallback_stage_factory.dart';
import 't02_stage_attempt_builder.dart';
import 't03_fallback_stage_factory.dart';
import 't03_stage_attempt_builder.dart';

class StageGenerator {
  const StageGenerator({
    this.stageSpecFactory = const StageSpecFactory(),
    this.templateResolver = const PuzzleTemplateResolver(),
    this.seedFactory = const StageSeedFactory(),
    this.attemptBuilder = const T01StageAttemptBuilder(),
    this.fallbackFactory = const T01FallbackStageFactory(),
    this.t02AttemptBuilder = const T02StageAttemptBuilder(),
    this.t02FallbackFactory = const T02FallbackStageFactory(),
    this.t03AttemptBuilder = const T03StageAttemptBuilder(),
    this.t03FallbackFactory = const T03FallbackStageFactory(),
    this.maxAttempts = 8,
  });

  final StageSpecFactory stageSpecFactory;
  final PuzzleTemplateResolver templateResolver;
  final StageSeedFactory seedFactory;
  final T01StageAttemptBuilder attemptBuilder;
  final T01FallbackStageFactory fallbackFactory;
  final T02StageAttemptBuilder t02AttemptBuilder;
  final T02FallbackStageFactory t02FallbackFactory;
  final T03StageAttemptBuilder t03AttemptBuilder;
  final T03FallbackStageFactory t03FallbackFactory;
  final int maxAttempts;

  GeneratedStage generate({
    required int level,
    int generatorVersion = GeneratorConfig.currentVersion,
  }) {
    if (level < 1) {
      throw ArgumentError.value(level, 'level', '1 이상이어야 합니다.');
    }
    if (generatorVersion < 1) {
      throw ArgumentError.value(
        generatorVersion,
        'generatorVersion',
        '1 이상이어야 합니다.',
      );
    }
    if (maxAttempts < 1) {
      throw ArgumentError.value(maxAttempts, 'maxAttempts', '1 이상이어야 합니다.');
    }

    final stageSpec = stageSpecFactory.create(
      level: level,
      generatorVersion: generatorVersion,
    );
    final templateId = templateResolver.resolve(stageSpec);
    return switch (templateId) {
      PuzzleTemplateId.t01AnchorChain => _generateT01(
        stageSpec: stageSpec,
        level: level,
        generatorVersion: generatorVersion,
      ),
      PuzzleTemplateId.t02EdgeSandwich => _generateT02(
        stageSpec: stageSpec,
        level: level,
        generatorVersion: generatorVersion,
      ),
      PuzzleTemplateId.t03AdjacentBlocks => _generateT03(
        stageSpec: stageSpec,
        level: level,
        generatorVersion: generatorVersion,
      ),
    };
  }

  GeneratedStage _generateT01({
    required StageSpec stageSpec,
    required int level,
    required int generatorVersion,
  }) {
    final failures = <StageGenerationAttemptFailure>[];
    for (var attempt = 0; attempt < maxAttempts; attempt += 1) {
      final key = StageGenerationKey(
        generatorVersion: generatorVersion,
        level: level,
        attempt: attempt,
      );
      final seed = seedFactory.create(key);
      try {
        return attemptBuilder.build(
          stageSpec: stageSpec,
          generationAttemptKey: key,
          generationAttemptSeed: seed,
        );
      } on StateError catch (error) {
        failures.add(
          StageGenerationAttemptFailure(
            attempt: attempt,
            seed: seed,
            message: error.toString(),
          ),
        );
      } on ArgumentError catch (error) {
        failures.add(
          StageGenerationAttemptFailure(
            attempt: attempt,
            seed: seed,
            message: error.toString(),
          ),
        );
      }
    }

    try {
      return fallbackFactory.create(
        stageSpec: stageSpec,
        fallbackAttempt: maxAttempts,
      );
    } on StateError catch (error) {
      throw StageGenerationException(
        level: level,
        generatorVersion: generatorVersion,
        failures: failures,
        fallbackMessage: error.toString(),
      );
    } on ArgumentError catch (error) {
      throw StageGenerationException(
        level: level,
        generatorVersion: generatorVersion,
        failures: failures,
        fallbackMessage: error.toString(),
      );
    }
  }

  GeneratedStage _generateT02({
    required StageSpec stageSpec,
    required int level,
    required int generatorVersion,
  }) {
    final failures = <StageGenerationAttemptFailure>[];
    for (var attempt = 0; attempt < maxAttempts; attempt += 1) {
      final key = StageGenerationKey(
        generatorVersion: generatorVersion,
        level: level,
        attempt: attempt,
      );
      final seed = seedFactory.create(key);
      try {
        return t02AttemptBuilder.build(
          stageSpec: stageSpec,
          generationAttemptKey: key,
          generationAttemptSeed: seed,
        );
      } on StateError catch (error) {
        failures.add(
          StageGenerationAttemptFailure(
            attempt: attempt,
            seed: seed,
            message: error.toString(),
          ),
        );
      } on ArgumentError catch (error) {
        failures.add(
          StageGenerationAttemptFailure(
            attempt: attempt,
            seed: seed,
            message: error.toString(),
          ),
        );
      }
    }

    try {
      return t02FallbackFactory.create(
        stageSpec: stageSpec,
        fallbackAttempt: maxAttempts,
      );
    } on StateError catch (error) {
      throw StageGenerationException(
        level: level,
        generatorVersion: generatorVersion,
        failures: failures,
        fallbackMessage: error.toString(),
      );
    } on ArgumentError catch (error) {
      throw StageGenerationException(
        level: level,
        generatorVersion: generatorVersion,
        failures: failures,
        fallbackMessage: error.toString(),
      );
    }
  }

  GeneratedStage _generateT03({
    required StageSpec stageSpec,
    required int level,
    required int generatorVersion,
  }) {
    final failures = <StageGenerationAttemptFailure>[];
    for (var attempt = 0; attempt < maxAttempts; attempt += 1) {
      final key = StageGenerationKey(
        generatorVersion: generatorVersion,
        level: level,
        attempt: attempt,
      );
      final seed = seedFactory.create(key);
      try {
        return t03AttemptBuilder.build(
          stageSpec: stageSpec,
          generationAttemptKey: key,
          generationAttemptSeed: seed,
        );
      } on StateError catch (error) {
        failures.add(
          StageGenerationAttemptFailure(
            attempt: attempt,
            seed: seed,
            message: error.toString(),
          ),
        );
      } on ArgumentError catch (error) {
        failures.add(
          StageGenerationAttemptFailure(
            attempt: attempt,
            seed: seed,
            message: error.toString(),
          ),
        );
      }
    }

    try {
      return t03FallbackFactory.create(
        stageSpec: stageSpec,
        fallbackAttempt: maxAttempts,
      );
    } on StateError catch (error) {
      throw StageGenerationException(
        level: level,
        generatorVersion: generatorVersion,
        failures: failures,
        fallbackMessage: error.toString(),
      );
    } on ArgumentError catch (error) {
      throw StageGenerationException(
        level: level,
        generatorVersion: generatorVersion,
        failures: failures,
        fallbackMessage: error.toString(),
      );
    }
  }
}
