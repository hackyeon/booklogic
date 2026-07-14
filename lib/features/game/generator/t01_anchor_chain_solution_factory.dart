import '../domain/book.dart';
import '../domain/book_placement.dart';
import '../domain/book_position.dart';
import 'book_catalog.dart';
import 'book_code.dart';
import 'deterministic_random.dart';
import 'generator_config.dart';
import 'puzzle_template_id.dart';
import 'stage_spec.dart';
import 'template_solution.dart';

class T01AnchorChainSolutionFactory {
  const T01AnchorChainSolutionFactory({this.catalog = const BookCatalog()});

  final BookCatalog catalog;

  bool supports(StageSpec spec) {
    return spec.tierCount == 1 &&
        spec.booksPerTier >= 4 &&
        spec.booksPerTier <= 6 &&
        spec.totalBookCount >= 4 &&
        spec.totalBookCount <= 6 &&
        spec.duplicateGroupCount == 0 &&
        spec.totalBookCount <= catalog.books.length;
  }

  TemplateSolution create(StageSpec spec, {int? generationSeed}) {
    if (!supports(spec)) {
      throw StateError('T01 Anchor Chain does not support this StageSpec.');
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
    final selectedBooks = shuffledBooks.take(spec.totalBookCount).toList();
    final targetPlacements = [
      for (var slotIndex = 0; slotIndex < selectedBooks.length; slotIndex += 1)
        BookPlacement(
          book: selectedBooks[slotIndex],
          position: BookPosition(tierIndex: 0, slotIndex: slotIndex),
        ),
    ];
    final solution = TemplateSolution(
      stageSpec: spec,
      templateId: PuzzleTemplateId.t01AnchorChain,
      targetPlacements: targetPlacements,
    );
    _validateSolution(solution);
    return solution;
  }

  void _validateSolution(TemplateSolution solution) {
    final spec = solution.stageSpec;
    final targetPlacements = solution.targetPlacements;
    if (solution.templateId != PuzzleTemplateId.t01AnchorChain) {
      throw StateError('T01 solution has an invalid templateId.');
    }
    if (targetPlacements.length != spec.totalBookCount) {
      throw StateError('T01 target count does not match StageSpec.');
    }
    if (targetPlacements.length < 4 || targetPlacements.length > 6) {
      throw StateError('T01 target count is outside 4..6.');
    }
    if (spec.totalBookCount > 18) {
      throw StateError('T01 StageSpec totalBookCount exceeds 18.');
    }

    final bookIds = <String>{};
    final visualKeys = <String>{};
    final positionKeys = <String>{};
    for (var index = 0; index < targetPlacements.length; index += 1) {
      final placement = targetPlacements[index];
      final position = placement.position;
      final book = placement.book;

      if (position.tierIndex != 0) {
        throw StateError('T01 target tierIndex must be 0.');
      }
      if (position.slotIndex != index) {
        throw StateError('T01 target slotIndex must match list order.');
      }
      if (!bookIds.add(book.id)) {
        throw StateError('T01 target contains duplicate book ids.');
      }
      final visualKey = _visualKey(book);
      if (!visualKeys.add(visualKey)) {
        throw StateError('T01 target contains duplicate visual books.');
      }
      final expectedBookId = BookCode.bookId(
        color: book.color,
        symbol: book.symbol,
      );
      if (book.id != expectedBookId) {
        throw StateError('T01 target book id does not match BookCode.');
      }
      final positionKey = '${position.tierIndex}:${position.slotIndex}';
      if (!positionKeys.add(positionKey)) {
        throw StateError('T01 target contains duplicate positions.');
      }
    }
  }

  String _visualKey(Book book) {
    return '${BookCode.color(book.color)}_${BookCode.symbol(book.symbol)}';
  }
}
