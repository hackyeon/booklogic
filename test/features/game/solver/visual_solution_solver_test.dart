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
import 'package:booklogic/features/game/solver/clue_partial_state.dart';
import 'package:booklogic/features/game/solver/visual_arrangement_signature.dart';
import 'package:booklogic/features/game/solver/visual_solution_solver.dart';

void main() {
  group('VisualArrangementSignature', () {
    test('uses canonical position order and visual book codes', () {
      final signature = VisualArrangementSignature.fromPlacements(
        tierCount: 1,
        booksPerTier: 4,
        placements: _placements([
          _book('green_drop_copy_02', BookColor.green, BookSymbol.drop),
          _book('red_star', BookColor.red, BookSymbol.star),
          _book('green_drop_copy_01', BookColor.green, BookSymbol.drop),
          _book('blue_moon', BookColor.blue, BookSymbol.moon),
        ]),
      );

      expect(signature.visualBookCodes, [
        'green_drop',
        'red_star',
        'green_drop',
        'blue_moon',
      ]);
      expect(
        signature.stableKey,
        '1x4|green_drop|red_star|green_drop|blue_moon',
      );
      expect(() => signature.visualBookCodes.add('x'), throwsUnsupportedError);
    });
  });

  group('VisualSolutionSolver', () {
    const solver = VisualSolutionSolver();

    test('finds one solution when clues fully fix a four-book shelf', () {
      final target = _fixedTarget();
      final analysis = solver.solve(
        stageSpec: _spec(),
        bookSet: target,
        clues: _fixedClues(),
        targetPlacements: target,
        initialPlacements: _placements([_green, _red, _blue, _yellow]),
      );

      expect(analysis.targetIsSolution, isTrue);
      expect(analysis.initialIsSolution, isFalse);
      expect(analysis.distinctVisualSolutionCount, 1);
      expect(analysis.isSolutionCountExact, isTrue);
      expect(analysis.targetSignatureFound, isTrue);
      expect(analysis.unsupportedReason, isNull);
    });

    test('counts visual arrangements instead of duplicate copy ids', () {
      final books = _placements([
        _book('green_drop_copy_01', BookColor.green, BookSymbol.drop),
        _book('green_drop_copy_02', BookColor.green, BookSymbol.drop),
        _red,
        _blue,
      ]);

      final analysis = solver.solve(
        stageSpec: _spec(),
        bookSet: books,
        clues: const [],
      );

      expect(analysis.distinctVisualSolutionCount, 12);
      expect(analysis.isSolutionCountExact, isTrue);
    });

    test('reports target and initial solution flags independently', () {
      final target = _placements([_red, _green, _yellow, _blue]);
      final solvedInitial = _fixedTarget();
      final analysis = solver.solve(
        stageSpec: _spec(),
        bookSet: target,
        clues: _fixedClues(),
        targetPlacements: target,
        initialPlacements: solvedInitial,
      );

      expect(analysis.targetIsSolution, isFalse);
      expect(analysis.initialIsSolution, isTrue);
    });

    test('stops at the solution limit without claiming an exact count', () {
      final analysis = solver.solve(
        stageSpec: _spec(),
        bookSet: _fixedTarget(),
        clues: const [],
        maximumDistinctSolutions: 2,
      );

      expect(analysis.distinctVisualSolutionCount, 2);
      expect(analysis.reachedSolutionLimit, isTrue);
      expect(analysis.isSolutionCountExact, isFalse);
    });

    test('rejects duplicate-copy BookIdSelector as unsupported', () {
      final books = _placements([
        _book('green_drop_copy_01', BookColor.green, BookSymbol.drop),
        _book('green_drop_copy_02', BookColor.green, BookSymbol.drop),
        _red,
        _blue,
      ]);
      final analysis = solver.solve(
        stageSpec: _spec(),
        bookSet: books,
        clues: const [
          EdgePositionClue(
            id: 'copy_left',
            subject: BookIdSelector(bookId: 'green_drop_copy_01'),
            tierIndex: 0,
            edge: ShelfEdge.left,
          ),
        ],
      );

      expect(analysis.unsupportedReason, 'unsupported_duplicate_id_selector');
      expect(analysis.distinctVisualSolutionCount, 0);
    });

    test('partial clue evaluation is conservative for fixed clues', () {
      final state = solver.evaluatePartialClue(
        stageSpec: _spec(),
        bookSet: _fixedTarget(),
        clue: const EdgePositionClue(
          id: 'red_left',
          subject: BookIdSelector(bookId: 'red_star'),
          tierIndex: 0,
          edge: ShelfEdge.left,
        ),
        assignedPositionByBookId: const {
          'red_star': BookPosition(tierIndex: 0, slotIndex: 2),
        },
      );

      expect(state, CluePartialState.violated);
    });

    test('partially evaluates C08 vertical relation clues', () {
      const clue = VerticalRelationClue(
        id: 'blue_above_red',
        subject: BookIdSelector(bookId: 'blue_moon'),
        reference: BookIdSelector(bookId: 'red_star'),
        relation: VerticalRelation.immediatelyAbove,
      );
      final bookSet = _placements([_blue, _red, _yellow]);

      expect(
        solver.evaluatePartialClue(
          stageSpec: _twoTierSixSpec(),
          bookSet: bookSet,
          clue: clue,
          assignedPositionByBookId: const {
            'blue_moon': BookPosition(tierIndex: 0, slotIndex: 2),
          },
        ),
        CluePartialState.undetermined,
      );
      expect(
        solver.evaluatePartialClue(
          stageSpec: _twoTierSixSpec(),
          bookSet: bookSet,
          clue: clue,
          assignedPositionByBookId: const {
            'blue_moon': BookPosition(tierIndex: 0, slotIndex: 2),
            'red_star': BookPosition(tierIndex: 1, slotIndex: 2),
          },
        ),
        CluePartialState.satisfied,
      );
      expect(
        solver.evaluatePartialClue(
          stageSpec: _twoTierSixSpec(),
          bookSet: bookSet,
          clue: clue,
          assignedPositionByBookId: const {
            'blue_moon': BookPosition(tierIndex: 0, slotIndex: 2),
            'red_star': BookPosition(tierIndex: 1, slotIndex: 3),
          },
        ),
        CluePartialState.violated,
      );
      expect(
        solver.evaluatePartialClue(
          stageSpec: _twoTierSixSpec(),
          bookSet: bookSet,
          clue: clue,
          assignedPositionByBookId: const {
            'blue_moon': BookPosition(tierIndex: 0, slotIndex: 2),
            'yellow_key': BookPosition(tierIndex: 1, slotIndex: 2),
          },
        ),
        CluePartialState.violated,
      );
    });

    test('partially evaluates C09 not-at-edge clues', () {
      final bookSet = _placements([
        _book('green_drop_copy_01', BookColor.green, BookSymbol.drop),
        _book('green_drop_copy_02', BookColor.green, BookSymbol.drop),
        _red,
      ]);
      const clue = NotAtEdgeClue(
        id: 'green_drop_not_edge',
        subject: BookVisualSelector(
          color: BookColor.green,
          symbol: BookSymbol.drop,
        ),
        tierIndex: 1,
      );

      expect(
        solver.evaluatePartialClue(
          stageSpec: _twoTierSixSpec(),
          bookSet: bookSet,
          clue: clue,
          assignedPositionByBookId: const {
            'green_drop_copy_01': BookPosition(tierIndex: 1, slotIndex: 2),
          },
        ),
        CluePartialState.undetermined,
      );
      expect(
        solver.evaluatePartialClue(
          stageSpec: _twoTierSixSpec(),
          bookSet: bookSet,
          clue: clue,
          assignedPositionByBookId: const {
            'green_drop_copy_01': BookPosition(tierIndex: 1, slotIndex: 2),
            'green_drop_copy_02': BookPosition(tierIndex: 1, slotIndex: 3),
          },
        ),
        CluePartialState.satisfied,
      );
      expect(
        solver.evaluatePartialClue(
          stageSpec: _twoTierSixSpec(),
          bookSet: bookSet,
          clue: clue,
          assignedPositionByBookId: const {
            'green_drop_copy_01': BookPosition(tierIndex: 1, slotIndex: 0),
          },
        ),
        CluePartialState.violated,
      );
    });

    test('partially evaluates C10 distance clues', () {
      const clue = DistanceClue(
        id: 'one_between',
        first: BookIdSelector(bookId: 'blue_moon'),
        second: BookIdSelector(bookId: 'red_star'),
        tierIndex: 0,
        booksBetween: 1,
      );
      final bookSet = _placements([_blue, _red, _yellow]);

      expect(
        solver.evaluatePartialClue(
          stageSpec: _twoTierSixSpec(),
          bookSet: bookSet,
          clue: clue,
          assignedPositionByBookId: const {
            'blue_moon': BookPosition(tierIndex: 0, slotIndex: 1),
          },
        ),
        CluePartialState.undetermined,
      );
      expect(
        solver.evaluatePartialClue(
          stageSpec: _twoTierSixSpec(),
          bookSet: bookSet,
          clue: clue,
          assignedPositionByBookId: const {
            'blue_moon': BookPosition(tierIndex: 0, slotIndex: 1),
            'red_star': BookPosition(tierIndex: 0, slotIndex: 3),
          },
        ),
        CluePartialState.satisfied,
      );
      expect(
        solver.evaluatePartialClue(
          stageSpec: _twoTierSixSpec(),
          bookSet: bookSet,
          clue: clue,
          assignedPositionByBookId: const {
            'blue_moon': BookPosition(tierIndex: 0, slotIndex: 1),
            'yellow_key': BookPosition(tierIndex: 0, slotIndex: 3),
          },
        ),
        CluePartialState.violated,
      );
      expect(
        solver.evaluatePartialClue(
          stageSpec: _twoTierSixSpec(),
          bookSet: bookSet,
          clue: clue,
          assignedPositionByBookId: const {
            'blue_moon': BookPosition(tierIndex: 0, slotIndex: 1),
            'red_star': BookPosition(tierIndex: 0, slotIndex: 2),
          },
        ),
        CluePartialState.violated,
      );
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

StageSpec _twoTierSixSpec() {
  return StageSpec(
    generationKey: const StageGenerationKey(generatorVersion: 2, level: 201),
    seed: 2,
    profileId: DifficultyProfileId.verticalIntro2x6,
    layout: const StageLayout(tierCount: 2, booksPerTier: 6),
    clueCount: 6,
    targetSwapCount: 6,
    duplicateGroupCount: 1,
    maxDuplicateCopies: 2,
  );
}

List<BookPlacement> _fixedTarget() {
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
