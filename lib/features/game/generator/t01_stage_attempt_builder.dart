import 'generated_stage.dart';
import 'generated_stage_factory.dart';
import 'generator_config.dart';
import 'stage_generation_key.dart';
import 'stage_spec.dart';
import 't01_anchor_chain_clue_factory.dart';
import 't01_anchor_chain_scrambler.dart';
import 't01_anchor_chain_solution_factory.dart';

class T01StageAttemptBuilder {
  const T01StageAttemptBuilder({
    this.solutionFactory = const T01AnchorChainSolutionFactory(),
    this.clueFactory = const T01AnchorChainClueFactory(),
    this.scrambler = const T01AnchorChainScrambler(),
    this.generatedStageFactory = const GeneratedStageFactory(),
  });

  final T01AnchorChainSolutionFactory solutionFactory;
  final T01AnchorChainClueFactory clueFactory;
  final T01AnchorChainScrambler scrambler;
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
      throw UnsupportedError('T01 attempt builder does not support StageSpec.');
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
