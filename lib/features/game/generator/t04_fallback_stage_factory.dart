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
import 't04_tier_grouping_clue_factory.dart';
import 't04_tier_grouping_scrambler.dart';
import 'template_scramble_result.dart';
import 'template_solution.dart';

class T04FallbackStageFactory {
  const T04FallbackStageFactory({
    this.seedFactory = const StageSeedFactory(),
    this.clueFactory = const T04TierGroupingClueFactory(),
    this.scrambler = const T04TierGroupingScrambler(),
    this.generatedStageFactory = const GeneratedStageFactory(),
  });

  final StageSeedFactory seedFactory;
  final T04TierGroupingClueFactory clueFactory;
  final T04TierGroupingScrambler scrambler;
  final GeneratedStageFactory generatedStageFactory;

  bool supports(StageSpec stageSpec) {
    return stageSpec.tierCount == 2 &&
        stageSpec.booksPerTier == 4 &&
        stageSpec.totalBookCount == 8 &&
        (stageSpec.duplicateGroupCount == 0 ||
            stageSpec.duplicateGroupCount == 1) &&
        stageSpec.maxDuplicateCopies >= 2 &&
        stageSpec.clueCount >= 4 &&
        stageSpec.clueCount <= 6 &&
        stageSpec.targetSwapCount >= 3 &&
        stageSpec.targetSwapCount <= 5;
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
      throw UnsupportedError('T04 fallback does not support this StageSpec.');
    }

    final fallbackKey = StageGenerationKey(
      generatorVersion: stageSpec.generatorVersion,
      level: stageSpec.level,
      attempt: fallbackAttempt,
    );
    final fallbackSeed = seedFactory.create(fallbackKey);
    final targetBooks = _selectTargetBooks(
      fallbackSeed: fallbackSeed,
      duplicateGroupCount: stageSpec.duplicateGroupCount,
    );
    final targetPlacements = [
      for (var index = 0; index < targetBooks.length; index += 1)
        BookPlacement(
          book: targetBooks[index],
          position: BookPosition(
            tierIndex: index ~/ stageSpec.booksPerTier,
            slotIndex: index % stageSpec.booksPerTier,
          ),
        ),
    ];
    final solution = TemplateSolution(
      stageSpec: stageSpec,
      templateId: PuzzleTemplateId.t04TierGrouping,
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

  List<Book> _selectTargetBooks({
    required int fallbackSeed,
    required int duplicateGroupCount,
  }) {
    final baseColorIndex = fallbackSeed % BookCatalog.canonicalColors.length;
    final topEdgeColor = BookCatalog.canonicalColors[baseColorIndex];
    final topMiddleColor =
        BookCatalog.canonicalColors[(baseColorIndex + 1) %
            BookCatalog.canonicalColors.length];
    final bottomEdgeColor =
        BookCatalog.canonicalColors[(baseColorIndex + 2) %
            BookCatalog.canonicalColors.length];
    final bottomInnerLeftColor =
        BookCatalog.canonicalColors[(baseColorIndex + 3) %
            BookCatalog.canonicalColors.length];
    final bottomInnerRightColor =
        BookCatalog.canonicalColors[(baseColorIndex + 4) %
            BookCatalog.canonicalColors.length];

    final topEdgeLeftSymbol = BookCatalog
        .canonicalSymbols[fallbackSeed % BookCatalog.canonicalSymbols.length];
    final topEdgeRightSymbol =
        BookCatalog.canonicalSymbols[(BookCatalog.canonicalSymbols.indexOf(
                  topEdgeLeftSymbol,
                ) +
                1) %
            BookCatalog.canonicalSymbols.length];
    final topMiddleSymbol =
        BookCatalog.canonicalSymbols[(fallbackSeed >> 4) %
            BookCatalog.canonicalSymbols.length];
    final topMiddleRightSymbol =
        BookCatalog.canonicalSymbols[(BookCatalog.canonicalSymbols.indexOf(
                  topMiddleSymbol,
                ) +
                1) %
            BookCatalog.canonicalSymbols.length];
    final bottomEdgeLeftSymbol =
        BookCatalog.canonicalSymbols[(fallbackSeed >> 8) %
            BookCatalog.canonicalSymbols.length];
    final bottomEdgeRightSymbol =
        BookCatalog.canonicalSymbols[(BookCatalog.canonicalSymbols.indexOf(
                  bottomEdgeLeftSymbol,
                ) +
                1) %
            BookCatalog.canonicalSymbols.length];
    final bottomInnerLeftSymbol =
        BookCatalog.canonicalSymbols[(fallbackSeed >> 12) %
            BookCatalog.canonicalSymbols.length];
    final bottomInnerRightSymbol =
        BookCatalog.canonicalSymbols[(fallbackSeed >> 16) %
            BookCatalog.canonicalSymbols.length];

    final topMiddleBooks = switch (duplicateGroupCount) {
      0 => (
        _book(topMiddleColor, topMiddleSymbol),
        _book(topMiddleColor, topMiddleRightSymbol),
      ),
      1 => (
        _copyBook(topMiddleColor, topMiddleSymbol, 1),
        _copyBook(topMiddleColor, topMiddleSymbol, 2),
      ),
      _ => throw StateError('T04 fallback duplicateGroupCount unsupported.'),
    };

    return [
      _book(topEdgeColor, topEdgeLeftSymbol),
      topMiddleBooks.$1,
      topMiddleBooks.$2,
      _book(topEdgeColor, topEdgeRightSymbol),
      _book(bottomEdgeColor, bottomEdgeLeftSymbol),
      _book(bottomInnerLeftColor, bottomInnerLeftSymbol),
      _book(bottomInnerRightColor, bottomInnerRightSymbol),
      _book(bottomEdgeColor, bottomEdgeRightSymbol),
    ];
  }

  TemplateScrambleResult _createScrambleResult({
    required TemplateSolution solution,
    required int fallbackSeed,
  }) {
    final cycleSlots = switch (solution.stageSpec.targetSwapCount) {
      3 => const [0, 4, 1, 5],
      4 => const [0, 4, 1, 5, 2],
      5 => const [0, 4, 1, 5, 2, 6],
      _ => throw StateError('T04 fallback targetSwapCount is unsupported.'),
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
          firstPosition: _positionForFlatIndex(
            pivotSlot,
            solution.stageSpec.booksPerTier,
          ),
          secondPosition: _positionForFlatIndex(
            otherSlot,
            solution.stageSpec.booksPerTier,
          ),
          firstBookIdBeforeSwap: firstBook.id,
          secondBookIdBeforeSwap: secondBook.id,
        ),
      );
      workingBooks[pivotSlot] = secondBook;
      workingBooks[otherSlot] = firstBook;
    }

    final initialPlacements = [
      for (var index = 0; index < workingBooks.length; index += 1)
        BookPlacement(
          book: workingBooks[index],
          position: _positionForFlatIndex(
            index,
            solution.stageSpec.booksPerTier,
          ),
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

  BookPosition _positionForFlatIndex(int flatIndex, int booksPerTier) {
    return BookPosition(
      tierIndex: flatIndex ~/ booksPerTier,
      slotIndex: flatIndex % booksPerTier,
    );
  }
}
