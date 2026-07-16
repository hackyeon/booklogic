import '../domain/book.dart';
import '../domain/book_placement.dart';
import 'book_catalog.dart';
import 'book_code.dart';
import 'book_instance_code.dart';
import 'deterministic_random.dart';
import 'generator_config.dart';
import 'puzzle_template_id.dart';
import 'stage_spec.dart';
import 't06_layout_plan.dart';
import 'template_solution.dart';

class T06VerticalPairSolutionFactory {
  const T06VerticalPairSolutionFactory({this.catalog = const BookCatalog()});

  final BookCatalog catalog;

  bool supports(StageSpec spec) {
    return spec.generatorVersion == GeneratorConfig.generatorVersion2 &&
        spec.level >= 201 &&
        spec.level <= 400 &&
        spec.totalBookCount == 12 &&
        ((spec.tierCount == 2 && spec.booksPerTier == 6) ||
            (spec.tierCount == 3 && spec.booksPerTier == 4)) &&
        spec.duplicateGroupCount >= 1 &&
        spec.duplicateGroupCount <= 3 &&
        spec.maxDuplicateCopies == 2 &&
        spec.clueCount >= 6 &&
        spec.clueCount <= 8 &&
        spec.targetSwapCount >= 6 &&
        spec.targetSwapCount <= 8;
  }

  TemplateSolution create(StageSpec spec, {int? generationSeed}) {
    if (!supports(spec)) {
      throw StateError('T06 Vertical Pair does not support this StageSpec.');
    }
    final effectiveSeed = generationSeed ?? spec.seed;
    if (effectiveSeed <= 0 || effectiveSeed > GeneratorConfig.uint32Mask) {
      throw ArgumentError.value(
        effectiveSeed,
        'generationSeed',
        '1부터 ${GeneratorConfig.uint32Mask} 사이여야 합니다.',
      );
    }

    final plan = T06LayoutPlan.fromStageSpec(spec);
    final shuffledBooks = DeterministicRandom(
      effectiveSeed,
    ).shuffled(catalog.books);
    final requiredBaseCount = spec.totalBookCount - spec.duplicateGroupCount;
    final bases = shuffledBooks.take(requiredBaseCount).toList();
    return _createFromBases(spec: spec, plan: plan, bases: bases);
  }

  TemplateSolution createFallback(StageSpec spec, {required int fallbackSeed}) {
    if (!supports(spec)) {
      throw StateError('T06 Vertical Pair does not support this StageSpec.');
    }
    if (fallbackSeed <= 0 || fallbackSeed > GeneratorConfig.uint32Mask) {
      throw ArgumentError.value(
        fallbackSeed,
        'fallbackSeed',
        '1부터 ${GeneratorConfig.uint32Mask} 사이여야 합니다.',
      );
    }
    final plan = T06LayoutPlan.fromStageSpec(spec);
    final requiredBaseCount = spec.totalBookCount - spec.duplicateGroupCount;
    final books = catalog.books;
    final offset = fallbackSeed % books.length;
    final bases = [
      for (var index = 0; index < requiredBaseCount; index += 1)
        books[(offset + index) % books.length],
    ];
    return _createFromBases(spec: spec, plan: plan, bases: bases);
  }

  TemplateSolution _createFromBases({
    required StageSpec spec,
    required T06LayoutPlan plan,
    required List<Book> bases,
  }) {
    var baseIndex = 0;
    final placements = <BookPlacement>[];

    for (final position in plan.canonicalPositions) {
      if (plan.isSecondDuplicatePosition(position)) {
        continue;
      }
      final base = bases[baseIndex];
      baseIndex += 1;
      if (plan.isFirstDuplicatePosition(position)) {
        final first = _copyOf(base, 1);
        final second = _copyOf(base, 2);
        placements.add(BookPlacement(book: first, position: position));
        placements.add(
          BookPlacement(
            book: second,
            position: plan.duplicatePairSecond(position),
          ),
        );
      } else {
        placements.add(BookPlacement(book: base, position: position));
      }
    }

    placements.sort((left, right) {
      final tier = left.position.tierIndex.compareTo(right.position.tierIndex);
      if (tier != 0) {
        return tier;
      }
      return left.position.slotIndex.compareTo(right.position.slotIndex);
    });
    final solution = TemplateSolution(
      stageSpec: spec,
      templateId: PuzzleTemplateId.t06VerticalPair,
      targetPlacements: placements,
    );
    _validateSolution(solution, plan);
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

  void _validateSolution(TemplateSolution solution, T06LayoutPlan plan) {
    final spec = solution.stageSpec;
    if (solution.targetPlacements.length != 12) {
      throw StateError('T06 target must contain 12 books.');
    }
    final ids = <String>{};
    final visuals = <String, List<BookPlacement>>{};
    for (final placement in solution.targetPlacements) {
      if (!ids.add(placement.book.id)) {
        throw StateError('T06 target contains duplicate Book.id.');
      }
      final key = BookCode.bookId(
        color: placement.book.color,
        symbol: placement.book.symbol,
      );
      visuals.putIfAbsent(key, () => []).add(placement);
    }
    final duplicateGroups = visuals.values
        .where((placements) => placements.length > 1)
        .toList();
    if (duplicateGroups.length != spec.duplicateGroupCount ||
        duplicateGroups.any((placements) => placements.length != 2)) {
      throw StateError('T06 duplicate visual structure is invalid.');
    }
    final duplicatePositions = {
      for (final position in plan.duplicatePositionPairs)
        '${position.tierIndex}:${position.slotIndex}',
    };
    for (final group in duplicateGroups) {
      for (final placement in group) {
        final key =
            '${placement.position.tierIndex}:${placement.position.slotIndex}';
        if (!duplicatePositions.contains(key) ||
            !BookInstanceCode.matchesBook(placement.book)) {
          throw StateError('T06 duplicate placement is invalid.');
        }
      }
    }
    for (final placement in solution.targetPlacements) {
      if (plan.verticalAnchorColumns.contains(placement.position.slotIndex)) {
        final key = BookCode.bookId(
          color: placement.book.color,
          symbol: placement.book.symbol,
        );
        if ((visuals[key]?.length ?? 0) != 1) {
          throw StateError('T06 anchor columns must be visually unique.');
        }
      }
    }
  }
}
