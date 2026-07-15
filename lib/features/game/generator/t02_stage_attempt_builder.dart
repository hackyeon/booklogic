import 'generated_stage.dart';
import 'generated_stage_factory.dart';
import 'generator_config.dart';
import 'stage_generation_key.dart';
import 'stage_spec.dart';
import 't02_edge_sandwich_clue_factory.dart';
import 't02_edge_sandwich_scrambler.dart';
import 't02_edge_sandwich_solution_factory.dart';

class T02StageAttemptBuilder {
  const T02StageAttemptBuilder({
    this.solutionFactory = const T02EdgeSandwichSolutionFactory(),
    this.clueFactory = const T02EdgeSandwichClueFactory(),
    this.scrambler = const T02EdgeSandwichScrambler(),
    this.generatedStageFactory = const GeneratedStageFactory(),
  });

  final T02EdgeSandwichSolutionFactory solutionFactory;
  final T02EdgeSandwichClueFactory clueFactory;
  final T02EdgeSandwichScrambler scrambler;
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
      throw UnsupportedError('T02 attempt builder does not support StageSpec.');
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
