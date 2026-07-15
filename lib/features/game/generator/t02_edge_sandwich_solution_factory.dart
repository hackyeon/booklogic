import '../domain/book.dart';
import '../domain/book_placement.dart';
import '../domain/book_position.dart';
import 'book_catalog.dart';
import 'book_code.dart';
import 'book_instance_code.dart';
import 'deterministic_random.dart';
import 'generator_config.dart';
import 'puzzle_template_id.dart';
import 'stage_spec.dart';
import 'template_solution.dart';

class T02EdgeSandwichSolutionFactory {
  const T02EdgeSandwichSolutionFactory({this.catalog = const BookCatalog()});

  final BookCatalog catalog;

  bool supports(StageSpec spec) {
    return spec.tierCount == 1 &&
        spec.booksPerTier == 6 &&
        spec.totalBookCount == 6 &&
        spec.duplicateGroupCount == 1 &&
        spec.maxDuplicateCopies >= 2 &&
        spec.clueCount >= 4 &&
        spec.clueCount <= 5 &&
        spec.targetSwapCount >= 3 &&
        spec.targetSwapCount <= 4;
  }

  TemplateSolution create(StageSpec spec, {int? generationSeed}) {
    if (!supports(spec)) {
      throw StateError('T02 Edge Sandwich does not support this StageSpec.');
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
    final edgeLeft = shuffledBooks.first;
    final edgeRight = _firstWhere(
      shuffledBooks,
      (book) => book.color == edgeLeft.color && book.symbol != edgeLeft.symbol,
      'T02 edgeRight',
    );
    final duplicateBase = _firstWhere(
      shuffledBooks,
      (book) => book.color != edgeLeft.color,
      'T02 duplicateBase',
    );
    final fillerA = _firstWhere(
      shuffledBooks,
      (book) =>
          book.color != edgeLeft.color && book.color != duplicateBase.color,
      'T02 fillerA',
    );
    final fillerB = _firstWhere(
      shuffledBooks,
      (book) =>
          book.color != edgeLeft.color &&
          book.color != duplicateBase.color &&
          book.color != fillerA.color,
      'T02 fillerB',
    );

    final duplicateCopy01 = _copyOf(duplicateBase, 1);
    final duplicateCopy02 = _copyOf(duplicateBase, 2);
    final targetBooks = [
      edgeLeft,
      fillerA,
      fillerB,
      duplicateCopy01,
      duplicateCopy02,
      edgeRight,
    ];
    final targetPlacements = [
      for (var slotIndex = 0; slotIndex < targetBooks.length; slotIndex += 1)
        BookPlacement(
          book: targetBooks[slotIndex],
          position: BookPosition(tierIndex: 0, slotIndex: slotIndex),
        ),
    ];
    final solution = TemplateSolution(
      stageSpec: spec,
      templateId: PuzzleTemplateId.t02EdgeSandwich,
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
    final spec = solution.stageSpec;
    final targetPlacements = solution.targetPlacements;
    if (solution.templateId != PuzzleTemplateId.t02EdgeSandwich) {
      throw StateError('T02 solution has an invalid templateId.');
    }
    if (!supports(spec) || targetPlacements.length != 6) {
      throw StateError('T02 target count does not match StageSpec.');
    }

    final books = [for (final placement in targetPlacements) placement.book];
    final edgeLeft = books[0];
    final edgeRight = books[5];
    final duplicateCopy01 = books[3];
    final duplicateCopy02 = books[4];

    if (edgeLeft.color != edgeRight.color ||
        edgeLeft.symbol == edgeRight.symbol) {
      throw StateError('T02 edge books must share color and differ by symbol.');
    }
    if (_visualKey(duplicateCopy01) != _visualKey(duplicateCopy02)) {
      throw StateError('T02 duplicate copies must share color and symbol.');
    }
    if (duplicateCopy01.color == edgeLeft.color) {
      throw StateError('T02 duplicate color must differ from edge color.');
    }
    if (duplicateCopy01.id !=
            BookInstanceCode.duplicateCopyId(
              color: duplicateCopy01.color,
              symbol: duplicateCopy01.symbol,
              copyNumber: 1,
            ) ||
        duplicateCopy02.id !=
            BookInstanceCode.duplicateCopyId(
              color: duplicateCopy02.color,
              symbol: duplicateCopy02.symbol,
              copyNumber: 2,
            )) {
      throw StateError('T02 duplicate copy ids are invalid.');
    }

    final bookIds = <String>{};
    final visualGroups = <String, int>{};
    final slotIndexes = <int>{};
    for (var index = 0; index < targetPlacements.length; index += 1) {
      final placement = targetPlacements[index];
      final book = placement.book;
      final position = placement.position;
      if (position.tierIndex != 0 || position.slotIndex != index) {
        throw StateError('T02 target must be a single ordered tier.');
      }
      if (!bookIds.add(book.id)) {
        throw StateError('T02 target contains duplicate Book.id.');
      }
      if (!BookInstanceCode.matchesBook(book)) {
        throw StateError('T02 target book id does not match visual data.');
      }
      slotIndexes.add(position.slotIndex);
      visualGroups.update(
        _visualKey(book),
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    if (slotIndexes.length != targetPlacements.length) {
      throw StateError('T02 target contains duplicate slots.');
    }
    final duplicateGroups = visualGroups.values.where((count) => count > 1);
    if (duplicateGroups.length != 1 || duplicateGroups.single != 2) {
      throw StateError('T02 target must contain one duplicate visual group.');
    }
  }

  String _visualKey(Book book) {
    return BookCode.bookId(color: book.color, symbol: book.symbol);
  }
}
