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
import 't05_tier_order_clue_factory.dart';
import 't05_tier_order_scrambler.dart';
import 'template_scramble_result.dart';
import 'template_solution.dart';

class T05FallbackStageFactory {
  const T05FallbackStageFactory({
    this.seedFactory = const StageSeedFactory(),
    this.clueFactory = const T05TierOrderClueFactory(),
    this.scrambler = const T05TierOrderScrambler(),
    this.generatedStageFactory = const GeneratedStageFactory(),
  });

  final StageSeedFactory seedFactory;
  final T05TierOrderClueFactory clueFactory;
  final T05TierOrderScrambler scrambler;
  final GeneratedStageFactory generatedStageFactory;

  bool supports(StageSpec stageSpec) {
    return stageSpec.level >= 101 &&
        stageSpec.level <= 200 &&
        stageSpec.tierCount == 2 &&
        stageSpec.booksPerTier == 5 &&
        stageSpec.totalBookCount == 10 &&
        (stageSpec.duplicateGroupCount == 1 ||
            stageSpec.duplicateGroupCount == 2) &&
        stageSpec.maxDuplicateCopies >= 2 &&
        stageSpec.clueCount >= 5 &&
        stageSpec.clueCount <= 7 &&
        stageSpec.targetSwapCount >= 4 &&
        stageSpec.targetSwapCount <= 6;
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
      throw UnsupportedError('T05 fallback does not support this StageSpec.');
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
      templateId: PuzzleTemplateId.t05TierOrder,
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
    final topBlockColor =
        BookCatalog.canonicalColors[(baseColorIndex + 1) %
            BookCatalog.canonicalColors.length];
    final topCenterColor =
        BookCatalog.canonicalColors[(baseColorIndex + 2) %
            BookCatalog.canonicalColors.length];
    final bottomEdgeColor =
        BookCatalog.canonicalColors[(baseColorIndex + 3) %
            BookCatalog.canonicalColors.length];
    final bottomBlockColor =
        BookCatalog.canonicalColors[(baseColorIndex + 4) %
            BookCatalog.canonicalColors.length];
    final bottomCenterColor =
        BookCatalog.canonicalColors[(baseColorIndex + 5) %
            BookCatalog.canonicalColors.length];

    final topEdgeLeftSymbol = BookCatalog
        .canonicalSymbols[fallbackSeed % BookCatalog.canonicalSymbols.length];
    final topEdgeRightSymbol =
        BookCatalog.canonicalSymbols[(BookCatalog.canonicalSymbols.indexOf(
                  topEdgeLeftSymbol,
                ) +
                1) %
            BookCatalog.canonicalSymbols.length];
    final topBlockSymbol =
        BookCatalog.canonicalSymbols[(fallbackSeed >> 4) %
            BookCatalog.canonicalSymbols.length];
    final topCenterSymbol =
        BookCatalog.canonicalSymbols[(fallbackSeed >> 8) %
            BookCatalog.canonicalSymbols.length];
    final bottomEdgeLeftSymbol =
        BookCatalog.canonicalSymbols[(fallbackSeed >> 12) %
            BookCatalog.canonicalSymbols.length];
    final bottomEdgeRightSymbol =
        BookCatalog.canonicalSymbols[(BookCatalog.canonicalSymbols.indexOf(
                  bottomEdgeLeftSymbol,
                ) +
                1) %
            BookCatalog.canonicalSymbols.length];
    final bottomBlockSymbol =
        BookCatalog.canonicalSymbols[(fallbackSeed >> 16) %
            BookCatalog.canonicalSymbols.length];
    final bottomCenterSymbol =
        BookCatalog.canonicalSymbols[(fallbackSeed >> 20) %
            BookCatalog.canonicalSymbols.length];

    final topBlockLeft = _copyBook(topBlockColor, topBlockSymbol, 1);
    final topBlockRight = _copyBook(topBlockColor, topBlockSymbol, 2);
    final (bottomBlockLeft, bottomBlockRight) = switch (duplicateGroupCount) {
      1 => (
        _book(bottomBlockColor, bottomBlockSymbol),
        _book(
          bottomBlockColor,
          BookCatalog.canonicalSymbols[(BookCatalog.canonicalSymbols.indexOf(
                    bottomBlockSymbol,
                  ) +
                  1) %
              BookCatalog.canonicalSymbols.length],
        ),
      ),
      2 => (
        _copyBook(bottomBlockColor, bottomBlockSymbol, 1),
        _copyBook(bottomBlockColor, bottomBlockSymbol, 2),
      ),
      _ => throw StateError('T05 fallback duplicateGroupCount unsupported.'),
    };

    return [
      _book(topEdgeColor, topEdgeLeftSymbol),
      topBlockLeft,
      topBlockRight,
      _book(topCenterColor, topCenterSymbol),
      _book(topEdgeColor, topEdgeRightSymbol),
      _book(bottomEdgeColor, bottomEdgeLeftSymbol),
      bottomBlockLeft,
      bottomBlockRight,
      _book(bottomCenterColor, bottomCenterSymbol),
      _book(bottomEdgeColor, bottomEdgeRightSymbol),
    ];
  }

  TemplateScrambleResult _createScrambleResult({
    required TemplateSolution solution,
    required int fallbackSeed,
  }) {
    final cycleSlots = switch (solution.stageSpec.targetSwapCount) {
      4 => const [0, 5, 1, 6, 3],
      5 => const [0, 5, 1, 6, 3, 8],
      6 => const [0, 5, 1, 6, 3, 8, 4],
      _ => throw StateError('T05 fallback targetSwapCount is unsupported.'),
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
