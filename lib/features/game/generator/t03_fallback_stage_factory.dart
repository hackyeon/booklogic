import '../domain/book.dart';
import '../domain/book_placement.dart';
import '../domain/book_position.dart';
import 'book_catalog.dart';
import 'book_code.dart';
import 'book_instance_code.dart';
import 'book_swap_step.dart';
import 'generated_stage.dart';
import 'generated_stage_factory.dart';
import 'puzzle_template_id.dart';
import 'stage_generation_key.dart';
import 'stage_seed_factory.dart';
import 'stage_spec.dart';
import 't03_adjacent_blocks_clue_factory.dart';
import 't03_adjacent_blocks_scrambler.dart';
import 'template_scramble_result.dart';
import 'template_solution.dart';

class T03FallbackStageFactory {
  const T03FallbackStageFactory({
    this.seedFactory = const StageSeedFactory(),
    this.clueFactory = const T03AdjacentBlocksClueFactory(),
    this.scrambler = const T03AdjacentBlocksScrambler(),
    this.generatedStageFactory = const GeneratedStageFactory(),
  });

  final StageSeedFactory seedFactory;
  final T03AdjacentBlocksClueFactory clueFactory;
  final T03AdjacentBlocksScrambler scrambler;
  final GeneratedStageFactory generatedStageFactory;

  bool supports(StageSpec stageSpec) {
    return stageSpec.tierCount == 1 &&
        stageSpec.booksPerTier == 6 &&
        stageSpec.totalBookCount == 6 &&
        stageSpec.duplicateGroupCount == 1 &&
        stageSpec.maxDuplicateCopies >= 2 &&
        stageSpec.clueCount >= 4 &&
        stageSpec.clueCount <= 5 &&
        stageSpec.targetSwapCount >= 3 &&
        stageSpec.targetSwapCount <= 4;
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
      throw UnsupportedError('T03 fallback does not support this StageSpec.');
    }

    final fallbackKey = StageGenerationKey(
      generatorVersion: stageSpec.generatorVersion,
      level: stageSpec.level,
      attempt: fallbackAttempt,
    );
    final fallbackSeed = seedFactory.create(fallbackKey);
    final targetBooks = _selectTargetBooks(fallbackSeed);
    final targetPlacements = [
      for (var slotIndex = 0; slotIndex < targetBooks.length; slotIndex += 1)
        BookPlacement(
          book: targetBooks[slotIndex],
          position: BookPosition(tierIndex: 0, slotIndex: slotIndex),
        ),
    ];
    final solution = TemplateSolution(
      stageSpec: stageSpec,
      templateId: PuzzleTemplateId.t03AdjacentBlocks,
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

  List<Book> _selectTargetBooks(int fallbackSeed) {
    final baseColorIndex = fallbackSeed % BookCatalog.canonicalColors.length;
    final blockAFirstColor = BookCatalog.canonicalColors[baseColorIndex];
    final blockAMiddleColor =
        BookCatalog.canonicalColors[(baseColorIndex + 1) %
            BookCatalog.canonicalColors.length];
    final blockALastColor =
        BookCatalog.canonicalColors[(baseColorIndex + 2) %
            BookCatalog.canonicalColors.length];
    final duplicateColor =
        BookCatalog.canonicalColors[(baseColorIndex + 3) %
            BookCatalog.canonicalColors.length];
    final blockBEndColor =
        BookCatalog.canonicalColors[(baseColorIndex + 4) %
            BookCatalog.canonicalColors.length];

    final blockAFirstSymbol = BookCatalog
        .canonicalSymbols[fallbackSeed % BookCatalog.canonicalSymbols.length];
    final blockAMiddleSymbol =
        BookCatalog.canonicalSymbols[(fallbackSeed >> 5) %
            BookCatalog.canonicalSymbols.length];
    final blockALastSymbol =
        BookCatalog.canonicalSymbols[(fallbackSeed >> 10) %
            BookCatalog.canonicalSymbols.length];
    final duplicateSymbol =
        BookCatalog.canonicalSymbols[(fallbackSeed >> 15) %
            BookCatalog.canonicalSymbols.length];
    final blockBEndSymbol =
        BookCatalog.canonicalSymbols[(fallbackSeed >> 20) %
            BookCatalog.canonicalSymbols.length];

    return [
      _book(blockAFirstColor, blockAFirstSymbol),
      _book(blockAMiddleColor, blockAMiddleSymbol),
      _book(blockALastColor, blockALastSymbol),
      _copyBook(duplicateColor, duplicateSymbol, 1),
      _copyBook(duplicateColor, duplicateSymbol, 2),
      _book(blockBEndColor, blockBEndSymbol),
    ];
  }

  TemplateScrambleResult _createScrambleResult({
    required TemplateSolution solution,
    required int fallbackSeed,
  }) {
    final cycleSlots = switch (solution.stageSpec.targetSwapCount) {
      3 => const [0, 1, 3, 5],
      4 => const [0, 1, 2, 3, 5],
      _ => throw StateError('T03 fallback targetSwapCount is unsupported.'),
    };
    final workingBooks = [
      for (final placement in solution.targetPlacements) placement.book,
    ];
    final swapHistory = <BookSwapStep>[];
    final pivotSlot = cycleSlots.first;
    for (var index = 1; index < cycleSlots.length; index += 1) {
      final otherSlot = cycleSlots[index];
      final firstBook = workingBooks[pivotSlot];
      final secondBook = workingBooks[otherSlot];
      swapHistory.add(
        BookSwapStep(
          stepIndex: swapHistory.length,
          firstPosition: BookPosition(tierIndex: 0, slotIndex: pivotSlot),
          secondPosition: BookPosition(tierIndex: 0, slotIndex: otherSlot),
          firstBookIdBeforeSwap: firstBook.id,
          secondBookIdBeforeSwap: secondBook.id,
        ),
      );
      workingBooks[pivotSlot] = secondBook;
      workingBooks[otherSlot] = firstBook;
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
      scrambleSeed: scrambler.createScrambleSeed(fallbackSeed),
      initialPlacements: initialPlacements,
      swapHistory: swapHistory,
    );
  }

  Book _book(BookColor color, BookSymbol symbol) {
    return Book(
      id: BookCode.bookId(color: color, symbol: symbol),
      color: color,
      symbol: symbol,
    );
  }

  Book _copyBook(BookColor color, BookSymbol symbol, int copyNumber) {
    return Book(
      id: BookInstanceCode.duplicateCopyId(
        color: color,
        symbol: symbol,
        copyNumber: copyNumber,
      ),
      color: color,
      symbol: symbol,
    );
  }
}
