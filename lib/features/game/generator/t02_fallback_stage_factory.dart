import '../domain/book.dart';
import '../domain/book_placement.dart';
import '../domain/book_position.dart';
import 'book_catalog.dart';
import 'book_instance_code.dart';
import 'book_swap_step.dart';
import 'generated_stage.dart';
import 'generated_stage_factory.dart';
import 'puzzle_template_id.dart';
import 'stage_generation_key.dart';
import 'stage_seed_factory.dart';
import 'stage_spec.dart';
import 't02_edge_sandwich_clue_factory.dart';
import 't02_edge_sandwich_scrambler.dart';
import 'template_scramble_result.dart';
import 'template_solution.dart';

class T02FallbackStageFactory {
  const T02FallbackStageFactory({
    this.seedFactory = const StageSeedFactory(),
    this.clueFactory = const T02EdgeSandwichClueFactory(),
    this.scrambler = const T02EdgeSandwichScrambler(),
    this.generatedStageFactory = const GeneratedStageFactory(),
  });

  final StageSeedFactory seedFactory;
  final T02EdgeSandwichClueFactory clueFactory;
  final T02EdgeSandwichScrambler scrambler;
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
      throw UnsupportedError('T02 fallback does not support this StageSpec.');
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
      templateId: PuzzleTemplateId.t02EdgeSandwich,
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
    final edgeColorIndex = fallbackSeed % BookCatalog.canonicalColors.length;
    final duplicateColorIndex =
        (edgeColorIndex + 1) % BookCatalog.canonicalColors.length;
    final fillerAColorIndex =
        (edgeColorIndex + 2) % BookCatalog.canonicalColors.length;
    final fillerBColorIndex =
        (edgeColorIndex + 3) % BookCatalog.canonicalColors.length;
    final edgeLeftSymbolIndex =
        (fallbackSeed >> 8) % BookCatalog.canonicalSymbols.length;
    final edgeRightSymbolIndex =
        (edgeLeftSymbolIndex + 1) % BookCatalog.canonicalSymbols.length;
    final duplicateSymbolIndex =
        (fallbackSeed >> 16) % BookCatalog.canonicalSymbols.length;
    final fillerASymbolIndex =
        (fallbackSeed >> 4) % BookCatalog.canonicalSymbols.length;
    final fillerBSymbolIndex =
        (fallbackSeed >> 12) % BookCatalog.canonicalSymbols.length;

    final edgeColor = BookCatalog.canonicalColors[edgeColorIndex];
    final duplicateColor = BookCatalog.canonicalColors[duplicateColorIndex];
    final fillerAColor = BookCatalog.canonicalColors[fillerAColorIndex];
    final fillerBColor = BookCatalog.canonicalColors[fillerBColorIndex];
    final edgeLeftSymbol = BookCatalog.canonicalSymbols[edgeLeftSymbolIndex];
    final edgeRightSymbol = BookCatalog.canonicalSymbols[edgeRightSymbolIndex];
    final duplicateSymbol = BookCatalog.canonicalSymbols[duplicateSymbolIndex];
    final fillerASymbol = BookCatalog.canonicalSymbols[fillerASymbolIndex];
    final fillerBSymbol = BookCatalog.canonicalSymbols[fillerBSymbolIndex];

    final edgeLeft = _book(edgeColor, edgeLeftSymbol);
    final edgeRight = _book(edgeColor, edgeRightSymbol);
    final fillerA = _book(fillerAColor, fillerASymbol);
    final fillerB = _book(fillerBColor, fillerBSymbol);
    final duplicateCopy01 = _copyBook(duplicateColor, duplicateSymbol, 1);
    final duplicateCopy02 = _copyBook(duplicateColor, duplicateSymbol, 2);

    return [
      edgeLeft,
      fillerA,
      fillerB,
      duplicateCopy01,
      duplicateCopy02,
      edgeRight,
    ];
  }

  TemplateScrambleResult _createScrambleResult({
    required TemplateSolution solution,
    required int fallbackSeed,
  }) {
    final cycleSlots = switch (solution.stageSpec.targetSwapCount) {
      3 => const [0, 1, 2, 3],
      4 => const [0, 1, 2, 3, 5],
      _ => throw StateError('T02 fallback targetSwapCount is unsupported.'),
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
      id: '${_colorCode(color)}_${_symbolCode(symbol)}',
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

  String _colorCode(BookColor color) {
    return switch (color) {
      BookColor.blue => 'blue',
      BookColor.red => 'red',
      BookColor.yellow => 'yellow',
      BookColor.green => 'green',
      BookColor.purple => 'purple',
      BookColor.orange => 'orange',
    };
  }

  String _symbolCode(BookSymbol symbol) {
    return switch (symbol) {
      BookSymbol.moon => 'moon',
      BookSymbol.star => 'star',
      BookSymbol.cloud => 'cloud',
      BookSymbol.key => 'key',
      BookSymbol.leaf => 'leaf',
      BookSymbol.drop => 'drop',
      BookSymbol.sun => 'sun',
      BookSymbol.diamond => 'diamond',
    };
  }
}
