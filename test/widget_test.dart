import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:booklogic/app/app.dart';
import 'package:booklogic/core/constants/app_durations.dart';
import 'package:booklogic/core/constants/app_strings.dart';
import 'package:booklogic/features/game/application/game_controller.dart';
import 'package:booklogic/features/game/application/game_status.dart';
import 'package:booklogic/features/game/domain/book.dart';
import 'package:booklogic/features/game/domain/book_placement.dart';
import 'package:booklogic/features/game/domain/book_position.dart';
import 'package:booklogic/features/game/domain/book_selector.dart';
import 'package:booklogic/features/game/domain/book_selector_resolver.dart';
import 'package:booklogic/features/game/domain/clue.dart';
import 'package:booklogic/features/game/domain/clue_evaluator.dart';
import 'package:booklogic/features/game/domain/clue_type.dart';
import 'package:booklogic/features/game/presentation/data/demo_bookshelf_data.dart';
import 'package:booklogic/features/game/presentation/data/demo_clue_data.dart';
import 'package:booklogic/features/game/presentation/formatters/book_label_formatter.dart';
import 'package:booklogic/features/game/presentation/formatters/clue_text_formatter.dart';
import 'package:booklogic/features/game/presentation/game_screen.dart';
import 'package:booklogic/features/game/presentation/widgets/bookshelf_widget.dart';
import 'package:booklogic/features/game/presentation/widgets/book_widget.dart';
import 'package:booklogic/features/game/presentation/widgets/clear_result_overlay.dart';
import 'package:booklogic/features/game/presentation/widgets/clue_card_widget.dart';

void main() {
  testWidgets('shows home screen and opens game screen', (tester) async {
    await tester.pumpWidget(const BookLogicApp());

    expect(find.text(AppStrings.appTitle), findsOneWidget);
    expect(find.text(AppStrings.continueButton), findsOneWidget);

    await tester.tap(find.text(AppStrings.continueButton));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.levelOne), findsOneWidget);
    expect(find.text(AppStrings.gameSelectionInstruction), findsOneWidget);
  });

  testWidgets('opens settings screen from home', (tester) async {
    await tester.pumpWidget(const BookLogicApp());

    await tester.tap(find.text(AppStrings.settingsButton));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.sound), findsOneWidget);
    expect(find.text(AppStrings.music), findsOneWidget);
    expect(find.text(AppStrings.haptic), findsOneWidget);
  });

  test('creates a book model', () {
    const book = Book(
      id: 'blue_moon',
      color: BookColor.blue,
      symbol: BookSymbol.moon,
    );

    expect(book.id, 'blue_moon');
    expect(book.color, BookColor.blue);
    expect(book.symbol, BookSymbol.moon);
    expect(book.toString(), contains('blue_moon'));
  });

  test('compares book positions by tier and slot', () {
    const first = BookPosition(tierIndex: 0, slotIndex: 1);
    const second = BookPosition(tierIndex: 0, slotIndex: 1);
    const different = BookPosition(tierIndex: 0, slotIndex: 2);

    expect(first, second);
    expect(first, isNot(different));
  });

  test('copies a book placement with a new position', () {
    const book = Book(
      id: 'green_cloud',
      color: BookColor.green,
      symbol: BookSymbol.cloud,
    );
    const original = BookPlacement(
      book: book,
      position: BookPosition(tierIndex: 0, slotIndex: 0),
    );

    final copied = original.copyWith(
      position: const BookPosition(tierIndex: 0, slotIndex: 2),
    );

    expect(copied.book, original.book);
    expect(copied.position, const BookPosition(tierIndex: 0, slotIndex: 2));
    expect(original.position, const BookPosition(tierIndex: 0, slotIndex: 0));
  });

  test('book selectors store values and compare by selector type', () {
    const blueMoon = BookIdSelector(bookId: 'blue_moon');
    const sameBlueMoon = BookIdSelector(bookId: 'blue_moon');
    const redStar = BookIdSelector(bookId: 'red_star');
    const blueSelector = BookColorSelector(color: BookColor.blue);
    const sameBlueSelector = BookColorSelector(color: BookColor.blue);
    const redSelector = BookColorSelector(color: BookColor.red);
    const moonSelector = BookSymbolSelector(symbol: BookSymbol.moon);
    const sameMoonSelector = BookSymbolSelector(symbol: BookSymbol.moon);
    const starSelector = BookSymbolSelector(symbol: BookSymbol.star);

    expect(blueMoon.bookId, 'blue_moon');
    expect(blueMoon, sameBlueMoon);
    expect(blueMoon, isNot(redStar));
    expect(blueSelector, sameBlueSelector);
    expect(blueSelector, isNot(redSelector));
    expect(moonSelector, sameMoonSelector);
    expect(moonSelector, isNot(starSelector));
    expect(blueMoon, isNot(blueSelector));
    expect(blueSelector, isNot(moonSelector));
    expect(() => BookIdSelector(bookId: ''), throwsAssertionError);
  });

  test('clue models store typed values and compare by value', () {
    const subject = BookIdSelector(bookId: 'blue_moon');
    const reference = BookIdSelector(bookId: 'red_star');
    const edgeClue = EdgePositionClue(
      id: 'edge',
      subject: subject,
      tierIndex: 0,
      edge: ShelfEdge.left,
    );
    const sameEdgeClue = EdgePositionClue(
      id: 'edge',
      subject: subject,
      tierIndex: 0,
      edge: ShelfEdge.left,
    );
    const differentEdgeClue = EdgePositionClue(
      id: 'edge_other',
      subject: subject,
      tierIndex: 0,
      edge: ShelfEdge.right,
    );
    const relativeClue = RelativeOrderClue(
      id: 'relative',
      subject: subject,
      reference: reference,
      tierIndex: 1,
      relation: HorizontalRelation.rightOf,
    );
    const adjacentClue = AdjacentClue(
      id: 'adjacent',
      subject: subject,
      reference: reference,
      tierIndex: 0,
      direction: AdjacentDirection.immediatelyLeftOf,
    );

    expect(edgeClue.id, 'edge');
    expect(edgeClue.subject, subject);
    expect(edgeClue.tierIndex, 0);
    expect(edgeClue.edge, ShelfEdge.left);
    expect(edgeClue.type, ClueType.edgePosition);
    expect(edgeClue, sameEdgeClue);
    expect(edgeClue, isNot(differentEdgeClue));
    expect(edgeClue.toString(), contains('EdgePositionClue'));

    expect(relativeClue.subject, subject);
    expect(relativeClue.reference, reference);
    expect(relativeClue.tierIndex, 1);
    expect(relativeClue.relation, HorizontalRelation.rightOf);
    expect(relativeClue.type, ClueType.relativeOrder);

    expect(adjacentClue.subject, subject);
    expect(adjacentClue.reference, reference);
    expect(adjacentClue.tierIndex, 0);
    expect(adjacentClue.direction, AdjacentDirection.immediatelyLeftOf);
    expect(adjacentClue.type, ClueType.adjacent);

    expect(
      () => EdgePositionClue(
        id: 'bad_tier',
        subject: subject,
        tierIndex: -1,
        edge: ShelfEdge.left,
      ),
      throwsAssertionError,
    );
  });

  test(
    'demo clues are fixed, ordered, unique, and use only step six types',
    () {
      expect(ClueType.values, [
        ClueType.edgePosition,
        ClueType.relativeOrder,
        ClueType.adjacent,
      ]);
      expect(demoClues, hasLength(3));
      expect(demoClues.map((clue) => clue.id), [
        'c02_blue_moon_left_edge',
        'c04_green_cloud_right_of_yellow_key',
        'c05_red_star_right_of_blue_moon',
      ]);
      expect(demoClues.map((clue) => clue.id).toSet(), hasLength(3));
      expect(demoClues[0], isA<EdgePositionClue>());
      expect(demoClues[0].type, ClueType.edgePosition);
      expect(demoClues[1], isA<RelativeOrderClue>());
      expect(demoClues[1].type, ClueType.relativeOrder);
      expect(demoClues[2], isA<AdjacentClue>());
      expect(demoClues[2].type, ClueType.adjacent);
    },
  );

  test('clue text formatter creates Korean clue sentences from typed data', () {
    const formatter = ClueTextFormatter();
    final books = _booksFromPlacements(demoBookshelfPlacements);

    expect(
      formatter.format(clue: demoClues[0], books: books),
      '파란 달 책은 1단의 왼쪽 끝에 있다.',
    );
    expect(
      formatter.format(
        clue: const EdgePositionClue(
          id: 'blue_moon_right_edge',
          subject: BookIdSelector(bookId: 'blue_moon'),
          tierIndex: 0,
          edge: ShelfEdge.right,
        ),
        books: books,
      ),
      '파란 달 책은 1단의 오른쪽 끝에 있다.',
    );
    expect(
      formatter.format(
        clue: const RelativeOrderClue(
          id: 'blue_moon_left_of_red_star',
          subject: BookIdSelector(bookId: 'blue_moon'),
          reference: BookIdSelector(bookId: 'red_star'),
          tierIndex: 0,
          relation: HorizontalRelation.leftOf,
        ),
        books: books,
      ),
      '파란 달 책은 1단에서 빨간 별 책보다 왼쪽에 있다.',
    );
    expect(
      formatter.format(clue: demoClues[1], books: books),
      '초록 구름 책은 1단에서 노란 열쇠 책보다 오른쪽에 있다.',
    );
    expect(
      formatter.format(
        clue: const AdjacentClue(
          id: 'blue_moon_left_of_red_star',
          subject: BookIdSelector(bookId: 'blue_moon'),
          reference: BookIdSelector(bookId: 'red_star'),
          tierIndex: 0,
          direction: AdjacentDirection.immediatelyLeftOf,
        ),
        books: books,
      ),
      '파란 달 책은 1단에서 빨간 별 책 바로 왼쪽에 있다.',
    );
    expect(
      formatter.format(clue: demoClues[2], books: books),
      '빨간 별 책은 1단에서 파란 달 책 바로 오른쪽에 있다.',
    );
    expect(
      formatter.format(
        clue: const EdgePositionClue(
          id: 'blue_moon_second_tier',
          subject: BookIdSelector(bookId: 'blue_moon'),
          tierIndex: 1,
          edge: ShelfEdge.left,
        ),
        books: books,
      ),
      '파란 달 책은 2단의 왼쪽 끝에 있다.',
    );
    expect(
      formatter.format(
        clue: const EdgePositionClue(
          id: 'unknown_book',
          subject: BookIdSelector(bookId: 'unknown_id'),
          tierIndex: 0,
          edge: ShelfEdge.left,
        ),
        books: books,
      ),
      '알 수 없는 책(unknown_id)은 1단의 왼쪽 끝에 있다.',
    );
    expect(
      const BookLabelFormatter().formatSelector(
        selector: const BookColorSelector(color: BookColor.blue),
        books: books,
      ),
      '모든 파란 책',
    );
    expect(
      const BookLabelFormatter().formatSelector(
        selector: const BookSymbolSelector(symbol: BookSymbol.moon),
        books: books,
      ),
      '모든 달 문양 책',
    );
  });

  test('book selector resolver resolves ids, groups, and stable order', () {
    const resolver = BookSelectorResolver();
    final originalOrder = _bookIdsBySlot(demoBookshelfPlacements);
    final mixedPlacements = [
      _demoPlacement('red_star', 3, tierIndex: 1),
      _demoPlacement('blue_moon', 2),
      _demoPlacement('yellow_key', 1, tierIndex: 1),
      _demoPlacement('green_cloud', 0),
    ];

    expect(
      resolver
          .resolve(
            selector: const BookIdSelector(bookId: 'blue_moon'),
            placements: demoBookshelfPlacements,
          )
          .single
          .book
          .id,
      'blue_moon',
    );
    expect(
      resolver.resolve(
        selector: const BookIdSelector(bookId: 'unknown_book'),
        placements: demoBookshelfPlacements,
      ),
      isEmpty,
    );
    expect(
      resolver
          .resolve(
            selector: const BookColorSelector(color: BookColor.blue),
            placements: demoBookshelfPlacements,
          )
          .map((placement) => placement.book.id),
      ['blue_moon'],
    );
    expect(
      resolver
          .resolve(
            selector: const BookSymbolSelector(symbol: BookSymbol.moon),
            placements: demoBookshelfPlacements,
          )
          .map((placement) => placement.book.id),
      ['blue_moon'],
    );
    expect(
      resolver
          .resolve(
            selector: const BookSymbolSelector(symbol: BookSymbol.moon),
            placements: mixedPlacements,
          )
          .map((placement) => placement.book.id),
      ['blue_moon'],
    );
    expect(_bookIdsBySlot(demoBookshelfPlacements), originalOrder);
  });

  test('book selector resolver returns multiple matches in position order', () {
    const resolver = BookSelectorResolver();
    const placements = [
      BookPlacement(
        book: Book(
          id: 'blue_moon_late',
          color: BookColor.blue,
          symbol: BookSymbol.moon,
        ),
        position: BookPosition(tierIndex: 1, slotIndex: 0),
      ),
      BookPlacement(
        book: Book(
          id: 'blue_star',
          color: BookColor.blue,
          symbol: BookSymbol.star,
        ),
        position: BookPosition(tierIndex: 0, slotIndex: 2),
      ),
      BookPlacement(
        book: Book(
          id: 'blue_cloud',
          color: BookColor.blue,
          symbol: BookSymbol.cloud,
        ),
        position: BookPosition(tierIndex: 0, slotIndex: 1),
      ),
    ];

    expect(
      resolver
          .resolve(
            selector: const BookColorSelector(color: BookColor.blue),
            placements: placements,
          )
          .map((placement) => placement.book.id),
      ['blue_cloud', 'blue_star', 'blue_moon_late'],
    );
  });

  test('clue evaluator handles edge position clues', () {
    const evaluator = ClueEvaluator();
    const leftClue = EdgePositionClue(
      id: 'left',
      subject: BookIdSelector(bookId: 'blue_moon'),
      tierIndex: 0,
      edge: ShelfEdge.left,
    );
    const rightClue = EdgePositionClue(
      id: 'right',
      subject: BookIdSelector(bookId: 'red_star'),
      tierIndex: 0,
      edge: ShelfEdge.right,
    );

    expect(
      evaluator.evaluate(
        clue: leftClue,
        placements: [
          _demoPlacement('blue_moon', 0),
          _demoPlacement('green_cloud', 1),
        ],
      ),
      isTrue,
    );
    expect(
      evaluator.evaluate(clue: leftClue, placements: demoBookshelfPlacements),
      isFalse,
    );
    expect(
      evaluator.evaluate(clue: rightClue, placements: demoBookshelfPlacements),
      isTrue,
    );
    expect(
      evaluator.evaluate(
        clue: rightClue,
        placements: [
          _demoPlacement('red_star', 1),
          _demoPlacement('yellow_key', 3),
        ],
      ),
      isFalse,
    );
    expect(
      evaluator.evaluate(
        clue: leftClue,
        placements: [_demoPlacement('blue_moon', 0, tierIndex: 1)],
      ),
      isFalse,
    );
    expect(
      evaluator.evaluate(
        clue: const EdgePositionClue(
          id: 'missing',
          subject: BookIdSelector(bookId: 'unknown_book'),
          tierIndex: 0,
          edge: ShelfEdge.left,
        ),
        placements: demoBookshelfPlacements,
      ),
      isFalse,
    );
    expect(
      evaluator.evaluate(
        clue: const EdgePositionClue(
          id: 'multi',
          subject: BookColorSelector(color: BookColor.blue),
          tierIndex: 0,
          edge: ShelfEdge.left,
        ),
        placements: const [
          BookPlacement(
            book: Book(
              id: 'blue_moon',
              color: BookColor.blue,
              symbol: BookSymbol.moon,
            ),
            position: BookPosition(tierIndex: 0, slotIndex: 0),
          ),
          BookPlacement(
            book: Book(
              id: 'blue_star',
              color: BookColor.blue,
              symbol: BookSymbol.star,
            ),
            position: BookPosition(tierIndex: 0, slotIndex: 1),
          ),
        ],
      ),
      isFalse,
    );
    expect(
      evaluator.evaluate(
        clue: leftClue,
        placements: [_demoPlacement('green_cloud', 0, tierIndex: 1)],
      ),
      isFalse,
    );
  });

  test('clue evaluator handles relative order clues', () {
    const evaluator = ClueEvaluator();
    const leftOf = RelativeOrderClue(
      id: 'left_of',
      subject: BookIdSelector(bookId: 'blue_moon'),
      reference: BookIdSelector(bookId: 'red_star'),
      tierIndex: 0,
      relation: HorizontalRelation.leftOf,
    );
    const rightOf = RelativeOrderClue(
      id: 'right_of',
      subject: BookIdSelector(bookId: 'green_cloud'),
      reference: BookIdSelector(bookId: 'yellow_key'),
      tierIndex: 0,
      relation: HorizontalRelation.rightOf,
    );

    expect(
      evaluator.evaluate(clue: leftOf, placements: demoBookshelfPlacements),
      isTrue,
    );
    expect(
      evaluator.evaluate(
        clue: leftOf,
        placements: [
          _demoPlacement('red_star', 0),
          _demoPlacement('blue_moon', 1),
        ],
      ),
      isFalse,
    );
    expect(
      evaluator.evaluate(clue: rightOf, placements: _completedDemoPlacements),
      isTrue,
    );
    expect(
      evaluator.evaluate(clue: rightOf, placements: demoBookshelfPlacements),
      isFalse,
    );
    expect(
      evaluator.evaluate(
        clue: leftOf,
        placements: [
          _demoPlacement('blue_moon', 0),
          _demoPlacement('yellow_key', 1),
          _demoPlacement('red_star', 3),
        ],
      ),
      isTrue,
    );
    expect(
      evaluator.evaluate(
        clue: leftOf,
        placements: [
          _demoPlacement('blue_moon', 0),
          _demoPlacement('red_star', 1, tierIndex: 1),
        ],
      ),
      isFalse,
    );
    expect(
      evaluator.evaluate(
        clue: const RelativeOrderClue(
          id: 'wrong_tier',
          subject: BookIdSelector(bookId: 'blue_moon'),
          reference: BookIdSelector(bookId: 'red_star'),
          tierIndex: 1,
          relation: HorizontalRelation.leftOf,
        ),
        placements: demoBookshelfPlacements,
      ),
      isFalse,
    );
    expect(
      evaluator.evaluate(
        clue: const RelativeOrderClue(
          id: 'same_book',
          subject: BookIdSelector(bookId: 'blue_moon'),
          reference: BookIdSelector(bookId: 'blue_moon'),
          tierIndex: 0,
          relation: HorizontalRelation.leftOf,
        ),
        placements: demoBookshelfPlacements,
      ),
      isFalse,
    );
    expect(
      evaluator.evaluate(
        clue: const RelativeOrderClue(
          id: 'missing_subject',
          subject: BookIdSelector(bookId: 'unknown_book'),
          reference: BookIdSelector(bookId: 'red_star'),
          tierIndex: 0,
          relation: HorizontalRelation.leftOf,
        ),
        placements: demoBookshelfPlacements,
      ),
      isFalse,
    );
  });

  test('clue evaluator handles adjacent clues', () {
    const evaluator = ClueEvaluator();
    const leftOf = AdjacentClue(
      id: 'left_of',
      subject: BookIdSelector(bookId: 'blue_moon'),
      reference: BookIdSelector(bookId: 'red_star'),
      tierIndex: 0,
      direction: AdjacentDirection.immediatelyLeftOf,
    );
    const rightOf = AdjacentClue(
      id: 'right_of',
      subject: BookIdSelector(bookId: 'red_star'),
      reference: BookIdSelector(bookId: 'blue_moon'),
      tierIndex: 0,
      direction: AdjacentDirection.immediatelyRightOf,
    );

    expect(
      evaluator.evaluate(
        clue: leftOf,
        placements: [
          _demoPlacement('blue_moon', 0),
          _demoPlacement('red_star', 1),
        ],
      ),
      isTrue,
    );
    expect(
      evaluator.evaluate(clue: leftOf, placements: demoBookshelfPlacements),
      isFalse,
    );
    expect(
      evaluator.evaluate(clue: rightOf, placements: _completedDemoPlacements),
      isTrue,
    );
    expect(
      evaluator.evaluate(
        clue: rightOf,
        placements: [
          _demoPlacement('red_star', 0),
          _demoPlacement('blue_moon', 1),
        ],
      ),
      isFalse,
    );
    expect(
      evaluator.evaluate(
        clue: rightOf,
        placements: [
          _demoPlacement('blue_moon', 0),
          _demoPlacement('red_star', 2),
        ],
      ),
      isFalse,
    );
    expect(
      evaluator.evaluate(
        clue: rightOf,
        placements: [
          _demoPlacement('blue_moon', 0),
          _demoPlacement('red_star', 1, tierIndex: 1),
        ],
      ),
      isFalse,
    );
    expect(
      evaluator.evaluate(
        clue: const AdjacentClue(
          id: 'same_book',
          subject: BookIdSelector(bookId: 'blue_moon'),
          reference: BookIdSelector(bookId: 'blue_moon'),
          tierIndex: 0,
          direction: AdjacentDirection.immediatelyRightOf,
        ),
        placements: demoBookshelfPlacements,
      ),
      isFalse,
    );
    expect(
      evaluator.evaluate(
        clue: const AdjacentClue(
          id: 'missing',
          subject: BookIdSelector(bookId: 'unknown_book'),
          reference: BookIdSelector(bookId: 'blue_moon'),
          tierIndex: 0,
          direction: AdjacentDirection.immediatelyRightOf,
        ),
        placements: demoBookshelfPlacements,
      ),
      isFalse,
    );
  });

  test('clue evaluator evaluates all clues from current placements only', () {
    const evaluator = ClueEvaluator();
    final cluesBefore = List<Clue>.of(demoClues);
    final placementsBefore = List<BookPlacement>.of(demoBookshelfPlacements);

    expect(
      evaluator.evaluateAll(
        clues: demoClues,
        placements: demoBookshelfPlacements,
      ),
      isEmpty,
    );
    expect(
      evaluator.evaluateAll(
        clues: demoClues,
        placements: _firstSatisfiedDemoPlacements,
      ),
      {'c02_blue_moon_left_edge'},
    );
    expect(
      evaluator.evaluateAll(
        clues: demoClues,
        placements: _completedDemoPlacements,
      ),
      {
        'c02_blue_moon_left_edge',
        'c04_green_cloud_right_of_yellow_key',
        'c05_red_star_right_of_blue_moon',
      },
    );
    expect(
      evaluator.evaluateAll(
        clues: demoClues,
        placements: _partiallyBrokenDemoPlacements,
      ),
      {'c04_green_cloud_right_of_yellow_key'},
    );
    expect(
      evaluator.evaluateAll(
        clues: const [],
        placements: demoBookshelfPlacements,
      ),
      isEmpty,
    );
    expect(demoClues, cluesBefore);
    expect(demoBookshelfPlacements, placementsBefore);
  });

  testWidgets('shows fixed demo books on the bookshelf', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookshelfWidget(
            placements: demoBookshelfPlacements,
            selectedBookId: null,
            isAnimating: false,
            activeSwap: null,
            isInteractionLocked: false,
            isClearing: false,
            isCleared: false,
            clearActiveBookId: null,
            onBookTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('bookshelf_tier_0')), findsOneWidget);
    expect(find.byKey(const Key('book_green_cloud')), findsOneWidget);
    expect(find.byKey(const Key('book_blue_moon')), findsOneWidget);
    expect(find.byKey(const Key('book_yellow_key')), findsOneWidget);
    expect(find.byKey(const Key('book_red_star')), findsOneWidget);
  });

  testWidgets('shows game screen with four books and fixed status', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: GameScreen()));

    expect(find.text(AppStrings.levelOne), findsOneWidget);
    expect(find.byKey(const Key('book_green_cloud')), findsOneWidget);
    expect(find.byKey(const Key('book_blue_moon')), findsOneWidget);
    expect(find.byKey(const Key('book_yellow_key')), findsOneWidget);
    expect(find.byKey(const Key('book_red_star')), findsOneWidget);
    expect(find.text('${AppStrings.moveCountPrefix} 0회'), findsOneWidget);
    expect(find.text('${AppStrings.clueTitle} 0/3'), findsOneWidget);
    expect(find.text(AppStrings.selectFirstBook), findsOneWidget);
  });

  testWidgets('shows fixed neutral clue panel and cards', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: GameScreen()));

    expect(find.byKey(const Key('clue_panel')), findsOneWidget);
    expect(
      find.byKey(const Key('clue_c02_blue_moon_left_edge')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('clue_c04_green_cloud_right_of_yellow_key')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('clue_c05_red_star_right_of_blue_moon')),
      findsOneWidget,
    );
    expect(find.text('파란 달 책은 1단의 왼쪽 끝에 있다.'), findsOneWidget);
    expect(find.text('초록 구름 책은 1단에서 노란 열쇠 책보다 오른쪽에 있다.'), findsOneWidget);
    expect(find.text('빨간 별 책은 1단에서 파란 달 책 바로 오른쪽에 있다.'), findsOneWidget);
    expect(find.text('${AppStrings.clueTitle} 0/3'), findsOneWidget);
    _expectNoDemoChecks();
  });

  testWidgets('clue card shows neutral and satisfied states', (tester) async {
    final semantics = tester.ensureSemantics();
    const clue = EdgePositionClue(
      id: 'c02_blue_moon_left_edge',
      subject: BookIdSelector(bookId: 'blue_moon'),
      tierIndex: 0,
      edge: ShelfEdge.left,
    );
    const text = '파란 달 책은 1단의 왼쪽 끝에 있다.';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ClueCardWidget(
            clue: clue,
            text: text,
            displayIndex: 1,
            isSatisfied: false,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('clue_c02_blue_moon_left_edge')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('clue_check_c02_blue_moon_left_edge')),
      findsNothing,
    );
    expect(_clueCardSemanticsLabels(tester), contains('단서 1. $text 미충족'));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ClueCardWidget(
            clue: clue,
            text: text,
            displayIndex: 1,
            isSatisfied: true,
          ),
        ),
      ),
    );
    await tester.pump(AppDurations.clueStateChange);

    expect(
      find.byKey(const Key('clue_check_c02_blue_moon_left_edge')),
      findsOneWidget,
    );
    expect(_clueCardSemanticsLabels(tester), contains('단서 1. $text 충족'));
    expect(find.text(text), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ClueCardWidget(
            clue: clue,
            text: text,
            displayIndex: 1,
            isSatisfied: false,
          ),
        ),
      ),
    );
    await tester.pump(AppDurations.clueStateChange);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('clue_check_c02_blue_moon_left_edge')),
      findsNothing,
    );
    expect(find.text(text), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('book widget applies and removes clear highlight', (
    tester,
  ) async {
    const book = Book(
      id: 'blue_moon',
      color: BookColor.blue,
      symbol: BookSymbol.moon,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: BookWidget(
              book: book,
              width: 80,
              height: 180,
              isSelected: false,
              isClearActive: false,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    final initialTop = _bookTopOf(tester, 'blue_moon');
    final initialWidth = tester
        .getSize(find.byKey(const Key('book_blue_moon')))
        .width;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: BookWidget(
              book: book,
              width: 80,
              height: 180,
              isSelected: false,
              isClearActive: true,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(AppDurations.bookSelectionDuration);

    expect(_bookTopOf(tester, 'blue_moon'), lessThan(initialTop));
    expect(
      tester.getSize(find.byKey(const Key('book_blue_moon'))).width,
      initialWidth,
    );
    expect(find.bySemanticsLabel('파란 달 책'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: BookWidget(
              book: book,
              width: 80,
              height: 180,
              isSelected: false,
              isClearActive: false,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(AppDurations.bookSelectionDuration);

    expect(
      _bookTopOf(tester, 'blue_moon'),
      moreOrLessEquals(initialTop, epsilon: 0.1),
    );
  });

  testWidgets('bookshelf applies clear highlight, glow, and input lock', (
    tester,
  ) async {
    var tapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookshelfWidget(
            placements: demoBookshelfPlacements,
            selectedBookId: null,
            isAnimating: false,
            activeSwap: null,
            isInteractionLocked: false,
            isClearing: true,
            isCleared: false,
            clearActiveBookId: 'blue_moon',
            onBookTap: (_) => tapCount += 1,
          ),
        ),
      ),
    );
    final blueTop = _bookTopOf(tester, 'blue_moon');
    final redTop = _bookTopOf(tester, 'red_star');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookshelfWidget(
            placements: demoBookshelfPlacements,
            selectedBookId: null,
            isAnimating: false,
            activeSwap: null,
            isInteractionLocked: false,
            isClearing: true,
            isCleared: false,
            clearActiveBookId: 'red_star',
            onBookTap: (_) => tapCount += 1,
          ),
        ),
      ),
    );
    await tester.pump(AppDurations.bookSelectionDuration);

    expect(_bookTopOf(tester, 'red_star'), lessThan(redTop));
    expect(_bookTopOf(tester, 'blue_moon'), greaterThanOrEqualTo(blueTop));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookshelfWidget(
            placements: demoBookshelfPlacements,
            selectedBookId: null,
            isAnimating: false,
            activeSwap: null,
            isInteractionLocked: true,
            isClearing: false,
            isCleared: true,
            clearActiveBookId: null,
            onBookTap: (_) => tapCount += 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bookshelf_clear_glow')), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('book_blue_moon')),
      warnIfMissed: false,
    );
    expect(tapCount, 0);
    expect(_visibleBookOrder(tester), [
      'green_cloud',
      'blue_moon',
      'yellow_key',
      'red_star',
    ]);
  });

  testWidgets('clear result overlay displays result and blocks background', (
    tester,
  ) async {
    var homeCount = 0;
    var nextCount = 0;
    var retryCount = 0;
    var behindTapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Center(
                child: ElevatedButton(
                  key: const Key('behind_button'),
                  onPressed: () => behindTapCount += 1,
                  child: const Text('behind'),
                ),
              ),
              ClearResultOverlay(
                level: 1,
                moveCount: 2,
                onRetry: () => retryCount += 1,
                onHome: () => homeCount += 1,
                onNextLevel: () => nextCount += 1,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('clear_result_overlay')), findsOneWidget);
    expect(find.byKey(const Key('clear_result_card')), findsOneWidget);
    expect(find.byKey(const Key('clear_result_title')), findsOneWidget);
    expect(find.text(AppStrings.clearResultTitle), findsOneWidget);
    expect(find.text('Level 1'), findsOneWidget);
    expect(find.text('${AppStrings.moveCountPrefix} 2회'), findsOneWidget);
    expect(find.byKey(const Key('clear_retry_button')), findsOneWidget);
    expect(find.text(AppStrings.retryButton), findsOneWidget);
    expect(find.text(AppStrings.homeButton), findsOneWidget);
    expect(find.text(AppStrings.nextLevelButton), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('behind_button')),
      warnIfMissed: false,
    );
    expect(behindTapCount, 0);

    await tester.tap(find.byKey(const Key('clear_next_level_button')));
    await tester.pump();
    expect(nextCount, 1);
    expect(retryCount, 0);
    expect(homeCount, 0);

    await tester.tap(find.byKey(const Key('clear_retry_button')));
    await tester.pump();
    expect(nextCount, 1);
    expect(retryCount, 1);
    expect(homeCount, 0);

    await tester.tap(find.byKey(const Key('clear_home_button')));
    await tester.pump();
    expect(nextCount, 1);
    expect(retryCount, 1);
    expect(homeCount, 1);
  });

  testWidgets('clear result overlay fits on a small screen', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              ClearResultOverlay(
                level: 1,
                moveCount: 2,
                onRetry: () {},
                onHome: () {},
                onNextLevel: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('clear_result_card')), findsOneWidget);
    expect(find.byKey(const Key('clear_next_level_button')), findsOneWidget);
    expect(find.byKey(const Key('clear_retry_button')), findsOneWidget);
    expect(find.byKey(const Key('clear_home_button')), findsOneWidget);
    expect(find.text(AppStrings.nextLevelButton), findsOneWidget);
    expect(find.text(AppStrings.retryButton), findsOneWidget);
    expect(find.text(AppStrings.homeButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small game screen lays out clues without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: GameScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('clue_panel')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small game screen supports restart and clear retry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: GameScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('book_green_cloud')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book_blue_moon')));
    await _finishSwap(tester);
    await _settleClueState(tester);
    await tester.tap(find.byKey(const Key('game_restart_button')));
    await tester.pumpAndSettle();

    expect(_visibleBookOrder(tester), _demoBookIds);
    expect(find.text('${AppStrings.moveCountPrefix} 0회'), findsOneWidget);

    await _clearDemoGame(tester);
    await tester.tap(find.byKey(const Key('clear_retry_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('clear_result_overlay')), findsNothing);
    expect(_visibleBookOrder(tester), _demoBookIds);
    expect(tester.takeException(), isNull);
  });

  test('game controller starts in idle state with no selected book', () {
    final controller = GameController(
      initialPlacements: demoBookshelfPlacements,
      initialClues: demoClues,
    );

    expect(controller.selectedBookId, isNull);
    expect(controller.moveCount, 0);
    expect(controller.status, GameStatus.idle);
    expect(controller.isAnimating, isFalse);
    expect(controller.canAcceptInput, isTrue);
    expect(controller.canRestart, isTrue);
    expect(controller.activeSwap, isNull);
    expect(controller.initialPlacements, demoBookshelfPlacements);
    expect(controller.placements, demoBookshelfPlacements);
    expect(controller.clues, demoClues);
    expect(controller.satisfiedClueIds, isEmpty);
    expect(controller.satisfiedClueCount, 0);
    expect(controller.areAllCluesSatisfied, isFalse);
    expect(controller.hasClearTriggered, isFalse);
    expect(controller.clearStepIndex, -1);
    expect(controller.clearActiveBookId, isNull);
    expect(controller.boardRevision, 0);
    expect(controller.isInputLocked, isFalse);
    controller.dispose();
  });

  test('game controller keeps clues ordered and unmodifiable', () {
    final mutableClues = List<Clue>.of(demoClues);
    final controller = GameController(
      initialPlacements: demoBookshelfPlacements,
      initialClues: mutableClues,
    );

    mutableClues.clear();

    expect(controller.clues, demoClues);
    expect(() => controller.clues.add(demoClues.first), throwsUnsupportedError);
    expect(
      () => controller.clues.remove(demoClues.first),
      throwsUnsupportedError,
    );
    expect(controller.clues.map((clue) => clue.id), [
      'c02_blue_moon_left_edge',
      'c04_green_cloud_right_of_yellow_key',
      'c05_red_star_right_of_blue_moon',
    ]);
    controller.dispose();
  });

  test('game controller exposes unmodifiable satisfied clue ids', () {
    final controller = GameController(
      initialPlacements: _completedDemoPlacements,
      initialClues: demoClues,
    );

    expect(controller.satisfiedClueCount, 3);
    expect(
      () => controller.satisfiedClueIds.add('manual_id'),
      throwsUnsupportedError,
    );
    expect(
      () => controller.satisfiedClueIds.remove('c02_blue_moon_left_edge'),
      throwsUnsupportedError,
    );
    controller.dispose();
  });

  test('game controller does not treat empty or wrong clue ids as clear', () {
    final emptyController = GameController(
      initialPlacements: _completedDemoPlacements,
      initialClues: const [],
    );
    final wrongIdsController = GameController(
      initialPlacements: _completedDemoPlacements,
      initialClues: demoClues,
      clueEvaluator: const _WrongIdClueEvaluator(),
    );

    expect(emptyController.areAllCluesSatisfied, isFalse);
    expect(emptyController.hasClearTriggered, isFalse);
    expect(wrongIdsController.satisfiedClueCount, 3);
    expect(wrongIdsController.areAllCluesSatisfied, isFalse);

    emptyController.dispose();
    wrongIdsController.dispose();
  });

  test('game controller selects a tapped book', () {
    final controller = GameController(
      initialPlacements: demoBookshelfPlacements,
      initialClues: demoClues,
    );

    controller.handleBookTap('blue_moon');

    expect(controller.selectedBookId, 'blue_moon');
    expect(controller.moveCount, 0);
    expect(controller.status, GameStatus.idle);
    expect(controller.satisfiedClueIds, isEmpty);
    expect(_bookIdsBySlot(controller.placements), [
      'green_cloud',
      'blue_moon',
      'yellow_key',
      'red_star',
    ]);
    controller.dispose();
  });

  test('game controller toggles the same selected book off', () {
    final controller = GameController(
      initialPlacements: demoBookshelfPlacements,
      initialClues: demoClues,
    );

    controller.handleBookTap('blue_moon');
    controller.handleBookTap('blue_moon');

    expect(controller.selectedBookId, isNull);
    expect(controller.moveCount, 0);
    expect(controller.status, GameStatus.idle);
    expect(controller.satisfiedClueIds, isEmpty);
    expect(_bookIdsBySlot(controller.placements), [
      'green_cloud',
      'blue_moon',
      'yellow_key',
      'red_star',
    ]);
    controller.dispose();
  });

  test('game controller swaps positions and enters animating state', () {
    final controller = GameController(
      initialPlacements: demoBookshelfPlacements,
      initialClues: demoClues,
    );

    controller.handleBookTap('blue_moon');
    controller.handleBookTap('red_star');

    expect(controller.selectedBookId, isNull);
    expect(controller.moveCount, 1);
    expect(controller.status, GameStatus.animating);
    expect(controller.isAnimating, isTrue);
    expect(controller.canAcceptInput, isFalse);
    expect(controller.activeSwap?.firstBookId, 'blue_moon');
    expect(controller.activeSwap?.secondBookId, 'red_star');
    expect(controller.satisfiedClueIds, isEmpty);
    expect(
      _positionOf(controller.placements, 'blue_moon'),
      const BookPosition(tierIndex: 0, slotIndex: 3),
    );
    expect(
      _positionOf(controller.placements, 'red_star'),
      const BookPosition(tierIndex: 0, slotIndex: 1),
    );
    expect(_bookIdsBySlot(controller.placements), [
      'green_cloud',
      'red_star',
      'yellow_key',
      'blue_moon',
    ]);
    controller.dispose();
  });

  test('game controller returns to idle after swap duration', () async {
    final controller = GameController(
      initialPlacements: demoBookshelfPlacements,
      initialClues: demoClues,
      swapDuration: _shortSwapDuration,
    );
    var notificationCount = 0;
    controller.addListener(() => notificationCount += 1);

    controller.handleBookTap('blue_moon');
    controller.handleBookTap('red_star');

    expect(controller.status, GameStatus.animating);
    expect(controller.activeSwap, isNotNull);
    expect(notificationCount, 2);

    await _waitForShortSwap();

    expect(controller.status, GameStatus.idle);
    expect(controller.isAnimating, isFalse);
    expect(controller.canAcceptInput, isTrue);
    expect(controller.activeSwap, isNull);
    expect(notificationCount, 3);
    controller.dispose();
  });

  test(
    'game controller evaluates clues only after swap animation ends',
    () async {
      final controller = GameController(
        initialPlacements: demoBookshelfPlacements,
        initialClues: demoClues,
        swapDuration: _shortSwapDuration,
      );
      var notificationCount = 0;
      controller.addListener(() => notificationCount += 1);

      controller.handleBookTap('green_cloud');
      controller.handleBookTap('blue_moon');

      expect(controller.status, GameStatus.animating);
      expect(controller.satisfiedClueIds, isEmpty);
      expect(controller.satisfiedClueCount, 0);
      expect(notificationCount, 2);

      await _waitForShortSwap();

      expect(controller.status, GameStatus.idle);
      expect(controller.satisfiedClueIds, {'c02_blue_moon_left_edge'});
      expect(controller.satisfiedClueCount, 1);
      expect(notificationCount, 3);
      controller.dispose();
    },
  );

  test(
    'game controller starts clearing once all clues are satisfied',
    () async {
      final controller = GameController(
        initialPlacements: demoBookshelfPlacements,
        initialClues: demoClues,
        swapDuration: _shortSwapDuration,
        clueCompletionDelay: _longClearDuration,
        clearBookStepDuration: _longClearDuration,
        clearFinalGlowDuration: _longClearDuration,
      );

      controller.handleBookTap('green_cloud');
      controller.handleBookTap('blue_moon');
      await _waitForShortSwap();
      expect(controller.status, GameStatus.idle);
      expect(controller.satisfiedClueCount, 1);
      expect(controller.hasClearTriggered, isFalse);

      controller.handleBookTap('green_cloud');
      controller.handleBookTap('red_star');
      expect(controller.status, GameStatus.animating);
      expect(controller.satisfiedClueCount, 1);
      expect(controller.hasClearTriggered, isFalse);
      await _waitForShortSwap();

      expect(controller.status, GameStatus.clearing);
      expect(controller.isClearing, isTrue);
      expect(controller.isInputLocked, isTrue);
      expect(controller.canAcceptGameInput, isFalse);
      expect(controller.satisfiedClueIds, {
        'c02_blue_moon_left_edge',
        'c04_green_cloud_right_of_yellow_key',
        'c05_red_star_right_of_blue_moon',
      });
      expect(controller.areAllCluesSatisfied, isTrue);
      expect(controller.hasClearTriggered, isTrue);
      expect(controller.selectedBookId, isNull);
      expect(controller.activeSwap, isNull);

      final moveCount = controller.moveCount;
      final order = _bookIdsBySlot(controller.placements);
      var notificationCount = 0;
      controller.addListener(() => notificationCount += 1);

      controller.handleBookTap('blue_moon');
      controller.cancelSelection();

      expect(controller.moveCount, moveCount);
      expect(_bookIdsBySlot(controller.placements), order);
      expect(controller.selectedBookId, isNull);
      expect(notificationCount, 0);
      controller.dispose();
    },
  );

  test('game controller advances clear steps and reaches cleared', () async {
    final controller = GameController(
      initialPlacements: demoBookshelfPlacements,
      initialClues: demoClues,
      swapDuration: _shortSwapDuration,
      clueCompletionDelay: _shortClearDuration,
      clearBookStepDuration: _shortClearDuration,
      clearFinalGlowDuration: _shortClearDuration,
    );
    final observedSteps = <int>[];
    final observedActiveBookIds = <String>[];
    controller.addListener(() {
      observedSteps.add(controller.clearStepIndex);
      final activeBookId = controller.clearActiveBookId;
      if (activeBookId != null) {
        observedActiveBookIds.add(activeBookId);
      }
    });

    controller.handleBookTap('green_cloud');
    controller.handleBookTap('blue_moon');
    await _waitForShortSwap();
    controller.handleBookTap('green_cloud');
    controller.handleBookTap('red_star');
    await _waitForShortSwap();

    expect(controller.status, GameStatus.clearing);
    expect(controller.clearStepIndex, -1);
    expect(controller.clearActiveBookId, isNull);

    for (var i = 0; i < 8; i += 1) {
      await _waitForShortClear();
    }

    expect(controller.status, GameStatus.cleared);
    expect(controller.isCleared, isTrue);
    expect(controller.hasClearTriggered, isTrue);
    expect(controller.satisfiedClueCount, 3);
    expect(controller.moveCount, 2);
    expect(_bookIdsBySlot(controller.placements), [
      'blue_moon',
      'red_star',
      'yellow_key',
      'green_cloud',
    ]);
    expect(observedSteps, containsAllInOrder([-1, 0, 1, 2, 3]));
    expect(
      observedActiveBookIds,
      containsAllInOrder([
        'blue_moon',
        'red_star',
        'yellow_key',
        'green_cloud',
      ]),
    );

    final notificationCount = observedSteps.length;
    controller.handleBookTap('blue_moon');
    controller.cancelSelection();
    expect(observedSteps, hasLength(notificationCount));
    controller.dispose();
  });

  test('game controller does not evaluate clues after dispose', () async {
    final evaluator = _CountingClueEvaluator();
    final controller = GameController(
      initialPlacements: demoBookshelfPlacements,
      initialClues: demoClues,
      swapDuration: _shortSwapDuration,
      clueEvaluator: evaluator,
    );
    var notificationCount = 0;
    controller.addListener(() => notificationCount += 1);

    expect(evaluator.evaluateAllCallCount, 1);

    controller.handleBookTap('green_cloud');
    controller.handleBookTap('blue_moon');
    controller.dispose();
    await _waitForShortSwap();

    expect(evaluator.evaluateAllCallCount, 1);
    expect(notificationCount, 2);
  });

  test(
    'game controller keeps clues while selecting, swapping, and settling',
    () async {
      final controller = GameController(
        initialPlacements: demoBookshelfPlacements,
        initialClues: demoClues,
        swapDuration: _shortSwapDuration,
      );

      controller.handleBookTap('blue_moon');
      expect(controller.clues, demoClues);

      controller.handleBookTap('red_star');
      expect(controller.clues, demoClues);

      await _waitForShortSwap();

      expect(controller.status, GameStatus.idle);
      expect(controller.clues, demoClues);
      controller.dispose();
    },
  );

  test(
    'game controller ignores book taps and cancel while animating',
    () async {
      final controller = GameController(
        initialPlacements: demoBookshelfPlacements,
        initialClues: demoClues,
        swapDuration: _shortSwapDuration,
      );
      var notificationCount = 0;
      controller.addListener(() => notificationCount += 1);

      controller.handleBookTap('blue_moon');
      controller.handleBookTap('red_star');
      controller.handleBookTap('green_cloud');
      controller.cancelSelection();
      controller.handleBookTap('yellow_key');

      expect(controller.selectedBookId, isNull);
      expect(controller.moveCount, 1);
      expect(controller.status, GameStatus.animating);
      expect(_bookIdsBySlot(controller.placements), [
        'green_cloud',
        'red_star',
        'yellow_key',
        'blue_moon',
      ]);
      expect(notificationCount, 2);

      await _waitForShortSwap();

      expect(controller.status, GameStatus.idle);
      expect(notificationCount, 3);
      controller.dispose();
    },
  );

  test(
    'game controller supports two swaps after animation completes',
    () async {
      final controller = GameController(
        initialPlacements: demoBookshelfPlacements,
        initialClues: demoClues,
        swapDuration: _shortSwapDuration,
      );

      controller.handleBookTap('blue_moon');
      controller.handleBookTap('red_star');
      await _waitForShortSwap();
      controller.handleBookTap('green_cloud');
      controller.handleBookTap('yellow_key');

      expect(controller.selectedBookId, isNull);
      expect(controller.moveCount, 2);
      expect(controller.status, GameStatus.animating);
      expect(_bookIdsBySlot(controller.placements), [
        'yellow_key',
        'red_star',
        'green_cloud',
        'blue_moon',
      ]);
      controller.dispose();
    },
  );

  test('game controller cancels an active selection', () {
    final controller = GameController(
      initialPlacements: demoBookshelfPlacements,
      initialClues: demoClues,
    );

    controller.handleBookTap('blue_moon');
    controller.cancelSelection();

    expect(controller.selectedBookId, isNull);
    expect(controller.moveCount, 0);
    expect(controller.status, GameStatus.idle);
    expect(_bookIdsBySlot(controller.placements), [
      'green_cloud',
      'blue_moon',
      'yellow_key',
      'red_star',
    ]);
    controller.dispose();
  });

  test('game controller ignores cancel when no book is selected', () {
    final controller = GameController(
      initialPlacements: demoBookshelfPlacements,
      initialClues: demoClues,
    );

    controller.cancelSelection();

    expect(controller.selectedBookId, isNull);
    expect(controller.moveCount, 0);
    expect(controller.status, GameStatus.idle);
    controller.dispose();
  });

  test('game controller ignores unknown book ids', () {
    final controller = GameController(
      initialPlacements: demoBookshelfPlacements,
      initialClues: demoClues,
    );
    var notificationCount = 0;
    controller.addListener(() => notificationCount += 1);

    controller.handleBookTap('unknown_book');

    expect(controller.selectedBookId, isNull);
    expect(controller.moveCount, 0);
    expect(controller.status, GameStatus.idle);
    expect(notificationCount, 0);
    controller.dispose();
  });

  test('game controller keeps list order while swapping positions', () async {
    final controller = GameController(
      initialPlacements: demoBookshelfPlacements,
      initialClues: demoClues,
      swapDuration: _shortSwapDuration,
    );
    final initialListOrder = controller.placements
        .map((placement) => placement.book.id)
        .toList();

    controller.handleBookTap('green_cloud');
    controller.handleBookTap('blue_moon');
    await _waitForShortSwap();
    controller.handleBookTap('yellow_key');
    controller.handleBookTap('red_star');

    expect(
      controller.placements.map((placement) => placement.book.id),
      initialListOrder,
    );
    expect(controller.moveCount, 2);
    controller.dispose();
  });

  test('game controller exposes an unmodifiable placement list', () {
    final controller = GameController(
      initialPlacements: demoBookshelfPlacements,
      initialClues: demoClues,
    );

    expect(
      () => controller.placements.add(demoBookshelfPlacements.first),
      throwsUnsupportedError,
    );
    controller.dispose();
  });

  test(
    'game controller stores initial placements defensively and unmodifiable',
    () {
      final initialPlacements = List<BookPlacement>.of(demoBookshelfPlacements);
      final controller = GameController(
        initialPlacements: initialPlacements,
        initialClues: demoClues,
      );

      initialPlacements
        ..clear()
        ..add(_demoPlacement('red_star', 0));

      expect(controller.initialPlacements, isNot(same(initialPlacements)));
      expect(controller.placements, isNot(same(controller.initialPlacements)));
      expect(_bookIdsBySlot(controller.initialPlacements), _demoBookIds);
      expect(_bookIdsBySlot(controller.placements), _demoBookIds);
      expect(
        () => controller.initialPlacements.add(demoBookshelfPlacements.first),
        throwsUnsupportedError,
      );

      controller.handleBookTap('green_cloud');
      controller.handleBookTap('blue_moon');

      expect(
        _positionOf(controller.initialPlacements, 'green_cloud'),
        const BookPosition(tierIndex: 0, slotIndex: 0),
      );
      expect(
        _positionOf(controller.placements, 'green_cloud'),
        const BookPosition(tierIndex: 0, slotIndex: 1),
      );
      controller.dispose();
    },
  );

  test('game controller restarts selected idle state once', () {
    final controller = GameController(
      initialPlacements: demoBookshelfPlacements,
      initialClues: demoClues,
    );
    var notificationCount = 0;
    controller.addListener(() => notificationCount += 1);

    controller.handleBookTap('blue_moon');
    expect(controller.selectedBookId, 'blue_moon');
    expect(notificationCount, 1);

    notificationCount = 0;
    controller.restart();

    _expectInitialDemoControllerState(controller, boardRevision: 1);
    expect(notificationCount, 1);
    controller.dispose();
  });

  test(
    'game controller restarts after progress and reevaluates clues',
    () async {
      final controller = GameController(
        initialPlacements: demoBookshelfPlacements,
        initialClues: demoClues,
        swapDuration: _shortSwapDuration,
      );

      controller.handleBookTap('green_cloud');
      controller.handleBookTap('blue_moon');
      await _waitForShortSwap();

      expect(controller.status, GameStatus.idle);
      expect(controller.moveCount, 1);
      expect(controller.satisfiedClueIds, {'c02_blue_moon_left_edge'});
      expect(_bookIdsBySlot(controller.placements), [
        'blue_moon',
        'green_cloud',
        'yellow_key',
        'red_star',
      ]);

      var notificationCount = 0;
      controller.addListener(() => notificationCount += 1);
      controller.restart();

      _expectInitialDemoControllerState(controller, boardRevision: 1);
      expect(notificationCount, 1);
      controller.dispose();
    },
  );

  test('game controller restarts after multiple swaps', () async {
    final controller = GameController(
      initialPlacements: demoBookshelfPlacements,
      initialClues: demoClues,
      swapDuration: _shortSwapDuration,
    );

    controller.handleBookTap('blue_moon');
    controller.handleBookTap('red_star');
    await _waitForShortSwap();
    controller.handleBookTap('green_cloud');
    controller.handleBookTap('yellow_key');
    await _waitForShortSwap();

    expect(controller.moveCount, 2);
    expect(_bookIdsBySlot(controller.placements), [
      'yellow_key',
      'red_star',
      'green_cloud',
      'blue_moon',
    ]);

    controller.restart();

    _expectInitialDemoControllerState(controller, boardRevision: 1);
    controller.dispose();
  });

  test(
    'game controller restarts from cleared and can clear the same puzzle again',
    () async {
      final controller = GameController(
        initialPlacements: demoBookshelfPlacements,
        initialClues: demoClues,
        swapDuration: _shortSwapDuration,
        clueCompletionDelay: _shortClearDuration,
        clearBookStepDuration: _shortClearDuration,
        clearFinalGlowDuration: _shortClearDuration,
      );
      final initialClueIds = controller.clues.map((clue) => clue.id).toList();

      await _solveDemoControllerToClearing(controller);
      await _finishControllerClear();

      expect(controller.status, GameStatus.cleared);
      expect(controller.hasClearTriggered, isTrue);

      var notificationCount = 0;
      controller.addListener(() => notificationCount += 1);
      controller.restart();

      _expectInitialDemoControllerState(controller, boardRevision: 1);
      expect(controller.clues.map((clue) => clue.id), initialClueIds);
      expect(notificationCount, 1);

      notificationCount = 0;
      await _solveDemoControllerToClearing(controller);
      await _finishControllerClear();

      expect(controller.status, GameStatus.cleared);
      expect(controller.hasClearTriggered, isTrue);
      expect(controller.moveCount, 2);
      expect(controller.boardRevision, 1);
      expect(notificationCount, greaterThan(0));
      controller.dispose();
    },
  );

  test('game controller ignores restart while animating or clearing', () async {
    final animatingController = GameController(
      initialPlacements: demoBookshelfPlacements,
      initialClues: demoClues,
      swapDuration: _shortSwapDuration,
    );

    animatingController.handleBookTap('blue_moon');
    animatingController.handleBookTap('red_star');

    final animatingOrder = _bookIdsBySlot(animatingController.placements);
    var animatingNotifications = 0;
    animatingController.addListener(() => animatingNotifications += 1);
    animatingController.restart();

    expect(animatingNotifications, 0);
    expect(animatingController.status, GameStatus.animating);
    expect(animatingController.boardRevision, 0);
    expect(_bookIdsBySlot(animatingController.placements), animatingOrder);

    await _waitForShortSwap();

    expect(animatingController.status, GameStatus.idle);
    expect(animatingController.moveCount, 1);
    expect(animatingNotifications, 1);
    animatingController.dispose();

    final clearingController = GameController(
      initialPlacements: demoBookshelfPlacements,
      initialClues: demoClues,
      swapDuration: _shortSwapDuration,
      clueCompletionDelay: _longClearDuration,
      clearBookStepDuration: _longClearDuration,
      clearFinalGlowDuration: _longClearDuration,
    );

    await _solveDemoControllerToClearing(clearingController);

    expect(clearingController.status, GameStatus.clearing);
    final clearingOrder = _bookIdsBySlot(clearingController.placements);
    var clearingNotifications = 0;
    clearingController.addListener(() => clearingNotifications += 1);
    clearingController.restart();

    expect(clearingNotifications, 0);
    expect(clearingController.status, GameStatus.clearing);
    expect(clearingController.boardRevision, 0);
    expect(clearingController.moveCount, 2);
    expect(_bookIdsBySlot(clearingController.placements), clearingOrder);
    clearingController.dispose();
  });

  test('game controller ignores visually identical book swaps', () {
    const duplicatePlacements = <BookPlacement>[
      BookPlacement(
        book: Book(
          id: 'blue_moon_a',
          color: BookColor.blue,
          symbol: BookSymbol.moon,
        ),
        position: BookPosition(tierIndex: 0, slotIndex: 0),
      ),
      BookPlacement(
        book: Book(
          id: 'blue_moon_b',
          color: BookColor.blue,
          symbol: BookSymbol.moon,
        ),
        position: BookPosition(tierIndex: 0, slotIndex: 1),
      ),
    ];
    final controller = GameController(
      initialPlacements: duplicatePlacements,
      initialClues: demoClues,
    );
    var notificationCount = 0;
    controller.addListener(() => notificationCount += 1);

    controller.handleBookTap('blue_moon_a');
    controller.handleBookTap('blue_moon_b');

    expect(controller.selectedBookId, isNull);
    expect(controller.moveCount, 0);
    expect(controller.status, GameStatus.idle);
    expect(controller.activeSwap, isNull);
    expect(
      _positionOf(controller.placements, 'blue_moon_a'),
      const BookPosition(tierIndex: 0, slotIndex: 0),
    );
    expect(
      _positionOf(controller.placements, 'blue_moon_b'),
      const BookPosition(tierIndex: 0, slotIndex: 1),
    );
    expect(notificationCount, 2);
    controller.dispose();
  });

  test('game controller does not mutate the input list', () {
    final initialPlacements = List<BookPlacement>.of(demoBookshelfPlacements);
    final controller = GameController(
      initialPlacements: initialPlacements,
      initialClues: demoClues,
    );

    controller.handleBookTap('blue_moon');
    controller.handleBookTap('red_star');

    expect(_bookIdsBySlot(initialPlacements), [
      'green_cloud',
      'blue_moon',
      'yellow_key',
      'red_star',
    ]);
    expect(_bookIdsBySlot(controller.placements), [
      'green_cloud',
      'red_star',
      'yellow_key',
      'blue_moon',
    ]);
    controller.dispose();
  });

  test('game controller keeps book identity while swapping positions', () {
    final controller = GameController(
      initialPlacements: demoBookshelfPlacements,
      initialClues: demoClues,
    );
    final initialBooks = {
      for (final placement in controller.placements)
        placement.book.id: placement.book,
    };

    controller.handleBookTap('blue_moon');
    controller.handleBookTap('red_star');

    for (final placement in controller.placements) {
      expect(placement.book, initialBooks[placement.book.id]);
    }
    controller.dispose();
  });

  test('game controller does not notify for ignored animation input', () async {
    final controller = GameController(
      initialPlacements: demoBookshelfPlacements,
      initialClues: demoClues,
      swapDuration: _shortSwapDuration,
    );
    var notificationCount = 0;
    controller.addListener(() => notificationCount += 1);

    controller.cancelSelection();
    controller.handleBookTap('unknown_book');
    controller.handleBookTap('blue_moon');
    controller.handleBookTap('red_star');
    controller.handleBookTap('green_cloud');
    controller.cancelSelection();

    expect(notificationCount, 2);
    expect(controller.selectedBookId, isNull);
    expect(controller.moveCount, 1);
    expect(controller.status, GameStatus.animating);

    await _waitForShortSwap();

    expect(notificationCount, 3);
    expect(controller.status, GameStatus.idle);
    controller.dispose();
  });

  testWidgets('game screen starts with no selected book', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: GameScreen()));

    expect(find.text(AppStrings.selectFirstBook), findsOneWidget);
  });

  testWidgets('tapping a book selects it', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: GameScreen()));

    await tester.tap(find.byKey(const Key('book_blue_moon')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        '${AppStrings.selectedBookPrefix} 파란 달 책 · ${AppStrings.selectSecondBook}',
      ),
      findsOneWidget,
    );
    expect(find.text('${AppStrings.moveCountPrefix} 0회'), findsOneWidget);
    expect(_visibleBookOrder(tester), [
      'green_cloud',
      'blue_moon',
      'yellow_key',
      'red_star',
    ]);
  });

  testWidgets('selection effect lifts the tapped book', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: GameScreen()));
    final initialTop = _bookTopOf(tester, 'blue_moon');

    await tester.tap(find.byKey(const Key('book_blue_moon')));
    await tester.pumpAndSettle();

    expect(_bookTopOf(tester, 'blue_moon'), lessThan(initialTop));

    await tester.tap(find.byKey(const Key('book_blue_moon')));
    await tester.pumpAndSettle();

    expect(
      _bookTopOf(tester, 'blue_moon'),
      moreOrLessEquals(initialTop, epsilon: 0.1),
    );
  });

  testWidgets('tapping the same book clears selection', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: GameScreen()));

    await tester.tap(find.byKey(const Key('book_blue_moon')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book_blue_moon')));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.selectFirstBook), findsOneWidget);
    expect(find.text('${AppStrings.moveCountPrefix} 0회'), findsOneWidget);
    expect(_visibleBookOrder(tester), [
      'green_cloud',
      'blue_moon',
      'yellow_key',
      'red_star',
    ]);
  });

  testWidgets('restart button exists and resets selected book', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: GameScreen()));

    expect(find.byKey(const Key('game_restart_button')), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('game_restart_button')))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('book_blue_moon')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        '${AppStrings.selectedBookPrefix} 파란 달 책 · ${AppStrings.selectSecondBook}',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('game_restart_button')));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.selectFirstBook), findsOneWidget);
    expect(find.text('${AppStrings.moveCountPrefix} 0회'), findsOneWidget);
    expect(find.text('${AppStrings.clueTitle} 0/3'), findsOneWidget);
    expect(_visibleBookOrder(tester), _demoBookIds);
    _expectNoDemoChecks();
  });

  testWidgets('valid swap shows animating status immediately', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: GameScreen()));

    await tester.tap(find.byKey(const Key('book_blue_moon')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book_red_star')));
    await tester.pump();

    expect(find.text(AppStrings.swappingBooks), findsOneWidget);
    expect(find.text('${AppStrings.moveCountPrefix} 1회'), findsOneWidget);
    expect(find.text(AppStrings.selectFirstBook), findsNothing);

    await _finishSwap(tester);
  });

  testWidgets('books animate between swapped slot positions', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: GameScreen()));
    final blueStart = _bookCenterXOf(tester, 'blue_moon');
    final redStart = _bookCenterXOf(tester, 'red_star');

    await tester.tap(find.byKey(const Key('book_blue_moon')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book_red_star')));
    await tester.pump();
    await tester.pump(_halfSwapDuration);

    final blueMid = _bookCenterXOf(tester, 'blue_moon');
    final redMid = _bookCenterXOf(tester, 'red_star');
    expect(blueMid, greaterThan(blueStart));
    expect(blueMid, lessThan(redStart));
    expect(redMid, lessThan(redStart));
    expect(redMid, greaterThan(blueStart));

    await _finishSwap(tester);

    expect(_bookCenterXOf(tester, 'blue_moon'), greaterThan(redStart - 1));
    expect(_bookCenterXOf(tester, 'red_star'), lessThan(blueStart + 1));
  });

  testWidgets('swap completion clears animation status and finalizes order', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: GameScreen()));

    await tester.tap(find.byKey(const Key('book_blue_moon')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book_red_star')));
    await tester.pump();

    expect(find.text(AppStrings.swappingBooks), findsOneWidget);

    await _finishSwap(tester);

    expect(find.text(AppStrings.selectFirstBook), findsOneWidget);
    expect(find.text('${AppStrings.moveCountPrefix} 1회'), findsOneWidget);
    expect(_visibleBookOrder(tester), [
      'green_cloud',
      'red_star',
      'yellow_key',
      'blue_moon',
    ]);
  });

  testWidgets('clues remain fixed after swapping books', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: GameScreen()));

    await tester.tap(find.byKey(const Key('book_blue_moon')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book_red_star')));
    await _finishSwap(tester);

    expect(find.text('${AppStrings.moveCountPrefix} 1회'), findsOneWidget);
    expect(find.text('${AppStrings.clueTitle} 0/3'), findsOneWidget);
    _expectDemoCluesVisible();
  });

  testWidgets('restart restores initial board after a completed swap', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: GameScreen()));

    await tester.tap(find.byKey(const Key('book_green_cloud')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book_blue_moon')));
    await _finishSwap(tester);
    await _settleClueState(tester);

    expect(_visibleBookOrder(tester), [
      'blue_moon',
      'green_cloud',
      'yellow_key',
      'red_star',
    ]);
    expect(find.text('${AppStrings.moveCountPrefix} 1회'), findsOneWidget);
    expect(find.text('${AppStrings.clueTitle} 1/3'), findsOneWidget);
    _expectOnlyDemoChecks(['c02_blue_moon_left_edge']);

    await tester.tap(find.byKey(const Key('game_restart_button')));
    await tester.pump();

    expect(_visibleBookOrder(tester), _demoBookIds);
    expect(find.text('${AppStrings.moveCountPrefix} 0회'), findsOneWidget);
    expect(find.text('${AppStrings.clueTitle} 0/3'), findsOneWidget);
    expect(find.text(AppStrings.selectFirstBook), findsOneWidget);
    expect(find.byKey(const Key('clear_result_overlay')), findsNothing);
    expect(find.byKey(const Key('bookshelf_clear_glow')), findsNothing);
    await _settleClueState(tester);
    _expectNoDemoChecks();
  });

  testWidgets('clear flow starts after all clues are satisfied', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: GameScreen()));

    expect(find.text('${AppStrings.clueTitle} 0/3'), findsOneWidget);
    _expectNoDemoChecks();

    await tester.tap(find.byKey(const Key('book_green_cloud')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book_blue_moon')));
    await tester.pump();

    expect(find.text(AppStrings.swappingBooks), findsOneWidget);
    expect(find.text('${AppStrings.clueTitle} 0/3'), findsOneWidget);
    _expectNoDemoChecks();

    await _finishSwap(tester);
    await _settleClueState(tester);

    expect(find.text('${AppStrings.clueTitle} 1/3'), findsOneWidget);
    _expectOnlyDemoChecks(['c02_blue_moon_left_edge']);
    expect(find.byKey(const Key('clear_result_overlay')), findsNothing);

    await tester.tap(find.byKey(const Key('book_green_cloud')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book_red_star')));
    await tester.pump();

    expect(find.text(AppStrings.swappingBooks), findsOneWidget);
    expect(find.byKey(const Key('clear_result_overlay')), findsNothing);

    await _finishSwap(tester);

    expect(find.text('${AppStrings.clueTitle} 3/3'), findsOneWidget);
    expect(find.text(AppStrings.clearingBooks), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('game_restart_button')))
          .onPressed,
      isNull,
    );
    _expectOnlyDemoChecks([
      'c02_blue_moon_left_edge',
      'c04_green_cloud_right_of_yellow_key',
      'c05_red_star_right_of_blue_moon',
    ]);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byKey(const Key('clear_result_overlay')), findsNothing);
    expect(find.text(AppStrings.levelOne), findsOneWidget);

    final orderBeforeLockedTap = _visibleBookOrder(tester);
    await tester.tap(
      find.byKey(const Key('book_blue_moon')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(find.text('${AppStrings.moveCountPrefix} 2회'), findsOneWidget);
    expect(_visibleBookOrder(tester), orderBeforeLockedTap);

    await tester.pump(AppDurations.clueCompletionDelay);
    await tester.pump(const Duration(milliseconds: 1));
    expect(
      _bookTopOf(tester, 'blue_moon'),
      lessThan(_bookTopOf(tester, 'green_cloud')),
    );
    await tester.pump(AppDurations.clearBookStep);
    await tester.pump(const Duration(milliseconds: 1));
    expect(
      _bookTopOf(tester, 'red_star'),
      lessThan(_bookTopOf(tester, 'green_cloud')),
    );
    await tester.pump(AppDurations.clearBookStep);
    await tester.pump(const Duration(milliseconds: 1));
    expect(
      _bookTopOf(tester, 'yellow_key'),
      lessThan(_bookTopOf(tester, 'green_cloud')),
    );
    await tester.pump(AppDurations.clearBookStep);
    await tester.pump(const Duration(milliseconds: 1));
    expect(
      _bookTopOf(tester, 'green_cloud'),
      lessThan(_bookTopOf(tester, 'blue_moon')),
    );
    await tester.pump(AppDurations.clearBookStep);
    expect(find.byKey(const Key('bookshelf_clear_glow')), findsOneWidget);

    await _finishClear(tester);

    expect(find.text(AppStrings.clearedBooks), findsOneWidget);
    expect(find.byKey(const Key('clear_result_overlay')), findsOneWidget);
    expect(find.byKey(const Key('clear_result_card')), findsOneWidget);
    expect(find.byKey(const Key('clear_result_title')), findsOneWidget);
    expect(find.byKey(const Key('clear_retry_button')), findsOneWidget);
    expect(find.text(AppStrings.clearResultTitle), findsOneWidget);
    expect(find.text(AppStrings.retryButton), findsOneWidget);
    expect(find.text('Level 1'), findsWidgets);
    expect(find.text('${AppStrings.moveCountPrefix} 2회'), findsWidgets);
    expect(find.text('${AppStrings.clueTitle} 3/3'), findsOneWidget);
    expect(find.byKey(const Key('clear_result_overlay')), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('book_blue_moon')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(find.text('${AppStrings.moveCountPrefix} 2회'), findsWidgets);
    expect(_visibleBookOrder(tester), orderBeforeLockedTap);

    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('clear_result_overlay')), findsOneWidget);
    _expectDemoCluesVisible();
  });

  testWidgets(
    'cleared overlay handles next level, home, and duplicate display',
    (tester) async {
      await tester.pumpWidget(const BookLogicApp());

      await tester.tap(find.text(AppStrings.continueButton));
      await tester.pumpAndSettle();
      await _clearDemoGame(tester);

      expect(find.byKey(const Key('clear_result_overlay')), findsOneWidget);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('clear_result_overlay')), findsOneWidget);

      await tester.tap(find.byKey(const Key('clear_next_level_button')));
      await tester.pump();

      expect(find.text(AppStrings.nextLevelNextStepMessage), findsOneWidget);
      expect(find.byKey(const Key('clear_result_overlay')), findsOneWidget);
      expect(find.text('Level 1'), findsWidgets);
      expect(find.text('${AppStrings.moveCountPrefix} 2회'), findsWidgets);

      await tester.tap(
        find.byIcon(Icons.settings_rounded),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(find.text(AppStrings.sound), findsNothing);

      await tester.tap(find.byKey(const Key('clear_home_button')));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.appTitle), findsOneWidget);
    },
  );

  testWidgets('clear retry restarts level and allows clearing again', (
    tester,
  ) async {
    await tester.pumpWidget(const BookLogicApp());

    await tester.tap(find.text(AppStrings.continueButton));
    await tester.pumpAndSettle();
    await _clearDemoGame(tester);

    expect(find.byKey(const Key('clear_result_overlay')), findsOneWidget);

    await tester.tap(find.byKey(const Key('clear_retry_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('clear_result_overlay')), findsNothing);
    expect(find.byKey(const Key('bookshelf_clear_glow')), findsNothing);
    expect(find.text(AppStrings.levelOne), findsOneWidget);
    expect(find.text(AppStrings.selectFirstBook), findsOneWidget);
    expect(find.text('${AppStrings.moveCountPrefix} 0회'), findsOneWidget);
    expect(find.text('${AppStrings.clueTitle} 0/3'), findsOneWidget);
    expect(_visibleBookOrder(tester), _demoBookIds);
    _expectNoDemoChecks();
    for (final id in _demoBookIds) {
      expect(find.byKey(Key('book_$id')), findsOneWidget);
    }
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('game_restart_button')))
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.settings_rounded),
          )
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.sound), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await _clearDemoGame(tester);

    expect(find.byKey(const Key('clear_result_overlay')), findsOneWidget);
    expect(find.byKey(const Key('clear_result_overlay')), findsOneWidget);
    expect(find.text('${AppStrings.moveCountPrefix} 2회'), findsWidgets);
  });

  testWidgets('back navigation is safe during clearing and after cleared', (
    tester,
  ) async {
    await tester.pumpWidget(const BookLogicApp());

    await tester.tap(find.text(AppStrings.continueButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book_green_cloud')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book_blue_moon')));
    await _finishSwap(tester);
    await _settleClueState(tester);
    await tester.tap(find.byKey(const Key('book_green_cloud')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book_red_star')));
    await _finishSwap(tester);

    expect(find.text(AppStrings.clearingBooks), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _finishClear(tester);

    expect(find.text(AppStrings.appTitle), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text(AppStrings.continueButton));
    await tester.pumpAndSettle();
    await _clearDemoGame(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.appTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a clue card does not affect book selection or moves', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: GameScreen()));

    await tester.tap(find.byKey(const Key('book_blue_moon')));
    await tester.pumpAndSettle();

    final clueFinder = find.byKey(const Key('clue_c02_blue_moon_left_edge'));
    await tester.ensureVisible(clueFinder);
    await tester.pumpAndSettle();
    await tester.tap(clueFinder);
    await tester.pumpAndSettle();

    expect(
      find.text(
        '${AppStrings.selectedBookPrefix} 파란 달 책 · ${AppStrings.selectSecondBook}',
      ),
      findsOneWidget,
    );
    expect(find.text('${AppStrings.moveCountPrefix} 0회'), findsOneWidget);
    expect(find.text('${AppStrings.clueTitle} 0/3'), findsOneWidget);
    expect(_visibleBookOrder(tester), [
      'green_cloud',
      'blue_moon',
      'yellow_key',
      'red_star',
    ]);
  });

  testWidgets('tapping empty game content clears selection', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: GameScreen()));

    await tester.tap(find.byKey(const Key('book_green_cloud')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        '${AppStrings.selectedBookPrefix} 초록 구름 책 · ${AppStrings.selectSecondBook}',
      ),
      findsOneWidget,
    );

    final backgroundFinder = find.byKey(const Key('game_content_background'));
    final backgroundTopLeft = tester.getTopLeft(backgroundFinder);
    await tester.tapAt(backgroundTopLeft + const Offset(4, 4));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.selectFirstBook), findsOneWidget);
    expect(find.text('${AppStrings.moveCountPrefix} 0회'), findsOneWidget);
    expect(_visibleBookOrder(tester), [
      'green_cloud',
      'blue_moon',
      'yellow_key',
      'red_star',
    ]);
  });

  testWidgets('rapid taps during animation are ignored', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: GameScreen()));

    await tester.tap(find.byKey(const Key('book_blue_moon')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book_red_star')));
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('book_green_cloud')),
      warnIfMissed: false,
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('book_yellow_key')),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(find.text(AppStrings.swappingBooks), findsOneWidget);
    expect(find.text('${AppStrings.moveCountPrefix} 1회'), findsOneWidget);

    await _finishSwap(tester);

    expect(find.text(AppStrings.selectFirstBook), findsOneWidget);
    expect(find.text('${AppStrings.moveCountPrefix} 1회'), findsOneWidget);
    expect(_visibleBookOrder(tester), [
      'green_cloud',
      'red_star',
      'yellow_key',
      'blue_moon',
    ]);
  });

  testWidgets('two swaps update move count and final order', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: GameScreen()));

    await tester.tap(find.byKey(const Key('book_blue_moon')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book_red_star')));
    await _finishSwap(tester);
    await tester.tap(find.byKey(const Key('book_green_cloud')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book_yellow_key')));
    await _finishSwap(tester);

    expect(find.text('${AppStrings.moveCountPrefix} 2회'), findsOneWidget);
    expect(find.text('${AppStrings.clueTitle} 1/3'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    _expectOnlyDemoChecks(['c04_green_cloud_right_of_yellow_key']);
    _expectDemoCluesVisible();
    expect(_visibleBookOrder(tester), [
      'yellow_key',
      'red_star',
      'green_cloud',
      'blue_moon',
    ]);
  });

  testWidgets('move count increments only after valid swaps', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: GameScreen()));

    await tester.tap(find.byKey(const Key('book_green_cloud')));
    await tester.pumpAndSettle();
    expect(find.text('${AppStrings.moveCountPrefix} 0회'), findsOneWidget);
    await tester.tap(find.byKey(const Key('book_red_star')));
    await _finishSwap(tester);

    expect(find.text('${AppStrings.moveCountPrefix} 1회'), findsOneWidget);
  });

  testWidgets('restart button is disabled while books are animating', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: GameScreen()));

    await tester.tap(find.byKey(const Key('book_blue_moon')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book_red_star')));
    await tester.pump();

    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('game_restart_button')))
          .onPressed,
      isNull,
    );
    await tester.tap(
      find.byKey(const Key('game_restart_button')),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(find.text(AppStrings.restartNextStepMessage), findsNothing);
    expect(find.text('${AppStrings.moveCountPrefix} 1회'), findsOneWidget);
    expect(find.text(AppStrings.swappingBooks), findsOneWidget);

    await _finishSwap(tester);
  });

  testWidgets('book and positioned keys remain after swapping', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: GameScreen()));

    for (final id in _demoBookIds) {
      expect(find.byKey(Key('book_$id')), findsOneWidget);
      expect(find.byKey(Key('positioned_$id')), findsOneWidget);
    }

    await tester.tap(find.byKey(const Key('book_blue_moon')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book_red_star')));
    await tester.pump();

    for (final id in _demoBookIds) {
      expect(find.byKey(Key('book_$id')), findsOneWidget);
      expect(find.byKey(Key('positioned_$id')), findsOneWidget);
    }

    await _finishSwap(tester);

    for (final id in _demoBookIds) {
      expect(find.byKey(Key('book_$id')), findsOneWidget);
      expect(find.byKey(Key('positioned_$id')), findsOneWidget);
    }
    expect(find.text('${AppStrings.clueTitle} 0/3'), findsOneWidget);
    _expectDemoCluesVisible();
  });

  testWidgets('existing routing still works from game screen', (tester) async {
    await tester.pumpWidget(const BookLogicApp());

    await tester.tap(find.text(AppStrings.continueButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.sound), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.levelOne), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.appTitle), findsOneWidget);
  });

  testWidgets('leaving game screen during swap cancels timer safely', (
    tester,
  ) async {
    await tester.pumpWidget(const BookLogicApp());

    await tester.tap(find.text(AppStrings.continueButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book_blue_moon')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book_red_star')));
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pump(AppDurations.bookSwap);

    expect(find.text(AppStrings.appTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

const _shortSwapDuration = Duration(milliseconds: 1);
const _shortClearDuration = Duration(milliseconds: 20);
const _longClearDuration = Duration(seconds: 30);
const _halfSwapDuration = Duration(milliseconds: 110);
const _demoBookIds = ['green_cloud', 'blue_moon', 'yellow_key', 'red_star'];

Future<void> _waitForShortSwap() async {
  await Future<void>.delayed(const Duration(milliseconds: 5));
}

Future<void> _waitForShortClear() async {
  await Future<void>.delayed(const Duration(milliseconds: 25));
}

Future<void> _solveDemoControllerToClearing(GameController controller) async {
  controller.handleBookTap('green_cloud');
  controller.handleBookTap('blue_moon');
  await _waitForShortSwap();
  controller.handleBookTap('green_cloud');
  controller.handleBookTap('red_star');
  await _waitForShortSwap();
}

Future<void> _finishControllerClear() async {
  for (var i = 0; i < 8; i += 1) {
    await _waitForShortClear();
  }
}

Future<void> _finishSwap(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(AppDurations.bookSwap);
  await tester.pump();
}

Future<void> _settleClueState(WidgetTester tester) async {
  await tester.pump(AppDurations.clueStateChange);
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump();
}

Future<void> _finishClear(WidgetTester tester) async {
  await tester.pump(AppDurations.clueCompletionDelay);
  for (var i = 0; i < _demoBookIds.length; i += 1) {
    await tester.pump(AppDurations.clearBookStep);
  }
  await tester.pump(AppDurations.clearFinalGlow);
  await tester.pump(AppDurations.resultOverlay);
  await tester.pump();
}

Future<void> _clearDemoGame(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('book_green_cloud')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('book_blue_moon')));
  await _finishSwap(tester);
  await _settleClueState(tester);
  await tester.tap(find.byKey(const Key('book_green_cloud')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('book_red_star')));
  await _finishSwap(tester);
  await _finishClear(tester);
}

void _expectDemoCluesVisible() {
  expect(find.byKey(const Key('clue_c02_blue_moon_left_edge')), findsOneWidget);
  expect(
    find.byKey(const Key('clue_c04_green_cloud_right_of_yellow_key')),
    findsOneWidget,
  );
  expect(
    find.byKey(const Key('clue_c05_red_star_right_of_blue_moon')),
    findsOneWidget,
  );
  expect(find.text('파란 달 책은 1단의 왼쪽 끝에 있다.'), findsOneWidget);
  expect(find.text('초록 구름 책은 1단에서 노란 열쇠 책보다 오른쪽에 있다.'), findsOneWidget);
  expect(find.text('빨간 별 책은 1단에서 파란 달 책 바로 오른쪽에 있다.'), findsOneWidget);
}

List<String?> _clueCardSemanticsLabels(WidgetTester tester) {
  final semanticsFinder = find.descendant(
    of: find.byType(ClueCardWidget),
    matching: find.byType(Semantics),
  );
  return tester
      .widgetList<Semantics>(semanticsFinder)
      .map((semantics) => semantics.properties.label)
      .toList();
}

void _expectNoDemoChecks() {
  _expectOnlyDemoChecks(const []);
}

void _expectOnlyDemoChecks(List<String> satisfiedIds) {
  for (final clue in demoClues) {
    final matcher = satisfiedIds.contains(clue.id)
        ? findsOneWidget
        : findsNothing;
    expect(find.byKey(Key('clue_check_${clue.id}')), matcher);
  }
}

void _expectInitialDemoControllerState(
  GameController controller, {
  int? boardRevision,
}) {
  expect(controller.selectedBookId, isNull);
  expect(controller.moveCount, 0);
  expect(controller.status, GameStatus.idle);
  expect(controller.activeSwap, isNull);
  expect(controller.satisfiedClueIds, isEmpty);
  expect(controller.satisfiedClueCount, 0);
  expect(controller.areAllCluesSatisfied, isFalse);
  expect(controller.hasClearTriggered, isFalse);
  expect(controller.clearStepIndex, -1);
  expect(controller.clearActiveBookId, isNull);
  expect(controller.canRestart, isTrue);
  expect(controller.isInputLocked, isFalse);
  expect(_bookIdsBySlot(controller.placements), _demoBookIds);
  expect(controller.clues, demoClues);
  if (boardRevision != null) {
    expect(controller.boardRevision, boardRevision);
  }
}

List<Book> _booksFromPlacements(List<BookPlacement> placements) {
  final seenBookIds = <String>{};
  final books = <Book>[];

  for (final placement in placements) {
    if (seenBookIds.add(placement.book.id)) {
      books.add(placement.book);
    }
  }
  return books;
}

BookPlacement _demoPlacement(
  String bookId,
  int slotIndex, {
  int tierIndex = 0,
}) {
  final book = demoBookshelfPlacements
      .firstWhere((placement) => placement.book.id == bookId)
      .book;
  return BookPlacement(
    book: book,
    position: BookPosition(tierIndex: tierIndex, slotIndex: slotIndex),
  );
}

final _firstSatisfiedDemoPlacements = [
  _demoPlacement('blue_moon', 0),
  _demoPlacement('green_cloud', 1),
  _demoPlacement('yellow_key', 2),
  _demoPlacement('red_star', 3),
];

final _completedDemoPlacements = [
  _demoPlacement('blue_moon', 0),
  _demoPlacement('red_star', 1),
  _demoPlacement('yellow_key', 2),
  _demoPlacement('green_cloud', 3),
];

final _partiallyBrokenDemoPlacements = [
  _demoPlacement('yellow_key', 0),
  _demoPlacement('red_star', 1),
  _demoPlacement('blue_moon', 2),
  _demoPlacement('green_cloud', 3),
];

List<String> _visibleBookOrder(WidgetTester tester) {
  final entries = [
    for (final id in _demoBookIds)
      MapEntry(id, tester.getCenter(find.byKey(Key('book_$id'))).dx),
  ]..sort((left, right) => left.value.compareTo(right.value));
  return [for (final entry in entries) entry.key];
}

double _bookCenterXOf(WidgetTester tester, String bookId) {
  return tester.getCenter(find.byKey(Key('book_$bookId'))).dx;
}

double _bookTopOf(WidgetTester tester, String bookId) {
  return tester.getTopLeft(find.byKey(Key('book_$bookId'))).dy;
}

BookPosition _positionOf(List<BookPlacement> placements, String bookId) {
  return placements
      .firstWhere((placement) => placement.book.id == bookId)
      .position;
}

List<String> _bookIdsBySlot(List<BookPlacement> placements) {
  final sortedPlacements = placements.toList()
    ..sort(
      (left, right) =>
          left.position.slotIndex.compareTo(right.position.slotIndex),
    );
  return [for (final placement in sortedPlacements) placement.book.id];
}

class _CountingClueEvaluator extends ClueEvaluator {
  int evaluateAllCallCount = 0;

  @override
  Set<String> evaluateAll({
    required List<Clue> clues,
    required List<BookPlacement> placements,
  }) {
    evaluateAllCallCount += 1;
    return super.evaluateAll(clues: clues, placements: placements);
  }
}

class _WrongIdClueEvaluator extends ClueEvaluator {
  const _WrongIdClueEvaluator();

  @override
  Set<String> evaluateAll({
    required List<Clue> clues,
    required List<BookPlacement> placements,
  }) {
    return const {'wrong_1', 'wrong_2', 'wrong_3'};
  }
}
