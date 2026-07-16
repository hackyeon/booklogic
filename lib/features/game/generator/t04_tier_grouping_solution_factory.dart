import '../domain/book.dart';
import '../domain/book_placement.dart';
import '../domain/book_position.dart';
import 'book_catalog.dart';
import 'book_instance_code.dart';
import 'deterministic_random.dart';
import 'generator_config.dart';
import 'puzzle_template_id.dart';
import 'stage_spec.dart';
import 't04_tier_grouping_support.dart';
import 'template_solution.dart';

class T04TierGroupingSolutionFactory {
  const T04TierGroupingSolutionFactory({this.catalog = const BookCatalog()});

  final BookCatalog catalog;

  bool supports(StageSpec spec) {
    return spec.tierCount == 2 &&
        spec.booksPerTier == 4 &&
        spec.totalBookCount == 8 &&
        (spec.duplicateGroupCount == 0 || spec.duplicateGroupCount == 1) &&
        spec.maxDuplicateCopies >= 2 &&
        spec.clueCount >= 4 &&
        spec.clueCount <= 6 &&
        spec.targetSwapCount >= 3 &&
        spec.targetSwapCount <= 5;
  }

  TemplateSolution create(StageSpec spec, {int? generationSeed}) {
    if (!supports(spec)) {
      throw StateError('T04 Tier Grouping does not support this StageSpec.');
    }

    final effectiveSeed = generationSeed ?? spec.seed;
    if (effectiveSeed <= 0 || effectiveSeed > GeneratorConfig.uint32Mask) {
      throw ArgumentError.value(
        effectiveSeed,
        'generationSeed',
        '1부터 ${GeneratorConfig.uint32Mask} 사이여야 합니다.',
      );
    }

    final random = DeterministicRandom(effectiveSeed);
    final shuffledBooks = random.shuffled(catalog.books);
    final topEdgeLeft = shuffledBooks.first;
    final topEdgeRight = _firstWhere(
      shuffledBooks,
      (book) =>
          book.color == topEdgeLeft.color && book.symbol != topEdgeLeft.symbol,
      'T04 topEdgeRight',
    );
    final topMiddleBase = _firstWhere(
      shuffledBooks,
      (book) => book.color != topEdgeLeft.color,
      'T04 topMiddleBase',
    );
    final bottomEdgeLeft = _firstWhere(
      shuffledBooks,
      (book) =>
          book.color != topEdgeLeft.color && book.color != topMiddleBase.color,
      'T04 bottomEdgeLeft',
    );
    final bottomEdgeRight = _firstWhere(
      shuffledBooks,
      (book) =>
          book.color == bottomEdgeLeft.color &&
          book.symbol != bottomEdgeLeft.symbol,
      'T04 bottomEdgeRight',
    );
    final bottomInnerLeft = _firstWhere(
      shuffledBooks,
      (book) =>
          book.color != topEdgeLeft.color &&
          book.color != topMiddleBase.color &&
          book.color != bottomEdgeLeft.color,
      'T04 bottomInnerLeft',
    );
    final bottomInnerRight = _firstWhere(
      shuffledBooks,
      (book) =>
          book.color != topEdgeLeft.color &&
          book.color != topMiddleBase.color &&
          book.color != bottomEdgeLeft.color &&
          book.color != bottomInnerLeft.color,
      'T04 bottomInnerRight',
    );

    final (topMiddleLeft, topMiddleRight) = switch (spec.duplicateGroupCount) {
      0 => (
        topMiddleBase,
        _firstWhere(
          shuffledBooks,
          (book) =>
              book.color == topMiddleBase.color &&
              book.symbol != topMiddleBase.symbol,
          'T04 topMiddleRight',
        ),
      ),
      1 => (_copyOf(topMiddleBase, 1), _copyOf(topMiddleBase, 2)),
      _ => throw StateError('T04 duplicateGroupCount is unsupported.'),
    };

    final targetBooks = [
      topEdgeLeft,
      topMiddleLeft,
      topMiddleRight,
      topEdgeRight,
      bottomEdgeLeft,
      bottomInnerLeft,
      bottomInnerRight,
      bottomEdgeRight,
    ];
    final targetPlacements = [
      for (var index = 0; index < targetBooks.length; index += 1)
        BookPlacement(
          book: targetBooks[index],
          position: BookPosition(
            tierIndex: index ~/ spec.booksPerTier,
            slotIndex: index % spec.booksPerTier,
          ),
        ),
    ];
    final solution = TemplateSolution(
      stageSpec: spec,
      templateId: PuzzleTemplateId.t04TierGrouping,
      targetPlacements: targetPlacements,
    );
    _validateSolution(solution);
    return solution;
  }

  Book _copyOf(Book base, int copyNumber) {
    return Book(
      id: BookInstanceCode.duplicateCopyId(
        color: base.color,
        symbol: base.symbol,
        copyNumber: copyNumber,
      ),
      color: base.color,
      symbol: base.symbol,
    );
  }

  Book _firstWhere(
    List<Book> books,
    bool Function(Book book) predicate,
    String label,
  ) {
    for (final book in books) {
      if (predicate(book)) {
        return book;
      }
    }
    throw StateError('$label could not be selected.');
  }

  void _validateSolution(TemplateSolution solution) {
    if (solution.templateId != PuzzleTemplateId.t04TierGrouping) {
      throw StateError('T04 solution has an invalid templateId.');
    }
    if (!supports(solution.stageSpec) ||
        solution.targetPlacements.length != solution.stageSpec.totalBookCount) {
      throw StateError('T04 target count does not match StageSpec.');
    }
    if (T04TierGroupingShape.fromPlacements(
          solution.targetPlacements,
          duplicateGroupCount: solution.stageSpec.duplicateGroupCount,
        ) ==
        null) {
      throw StateError('T04 target structure is invalid.');
    }
  }
}
