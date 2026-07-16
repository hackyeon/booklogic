import 'generated_stage.dart';
import 'generated_stage_factory.dart';
import 'stage_generation_key.dart';
import 'stage_seed_factory.dart';
import 'stage_spec.dart';
import 't06_vertical_pair_clue_factory.dart';
import 't06_vertical_pair_scrambler.dart';
import 't06_vertical_pair_solution_factory.dart';

class T06FallbackStageFactory {
  const T06FallbackStageFactory({
    this.seedFactory = const StageSeedFactory(),
    this.solutionFactory = const T06VerticalPairSolutionFactory(),
    this.clueFactory = const T06VerticalPairClueFactory(),
    this.scrambler = const T06VerticalPairScrambler(),
    this.generatedStageFactory = const GeneratedStageFactory(),
  });

  final StageSeedFactory seedFactory;
  final T06VerticalPairSolutionFactory solutionFactory;
  final T06VerticalPairClueFactory clueFactory;
  final T06VerticalPairScrambler scrambler;
  final GeneratedStageFactory generatedStageFactory;

  bool supports(StageSpec stageSpec) {
    return solutionFactory.supports(stageSpec);
  }

  GeneratedStage create({
    required StageSpec stageSpec,
    required int fallbackAttempt,
  }) {
    if (fallbackAttempt < 1) {
      throw ArgumentError.value(
        fallbackAttempt,
        'fallbackAttempt',
        '1 이상이어야 합니다.',
      );
    }
    if (!supports(stageSpec)) {
      throw UnsupportedError('T06 fallback does not support this StageSpec.');
    }
    final fallbackKey = StageGenerationKey(
      generatorVersion: stageSpec.generatorVersion,
      level: stageSpec.level,
      attempt: fallbackAttempt,
    );
    final fallbackSeed = seedFactory.create(fallbackKey);
    final solution = solutionFactory.createFallback(
      stageSpec,
      fallbackSeed: fallbackSeed,
    );
    final clues = clueFactory.create(solution);
    final scrambleResult = scrambler.create(
      solution: solution,
      clues: clues,
      generationSeed: fallbackSeed,
      priorityCycles: _fallbackCycles(stageSpec),
    );
    return generatedStageFactory.create(
      scrambleResult: scrambleResult,
      clues: clues,
      generationAttemptKey: fallbackKey,
      generationAttemptSeed: fallbackSeed,
      isFallback: true,
    );
  }

  List<List<int>> _fallbackCycles(StageSpec stageSpec) {
    return switch ((
      stageSpec.tierCount,
      stageSpec.booksPerTier,
      stageSpec.targetSwapCount,
    )) {
      (2, 6, 6) => const [
        [0, 6, 1, 7, 4, 10, 5],
      ],
      (2, 6, 7) => const [
        [0, 6, 1, 7, 4, 10, 5, 11],
      ],
      (3, 4, 7) => const [
        [0, 4, 8, 1, 5, 9, 3, 7],
      ],
      (3, 4, 8) => const [
        [0, 4, 8, 1, 5, 9, 3, 7, 11],
      ],
      _ => const [],
    };
  }
}
