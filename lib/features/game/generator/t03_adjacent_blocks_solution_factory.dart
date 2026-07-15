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

class T03AdjacentBlocksSolutionFactory {
  const T03AdjacentBlocksSolutionFactory({this.catalog = const BookCatalog()});

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
      throw StateError('T03 Adjacent Blocks does not support this StageSpec.');
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
    final blockAFirst = shuffledBooks.first;
    final blockAMiddle = _firstWhere(
      shuffledBooks,
      (book) => book.color != blockAFirst.color,
      'T03 blockAMiddle',
    );
    final blockALast = _firstWhere(
      shuffledBooks,
      (book) =>
          book.color != blockAFirst.color && book.color != blockAMiddle.color,
      'T03 blockALast',
    );
    final duplicateBase = _firstWhere(
      shuffledBooks,
      (book) =>
          book.color != blockAFirst.color &&
          book.color != blockAMiddle.color &&
          book.color != blockALast.color,
      'T03 duplicateBase',
    );
    final blockBEnd = _firstWhere(
      shuffledBooks,
      (book) =>
          book.color != blockAFirst.color &&
          book.color != blockAMiddle.color &&
          book.color != blockALast.color &&
          book.color != duplicateBase.color,
      'T03 blockBEnd',
    );

    final duplicateCopy01 = _copyOf(duplicateBase, 1);
    final duplicateCopy02 = _copyOf(duplicateBase, 2);
    final targetBooks = [
      blockAFirst,
      blockAMiddle,
      blockALast,
      duplicateCopy01,
      duplicateCopy02,
      blockBEnd,
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
      templateId: PuzzleTemplateId.t03AdjacentBlocks,
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
    if (solution.templateId != PuzzleTemplateId.t03AdjacentBlocks) {
      throw StateError('T03 solution has an invalid templateId.');
    }
    if (!supports(spec) || targetPlacements.length != 6) {
      throw StateError('T03 target count does not match StageSpec.');
    }

    final books = [for (final placement in targetPlacements) placement.book];
    final duplicateCopy01 = books[3];
    final duplicateCopy02 = books[4];

    if (_visualKey(duplicateCopy01) != _visualKey(duplicateCopy02) ||
        duplicateCopy01.id == duplicateCopy02.id) {
      throw StateError('T03 duplicate copies must share visual data only.');
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
      throw StateError('T03 duplicate copy ids are invalid.');
    }

    final bookIds = <String>{};
    final visualGroups = <String, int>{};
    final colorSet = <BookColor>{};
    final slotIndexes = <int>{};
    for (var index = 0; index < targetPlacements.length; index += 1) {
      final placement = targetPlacements[index];
      final book = placement.book;
      final position = placement.position;
      if (position.tierIndex != 0 || position.slotIndex != index) {
        throw StateError('T03 target must be a single ordered tier.');
      }
      if (!bookIds.add(book.id)) {
        throw StateError('T03 target contains duplicate Book.id.');
      }
      if (!BookInstanceCode.matchesBook(book)) {
        throw StateError('T03 target book id does not match visual data.');
      }
      slotIndexes.add(position.slotIndex);
      visualGroups.update(
        _visualKey(book),
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      colorSet.add(book.color);
    }
    if (slotIndexes.length != targetPlacements.length) {
      throw StateError('T03 target contains duplicate slots.');
    }
    final duplicateGroups = visualGroups.values.where((count) => count > 1);
    if (duplicateGroups.length != 1 || duplicateGroups.single != 2) {
      throw StateError('T03 target must contain one duplicate visual group.');
    }
    if (colorSet.length != 5) {
      throw StateError('T03 target must use five distinct colors.');
    }
    if (books[0].color == books[1].color ||
        books[0].color == books[2].color ||
        books[1].color == books[2].color ||
        books[5].color == books[0].color ||
        books[5].color == books[1].color ||
        books[5].color == books[2].color ||
        duplicateCopy01.color == books[0].color ||
        duplicateCopy01.color == books[1].color ||
        duplicateCopy01.color == books[2].color ||
        duplicateCopy01.color == books[5].color) {
      throw StateError('T03 target block colors are invalid.');
    }
  }

  String _visualKey(Book book) {
    return BookCode.bookId(color: book.color, symbol: book.symbol);
  }
}
