import 'package:flutter_test/flutter_test.dart';

import 'package:booklogic/features/game/domain/book.dart';
import 'package:booklogic/features/game/domain/book_placement.dart';
import 'package:booklogic/features/game/domain/book_position.dart';
import 'package:booklogic/features/game/domain/book_selector.dart';
import 'package:booklogic/features/game/domain/clue.dart';
import 'package:booklogic/features/game/domain/clue_evaluator.dart';
import 'package:booklogic/features/game/presentation/formatters/clue_text_formatter.dart';

void main() {
  const evaluator = ClueEvaluator();

  group('TierAssignmentClue', () {
    test('requires every selected book to be on the requested tier', () {
      final placements = _placements([
        _blueMoon,
        _blueStar,
        _redKey,
        _greenLeaf,
      ]);

      expect(
        evaluator.evaluate(
          clue: const TierAssignmentClue(
            id: 'blue_tier_0',
            subject: BookColorSelector(color: BookColor.blue),
            tierIndex: 0,
          ),
          placements: placements,
        ),
        isTrue,
      );
      expect(
        evaluator.evaluate(
          clue: const TierAssignmentClue(
            id: 'blue_tier_0',
            subject: BookColorSelector(color: BookColor.blue),
            tierIndex: 0,
          ),
          placements: [
            placements[0],
            placements[1].copyWith(
              position: const BookPosition(tierIndex: 1, slotIndex: 1),
            ),
            placements[2],
            placements[3],
          ],
        ),
        isFalse,
      );
      expect(
        evaluator.evaluate(
          clue: const TierAssignmentClue(
            id: 'green_tier_0',
            subject: BookColorSelector(color: BookColor.purple),
            tierIndex: 0,
          ),
          placements: placements,
        ),
        isFalse,
      );
      expect(
        evaluator.evaluate(
          clue: const TierAssignmentClue(
            id: 'book_tier_0',
            subject: BookIdSelector(bookId: 'blue_moon'),
            tierIndex: 0,
          ),
          placements: placements,
        ),
        isTrue,
      );
      expect(
        evaluator.evaluate(
          clue: const TierAssignmentClue(
            id: 'book_tier_9',
            subject: BookIdSelector(bookId: 'blue_moon'),
            tierIndex: 9,
          ),
          placements: placements,
        ),
        isFalse,
      );
      expect(_ids(placements), [
        'blue_moon',
        'blue_star',
        'red_key',
        'green_leaf',
      ]);
    });
  });

  group('SameTierClue', () {
    test('requires both selector results to share exactly one tier', () {
      final placements = _placements([
        _blueMoon,
        _blueStar,
        _redKey,
        _yellowMoon,
        _greenLeaf,
        _purpleSun,
      ]);

      expect(
        evaluator.evaluate(
          clue: const SameTierClue(
            id: 'same_tier',
            first: BookIdSelector(bookId: 'green_leaf'),
            second: BookIdSelector(bookId: 'purple_sun'),
          ),
          placements: placements,
        ),
        isTrue,
      );
      expect(
        evaluator.evaluate(
          clue: const SameTierClue(
            id: 'different_tiers',
            first: BookIdSelector(bookId: 'blue_moon'),
            second: BookIdSelector(bookId: 'green_leaf'),
          ),
          placements: placements,
        ),
        isFalse,
      );
      expect(
        evaluator.evaluate(
          clue: const SameTierClue(
            id: 'missing',
            first: BookIdSelector(bookId: 'missing_book'),
            second: BookIdSelector(bookId: 'green_leaf'),
          ),
          placements: placements,
        ),
        isFalse,
      );
      expect(
        evaluator.evaluate(
          clue: const SameTierClue(
            id: 'overlap',
            first: BookColorSelector(color: BookColor.blue),
            second: BookIdSelector(bookId: 'blue_moon'),
          ),
          placements: placements,
        ),
        isFalse,
      );
      expect(
        evaluator.evaluate(
          clue: const SameTierClue(
            id: 'group_same_tier',
            first: BookColorSelector(color: BookColor.blue),
            second: BookIdSelector(bookId: 'red_key'),
          ),
          placements: placements,
        ),
        isTrue,
      );
      expect(
        evaluator.evaluate(
          clue: const SameTierClue(
            id: 'group_split',
            first: BookColorSelector(color: BookColor.blue),
            second: BookIdSelector(bookId: 'red_key'),
          ),
          placements: [
            placements[0],
            placements[1].copyWith(
              position: const BookPosition(tierIndex: 1, slotIndex: 2),
            ),
            ...placements.skip(2),
          ],
        ),
        isFalse,
      );
      expect(_ids(placements), [
        'blue_moon',
        'blue_star',
        'red_key',
        'yellow_moon',
        'green_leaf',
        'purple_sun',
      ]);
    });
  });

  group('multi-tier C03 and C06', () {
    test('BothEdgesClue does not ignore same-color books on another tier', () {
      final placements = _placements([
        _blueMoon,
        _redKey,
        _greenLeaf,
        _blueStar,
        _yellowMoon,
        _purpleSun,
        _orangeDrop,
        _redCloud,
      ]);

      expect(
        evaluator.evaluate(
          clue: const BothEdgesClue(
            id: 'blue_edges',
            subject: BookColorSelector(color: BookColor.blue),
            tierIndex: 0,
          ),
          placements: placements,
        ),
        isTrue,
      );
      expect(
        evaluator.evaluate(
          clue: const BothEdgesClue(
            id: 'blue_split',
            subject: BookColorSelector(color: BookColor.blue),
            tierIndex: 0,
          ),
          placements: [
            placements[0],
            placements[1],
            placements[2],
            placements[3].copyWith(
              position: const BookPosition(tierIndex: 1, slotIndex: 3),
            ),
            ...placements.skip(4).take(3),
            placements[7].copyWith(
              position: const BookPosition(tierIndex: 0, slotIndex: 3),
            ),
          ],
        ),
        isFalse,
      );
      expect(
        evaluator.evaluate(
          clue: const BothEdgesClue(
            id: 'blue_three',
            subject: BookColorSelector(color: BookColor.blue),
            tierIndex: 0,
          ),
          placements: [
            ...placements,
            const BookPlacement(
              book: Book(
                id: 'blue_key',
                color: BookColor.blue,
                symbol: BookSymbol.key,
              ),
              position: BookPosition(tierIndex: 1, slotIndex: 4),
            ),
          ],
        ),
        isFalse,
      );
    });

    test('BetweenClue requires subjects and boundaries on the clue tier', () {
      final placements = _placements([
        _blueMoon,
        _redKey,
        _redCloud,
        _blueStar,
        _yellowMoon,
        _purpleSun,
        _orangeDrop,
        _greenLeaf,
      ]);

      expect(
        evaluator.evaluate(
          clue: const BetweenClue(
            id: 'red_between_blue',
            subject: BookColorSelector(color: BookColor.red),
            boundary: BookColorSelector(color: BookColor.blue),
            tierIndex: 0,
          ),
          placements: placements,
        ),
        isTrue,
      );
      expect(
        evaluator.evaluate(
          clue: const BetweenClue(
            id: 'red_split',
            subject: BookColorSelector(color: BookColor.red),
            boundary: BookColorSelector(color: BookColor.blue),
            tierIndex: 0,
          ),
          placements: [
            placements[0],
            placements[1],
            placements[2].copyWith(
              position: const BookPosition(tierIndex: 1, slotIndex: 2),
            ),
            ...placements.skip(3),
          ],
        ),
        isFalse,
      );
      expect(
        evaluator.evaluate(
          clue: const BetweenClue(
            id: 'boundary_split',
            subject: BookColorSelector(color: BookColor.red),
            boundary: BookColorSelector(color: BookColor.blue),
            tierIndex: 0,
          ),
          placements: [
            placements[0],
            placements[1],
            placements[2],
            placements[3].copyWith(
              position: const BookPosition(tierIndex: 1, slotIndex: 3),
            ),
            ...placements.skip(4),
          ],
        ),
        isFalse,
      );
      expect(
        evaluator.evaluate(
          clue: const BetweenClue(
            id: 'subject_missing',
            subject: BookIdSelector(bookId: 'missing_book'),
            boundary: BookColorSelector(color: BookColor.blue),
            tierIndex: 0,
          ),
          placements: placements,
        ),
        isFalse,
      );
      expect(
        evaluator.evaluate(
          clue: const BetweenClue(
            id: 'boundary_three',
            subject: BookColorSelector(color: BookColor.red),
            boundary: BookColorSelector(color: BookColor.blue),
            tierIndex: 0,
          ),
          placements: [
            ...placements,
            const BookPlacement(
              book: Book(
                id: 'blue_key',
                color: BookColor.blue,
                symbol: BookSymbol.key,
              ),
              position: BookPosition(tierIndex: 1, slotIndex: 4),
            ),
          ],
        ),
        isFalse,
      );
    });
  });

  group('multi-tier C04 and C05', () {
    test('AdjacentClue requires the whole selector group on the clue tier', () {
      final placements = [
        const BookPlacement(
          book: _blueMoon,
          position: BookPosition(tierIndex: 0, slotIndex: 0),
        ),
        const BookPlacement(
          book: _redKey,
          position: BookPosition(tierIndex: 0, slotIndex: 1),
        ),
        const BookPlacement(
          book: _redCloud,
          position: BookPosition(tierIndex: 0, slotIndex: 2),
        ),
        const BookPlacement(
          book: _greenLeaf,
          position: BookPosition(tierIndex: 0, slotIndex: 3),
        ),
        const BookPlacement(
          book: _yellowMoon,
          position: BookPosition(tierIndex: 1, slotIndex: 0),
        ),
      ];
      const clue = AdjacentClue(
        id: 'green_right_of_red_group',
        subject: BookIdSelector(bookId: 'green_leaf'),
        reference: BookColorSelector(color: BookColor.red),
        tierIndex: 0,
        direction: AdjacentDirection.immediatelyRightOf,
      );

      expect(evaluator.evaluate(clue: clue, placements: placements), isTrue);
      expect(
        evaluator.evaluate(
          clue: clue,
          placements: [
            placements[0],
            placements[1],
            placements[2].copyWith(
              position: const BookPosition(tierIndex: 1, slotIndex: 1),
            ),
            placements[3],
            placements[4].copyWith(
              position: const BookPosition(tierIndex: 0, slotIndex: 2),
            ),
          ],
        ),
        isFalse,
      );
    });

    test(
      'RelativeOrderClue requires the whole selector group on the clue tier',
      () {
        final placements = [
          const BookPlacement(
            book: _blueMoon,
            position: BookPosition(tierIndex: 0, slotIndex: 0),
          ),
          const BookPlacement(
            book: _redKey,
            position: BookPosition(tierIndex: 0, slotIndex: 1),
          ),
          const BookPlacement(
            book: _redCloud,
            position: BookPosition(tierIndex: 0, slotIndex: 2),
          ),
          const BookPlacement(
            book: _greenLeaf,
            position: BookPosition(tierIndex: 0, slotIndex: 3),
          ),
          const BookPlacement(
            book: _yellowMoon,
            position: BookPosition(tierIndex: 1, slotIndex: 0),
          ),
        ];
        const clue = RelativeOrderClue(
          id: 'red_group_left_of_green',
          subject: BookColorSelector(color: BookColor.red),
          reference: BookIdSelector(bookId: 'green_leaf'),
          tierIndex: 0,
          relation: HorizontalRelation.leftOf,
        );

        expect(evaluator.evaluate(clue: clue, placements: placements), isTrue);
        expect(
          evaluator.evaluate(
            clue: clue,
            placements: [
              placements[0],
              placements[1],
              placements[2].copyWith(
                position: const BookPosition(tierIndex: 1, slotIndex: 1),
              ),
              placements[3],
              placements[4].copyWith(
                position: const BookPosition(tierIndex: 0, slotIndex: 2),
              ),
            ],
          ),
          isFalse,
        );
      },
    );
  });

  group('C08 C09 C10', () {
    test('VerticalRelationClue requires same slot and adjacent tiers', () {
      final placements = [
        _placement(_greenLeaf, 0, 1),
        _placement(_blueMoon, 0, 2),
        _placement(_blueStar, 1, 0),
        _placement(_redKey, 1, 2),
        _placement(_yellowMoon, 2, 2),
      ];

      expect(
        evaluator.evaluate(
          clue: const VerticalRelationClue(
            id: 'blue_above_red',
            subject: BookIdSelector(bookId: 'blue_moon'),
            reference: BookIdSelector(bookId: 'red_key'),
            relation: VerticalRelation.immediatelyAbove,
          ),
          placements: placements,
        ),
        isTrue,
      );
      expect(
        evaluator.evaluate(
          clue: const VerticalRelationClue(
            id: 'red_below_blue',
            subject: BookIdSelector(bookId: 'red_key'),
            reference: BookIdSelector(bookId: 'blue_moon'),
            relation: VerticalRelation.immediatelyBelow,
          ),
          placements: placements,
        ),
        isTrue,
      );
      expect(
        evaluator.evaluate(
          clue: const VerticalRelationClue(
            id: 'same_tier',
            subject: BookIdSelector(bookId: 'green_leaf'),
            reference: BookIdSelector(bookId: 'blue_moon'),
            relation: VerticalRelation.immediatelyAbove,
          ),
          placements: placements,
        ),
        isFalse,
      );
      expect(
        evaluator.evaluate(
          clue: const VerticalRelationClue(
            id: 'slot_diff',
            subject: BookIdSelector(bookId: 'blue_star'),
            reference: BookIdSelector(bookId: 'green_leaf'),
            relation: VerticalRelation.immediatelyBelow,
          ),
          placements: placements,
        ),
        isFalse,
      );
      expect(
        evaluator.evaluate(
          clue: const VerticalRelationClue(
            id: 'tier_gap',
            subject: BookIdSelector(bookId: 'blue_moon'),
            reference: BookIdSelector(bookId: 'yellow_moon'),
            relation: VerticalRelation.immediatelyAbove,
          ),
          placements: placements,
        ),
        isFalse,
      );
      expect(
        evaluator.evaluate(
          clue: const VerticalRelationClue(
            id: 'selector_two_books',
            subject: BookColorSelector(color: BookColor.blue),
            reference: BookIdSelector(bookId: 'red_key'),
            relation: VerticalRelation.immediatelyAbove,
          ),
          placements: placements,
        ),
        isFalse,
      );
      expect(
        evaluator.evaluate(
          clue: const VerticalRelationClue(
            id: 'overlap',
            subject: BookIdSelector(bookId: 'blue_moon'),
            reference: BookIdSelector(bookId: 'blue_moon'),
            relation: VerticalRelation.immediatelyAbove,
          ),
          placements: placements,
        ),
        isFalse,
      );
      expect(_ids(placements), [
        'green_leaf',
        'blue_moon',
        'blue_star',
        'red_key',
        'yellow_moon',
      ]);
    });

    test('NotAtEdgeClue requires every selected book inside one tier', () {
      final placements = [
        _placement(_blueMoon, 0, 0),
        _placement(_redKey, 0, 5),
        _placement(_yellowStar, 1, 0),
        _placement(_greenCloudCopy01, 1, 2),
        _placement(_greenCloudCopy02, 1, 3),
        _placement(_purpleMoon, 1, 5),
      ];
      const clue = NotAtEdgeClue(
        id: 'green_cloud_not_edge',
        subject: BookVisualSelector(
          color: BookColor.green,
          symbol: BookSymbol.cloud,
        ),
        tierIndex: 1,
      );

      expect(evaluator.evaluate(clue: clue, placements: placements), isTrue);
      expect(
        evaluator.evaluate(
          clue: clue,
          placements: [
            ...placements.take(3),
            _placement(_greenCloudCopy01, 1, 0),
            ...placements.skip(4),
          ],
        ),
        isFalse,
      );
      expect(
        evaluator.evaluate(
          clue: clue,
          placements: [
            ...placements.take(4),
            _placement(_greenCloudCopy02, 0, 3),
            placements.last,
          ],
        ),
        isFalse,
      );
      expect(
        evaluator.evaluate(
          clue: const NotAtEdgeClue(
            id: 'missing',
            subject: BookIdSelector(bookId: 'missing_book'),
            tierIndex: 1,
          ),
          placements: placements,
        ),
        isFalse,
      );
    });

    test('DistanceClue checks exact same-tier gap', () {
      final placements = [
        _placement(_blueMoon, 0, 0),
        _placement(_yellowStar, 0, 1),
        _placement(_greenLeaf, 0, 2),
        _placement(_purpleMoon, 0, 3),
        _placement(_redKey, 1, 3),
        _placement(_blueStar, 1, 5),
      ];

      expect(
        evaluator.evaluate(
          clue: const DistanceClue(
            id: 'one_between',
            first: BookIdSelector(bookId: 'yellow_star'),
            second: BookIdSelector(bookId: 'purple_moon'),
            tierIndex: 0,
            booksBetween: 1,
          ),
          placements: placements,
        ),
        isTrue,
      );
      expect(
        evaluator.evaluate(
          clue: const DistanceClue(
            id: 'two_between',
            first: BookIdSelector(bookId: 'blue_moon'),
            second: BookIdSelector(bookId: 'purple_moon'),
            tierIndex: 0,
            booksBetween: 2,
          ),
          placements: placements,
        ),
        isTrue,
      );
      expect(
        evaluator.evaluate(
          clue: const DistanceClue(
            id: 'adjacent_is_not_distance_one',
            first: BookIdSelector(bookId: 'yellow_star'),
            second: BookIdSelector(bookId: 'green_leaf'),
            tierIndex: 0,
            booksBetween: 1,
          ),
          placements: placements,
        ),
        isFalse,
      );
      expect(
        evaluator.evaluate(
          clue: const DistanceClue(
            id: 'different_tier',
            first: BookIdSelector(bookId: 'purple_moon'),
            second: BookIdSelector(bookId: 'red_key'),
            tierIndex: 0,
            booksBetween: 1,
          ),
          placements: placements,
        ),
        isFalse,
      );
      expect(
        evaluator.evaluate(
          clue: const DistanceClue(
            id: 'selector_two_books',
            first: BookColorSelector(color: BookColor.blue),
            second: BookIdSelector(bookId: 'purple_moon'),
            tierIndex: 0,
            booksBetween: 1,
          ),
          placements: placements,
        ),
        isFalse,
      );
      expect(
        () => DistanceClue(
          id: 'zero_between',
          first: const BookIdSelector(bookId: 'yellow_star'),
          second: const BookIdSelector(bookId: 'green_leaf'),
          tierIndex: 0,
          booksBetween: 0,
        ),
        throwsAssertionError,
      );
    });
  });

  test('ClueTextFormatter formats C01 and C07 without internal ids', () {
    const formatter = ClueTextFormatter();
    final books = [
      _blueMoon,
      _redKey,
      _yellowStar,
      _purpleMoon,
      _purpleSun,
      _greenCloudCopy01,
      _greenCloudCopy02,
      _greenLeaf,
    ];

    expect(
      formatter.format(
        clue: const TierAssignmentClue(
          id: 'blue_tier_0',
          subject: BookColorSelector(color: BookColor.blue),
          tierIndex: 0,
        ),
        books: books,
      ),
      '모든 파란 책은 1단에 있다.',
    );
    expect(
      formatter.format(
        clue: const TierAssignmentClue(
          id: 'yellow_tier_1',
          subject: BookColorSelector(color: BookColor.yellow),
          tierIndex: 1,
        ),
        books: books,
      ),
      '모든 노란 책은 2단에 있다.',
    );
    expect(
      formatter.format(
        clue: const SameTierClue(
          id: 'same_tier',
          first: BookIdSelector(bookId: 'purple_sun'),
          second: BookIdSelector(bookId: 'green_leaf'),
        ),
        books: books,
      ),
      '보라 태양 책과 초록 잎 책은 같은 단에 있다.',
    );
    expect(
      formatter.format(
        clue: const VerticalRelationClue(
          id: 'blue_above_red',
          subject: BookIdSelector(bookId: 'blue_moon'),
          reference: BookIdSelector(bookId: 'red_key'),
          relation: VerticalRelation.immediatelyAbove,
        ),
        books: books,
      ),
      '파란 달 책은 빨간 열쇠 책 바로 위에 있다.',
    );
    expect(
      formatter.format(
        clue: const NotAtEdgeClue(
          id: 'green_cloud_not_edge',
          subject: BookVisualSelector(
            color: BookColor.green,
            symbol: BookSymbol.cloud,
          ),
          tierIndex: 1,
        ),
        books: books,
      ),
      '모든 초록 구름 책은 2단의 끝 칸에 있지 않다.',
    );
    expect(
      formatter.format(
        clue: const DistanceClue(
          id: 'one_between',
          first: BookIdSelector(bookId: 'yellow_star'),
          second: BookIdSelector(bookId: 'purple_moon'),
          tierIndex: 0,
          booksBetween: 1,
        ),
        books: books,
      ),
      '노란 별 책과 보라 달 책 사이에는 책이 한 권 있다.',
    );
    expect(
      formatter.format(
        clue: const DistanceClue(
          id: 'two_between',
          first: BookIdSelector(bookId: 'blue_moon'),
          second: BookIdSelector(bookId: 'purple_moon'),
          tierIndex: 0,
          booksBetween: 2,
        ),
        books: books,
      ),
      '파란 달 책과 보라 달 책 사이에는 책이 두 권 있다.',
    );
  });
}

const _blueMoon = Book(
  id: 'blue_moon',
  color: BookColor.blue,
  symbol: BookSymbol.moon,
);
const _blueStar = Book(
  id: 'blue_star',
  color: BookColor.blue,
  symbol: BookSymbol.star,
);
const _redKey = Book(
  id: 'red_key',
  color: BookColor.red,
  symbol: BookSymbol.key,
);
const _redCloud = Book(
  id: 'red_cloud',
  color: BookColor.red,
  symbol: BookSymbol.cloud,
);
const _yellowMoon = Book(
  id: 'yellow_moon',
  color: BookColor.yellow,
  symbol: BookSymbol.moon,
);
const _greenLeaf = Book(
  id: 'green_leaf',
  color: BookColor.green,
  symbol: BookSymbol.leaf,
);
const _purpleSun = Book(
  id: 'purple_sun',
  color: BookColor.purple,
  symbol: BookSymbol.sun,
);
const _orangeDrop = Book(
  id: 'orange_drop',
  color: BookColor.orange,
  symbol: BookSymbol.drop,
);
const _greenCloudCopy01 = Book(
  id: 'green_cloud_copy_01',
  color: BookColor.green,
  symbol: BookSymbol.cloud,
);
const _greenCloudCopy02 = Book(
  id: 'green_cloud_copy_02',
  color: BookColor.green,
  symbol: BookSymbol.cloud,
);
const _yellowStar = Book(
  id: 'yellow_star',
  color: BookColor.yellow,
  symbol: BookSymbol.star,
);
const _purpleMoon = Book(
  id: 'purple_moon',
  color: BookColor.purple,
  symbol: BookSymbol.moon,
);

List<BookPlacement> _placements(List<Book> books) {
  return [
    for (var index = 0; index < books.length; index += 1)
      BookPlacement(
        book: books[index],
        position: BookPosition(tierIndex: index ~/ 4, slotIndex: index % 4),
      ),
  ];
}

List<String> _ids(List<BookPlacement> placements) {
  return [for (final placement in placements) placement.book.id];
}

BookPlacement _placement(Book book, int tierIndex, int slotIndex) {
  return BookPlacement(
    book: book,
    position: BookPosition(tierIndex: tierIndex, slotIndex: slotIndex),
  );
}
