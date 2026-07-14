import 'package:flutter_test/flutter_test.dart';

import 'package:booklogic/features/game/domain/book.dart';
import 'package:booklogic/features/game/domain/book_placement.dart';
import 'package:booklogic/features/game/domain/book_position.dart';
import 'package:booklogic/features/game/generator/book_catalog.dart';
import 'package:booklogic/features/game/generator/book_code.dart';
import 'package:booklogic/features/game/generator/difficulty_profile.dart';
import 'package:booklogic/features/game/generator/puzzle_template_id.dart';
import 'package:booklogic/features/game/generator/stage_generation_key.dart';
import 'package:booklogic/features/game/generator/stage_layout.dart';
import 'package:booklogic/features/game/generator/stage_spec.dart';
import 'package:booklogic/features/game/generator/stage_spec_factory.dart';
import 'package:booklogic/features/game/generator/t01_anchor_chain_solution_factory.dart';
import 'package:booklogic/features/game/generator/template_solution.dart';

void main() {
  group('BookCode', () {
    test('maps colors and symbols to stable codes', () {
      expect(BookCode.color(BookColor.blue), 'blue');
      expect(BookCode.color(BookColor.red), 'red');
      expect(BookCode.color(BookColor.yellow), 'yellow');
      expect(BookCode.color(BookColor.green), 'green');
      expect(BookCode.color(BookColor.purple), 'purple');
      expect(BookCode.color(BookColor.orange), 'orange');

      expect(BookCode.symbol(BookSymbol.moon), 'moon');
      expect(BookCode.symbol(BookSymbol.star), 'star');
      expect(BookCode.symbol(BookSymbol.cloud), 'cloud');
      expect(BookCode.symbol(BookSymbol.key), 'key');
      expect(BookCode.symbol(BookSymbol.leaf), 'leaf');
      expect(BookCode.symbol(BookSymbol.drop), 'drop');
      expect(BookCode.symbol(BookSymbol.sun), 'sun');
      expect(BookCode.symbol(BookSymbol.diamond), 'diamond');
    });

    test('builds stable book ids without display text', () {
      final ids = [
        BookCode.bookId(color: BookColor.blue, symbol: BookSymbol.moon),
        BookCode.bookId(color: BookColor.red, symbol: BookSymbol.star),
        BookCode.bookId(color: BookColor.yellow, symbol: BookSymbol.key),
        BookCode.bookId(color: BookColor.green, symbol: BookSymbol.cloud),
        BookCode.bookId(color: BookColor.purple, symbol: BookSymbol.diamond),
        BookCode.bookId(color: BookColor.orange, symbol: BookSymbol.sun),
      ];

      expect(ids, [
        'blue_moon',
        'red_star',
        'yellow_key',
        'green_cloud',
        'purple_diamond',
        'orange_sun',
      ]);
      for (final id in ids) {
        expect(id, matches(RegExp(r'^[a-z]+_[a-z]+$')));
        expect(id.contains(' '), isFalse);
        expect(id.contains('-'), isFalse);
        expect(id.contains(RegExp(r'[A-Z]')), isFalse);
        expect(id.contains(RegExp(r'[가-힣]')), isFalse);
      }
    });
  });

  group('BookCatalog', () {
    test('contains the canonical color and symbol order', () {
      expect(BookCatalog.canonicalColors, const [
        BookColor.blue,
        BookColor.red,
        BookColor.yellow,
        BookColor.green,
        BookColor.purple,
        BookColor.orange,
      ]);
      expect(BookCatalog.canonicalSymbols, const [
        BookSymbol.moon,
        BookSymbol.star,
        BookSymbol.cloud,
        BookSymbol.key,
        BookSymbol.leaf,
        BookSymbol.drop,
        BookSymbol.sun,
        BookSymbol.diamond,
      ]);
    });

    test('contains 48 unique books in generator v1 order', () {
      final catalog = const BookCatalog();
      final books = catalog.books;

      expect(books, hasLength(48));
      expect(_ids(books), _catalogGoldenIds);
      expect(books.first, _book('blue_moon', BookColor.blue, BookSymbol.moon));
      expect(
        books[7],
        _book('blue_diamond', BookColor.blue, BookSymbol.diamond),
      );
      expect(books[8], _book('red_moon', BookColor.red, BookSymbol.moon));
      expect(
        books.last,
        _book('orange_diamond', BookColor.orange, BookSymbol.diamond),
      );
      expect(_ids(books).toSet(), hasLength(48));
      expect(_visualKeys(books).toSet(), hasLength(48));
    });

    test('has eight books per color and six books per symbol', () {
      final books = const BookCatalog().books;

      for (final color in BookCatalog.canonicalColors) {
        expect(books.where((book) => book.color == color), hasLength(8));
      }
      for (final symbol in BookCatalog.canonicalSymbols) {
        expect(books.where((book) => book.symbol == symbol), hasLength(6));
      }
    });

    test(
      'protects books from external mutation and repeated reads are stable',
      () {
        final catalog = const BookCatalog();
        final firstRead = catalog.books;
        final secondRead = catalog.books;

        expect(identical(firstRead, secondRead), isTrue);
        expect(_ids(firstRead), _catalogGoldenIds);
        expect(
          () => firstRead.add(_book('x', BookColor.blue, BookSymbol.moon)),
          throwsUnsupportedError,
        );
        expect(() => firstRead.remove(firstRead.first), throwsUnsupportedError);
        expect(() => firstRead.clear(), throwsUnsupportedError);
        expect(
          () => firstRead.sort((left, right) => left.id.compareTo(right.id)),
          throwsUnsupportedError,
        );
        expect(() => firstRead.shuffle(), throwsUnsupportedError);
        expect(_ids(catalog.books), _catalogGoldenIds);
      },
    );
  });

  group('TemplateSolution', () {
    test('stores fields, exposes books, and protects lists', () {
      final spec = _customSpec();
      final sourcePlacements = _placementsForIds(['blue_moon', 'red_star']);
      final solution = TemplateSolution(
        stageSpec: spec,
        templateId: PuzzleTemplateId.t01AnchorChain,
        targetPlacements: sourcePlacements,
      );

      sourcePlacements.add(
        BookPlacement(
          book: _book('yellow_key', BookColor.yellow, BookSymbol.key),
          position: const BookPosition(tierIndex: 0, slotIndex: 2),
        ),
      );

      expect(solution.stageSpec, spec);
      expect(solution.templateId, PuzzleTemplateId.t01AnchorChain);
      expect(solution.totalBookCount, 2);
      expect(_placementIds(solution.targetPlacements), [
        'blue_moon',
        'red_star',
      ]);
      expect(_ids(solution.books), ['blue_moon', 'red_star']);
      expect(
        () => solution.targetPlacements.add(sourcePlacements.last),
        throwsUnsupportedError,
      );
      expect(
        () => solution.targetPlacements.remove(solution.targetPlacements.first),
        throwsUnsupportedError,
      );
      expect(() => solution.targetPlacements.clear(), throwsUnsupportedError);
      expect(
        () => solution.books.add(sourcePlacements.last.book),
        throwsUnsupportedError,
      );
    });

    test(
      'compares target placement order and prints useful debugging data',
      () {
        final spec = _customSpec();
        final first = TemplateSolution(
          stageSpec: spec,
          templateId: PuzzleTemplateId.t01AnchorChain,
          targetPlacements: _placementsForIds(['blue_moon', 'red_star']),
        );
        final second = TemplateSolution(
          stageSpec: spec,
          templateId: PuzzleTemplateId.t01AnchorChain,
          targetPlacements: _placementsForIds(['blue_moon', 'red_star']),
        );
        final reversed = TemplateSolution(
          stageSpec: spec,
          templateId: PuzzleTemplateId.t01AnchorChain,
          targetPlacements: _placementsForIds(['red_star', 'blue_moon']),
        );

        expect(first, second);
        expect(first.hashCode, second.hashCode);
        expect(first, isNot(reversed));
        expect(first.toString(), contains('level: ${spec.level}'));
        expect(first.toString(), contains('PuzzleTemplateId.t01AnchorChain'));
        expect(first.toString(), contains('totalBookCount: 2'));
      },
    );
  });

  group('T01AnchorChainSolutionFactory supports', () {
    const stageSpecFactory = StageSpecFactory();
    const t01Factory = T01AnchorChainSolutionFactory();

    test('supports generated levels 1, 6, and 20 but rejects level 21', () {
      expect(t01Factory.supports(stageSpecFactory.create(level: 1)), isTrue);
      expect(t01Factory.supports(stageSpecFactory.create(level: 6)), isTrue);
      expect(t01Factory.supports(stageSpecFactory.create(level: 20)), isTrue);

      final level21Spec = stageSpecFactory.create(level: 21);

      expect(level21Spec.duplicateGroupCount, 1);
      expect(t01Factory.supports(level21Spec), isFalse);
      expect(() => t01Factory.create(level21Spec), throwsStateError);
    });

    test('accepts only one-tier unique-book specs', () {
      expect(
        t01Factory.supports(_customSpec(tierCount: 2, booksPerTier: 4)),
        isFalse,
      );
      expect(
        t01Factory.supports(_customSpec(tierCount: 3, booksPerTier: 4)),
        isFalse,
      );
      expect(t01Factory.supports(_customSpec(booksPerTier: 6)), isTrue);
      expect(
        t01Factory.supports(
          _customSpec(duplicateGroupCount: 1, maxDuplicateCopies: 2),
        ),
        isFalse,
      );
    });
  });

  group('T01AnchorChainSolutionFactory golden solutions', () {
    const stageSpecFactory = StageSpecFactory();
    const t01Factory = T01AnchorChainSolutionFactory();

    test('generator v1 target arrays remain stable', () {
      // If this fails, generated book selections or hidden target order changed.
      // Do not refresh expectations unless a new generatorVersion is introduced.
      _expectGoldenSolution(
        t01Factory.create(stageSpecFactory.create(level: 1)),
        ['red_key', 'blue_moon', 'blue_leaf', 'yellow_leaf'],
      );
      _expectGoldenSolution(
        t01Factory.create(stageSpecFactory.create(level: 6)),
        [
          'orange_moon',
          'yellow_drop',
          'blue_leaf',
          'yellow_moon',
          'yellow_star',
        ],
      );
      _expectGoldenSolution(
        t01Factory.create(stageSpecFactory.create(level: 20)),
        ['red_drop', 'yellow_sun', 'yellow_moon', 'blue_star', 'green_key'],
      );
    });

    test('is deterministic across repeated specs, factories, and catalogs', () {
      final spec = stageSpecFactory.create(level: 1);
      final first = t01Factory.create(spec);
      final secondFactory = const T01AnchorChainSolutionFactory();
      final thirdFactory = T01AnchorChainSolutionFactory(
        catalog: const BookCatalog(),
      );

      for (var index = 0; index < 100; index += 1) {
        expect(t01Factory.create(spec), first);
      }
      expect(secondFactory.create(spec), first);
      expect(thirdFactory.create(spec), first);
      expect(
        _placementIds(
          t01Factory.create(stageSpecFactory.create(level: 6)).targetPlacements,
        ),
        isNot(_placementIds(first.targetPlacements)),
      );
    });

    test('creates valid immutable solutions for levels 1 through 20', () {
      final catalog = const BookCatalog();
      final catalogIdsBefore = _ids(catalog.books);

      for (var level = 1; level <= 20; level += 1) {
        final spec = stageSpecFactory.create(level: level);
        final specBefore = spec;
        final solution = T01AnchorChainSolutionFactory(
          catalog: catalog,
        ).create(spec);

        expect(t01Factory.supports(spec), isTrue);
        _expectSolutionIntegrity(solution, catalog);
        expect(spec, specBefore);
        expect(_ids(catalog.books), catalogIdsBefore);
        for (final placement in solution.targetPlacements) {
          expect(
            placement.book.id,
            BookCode.bookId(
              color: placement.book.color,
              symbol: placement.book.symbol,
            ),
          );
        }
      }

      final level21Spec = stageSpecFactory.create(level: 21);

      expect(t01Factory.supports(level21Spec), isFalse);
      expect(() => t01Factory.create(level21Spec), throwsStateError);
    });
  });
}

Book _book(String id, BookColor color, BookSymbol symbol) {
  return Book(id: id, color: color, symbol: symbol);
}

List<String> _ids(Iterable<Book> books) {
  return [for (final book in books) book.id];
}

List<String> _placementIds(List<BookPlacement> placements) {
  return [for (final placement in placements) placement.book.id];
}

List<String> _visualKeys(Iterable<Book> books) {
  return [
    for (final book in books)
      '${BookCode.color(book.color)}_${BookCode.symbol(book.symbol)}',
  ];
}

List<BookPlacement> _placementsForIds(List<String> ids) {
  final catalog = const BookCatalog();
  return [
    for (var index = 0; index < ids.length; index += 1)
      BookPlacement(
        book: catalog.books.firstWhere((book) => book.id == ids[index]),
        position: BookPosition(tierIndex: 0, slotIndex: index),
      ),
  ];
}

StageSpec _customSpec({
  int tierCount = 1,
  int booksPerTier = 4,
  int duplicateGroupCount = 0,
  int maxDuplicateCopies = 1,
}) {
  return StageSpec(
    generationKey: const StageGenerationKey(generatorVersion: 1, level: 999),
    seed: 123456789,
    profileId: DifficultyProfileId.intro,
    layout: StageLayout(tierCount: tierCount, booksPerTier: booksPerTier),
    clueCount: 2,
    targetSwapCount: 1,
    duplicateGroupCount: duplicateGroupCount,
    maxDuplicateCopies: maxDuplicateCopies,
  );
}

void _expectGoldenSolution(
  TemplateSolution solution,
  List<String> expectedIds,
) {
  expect(solution.templateId, PuzzleTemplateId.t01AnchorChain);
  expect(
    solution.targetPlacements,
    hasLength(solution.stageSpec.totalBookCount),
  );
  expect(_placementIds(solution.targetPlacements), expectedIds);
  _expectSolutionIntegrity(solution, const BookCatalog());
}

void _expectSolutionIntegrity(TemplateSolution solution, BookCatalog catalog) {
  final placements = solution.targetPlacements;
  final ids = _placementIds(placements);
  final visualKeys = _visualKeys(solution.books);
  final positionKeys = <String>{};

  expect(placements, hasLength(solution.stageSpec.totalBookCount));
  expect(solution.totalBookCount, placements.length);
  expect(ids.toSet(), hasLength(ids.length));
  expect(visualKeys.toSet(), hasLength(visualKeys.length));
  expect(solution.stageSpec.totalBookCount, lessThanOrEqualTo(18));
  expect(solution.books.every(catalog.books.contains), isTrue);

  for (var index = 0; index < placements.length; index += 1) {
    final placement = placements[index];

    expect(placement.position.tierIndex, 0);
    expect(placement.position.slotIndex, index);
    expect(placements[index].book, solution.books[index]);
    expect(positionKeys.add('0:$index'), isTrue);
  }
}

const _catalogGoldenIds = [
  'blue_moon',
  'blue_star',
  'blue_cloud',
  'blue_key',
  'blue_leaf',
  'blue_drop',
  'blue_sun',
  'blue_diamond',
  'red_moon',
  'red_star',
  'red_cloud',
  'red_key',
  'red_leaf',
  'red_drop',
  'red_sun',
  'red_diamond',
  'yellow_moon',
  'yellow_star',
  'yellow_cloud',
  'yellow_key',
  'yellow_leaf',
  'yellow_drop',
  'yellow_sun',
  'yellow_diamond',
  'green_moon',
  'green_star',
  'green_cloud',
  'green_key',
  'green_leaf',
  'green_drop',
  'green_sun',
  'green_diamond',
  'purple_moon',
  'purple_star',
  'purple_cloud',
  'purple_key',
  'purple_leaf',
  'purple_drop',
  'purple_sun',
  'purple_diamond',
  'orange_moon',
  'orange_star',
  'orange_cloud',
  'orange_key',
  'orange_leaf',
  'orange_drop',
  'orange_sun',
  'orange_diamond',
];
