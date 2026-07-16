import 'package:flutter_test/flutter_test.dart';

import 'package:booklogic/features/game/domain/book.dart';
import 'package:booklogic/features/game/domain/book_placement.dart';
import 'package:booklogic/features/game/domain/book_position.dart';
import 'package:booklogic/features/game/domain/book_selector.dart';
import 'package:booklogic/features/game/domain/clue.dart';
import 'package:booklogic/features/game/generator/difficulty_profile.dart';
import 'package:booklogic/features/game/generator/stage_generation_key.dart';
import 'package:booklogic/features/game/generator/stage_layout.dart';
import 'package:booklogic/features/game/generator/stage_spec.dart';
import 'package:booklogic/features/game/solver/visual_swap_reachability_checker.dart';

void main() {
  group('VisualSwapReachabilityChecker', () {
    const checker = VisualSwapReachabilityChecker();

    test('reports depth zero when initial placements already solve clues', () {
      final result = checker.check(
        stageSpec: _spec(),
        initialPlacements: _target(),
        clues: _fixedClues(),
        maximumDepth: 0,
      );

      expect(result.foundSolution, isTrue);
      expect(result.minimumDepth, 0);
      expect(result.visitedStateCount, 1);
    });

    test('finds a one-swap solution', () {
      final result = checker.check(
        stageSpec: _spec(),
        initialPlacements: _placements([_yellow, _red, _green, _blue]),
        clues: _fixedClues(),
        maximumDepth: 1,
      );

      expect(result.foundSolution, isTrue);
      expect(result.minimumDepth, 1);
      expect(result.reachedStateLimit, isFalse);
    });

    test('finds a two-swap solution and respects a shallower depth cap', () {
      final initial = _placements([_yellow, _red, _blue, _green]);

      final shallow = checker.check(
        stageSpec: _spec(),
        initialPlacements: initial,
        clues: _fixedClues(),
        maximumDepth: 1,
      );
      final deep = checker.check(
        stageSpec: _spec(),
        initialPlacements: initial,
        clues: _fixedClues(),
        maximumDepth: 2,
      );

      expect(shallow.foundSolution, isFalse);
      expect(deep.foundSolution, isTrue);
      expect(deep.minimumDepth, 2);
    });

    test('does not enqueue swaps between visually identical books', () {
      final result = checker.check(
        stageSpec: _spec(),
        initialPlacements: _placements([
          _book('green_drop_copy_01', BookColor.green, BookSymbol.drop),
          _book('green_drop_copy_02', BookColor.green, BookSymbol.drop),
          _red,
          _blue,
        ]),
        clues: const [
          EdgePositionClue(
            id: 'red_left',
            subject: BookIdSelector(bookId: 'red_star'),
            tierIndex: 0,
            edge: ShelfEdge.left,
          ),
          EdgePositionClue(
            id: 'blue_right',
            subject: BookIdSelector(bookId: 'blue_moon'),
            tierIndex: 0,
            edge: ShelfEdge.left,
          ),
        ],
        maximumDepth: 1,
      );

      expect(result.foundSolution, isFalse);
      expect(result.visitedStateCount, lessThan(7));
    });
  });
}

const _red = Book(
  id: 'red_star',
  color: BookColor.red,
  symbol: BookSymbol.star,
);
const _yellow = Book(
  id: 'yellow_key',
  color: BookColor.yellow,
  symbol: BookSymbol.key,
);
const _green = Book(
  id: 'green_leaf',
  color: BookColor.green,
  symbol: BookSymbol.leaf,
);
const _blue = Book(
  id: 'blue_moon',
  color: BookColor.blue,
  symbol: BookSymbol.moon,
);

StageSpec _spec() {
  return StageSpec(
    generationKey: const StageGenerationKey(generatorVersion: 1, level: 1),
    seed: 1,
    profileId: DifficultyProfileId.intro,
    layout: const StageLayout(tierCount: 1, booksPerTier: 4),
    clueCount: 4,
    targetSwapCount: 1,
    duplicateGroupCount: 0,
    maxDuplicateCopies: 1,
  );
}

List<BookPlacement> _target() {
  return _placements([_red, _yellow, _green, _blue]);
}

List<Clue> _fixedClues() {
  return const [
    EdgePositionClue(
      id: 'red_left',
      subject: BookIdSelector(bookId: 'red_star'),
      tierIndex: 0,
      edge: ShelfEdge.left,
    ),
    EdgePositionClue(
      id: 'blue_right',
      subject: BookIdSelector(bookId: 'blue_moon'),
      tierIndex: 0,
      edge: ShelfEdge.right,
    ),
    AdjacentClue(
      id: 'yellow_after_red',
      subject: BookIdSelector(bookId: 'yellow_key'),
      reference: BookIdSelector(bookId: 'red_star'),
      tierIndex: 0,
      direction: AdjacentDirection.immediatelyRightOf,
    ),
    AdjacentClue(
      id: 'green_before_blue',
      subject: BookIdSelector(bookId: 'green_leaf'),
      reference: BookIdSelector(bookId: 'blue_moon'),
      tierIndex: 0,
      direction: AdjacentDirection.immediatelyLeftOf,
    ),
  ];
}

List<BookPlacement> _placements(List<Book> books) {
  return [
    for (var slotIndex = 0; slotIndex < books.length; slotIndex += 1)
      BookPlacement(
        book: books[slotIndex],
        position: BookPosition(tierIndex: 0, slotIndex: slotIndex),
      ),
  ];
}

Book _book(String id, BookColor color, BookSymbol symbol) {
  return Book(id: id, color: color, symbol: symbol);
}
