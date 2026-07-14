import '../domain/book.dart';
import '../domain/book_placement.dart';
import '../domain/book_position.dart';
import 'book_catalog.dart';
import 'book_swap_step.dart';
import 'generated_stage.dart';
import 'generated_stage_factory.dart';
import 'generator_config.dart';
import 'puzzle_template_id.dart';
import 'stage_generation_key.dart';
import 'stage_seed_factory.dart';
import 'stage_spec.dart';
import 't01_anchor_chain_clue_factory.dart';
import 'template_scramble_result.dart';
import 'template_solution.dart';

class T01FallbackStageFactory {
  const T01FallbackStageFactory({
    this.seedFactory = const StageSeedFactory(),
    this.catalog = const BookCatalog(),
    this.clueFactory = const T01AnchorChainClueFactory(),
    this.generatedStageFactory = const GeneratedStageFactory(),
  });

  final StageSeedFactory seedFactory;
  final BookCatalog catalog;
  final T01AnchorChainClueFactory clueFactory;
  final GeneratedStageFactory generatedStageFactory;

  bool supports(StageSpec stageSpec) {
    return stageSpec.tierCount == 1 &&
        (stageSpec.booksPerTier == 4 || stageSpec.booksPerTier == 5) &&
        (stageSpec.totalBookCount == 4 || stageSpec.totalBookCount == 5) &&
        stageSpec.duplicateGroupCount == 0 &&
        stageSpec.clueCount >= 2 &&
        stageSpec.clueCount <= stageSpec.totalBookCount - 1 &&
        stageSpec.targetSwapCount >= 1 &&
        stageSpec.targetSwapCount <= stageSpec.totalBookCount - 1;
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
      throw UnsupportedError('T01 fallback does not support this StageSpec.');
    }

    final fallbackKey = StageGenerationKey(
      generatorVersion: stageSpec.generatorVersion,
      level: stageSpec.level,
      attempt: fallbackAttempt,
    );
    final fallbackSeed = seedFactory.create(fallbackKey);
    final selectedBooks = _selectBooks(
      fallbackSeed: fallbackSeed,
      totalBookCount: stageSpec.totalBookCount,
    );
    final targetPlacements = [
      for (var slotIndex = 0; slotIndex < selectedBooks.length; slotIndex += 1)
        BookPlacement(
          book: selectedBooks[slotIndex],
          position: BookPosition(tierIndex: 0, slotIndex: slotIndex),
        ),
    ];
    final solution = TemplateSolution(
      stageSpec: stageSpec,
      templateId: PuzzleTemplateId.t01AnchorChain,
      targetPlacements: targetPlacements,
    );
    final clues = clueFactory.create(solution);
    final scrambleResult = _createScrambleResult(
      solution: solution,
      fallbackSeed: fallbackSeed,
    );
    return generatedStageFactory.create(
      scrambleResult: scrambleResult,
      clues: clues,
      generationAttemptKey: fallbackKey,
      generationAttemptSeed: fallbackSeed,
      isFallback: true,
    );
  }

  List<Book> _selectBooks({
    required int fallbackSeed,
    required int totalBookCount,
  }) {
    final offset = fallbackSeed % catalog.books.length;
    return [
      for (var index = 0; index < totalBookCount; index += 1)
        catalog.books[(offset + index) % catalog.books.length],
    ];
  }

  TemplateScrambleResult _createScrambleResult({
    required TemplateSolution solution,
    required int fallbackSeed,
  }) {
    final workingBooks = [
      for (final placement in solution.targetPlacements) placement.book,
    ];
    final swapHistory = <BookSwapStep>[];

    for (
      var slotIndex = 1;
      slotIndex <= solution.stageSpec.targetSwapCount;
      slotIndex += 1
    ) {
      final firstBook = workingBooks[0];
      final secondBook = workingBooks[slotIndex];
      swapHistory.add(
        BookSwapStep(
          stepIndex: swapHistory.length,
          firstPosition: const BookPosition(tierIndex: 0, slotIndex: 0),
          secondPosition: BookPosition(tierIndex: 0, slotIndex: slotIndex),
          firstBookIdBeforeSwap: firstBook.id,
          secondBookIdBeforeSwap: secondBook.id,
        ),
      );
      workingBooks[0] = secondBook;
      workingBooks[slotIndex] = firstBook;
    }

    final initialPlacements = [
      for (var slotIndex = 0; slotIndex < workingBooks.length; slotIndex += 1)
        BookPlacement(
          book: workingBooks[slotIndex],
          position: BookPosition(tierIndex: 0, slotIndex: slotIndex),
        ),
    ];
    return TemplateScrambleResult(
      solution: solution,
      scrambleSeed: _createScrambleSeed(fallbackSeed),
      initialPlacements: initialPlacements,
      swapHistory: swapHistory,
    );
  }

  int _createScrambleSeed(int generationSeed) {
    final value =
        (generationSeed ^ GeneratorConfig.t01ScrambleSalt) &
        GeneratorConfig.uint32Mask;
    if (value == 0) {
      return GeneratorConfig.zeroSeedFallback;
    }
    return value;
  }
}
