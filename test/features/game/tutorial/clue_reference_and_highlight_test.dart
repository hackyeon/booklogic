import 'package:flutter_test/flutter_test.dart';

import 'package:booklogic/core/constants/app_durations.dart';
import 'package:booklogic/features/game/application/game_controller.dart';
import 'package:booklogic/features/game/domain/book.dart';
import 'package:booklogic/features/game/domain/book_placement.dart';
import 'package:booklogic/features/game/domain/book_position.dart';
import 'package:booklogic/features/game/domain/book_selector.dart';
import 'package:booklogic/features/game/domain/clue.dart';
import 'package:booklogic/features/game/tutorial/application/clue_book_reference_resolver.dart';

void main() {
  group('ClueBookReferenceResolver', () {
    const resolver = ClueBookReferenceResolver();

    test('collects C01 through C10 selectors in canonical order', () {
      final placements = _placements();
      final clues = <Clue>[
        const TierAssignmentClue(
          id: 'c01',
          subject: BookColorSelector(color: BookColor.blue),
          tierIndex: 0,
        ),
        const EdgePositionClue(
          id: 'c02',
          subject: BookIdSelector(bookId: 'red_star'),
          tierIndex: 0,
          edge: ShelfEdge.left,
        ),
        const BothEdgesClue(
          id: 'c03',
          subject: BookSymbolSelector(symbol: BookSymbol.moon),
          tierIndex: 0,
        ),
        const RelativeOrderClue(
          id: 'c04',
          subject: BookIdSelector(bookId: 'blue_moon'),
          reference: BookIdSelector(bookId: 'green_leaf'),
          tierIndex: 0,
          relation: HorizontalRelation.leftOf,
        ),
        const AdjacentClue(
          id: 'c05',
          subject: BookIdSelector(bookId: 'green_leaf'),
          reference: BookIdSelector(bookId: 'yellow_key'),
          tierIndex: 0,
          direction: AdjacentDirection.immediatelyLeftOf,
        ),
        const BetweenClue(
          id: 'c06',
          subject: BookIdSelector(bookId: 'red_star'),
          boundary: BookColorSelector(color: BookColor.blue),
          tierIndex: 0,
        ),
        const SameTierClue(
          id: 'c07',
          first: BookIdSelector(bookId: 'red_star'),
          second: BookIdSelector(bookId: 'yellow_key'),
        ),
        const VerticalRelationClue(
          id: 'c08',
          subject: BookIdSelector(bookId: 'blue_moon'),
          reference: BookIdSelector(bookId: 'green_leaf'),
          relation: VerticalRelation.immediatelyAbove,
        ),
        const NotAtEdgeClue(
          id: 'c09',
          subject: BookIdSelector(bookId: 'green_leaf'),
          tierIndex: 0,
        ),
        const DistanceClue(
          id: 'c10',
          first: BookIdSelector(bookId: 'blue_moon'),
          second: BookIdSelector(bookId: 'yellow_key'),
          tierIndex: 0,
          booksBetween: 1,
        ),
      ];

      expect(
        clues.map(
          (clue) => resolver.resolveBookIds(clue: clue, placements: placements),
        ),
        [
          ['blue_moon', 'blue_cloud'],
          ['red_star'],
          ['blue_moon'],
          ['blue_moon', 'green_leaf'],
          ['green_leaf', 'yellow_key'],
          ['blue_moon', 'red_star', 'blue_cloud'],
          ['red_star', 'yellow_key'],
          ['blue_moon', 'green_leaf'],
          ['green_leaf'],
          ['blue_moon', 'yellow_key'],
        ],
      );
    });
  });

  group('GameController clue highlight', () {
    test(
      'replaces active highlight and clears it after the injected duration',
      () async {
        final controller = GameController(
          initialPlacements: _placements(),
          clues: const [
            EdgePositionClue(
              id: 'a',
              subject: BookIdSelector(bookId: 'blue_moon'),
              tierIndex: 0,
              edge: ShelfEdge.left,
            ),
            EdgePositionClue(
              id: 'b',
              subject: BookIdSelector(bookId: 'yellow_key'),
              tierIndex: 0,
              edge: ShelfEdge.right,
            ),
          ],
          clueBookHighlightDuration: const Duration(milliseconds: 30),
        );

        controller.highlightClue('a');
        expect(controller.highlightedClueId, 'a');
        expect(controller.clueHighlightedBookIds, {'blue_moon'});

        await Future<void>.delayed(const Duration(milliseconds: 15));
        controller.highlightClue('b');
        expect(controller.highlightedClueId, 'b');
        expect(controller.clueHighlightedBookIds, {'yellow_key'});

        await Future<void>.delayed(const Duration(milliseconds: 29));
        expect(controller.highlightedClueId, 'b');

        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(controller.highlightedClueId, isNull);
        expect(controller.clueHighlightedBookIds, isEmpty);
        expect(
          AppDurations.clueBookHighlight,
          const Duration(milliseconds: 800),
        );

        controller.dispose();
      },
    );
  });
}

List<BookPlacement> _placements() {
  return const [
    BookPlacement(
      book: Book(
        id: 'blue_moon',
        color: BookColor.blue,
        symbol: BookSymbol.moon,
      ),
      position: BookPosition(tierIndex: 0, slotIndex: 0),
    ),
    BookPlacement(
      book: Book(id: 'red_star', color: BookColor.red, symbol: BookSymbol.star),
      position: BookPosition(tierIndex: 0, slotIndex: 1),
    ),
    BookPlacement(
      book: Book(
        id: 'green_leaf',
        color: BookColor.green,
        symbol: BookSymbol.leaf,
      ),
      position: BookPosition(tierIndex: 0, slotIndex: 2),
    ),
    BookPlacement(
      book: Book(
        id: 'yellow_key',
        color: BookColor.yellow,
        symbol: BookSymbol.key,
      ),
      position: BookPosition(tierIndex: 0, slotIndex: 3),
    ),
    BookPlacement(
      book: Book(
        id: 'blue_cloud',
        color: BookColor.blue,
        symbol: BookSymbol.cloud,
      ),
      position: BookPosition(tierIndex: 1, slotIndex: 0),
    ),
    BookPlacement(
      book: Book(
        id: 'orange_drop',
        color: BookColor.orange,
        symbol: BookSymbol.drop,
      ),
      position: BookPosition(tierIndex: 1, slotIndex: 1),
    ),
    BookPlacement(
      book: Book(
        id: 'purple_sun',
        color: BookColor.purple,
        symbol: BookSymbol.sun,
      ),
      position: BookPosition(tierIndex: 1, slotIndex: 2),
    ),
    BookPlacement(
      book: Book(
        id: 'red_diamond',
        color: BookColor.red,
        symbol: BookSymbol.diamond,
      ),
      position: BookPosition(tierIndex: 1, slotIndex: 3),
    ),
  ];
}
