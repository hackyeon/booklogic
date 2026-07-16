import 'generated_stage.dart';
import 'generator_config.dart';
import 'generator_version_policy.dart';
import 'puzzle_template_resolver.dart';
import 'quality/generator_v1_quality_manifest.dart';
import 'quality/generator_v2_quality_manifest.dart';
import 'stage_candidate_builder_router.dart';
import 'stage_generation_attempt_failure.dart';
import 'stage_generation_exception.dart';
import 'stage_generation_key.dart';
import 'stage_seed_factory.dart';
import 'stage_spec_factory.dart';
import 't01_fallback_stage_factory.dart';
import 't01_stage_attempt_builder.dart';
import 't02_fallback_stage_factory.dart';
import 't02_stage_attempt_builder.dart';
import 't03_fallback_stage_factory.dart';
import 't03_stage_attempt_builder.dart';
import 't04_fallback_stage_factory.dart';
import 't04_stage_attempt_builder.dart';
import 't05_fallback_stage_factory.dart';
import 't05_stage_attempt_builder.dart';
import 't06_fallback_stage_factory.dart';
import 't06_stage_attempt_builder.dart';

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
    this.t04AttemptBuilder = const T04StageAttemptBuilder(),
    this.t04FallbackFactory = const T04FallbackStageFactory(),
    this.t05AttemptBuilder = const T05StageAttemptBuilder(),
    this.t05FallbackFactory = const T05FallbackStageFactory(),
    this.t06AttemptBuilder = const T06StageAttemptBuilder(),
    this.t06FallbackFactory = const T06FallbackStageFactory(),
    this.versionPolicy = const GeneratorVersionPolicy(),
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
  final T04StageAttemptBuilder t04AttemptBuilder;
  final T04FallbackStageFactory t04FallbackFactory;
  final T05StageAttemptBuilder t05AttemptBuilder;
  final T05FallbackStageFactory t05FallbackFactory;
  final T06StageAttemptBuilder t06AttemptBuilder;
  final T06FallbackStageFactory t06FallbackFactory;
  final GeneratorVersionPolicy versionPolicy;
  final int maxAttempts;

  GeneratedStage generate({
    required int level,
    int generatorVersion = GeneratorConfig.currentVersion,
  }) {
    versionPolicy.validate(level: level, generatorVersion: generatorVersion);
    if (maxAttempts < 1) {
      throw ArgumentError.value(maxAttempts, 'maxAttempts', '1 이상이어야 합니다.');
    }

    final stageSpec = stageSpecFactory.create(
      level: level,
      generatorVersion: generatorVersion,
    );
    templateResolver.resolve(stageSpec, generatorVersion: generatorVersion);

    final preferredAttempt = _preferredAttempt(
      level: level,
      generatorVersion: generatorVersion,
    );
    final router = _router();
    final failures = <StageGenerationAttemptFailure>[];
    for (final attempt in _attemptOrder(preferredAttempt)) {
      final seed = seedFactory.create(
        StageGenerationKey(
          generatorVersion: stageSpec.generatorVersion,
          level: stageSpec.level,
          attempt: attempt,
        ),
      );
      try {
        return router.buildAttempt(
          stageSpec: stageSpec,
          generationAttempt: attempt,
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
      return router.buildFallback(stageSpec: stageSpec);
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

  int _preferredAttempt({required int level, required int generatorVersion}) {
    final preferredAttempt = switch (generatorVersion) {
      GeneratorConfig.generatorVersion1 =>
        GeneratorV1QualityManifest.preferredAttemptByLevel[level],
      GeneratorConfig.generatorVersion2 =>
        GeneratorV2QualityManifest.preferredAttemptByLevel[level],
      _ => null,
    };
    if (preferredAttempt == null) {
      throw UnsupportedError('StageGenerator does not support level $level.');
    }
    return preferredAttempt;
  }

  Iterable<int> _attemptOrder(int preferredAttempt) sync* {
    if (preferredAttempt >= 0 && preferredAttempt < maxAttempts) {
      yield preferredAttempt;
    }
    for (var attempt = 0; attempt < maxAttempts; attempt += 1) {
      if (attempt != preferredAttempt) {
        yield attempt;
      }
    }
  }

  StageCandidateBuilderRouter _router() {
    return StageCandidateBuilderRouter(
      templateResolver: templateResolver,
      seedFactory: seedFactory,
      t01Builder: attemptBuilder,
      t02Builder: t02AttemptBuilder,
      t03Builder: t03AttemptBuilder,
      t04Builder: t04AttemptBuilder,
      t05Builder: t05AttemptBuilder,
      t06Builder: t06AttemptBuilder,
      t01FallbackFactory: fallbackFactory,
      t02FallbackFactory: t02FallbackFactory,
      t03FallbackFactory: t03FallbackFactory,
      t04FallbackFactory: t04FallbackFactory,
      t05FallbackFactory: t05FallbackFactory,
      t06FallbackFactory: t06FallbackFactory,
      fallbackAttempt: maxAttempts,
    );
  }
}
