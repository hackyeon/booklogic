import 'generated_stage.dart';
import 'generator_config.dart';
import 'stage_generation_attempt_failure.dart';
import 'stage_generation_exception.dart';
import 'stage_generation_key.dart';
import 'stage_seed_factory.dart';
import 'stage_spec_factory.dart';
import 't01_fallback_stage_factory.dart';
import 't01_stage_attempt_builder.dart';

class StageGenerator {
  const StageGenerator({
    this.stageSpecFactory = const StageSpecFactory(),
    this.seedFactory = const StageSeedFactory(),
    this.attemptBuilder = const T01StageAttemptBuilder(),
    this.fallbackFactory = const T01FallbackStageFactory(),
    this.maxAttempts = 8,
  });

  final StageSpecFactory stageSpecFactory;
  final StageSeedFactory seedFactory;
  final T01StageAttemptBuilder attemptBuilder;
  final T01FallbackStageFactory fallbackFactory;
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
    if (!attemptBuilder.supports(stageSpec)) {
      throw UnsupportedError('StageGenerator does not support level $level.');
    }

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
}
