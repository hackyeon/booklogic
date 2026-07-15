import 'package:flutter_test/flutter_test.dart';

import 'package:booklogic/features/game/domain/book.dart';
import 'package:booklogic/features/game/domain/book_placement.dart';
import 'package:booklogic/features/game/domain/book_position.dart';
import 'package:booklogic/features/game/domain/book_selector.dart';
import 'package:booklogic/features/game/domain/clue.dart';
import 'package:booklogic/features/game/domain/clue_evaluator.dart';
import 'package:booklogic/features/game/generator/book_catalog.dart';
import 'package:booklogic/features/game/generator/difficulty_profile.dart';
import 'package:booklogic/features/game/generator/puzzle_template_id.dart';
import 'package:booklogic/features/game/generator/stage_generation_key.dart';
import 'package:booklogic/features/game/generator/stage_layout.dart';
import 'package:booklogic/features/game/generator/stage_spec.dart';
import 'package:booklogic/features/game/generator/stage_spec_factory.dart';
import 'package:booklogic/features/game/generator/t01_anchor_chain_clue_factory.dart';
import 'package:booklogic/features/game/generator/t01_anchor_chain_solution_factory.dart';
import 'package:booklogic/features/game/generator/template_solution.dart';
import 'package:booklogic/features/game/presentation/formatters/clue_text_formatter.dart';

void main() {
  group('T01AnchorChainClueFactory supports', () {
    const stageSpecFactory = StageSpecFactory();
    const solutionFactory = T01AnchorChainSolutionFactory();
    const clueFactory = T01AnchorChainClueFactory();

    test('supports generated level 1, 6, and 20 solutions', () {
      expect(
        clueFactory.supports(
          solutionFactory.create(stageSpecFactory.create(level: 1)),
        ),
        isTrue,
      );
      expect(
        clueFactory.supports(
          solutionFactory.create(stageSpecFactory.create(level: 6)),
        ),
        isTrue,
      );
      expect(
        clueFactory.supports(
          solutionFactory.create(stageSpecFactory.create(level: 20)),
        ),
        isTrue,
      );

      final level21Spec = stageSpecFactory.create(level: 21);
      expect(level21Spec.duplicateGroupCount, 1);
      expect(solutionFactory.supports(level21Spec), isFalse);
      expect(() => solutionFactory.create(level21Spec), throwsStateError);
    });

    test('rejects unsupported solution shapes', () {
      expect(
        clueFactory.supports(
          _solutionForIds(
            _ids4,
            spec: _customSpec(duplicateGroupCount: 1, maxDuplicateCopies: 2),
          ),
        ),
        isFalse,
      );
      expect(
        clueFactory.supports(
          _solutionForIds(
            _ids4,
            spec: _customSpec(tierCount: 2, booksPerTier: 4),
          ),
        ),
        isFalse,
      );
      expect(
        clueFactory.supports(
          _solutionForIds(
            _ids4,
            spec: _customSpec(tierCount: 3, booksPerTier: 4),
          ),
        ),
        isFalse,
      );
      expect(
        clueFactory.supports(
          _solutionFromPlacements([
            _placement(_catalogBook('blue_moon'), slotIndex: 0),
            _placement(_catalogBook('blue_moon'), slotIndex: 1),
            _placement(_catalogBook('red_star'), slotIndex: 2),
            _placement(_catalogBook('yellow_key'), slotIndex: 3),
          ]),
        ),
        isFalse,
      );
      expect(
        clueFactory.supports(
          _solutionFromPlacements([
            _placement(_catalogBook('blue_moon'), slotIndex: 0),
            _placement(_catalogBook('red_star'), slotIndex: 1),
            _placement(
              const Book(
                id: 'blue_moon_copy',
                color: BookColor.blue,
                symbol: BookSymbol.moon,
              ),
              slotIndex: 2,
            ),
            _placement(_catalogBook('yellow_key'), slotIndex: 3),
          ]),
        ),
        isFalse,
      );
      expect(
        clueFactory.supports(_solutionForIds(_ids4, slotIndexes: [0, 1, 2, 4])),
        isFalse,
      );
      expect(
        clueFactory.supports(
          _solutionForIds(
            _ids4.take(3).toList(),
            spec: _customSpec(booksPerTier: 4),
          ),
        ),
        isFalse,
      );
      expect(
        clueFactory.supports(
          _solutionForIds(_ids4, spec: _customSpec(clueCount: 1)),
        ),
        isFalse,
      );
      expect(
        clueFactory.supports(
          _solutionForIds(_ids4, spec: _customSpec(clueCount: 4)),
        ),
        isFalse,
      );
    });
  });

  group('T01AnchorChainClueFactory maxClueCount', () {
    const clueFactory = T01AnchorChainClueFactory();

    test('returns target placement count minus one', () {
      expect(clueFactory.maxClueCount(_solutionForIds(_ids4)), 3);
      expect(clueFactory.maxClueCount(_solutionForIds(_ids5)), 4);
      expect(clueFactory.maxClueCount(_solutionForIds(_ids6)), 5);
    });
  });

  group('T01AnchorChainClueFactory golden clues', () {
    const stageSpecFactory = StageSpecFactory();
    const solutionFactory = T01AnchorChainSolutionFactory();
    const clueFactory = T01AnchorChainClueFactory();

    test('level 1 generator v1 clues remain stable', () {
      final solution = solutionFactory.create(
        stageSpecFactory.create(level: 1),
      );
      final clues = clueFactory.create(solution);

      expect(clues, hasLength(3));
      expect(_clueIds(clues), [
        't01_c02_00_red_key_left_edge',
        't01_c05_01_blue_moon_immediately_right_of_red_key',
        't01_c04_02_blue_leaf_left_of_yellow_leaf',
      ]);
      expect(clues[0], isA<EdgePositionClue>());
      expect(clues[1], isA<AdjacentClue>());
      expect(clues[2], isA<RelativeOrderClue>());

      final edge = clues[0] as EdgePositionClue;
      expect(edge.subject, const BookIdSelector(bookId: 'red_key'));
      expect(edge.tierIndex, 0);
      expect(edge.edge, ShelfEdge.left);

      final adjacent = clues[1] as AdjacentClue;
      expect(adjacent.subject, const BookIdSelector(bookId: 'blue_moon'));
      expect(adjacent.reference, const BookIdSelector(bookId: 'red_key'));
      expect(adjacent.tierIndex, 0);
      expect(adjacent.direction, AdjacentDirection.immediatelyRightOf);

      final relative = clues[2] as RelativeOrderClue;
      expect(relative.subject, const BookIdSelector(bookId: 'blue_leaf'));
      expect(relative.reference, const BookIdSelector(bookId: 'yellow_leaf'));
      expect(relative.tierIndex, 0);
      expect(relative.relation, HorizontalRelation.leftOf);

      expect(_texts(clues, solution.books), [
        '빨간 열쇠 책은 1단의 왼쪽 끝에 있다.',
        '파란 달 책은 1단에서 빨간 열쇠 책 바로 오른쪽에 있다.',
        '파란 잎 책은 1단에서 노란 잎 책보다 왼쪽에 있다.',
      ]);
    });

    test('level 6 generator v1 clue ids and text remain stable', () {
      final solution = solutionFactory.create(
        stageSpecFactory.create(level: 6),
      );
      final clues = clueFactory.create(solution);

      expect(clues, hasLength(3));
      expect(_clueIds(clues), [
        't01_c02_00_orange_moon_left_edge',
        't01_c05_01_yellow_drop_immediately_right_of_orange_moon',
        't01_c04_02_blue_leaf_left_of_yellow_moon',
      ]);
      expect(_texts(clues, solution.books), [
        '주황 달 책은 1단의 왼쪽 끝에 있다.',
        '노란 물방울 책은 1단에서 주황 달 책 바로 오른쪽에 있다.',
        '파란 잎 책은 1단에서 노란 달 책보다 왼쪽에 있다.',
      ]);
      expect(
        _clueIds(clues),
        isNot(contains('t01_c04_03_yellow_moon_left_of_yellow_star')),
      );
    });

    test('level 20 generator v1 clue ids and text remain stable', () {
      final solution = solutionFactory.create(
        stageSpecFactory.create(level: 20),
      );
      final clues = clueFactory.create(solution);

      expect(clues, hasLength(3));
      expect(_clueIds(clues), [
        't01_c02_00_red_drop_left_edge',
        't01_c05_01_yellow_sun_immediately_right_of_red_drop',
        't01_c04_02_yellow_moon_left_of_blue_star',
      ]);
      expect(_texts(clues, solution.books), [
        '빨간 물방울 책은 1단의 왼쪽 끝에 있다.',
        '노란 태양 책은 1단에서 빨간 물방울 책 바로 오른쪽에 있다.',
        '노란 달 책은 1단에서 파란 별 책보다 왼쪽에 있다.',
      ]);
      expect(
        _clueIds(clues),
        isNot(contains('t01_c04_03_blue_star_left_of_green_key')),
      );
    });
  });

  group('T01AnchorChainClueFactory clue counts', () {
    const clueFactory = T01AnchorChainClueFactory();

    test('selects exactly StageSpec.clueCount leading candidates', () {
      _expectClueTypeSequence(
        clueFactory.create(
          _solutionForIds(_ids4, spec: _customSpec(clueCount: 2)),
        ),
        [EdgePositionClue, AdjacentClue],
      );
      _expectClueTypeSequence(
        clueFactory.create(
          _solutionForIds(_ids4, spec: _customSpec(clueCount: 3)),
        ),
        [EdgePositionClue, AdjacentClue, RelativeOrderClue],
      );
      _expectClueTypeSequence(
        clueFactory.create(
          _solutionForIds(
            _ids5,
            spec: _customSpec(booksPerTier: 5, clueCount: 3),
          ),
        ),
        [EdgePositionClue, AdjacentClue, RelativeOrderClue],
      );
      _expectClueTypeSequence(
        clueFactory.create(
          _solutionForIds(
            _ids5,
            spec: _customSpec(booksPerTier: 5, clueCount: 4),
          ),
        ),
        [EdgePositionClue, AdjacentClue, RelativeOrderClue, RelativeOrderClue],
      );
      _expectClueTypeSequence(
        clueFactory.create(
          _solutionForIds(
            _ids6,
            spec: _customSpec(booksPerTier: 6, clueCount: 4),
          ),
        ),
        [EdgePositionClue, AdjacentClue, RelativeOrderClue, RelativeOrderClue],
      );
      _expectClueTypeSequence(
        clueFactory.create(
          _solutionForIds(
            _ids6,
            spec: _customSpec(booksPerTier: 6, clueCount: 5),
          ),
        ),
        [
          EdgePositionClue,
          AdjacentClue,
          RelativeOrderClue,
          RelativeOrderClue,
          RelativeOrderClue,
        ],
      );
    });
  });

  group('T01AnchorChainClueFactory satisfaction and determinism', () {
    const stageSpecFactory = StageSpecFactory();
    const solutionFactory = T01AnchorChainSolutionFactory();
    const clueFactory = T01AnchorChainClueFactory();
    const evaluator = ClueEvaluator();

    test('levels 1 through 20 satisfy every generated clue', () {
      for (var level = 1; level <= 20; level += 1) {
        final solution = solutionFactory.create(
          stageSpecFactory.create(level: level),
        );
        final clues = clueFactory.create(solution);
        final satisfiedIds = evaluator.evaluateAll(
          clues: clues,
          placements: solution.targetPlacements,
        );

        expect(clues, hasLength(solution.stageSpec.clueCount));
        expect(satisfiedIds, hasLength(clues.length), reason: 'level $level');
        for (final clue in clues) {
          expect(satisfiedIds, contains(clue.id), reason: 'level $level');
          _expectSelectorsResolveOnce(clue, solution.targetPlacements);
        }
      }
    });

    test(
      'is deterministic for repeated factories and shuffled input order',
      () {
        final solution = solutionFactory.create(
          stageSpecFactory.create(level: 1),
        );
        final expected = clueFactory.create(solution);

        for (var index = 0; index < 100; index += 1) {
          expect(clueFactory.create(solution), expected);
        }
        expect(const T01AnchorChainClueFactory().create(solution), expected);

        final reversedSolution = TemplateSolution(
          stageSpec: solution.stageSpec,
          templateId: solution.templateId,
          targetPlacements: solution.targetPlacements.reversed.toList(),
        );
        expect(clueFactory.create(reversedSolution), expected);

        final level6Solution = solutionFactory.create(
          stageSpecFactory.create(level: 6),
        );
        expect(clueFactory.create(level6Solution), isNot(expected));
      },
    );

    test('uses stable unique ids for levels 1 through 20', () {
      for (var level = 1; level <= 20; level += 1) {
        final solution = solutionFactory.create(
          stageSpecFactory.create(level: level),
        );
        final ids = _clueIds(clueFactory.create(solution));

        expect(ids.toSet(), hasLength(ids.length), reason: 'level $level');
        for (final id in ids) {
          expect(id, isNotEmpty, reason: 'level $level');
          expect(id, matches(RegExp(r'^[a-z0-9_]+$')), reason: id);
          expect(id.contains(' '), isFalse);
          expect(id.contains('-'), isFalse);
          expect(id.contains(RegExp(r'[A-Z]')), isFalse);
          expect(id.contains(RegExp(r'[가-힣]')), isFalse);
        }
      }
    });
  });

  group('T01AnchorChainClueFactory immutability and invalid input', () {
    const clueFactory = T01AnchorChainClueFactory();

    test('does not mutate solution data and returns an immutable list', () {
      final catalog = const BookCatalog();
      final catalogIdsBefore = _bookIds(catalog.books);
      final solution = _solutionForIds(
        _ids5,
        spec: _customSpec(booksPerTier: 5, clueCount: 4),
      );
      final solutionBefore = _solutionSignature(solution);
      final placementsBefore = _placementSignature(solution.targetPlacements);

      final clues = clueFactory.create(solution);

      expect(_solutionSignature(solution), solutionBefore);
      expect(_placementSignature(solution.targetPlacements), placementsBefore);
      expect(_bookIds(catalog.books), catalogIdsBefore);
      expect(() => clues.add(clues.first), throwsUnsupportedError);
      expect(() => clues.remove(clues.first), throwsUnsupportedError);
      expect(() => clues.clear(), throwsUnsupportedError);
      expect(
        () => clues.sort((left, right) => left.id.compareTo(right.id)),
        throwsUnsupportedError,
      );
      expect(() => clues.shuffle(), throwsUnsupportedError);
    });

    test(
      'throws StateError for invalid solutions instead of correcting them',
      () {
        expect(
          () => clueFactory.create(
            _solutionForIds(
              _ids4,
              spec: _customSpec(tierCount: 2, booksPerTier: 4),
            ),
          ),
          throwsStateError,
        );
        expect(
          () => clueFactory.create(
            _solutionFromPlacements([
              _placement(_catalogBook('blue_moon'), slotIndex: 0),
              _placement(_catalogBook('blue_moon'), slotIndex: 1),
              _placement(_catalogBook('red_star'), slotIndex: 2),
              _placement(_catalogBook('yellow_key'), slotIndex: 3),
            ]),
          ),
          throwsStateError,
        );
        expect(
          () => clueFactory.create(
            _solutionForIds(_ids4, spec: _customSpec(clueCount: 1)),
          ),
          throwsStateError,
        );
        expect(
          () => clueFactory.create(
            _solutionForIds(_ids4, spec: _customSpec(clueCount: 4)),
          ),
          throwsStateError,
        );
        expect(
          () => clueFactory.create(
            _solutionForIds(_ids4, slotIndexes: [0, 0, 1, 2]),
          ),
          throwsStateError,
        );
        expect(
          () => clueFactory.create(
            _solutionForIds(_ids4, slotIndexes: [0, 1, 2, 4]),
          ),
          throwsStateError,
        );
        expect(
          () => clueFactory.create(
            _solutionForIds(
              _ids4.take(3).toList(),
              spec: _customSpec(booksPerTier: 4),
            ),
          ),
          throwsStateError,
        );
      },
    );
  });

  group('T01AnchorChainClueFactory permutation behavior', () {
    const clueFactory = T01AnchorChainClueFactory();

    test(
      'maximum clue count leaves one satisfying order for 4 and 5 books',
      () {
        final fourBookSolution = _solutionForIds(
          _ids4,
          spec: _customSpec(clueCount: 3),
        );
        final fourBookMatches = _satisfyingOrders(
          books: fourBookSolution.books,
          clues: clueFactory.create(fourBookSolution),
        );

        expect(fourBookMatches, hasLength(1));
        expect(fourBookMatches.single, _bookIds(fourBookSolution.books));

        final fiveBookSolution = _solutionForIds(
          _ids5,
          spec: _customSpec(booksPerTier: 5, clueCount: 4),
        );
        final fiveBookMatches = _satisfyingOrders(
          books: fiveBookSolution.books,
          clues: clueFactory.create(fiveBookSolution),
        );

        expect(fiveBookMatches, hasLength(1));
        expect(fiveBookMatches.single, _bookIds(fiveBookSolution.books));
      },
    );

    test(
      'partial clues can allow multiple answers without factory failure',
      () {
        final solution = _solutionForIds(
          _ids5,
          spec: _customSpec(booksPerTier: 5, clueCount: 3),
        );
        final clues = clueFactory.create(solution);
        final matches = _satisfyingOrders(books: solution.books, clues: clues);

        expect(clues, hasLength(3));
        expect(matches.length, greaterThan(1));
      },
    );
  });
}

const _ids4 = ['red_key', 'blue_moon', 'blue_leaf', 'yellow_leaf'];
const _ids5 = [
  'orange_moon',
  'yellow_drop',
  'blue_leaf',
  'yellow_moon',
  'yellow_star',
];
const _ids6 = [
  'red_drop',
  'yellow_sun',
  'yellow_moon',
  'blue_star',
  'green_key',
  'orange_leaf',
];

StageSpec _customSpec({
  int tierCount = 1,
  int booksPerTier = 4,
  int clueCount = 2,
  int duplicateGroupCount = 0,
  int maxDuplicateCopies = 1,
}) {
  return StageSpec(
    generationKey: const StageGenerationKey(generatorVersion: 1, level: 999),
    seed: 123456789,
    profileId: DifficultyProfileId.intro,
    layout: StageLayout(tierCount: tierCount, booksPerTier: booksPerTier),
    clueCount: clueCount,
    targetSwapCount: 1,
    duplicateGroupCount: duplicateGroupCount,
    maxDuplicateCopies: maxDuplicateCopies,
  );
}

TemplateSolution _solutionForIds(
  List<String> ids, {
  StageSpec? spec,
  List<int>? slotIndexes,
  List<int>? tierIndexes,
}) {
  return _solutionFromPlacements([
    for (var index = 0; index < ids.length; index += 1)
      _placement(
        _catalogBook(ids[index]),
        tierIndex: tierIndexes?[index] ?? 0,
        slotIndex: slotIndexes?[index] ?? index,
      ),
  ], spec: spec ?? _customSpec(booksPerTier: ids.length));
}

TemplateSolution _solutionFromPlacements(
  List<BookPlacement> placements, {
  StageSpec? spec,
}) {
  return TemplateSolution(
    stageSpec: spec ?? _customSpec(booksPerTier: placements.length),
    templateId: PuzzleTemplateId.t01AnchorChain,
    targetPlacements: placements,
  );
}

BookPlacement _placement(
  Book book, {
  int tierIndex = 0,
  required int slotIndex,
}) {
  return BookPlacement(
    book: book,
    position: BookPosition(tierIndex: tierIndex, slotIndex: slotIndex),
  );
}

Book _catalogBook(String id) {
  return const BookCatalog().books.firstWhere((book) => book.id == id);
}

List<String> _clueIds(List<Clue> clues) {
  return [for (final clue in clues) clue.id];
}

List<String> _bookIds(List<Book> books) {
  return [for (final book in books) book.id];
}

List<String> _texts(List<Clue> clues, List<Book> books) {
  const formatter = ClueTextFormatter();
  return [for (final clue in clues) formatter.format(clue: clue, books: books)];
}

void _expectClueTypeSequence(List<Clue> clues, List<Type> expectedTypes) {
  expect(clues, hasLength(expectedTypes.length));
  for (var index = 0; index < expectedTypes.length; index += 1) {
    expect(clues[index].runtimeType, expectedTypes[index]);
  }
}

void _expectSelectorsResolveOnce(Clue clue, List<BookPlacement> placements) {
  switch (clue) {
    case EdgePositionClue(:final subject):
      _expectSelectorResolvesOnce(subject, placements);
    case AdjacentClue(:final subject, :final reference):
      _expectSelectorResolvesOnce(subject, placements);
      _expectSelectorResolvesOnce(reference, placements);
    case RelativeOrderClue(:final subject, :final reference):
      _expectSelectorResolvesOnce(subject, placements);
      _expectSelectorResolvesOnce(reference, placements);
    case BothEdgesClue():
      fail('T01 selector helper does not accept BothEdgesClue.');
    case BetweenClue():
      fail('T01 selector helper does not accept BetweenClue.');
  }
}

void _expectSelectorResolvesOnce(
  BookSelector selector,
  List<BookPlacement> placements,
) {
  expect(selector, isA<BookIdSelector>());
  final bookId = (selector as BookIdSelector).bookId;
  expect(
    placements.where((placement) => placement.book.id == bookId),
    hasLength(1),
  );
}

String _solutionSignature(TemplateSolution solution) {
  return [
    solution.stageSpec.hashCode,
    solution.templateId,
    _placementSignature(solution.targetPlacements),
  ].join('|');
}

String _placementSignature(List<BookPlacement> placements) {
  return [
    for (final placement in placements)
      [
        placement.book.id,
        placement.book.color,
        placement.book.symbol,
        placement.position.tierIndex,
        placement.position.slotIndex,
      ].join(':'),
  ].join('|');
}

List<List<String>> _satisfyingOrders({
  required List<Book> books,
  required List<Clue> clues,
}) {
  const evaluator = ClueEvaluator();
  final matches = <List<String>>[];
  for (final permutation in _permutations(books)) {
    final placements = [
      for (var index = 0; index < permutation.length; index += 1)
        BookPlacement(
          book: permutation[index],
          position: BookPosition(tierIndex: 0, slotIndex: index),
        ),
    ];
    final satisfiedIds = evaluator.evaluateAll(
      clues: clues,
      placements: placements,
    );
    if (satisfiedIds.length == clues.length &&
        clues.every((clue) => satisfiedIds.contains(clue.id))) {
      matches.add(_bookIds(permutation));
    }
  }
  return matches;
}

List<List<Book>> _permutations(List<Book> books) {
  if (books.length == 1) {
    return [
      [books.single],
    ];
  }

  final result = <List<Book>>[];
  for (var index = 0; index < books.length; index += 1) {
    final book = books[index];
    final rest = [...books.take(index), ...books.skip(index + 1)];
    for (final permutation in _permutations(rest)) {
      result.add([book, ...permutation]);
    }
  }
  return result;
}
