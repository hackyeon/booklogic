import '../domain/book.dart';
import '../domain/book_placement.dart';
import '../domain/book_position.dart';
import 'book_catalog.dart';
import 'book_instance_code.dart';
import 'deterministic_random.dart';
import 'generator_config.dart';
import 'puzzle_template_id.dart';
import 'stage_spec.dart';
import 't05_tier_order_support.dart';
import 'template_solution.dart';

class T05TierOrderSolutionFactory {
  const T05TierOrderSolutionFactory({this.catalog = const BookCatalog()});

  final BookCatalog catalog;

  bool supports(StageSpec spec) {
    return spec.level >= 101 &&
        spec.level <= 200 &&
        spec.tierCount == 2 &&
        spec.booksPerTier == 5 &&
        spec.totalBookCount == 10 &&
        (spec.duplicateGroupCount == 1 || spec.duplicateGroupCount == 2) &&
        spec.maxDuplicateCopies >= 2 &&
        spec.clueCount >= 5 &&
        spec.clueCount <= 7 &&
        spec.targetSwapCount >= 4 &&
        spec.targetSwapCount <= 6;
  }

  TemplateSolution create(StageSpec spec, {int? generationSeed}) {
    if (!supports(spec)) {
      throw StateError('T05 Tier Order does not support this StageSpec.');
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
      'T05 topEdgeRight',
    );
    final topBlockBase = _firstWhere(
      shuffledBooks,
      (book) => book.color != topEdgeLeft.color,
      'T05 topBlockBase',
    );
    final topCenter = _firstWhere(
      shuffledBooks,
      (book) =>
          book.color != topEdgeLeft.color && book.color != topBlockBase.color,
      'T05 topCenter',
    );
    final bottomEdgeLeft = _firstWhere(
      shuffledBooks,
      (book) =>
          book.color != topEdgeLeft.color &&
          book.color != topBlockBase.color &&
          book.color != topCenter.color,
      'T05 bottomEdgeLeft',
    );
    final bottomEdgeRight = _firstWhere(
      shuffledBooks,
      (book) =>
          book.color == bottomEdgeLeft.color &&
          book.symbol != bottomEdgeLeft.symbol,
      'T05 bottomEdgeRight',
    );
    final bottomBlockBase = _firstWhere(
      shuffledBooks,
      (book) =>
          book.color != topEdgeLeft.color &&
          book.color != topBlockBase.color &&
          book.color != topCenter.color &&
          book.color != bottomEdgeLeft.color,
      'T05 bottomBlockBase',
    );
    final bottomCenter = _firstWhere(
      shuffledBooks,
      (book) =>
          book.color != topEdgeLeft.color &&
          book.color != topBlockBase.color &&
          book.color != topCenter.color &&
          book.color != bottomEdgeLeft.color &&
          book.color != bottomBlockBase.color,
      'T05 bottomCenter',
    );

    final topBlockLeft = _copyOf(topBlockBase, 1);
    final topBlockRight = _copyOf(topBlockBase, 2);
    final (
      bottomBlockLeft,
      bottomBlockRight,
    ) = switch (spec.duplicateGroupCount) {
      1 => (
        bottomBlockBase,
        _firstWhere(
          shuffledBooks,
          (book) =>
              book.color == bottomBlockBase.color &&
              book.symbol != bottomBlockBase.symbol,
          'T05 bottomBlockRight',
        ),
      ),
      2 => (_copyOf(bottomBlockBase, 1), _copyOf(bottomBlockBase, 2)),
      _ => throw StateError('T05 duplicateGroupCount is unsupported.'),
    };

    final targetBooks = [
      topEdgeLeft,
      topBlockLeft,
      topBlockRight,
      topCenter,
      topEdgeRight,
      bottomEdgeLeft,
      bottomBlockLeft,
      bottomBlockRight,
      bottomCenter,
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
      templateId: PuzzleTemplateId.t05TierOrder,
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
    if (solution.templateId != PuzzleTemplateId.t05TierOrder) {
      throw StateError('T05 solution has an invalid templateId.');
    }
    if (!supports(solution.stageSpec) ||
        solution.targetPlacements.length != solution.stageSpec.totalBookCount) {
      throw StateError('T05 target count does not match StageSpec.');
    }
    if (T05TierOrderShape.fromPlacements(
          solution.targetPlacements,
          duplicateGroupCount: solution.stageSpec.duplicateGroupCount,
        ) ==
        null) {
      throw StateError('T05 target structure is invalid.');
    }
  }
}
