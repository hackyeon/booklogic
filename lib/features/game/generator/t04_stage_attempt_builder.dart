import 'generated_stage.dart';
import 'generated_stage_factory.dart';
import 'generator_config.dart';
import 'stage_generation_key.dart';
import 'stage_spec.dart';
import 't04_tier_grouping_clue_factory.dart';
import 't04_tier_grouping_scrambler.dart';
import 't04_tier_grouping_solution_factory.dart';

class T04StageAttemptBuilder {
  const T04StageAttemptBuilder({
    this.solutionFactory = const T04TierGroupingSolutionFactory(),
    this.clueFactory = const T04TierGroupingClueFactory(),
    this.scrambler = const T04TierGroupingScrambler(),
    this.generatedStageFactory = const GeneratedStageFactory(),
  });

  final T04TierGroupingSolutionFactory solutionFactory;
  final T04TierGroupingClueFactory clueFactory;
  final T04TierGroupingScrambler scrambler;
  final GeneratedStageFactory generatedStageFactory;

  bool supports(StageSpec stageSpec) {
    return solutionFactory.supports(stageSpec);
  }

  GeneratedStage build({
    required StageSpec stageSpec,
    required StageGenerationKey generationAttemptKey,
    required int generationAttemptSeed,
  }) {
    _validateInput(
      stageSpec: stageSpec,
      generationAttemptKey: generationAttemptKey,
      generationAttemptSeed: generationAttemptSeed,
    );
    if (!supports(stageSpec)) {
      throw UnsupportedError('T04 attempt builder does not support StageSpec.');
    }

    final solution = solutionFactory.create(
      stageSpec,
      generationSeed: generationAttemptSeed,
    );
    final clues = clueFactory.create(solution);
    final scrambleResult = scrambler.create(
      solution: solution,
      clues: clues,
      generationSeed: generationAttemptSeed,
    );
    return generatedStageFactory.create(
      scrambleResult: scrambleResult,
      clues: clues,
      generationAttemptKey: generationAttemptKey,
      generationAttemptSeed: generationAttemptSeed,
    );
  }

  void _validateInput({
    required StageSpec stageSpec,
    required StageGenerationKey generationAttemptKey,
    required int generationAttemptSeed,
  }) {
    if (generationAttemptKey.level != stageSpec.level ||
        generationAttemptKey.generatorVersion != stageSpec.generatorVersion ||
        generationAttemptKey.attempt < 0) {
      throw ArgumentError.value(
        generationAttemptKey,
        'generationAttemptKey',
        'StageSpec와 같은 level/version의 attempt key여야 합니다.',
      );
    }
    if (generationAttemptSeed <= 0 ||
        generationAttemptSeed > GeneratorConfig.uint32Mask) {
      throw ArgumentError.value(
        generationAttemptSeed,
        'generationAttemptSeed',
        '1부터 ${GeneratorConfig.uint32Mask} 사이여야 합니다.',
      );
    }
  }
}
