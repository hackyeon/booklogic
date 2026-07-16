import 'generated_stage.dart';
import 'puzzle_template_id.dart';
import 'puzzle_template_resolver.dart';
import 'stage_generation_key.dart';
import 'stage_seed_factory.dart';
import 'stage_spec.dart';
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

class StageCandidateBuilderRouter {
  const StageCandidateBuilderRouter({
    this.templateResolver = const PuzzleTemplateResolver(),
    this.seedFactory = const StageSeedFactory(),
    this.t01Builder = const T01StageAttemptBuilder(),
    this.t02Builder = const T02StageAttemptBuilder(),
    this.t03Builder = const T03StageAttemptBuilder(),
    this.t04Builder = const T04StageAttemptBuilder(),
    this.t05Builder = const T05StageAttemptBuilder(),
    this.t06Builder = const T06StageAttemptBuilder(),
    this.t01FallbackFactory = const T01FallbackStageFactory(),
    this.t02FallbackFactory = const T02FallbackStageFactory(),
    this.t03FallbackFactory = const T03FallbackStageFactory(),
    this.t04FallbackFactory = const T04FallbackStageFactory(),
    this.t05FallbackFactory = const T05FallbackStageFactory(),
    this.t06FallbackFactory = const T06FallbackStageFactory(),
    this.fallbackAttempt = 8,
  });

  final PuzzleTemplateResolver templateResolver;
  final StageSeedFactory seedFactory;
  final T01StageAttemptBuilder t01Builder;
  final T02StageAttemptBuilder t02Builder;
  final T03StageAttemptBuilder t03Builder;
  final T04StageAttemptBuilder t04Builder;
  final T05StageAttemptBuilder t05Builder;
  final T06StageAttemptBuilder t06Builder;
  final T01FallbackStageFactory t01FallbackFactory;
  final T02FallbackStageFactory t02FallbackFactory;
  final T03FallbackStageFactory t03FallbackFactory;
  final T04FallbackStageFactory t04FallbackFactory;
  final T05FallbackStageFactory t05FallbackFactory;
  final T06FallbackStageFactory t06FallbackFactory;
  final int fallbackAttempt;

  GeneratedStage buildAttempt({
    required StageSpec stageSpec,
    required int generationAttempt,
  }) {
    if (generationAttempt < 0) {
      throw ArgumentError.value(
        generationAttempt,
        'generationAttempt',
        '0 이상이어야 합니다.',
      );
    }
    final key = StageGenerationKey(
      generatorVersion: stageSpec.generatorVersion,
      level: stageSpec.level,
      attempt: generationAttempt,
    );
    final seed = seedFactory.create(key);
    final templateId = templateResolver.resolve(stageSpec);
    return switch (templateId) {
      PuzzleTemplateId.t01AnchorChain => t01Builder.build(
        stageSpec: stageSpec,
        generationAttemptKey: key,
        generationAttemptSeed: seed,
      ),
      PuzzleTemplateId.t02EdgeSandwich => t02Builder.build(
        stageSpec: stageSpec,
        generationAttemptKey: key,
        generationAttemptSeed: seed,
      ),
      PuzzleTemplateId.t03AdjacentBlocks => t03Builder.build(
        stageSpec: stageSpec,
        generationAttemptKey: key,
        generationAttemptSeed: seed,
      ),
      PuzzleTemplateId.t04TierGrouping => t04Builder.build(
        stageSpec: stageSpec,
        generationAttemptKey: key,
        generationAttemptSeed: seed,
      ),
      PuzzleTemplateId.t05TierOrder => t05Builder.build(
        stageSpec: stageSpec,
        generationAttemptKey: key,
        generationAttemptSeed: seed,
      ),
      PuzzleTemplateId.t06VerticalPair => t06Builder.build(
        stageSpec: stageSpec,
        generationAttemptKey: key,
        generationAttemptSeed: seed,
      ),
    };
  }

  GeneratedStage buildFallback({required StageSpec stageSpec}) {
    final templateId = templateResolver.resolve(stageSpec);
    return switch (templateId) {
      PuzzleTemplateId.t01AnchorChain => t01FallbackFactory.create(
        stageSpec: stageSpec,
        fallbackAttempt: fallbackAttempt,
      ),
      PuzzleTemplateId.t02EdgeSandwich => t02FallbackFactory.create(
        stageSpec: stageSpec,
        fallbackAttempt: fallbackAttempt,
      ),
      PuzzleTemplateId.t03AdjacentBlocks => t03FallbackFactory.create(
        stageSpec: stageSpec,
        fallbackAttempt: fallbackAttempt,
      ),
      PuzzleTemplateId.t04TierGrouping => t04FallbackFactory.create(
        stageSpec: stageSpec,
        fallbackAttempt: fallbackAttempt,
      ),
      PuzzleTemplateId.t05TierOrder => t05FallbackFactory.create(
        stageSpec: stageSpec,
        fallbackAttempt: fallbackAttempt,
      ),
      PuzzleTemplateId.t06VerticalPair => t06FallbackFactory.create(
        stageSpec: stageSpec,
        fallbackAttempt: fallbackAttempt,
      ),
    };
  }
}
