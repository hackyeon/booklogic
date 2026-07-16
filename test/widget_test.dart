import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:booklogic/app/app.dart';
import 'package:booklogic/core/constants/app_durations.dart';
import 'package:booklogic/core/constants/app_strings.dart';
import 'package:booklogic/core/feedback/application/app_feedback_settings_controller.dart';
import 'package:booklogic/core/feedback/domain/app_feedback_settings.dart';
import 'package:booklogic/core/feedback/data/app_feedback_settings_store.dart';
import 'package:booklogic/core/progress/game_progress.dart';
import 'package:booklogic/core/progress/game_progress_controller.dart';
import 'package:booklogic/core/progress/game_progress_store.dart';
import 'package:booklogic/core/progress/shared_preferences_game_progress_store.dart';
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
import 'package:booklogic/features/game/generator/generated_stage.dart';
import 'package:booklogic/features/game/generator/generator_config.dart';
import 'package:booklogic/features/game/generator/generator_version_policy.dart';
import 'package:booklogic/features/game/generator/stage_generation_attempt_failure.dart';
import 'package:booklogic/features/game/generator/stage_generation_exception.dart';
import 'package:booklogic/features/game/generator/stage_generator.dart';
import 'package:booklogic/features/game/presentation/data/demo_bookshelf_data.dart';
import 'package:booklogic/features/game/presentation/data/demo_clue_data.dart';
import 'package:booklogic/features/game/presentation/formatters/book_label_formatter.dart';
import 'package:booklogic/features/game/presentation/formatters/clue_text_formatter.dart';
import 'package:booklogic/features/game/presentation/game_screen.dart';
import 'package:booklogic/features/game/presentation/widgets/bookshelf_widget.dart';
import 'package:booklogic/features/game/presentation/widgets/book_widget.dart';
import 'package:booklogic/features/game/presentation/widgets/clear_result_overlay.dart';
import 'package:booklogic/features/game/presentation/widgets/clue_card_widget.dart';
import 'package:booklogic/features/game/tutorial/application/learning_progress_store.dart';
import 'package:booklogic/features/game/tutorial/domain/learning_progress.dart';
import 'package:booklogic/features/settings/presentation/settings_screen.dart';

import 'helpers/fake_game_progress_store.dart';
import 'helpers/fake_app_feedback_settings_store.dart';
import 'helpers/fake_game_haptic_player.dart';
import 'helpers/fake_game_sound_player.dart';
import 'helpers/fake_learning_progress_store.dart';

void main() {
  testWidgets('shows home screen and opens game screen', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.appTitle), findsOneWidget);
    expect(find.byKey(const Key('home_continue_button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('home_continue_button')));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.levelOne), findsOneWidget);
    expect(find.text(AppStrings.gameSelectionInstruction), findsOneWidget);
  });

  testWidgets('opens settings screen from home', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.settingsButton));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.sound), findsOneWidget);
    expect(find.text(AppStrings.music), findsNothing);
    expect(find.text(AppStrings.haptic), findsOneWidget);
  });

  testWidgets('home disables continue while progress is loading', (
    tester,
  ) async {
    final blocker = Completer<void>();
    final store = FakeGameProgressStore(readBlocker: blocker);

    await tester.pumpWidget(_app(progressStore: store));
    await tester.pump();

    expect(find.byKey(const Key('game_progress_loading')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('home_continue_button')))
          .onPressed,
      isNull,
    );

    await tester.tap(
      find.byKey(const Key('home_continue_button')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(find.byKey(const Key('book_red_key')), findsNothing);

    blocker.complete();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('game_progress_loading')), findsNothing);
    expect(find.text('계속하기 · Level 1'), findsOneWidget);
  });

  testWidgets('home starts from stored level', (tester) async {
    final store = FakeGameProgressStore(
      progress: GameProgress(
        schemaVersion: 1,
        currentLevel: 6,
        highestUnlockedLevel: 6,
        generatorVersion: 1,
      ),
    );

    await tester.pumpWidget(_app(progressStore: store));
    await tester.pumpAndSettle();

    expect(find.text('계속하기 · Level 6'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home_continue_button')));
    await tester.pumpAndSettle();

    expect(find.text('Level 6'), findsOneWidget);
    expect(
      _visibleBookOrder(tester, _generatedLevel6BookIds),
      _generatedLevel6BookIds,
    );
  });

  testWidgets('app restores progress from shared preferences JSON', (
    tester,
  ) async {
    final progress = GameProgress(
      schemaVersion: 1,
      currentLevel: 2,
      highestUnlockedLevel: 2,
      generatorVersion: 1,
    );
    SharedPreferences.setMockInitialValues({
      SharedPreferencesGameProgressStore.storageKey: progress.encode(),
    });

    await tester.pumpWidget(
      BookLogicApp(
        progressStore: SharedPreferencesGameProgressStore(),
        learningProgressStore: FakeLearningProgressStore(
          progress: LearningProgress(tutorialCompleted: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('계속하기 · Level 2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home_continue_button')));
    await tester.pumpAndSettle();

    expect(find.text('Level 2'), findsOneWidget);
    expect(find.text(_initialClueTitle(2)), findsOneWidget);
    expect(find.text('${AppStrings.moveCountPrefix} 0회'), findsOneWidget);
    expect(
      _visibleBookOrder(tester, _generatedLevel2BookIds),
      _generatedLevel2BookIds,
    );
  });

  testWidgets('app restores level 51 T04 from shared preferences JSON', (
    tester,
  ) async {
    final progress = GameProgress(
      schemaVersion: 1,
      currentLevel: 51,
      highestUnlockedLevel: 51,
      generatorVersion: 1,
    );
    SharedPreferences.setMockInitialValues({
      SharedPreferencesGameProgressStore.storageKey: progress.encode(),
    });

    await tester.pumpWidget(
      BookLogicApp(
        progressStore: SharedPreferencesGameProgressStore(),
        learningProgressStore: FakeLearningProgressStore(
          progress: LearningProgress(tutorialCompleted: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('계속하기 · Level 51'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home_continue_button')));
    await tester.pumpAndSettle();

    expect(find.text('Level 51'), findsOneWidget);
    expect(find.byKey(const Key('bookshelf_tier_0')), findsOneWidget);
    expect(find.byKey(const Key('bookshelf_tier_1')), findsOneWidget);
    expect(find.text(_initialClueTitle(51)), findsOneWidget);
    expect(find.text('${AppStrings.moveCountPrefix} 0회'), findsOneWidget);
    expect(
      _visibleBookGridOrder(tester, _generatedLevel51BookIds),
      _generatedLevel51BookIds,
    );
  });

  testWidgets('app restores level 101 T05 from shared preferences JSON', (
    tester,
  ) async {
    final progress = GameProgress(
      schemaVersion: 1,
      currentLevel: 101,
      highestUnlockedLevel: 101,
      generatorVersion: 1,
    );
    SharedPreferences.setMockInitialValues({
      SharedPreferencesGameProgressStore.storageKey: progress.encode(),
    });

    await tester.pumpWidget(
      BookLogicApp(
        progressStore: SharedPreferencesGameProgressStore(),
        learningProgressStore: FakeLearningProgressStore(
          progress: LearningProgress(tutorialCompleted: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('계속하기 · Level 101'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home_continue_button')));
    await tester.pumpAndSettle();

    expect(find.text('Level 101'), findsOneWidget);
    expect(find.byKey(const Key('bookshelf_tier_0')), findsOneWidget);
    expect(find.byKey(const Key('bookshelf_tier_1')), findsOneWidget);
    expect(find.text(_initialClueTitle(101)), findsOneWidget);
    expect(find.text('${AppStrings.moveCountPrefix} 0회'), findsOneWidget);
    expect(
      _visibleBookGridOrder(tester, _generatedLevel101BookIds),
      _generatedLevel101BookIds,
    );
  });

  testWidgets('corrupted shared preferences progress recovers to level 1', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesGameProgressStore.storageKey:
          '{"schemaVersion":1,"currentLevel":0,"highestUnlockedLevel":0,"generatorVersion":1}',
    });

    await tester.pumpWidget(
      BookLogicApp(
        progressStore: SharedPreferencesGameProgressStore(),
        learningProgressStore: FakeLearningProgressStore(
          progress: LearningProgress(tutorialCompleted: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home_progress_load_warning')), findsNothing);
    expect(find.text('계속하기 · Level 1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home_continue_button')));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.levelOne), findsOneWidget);
    expect(_visibleBookOrder(tester), _generatedLevel1BookIds);
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
    'demo clues are fixed, ordered, unique, and clue types stay append-only',
    () {
      expect(ClueType.values, [
        ClueType.edgePosition,
        ClueType.relativeOrder,
        ClueType.adjacent,
        ClueType.bothEdges,
        ClueType.between,
        ClueType.tierAssignment,
        ClueType.sameTier,
        ClueType.verticalRelation,
        ClueType.notAtEdge,
        ClueType.distance,
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
            tierCount: 1,
            booksPerTier: demoBookshelfPlacements.length,
            selectedBookId: null,
            isAnimating: false,
            activeSwap: null,
            isInteractionLocked: false,
            isClearing: false,
            isCleared: false,
            clearActiveBookId: null,
            isShelfGlowing: false,
            onBookTap: (_) {},
            onEmptyTap: () {},
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
    await tester.pumpWidget(MaterialApp(home: _gameScreen()));

    expect(find.byKey(const Key('game_level_label')), findsOneWidget);
    expect(find.text(AppStrings.levelOne), findsOneWidget);
    for (final bookId in _generatedLevel1BookIds) {
      expect(find.byKey(Key('book_$bookId')), findsOneWidget);
    }
    expect(find.text('${AppStrings.moveCountPrefix} 0회'), findsOneWidget);
    expect(find.text(_initialClueTitle(1)), findsOneWidget);
    expect(find.text(AppStrings.selectFirstBook), findsOneWidget);
  });

  testWidgets('shows generated level 1 clue panel and cards', (tester) async {
    await tester.pumpWidget(MaterialApp(home: _gameScreen()));

    expect(find.byKey(const Key('clue_panel')), findsOneWidget);
    _expectGeneratedCluesVisible(1);
    expect(find.text(_initialClueTitle(1)), findsOneWidget);
    _expectInitialGeneratedLevel1Checks();
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
            tierCount: 1,
            booksPerTier: demoBookshelfPlacements.length,
            selectedBookId: null,
            isAnimating: false,
            activeSwap: null,
            isInteractionLocked: false,
            isClearing: true,
            isCleared: false,
            clearActiveBookId: 'blue_moon',
            isShelfGlowing: false,
            onBookTap: (_) => tapCount += 1,
            onEmptyTap: () {},
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
            tierCount: 1,
            booksPerTier: demoBookshelfPlacements.length,
            selectedBookId: null,
            isAnimating: false,
            activeSwap: null,
            isInteractionLocked: false,
            isClearing: true,
            isCleared: false,
            clearActiveBookId: 'red_star',
            isShelfGlowing: false,
            onBookTap: (_) => tapCount += 1,
            onEmptyTap: () {},
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
            tierCount: 1,
            booksPerTier: demoBookshelfPlacements.length,
            selectedBookId: null,
            isAnimating: false,
            activeSwap: null,
            isInteractionLocked: true,
            isClearing: false,
            isCleared: true,
            clearActiveBookId: null,
            isShelfGlowing: true,
            onBookTap: (_) => tapCount += 1,
            onEmptyTap: () {},
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
    expect(_visibleBookOrder(tester, _demoBookIds), [
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
                nextLevelErrorMessage: AppStrings.nextLevelPreparationError,
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
    expect(find.byKey(const Key('clear_next_level_error')), findsOneWidget);
    expect(find.byKey(const Key('clear_retry_button')), findsOneWidget);
    expect(find.byKey(const Key('clear_home_button')), findsOneWidget);
    expect(find.text(AppStrings.nextLevelPreparationError), findsOneWidget);
    expect(find.text(AppStrings.nextLevelButton), findsOneWidget);
    expect(find.text(AppStrings.retryButton), findsOneWidget);
    expect(find.text(AppStrings.homeButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'clear result overlay disables actions while preparing next level',
    (tester) async {
      var nextCount = 0;
      var retryCount = 0;
      var homeCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                ClearResultOverlay(
                  level: 1,
                  moveCount: 2,
                  isPreparingNextLevel: true,
                  onRetry: () => retryCount += 1,
                  onHome: () => homeCount += 1,
                  onNextLevel: () => nextCount += 1,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text(AppStrings.preparingNextLevelButton), findsOneWidget);
      expect(
        find.byKey(const Key('clear_next_level_progress')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('clear_next_level_button')),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(
        find.byKey(const Key('clear_next_level_button')),
        warnIfMissed: false,
      );
      await tester.tap(
        find.byKey(const Key('clear_retry_button')),
        warnIfMissed: false,
      );
      await tester.tap(
        find.byKey(const Key('clear_home_button')),
        warnIfMissed: false,
      );
      await tester.pump();

      expect(nextCount, 0);
      expect(retryCount, 0);
      expect(homeCount, 0);
    },
  );

  testWidgets('clear result overlay shows next level error without details', (
    tester,
  ) async {
    var nextCount = 0;
    var retryCount = 0;
    var homeCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              ClearResultOverlay(
                level: 1,
                moveCount: 2,
                nextLevelErrorMessage: AppStrings.nextLevelPreparationError,
                onRetry: () => retryCount += 1,
                onHome: () => homeCount += 1,
                onNextLevel: () => nextCount += 1,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('clear_next_level_error')), findsOneWidget);
    expect(find.text(AppStrings.nextLevelPreparationError), findsOneWidget);
    expect(find.text(AppStrings.clearResultTitle), findsOneWidget);
    expect(find.text('Level 1'), findsOneWidget);
    expect(find.text('${AppStrings.moveCountPrefix} 2회'), findsOneWidget);
    expect(find.textContaining('seed'), findsNothing);
    expect(find.textContaining('StageGenerationException'), findsNothing);
    expect(find.textContaining('UnsupportedError'), findsNothing);
    expect(find.textContaining('generatorVersion'), findsNothing);

    await tester.tap(find.byKey(const Key('clear_next_level_button')));
    await tester.tap(find.byKey(const Key('clear_retry_button')));
    await tester.tap(find.byKey(const Key('clear_home_button')));
    await tester.pump();

    expect(nextCount, 1);
    expect(retryCount, 1);
    expect(homeCount, 1);
  });

  testWidgets('small game screen lays out clues without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: _gameScreen()));
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

    await tester.pumpWidget(MaterialApp(home: _gameScreen()));
    await tester.pumpAndSettle();

    await _tapReverseSwapStep(tester, level: 1, reverseIndex: 0);
    await _settleClueState(tester);
    await tester.tap(find.byKey(const Key('game_restart_button')));
    await tester.pumpAndSettle();

    expect(_visibleBookOrder(tester), _generatedLevel1BookIds);
    expect(find.text('${AppStrings.moveCountPrefix} 0회'), findsOneWidget);

    await _clearGeneratedLevel1Game(tester);
    await tester.tap(find.byKey(const Key('clear_retry_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('clear_result_overlay')), findsNothing);
    expect(_visibleBookOrder(tester), _generatedLevel1BookIds);
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

  test('game controller fromGeneratedStage starts from generated level 1', () {
    final stage = _generatedStage(1);
    final controller = GameController.fromGeneratedStage(stage: stage);

    expect(controller.generatedStage, same(stage));
    expect(controller.isGeneratedStageGame, isTrue);
    expect(controller.level, 1);
    expect(controller.generatorVersion, stage.generatorVersion);
    expect(controller.booksPerTier, 4);
    expect(controller.placements, stage.initialPlacements);
    expect(controller.placements, isNot(same(stage.initialPlacements)));
    expect(controller.initialPlacements, stage.initialPlacements);
    expect(controller.clues, stage.clues);
    expect(controller.clues, isNot(same(stage.clues)));
    expect(_bookIdsBySlot(controller.placements), _generatedLevel1BookIds);
    expect(controller.moveCount, 0);
    expect(controller.status, GameStatus.idle);
    expect(controller.selectedBookId, isNull);
    expect(
      controller.satisfiedClueCount,
      _generatedLevel1InitialSatisfiedClueIds.length,
    );
    expect(
      controller.satisfiedClueIds,
      _generatedLevel1InitialSatisfiedClueIds.toSet(),
    );
    expect(controller.areAllCluesSatisfied, isFalse);

    controller.dispose();
  });

  test(
    'game controller fromGeneratedStage exposes generated level metadata',
    () {
      final levelSix = _generatedStage(6);
      final controller = GameController.fromGeneratedStage(stage: levelSix);

      expect(controller.level, 6);
      expect(controller.generatorVersion, levelSix.generatorVersion);
      expect(controller.booksPerTier, 5);
      expect(_bookIdsBySlot(controller.placements), _generatedLevel6BookIds);

      controller.dispose();
    },
  );

  test(
    'game controller fromGeneratedStage protects stage data and restarts same puzzle',
    () async {
      final stage = _generatedStage(1);
      final initialStageOrder = _bookIdsBySlot(stage.initialPlacements);
      final targetStageOrder = _bookIdsBySlot(stage.targetPlacements);
      final clueIds = stage.clues.map((clue) => clue.id).toList();
      final controller = GameController.fromGeneratedStage(
        stage: stage,
        swapDuration: _shortSwapDuration,
      );

      final firstReverseStep = stage.swapHistory.last;
      final firstBookId = _bookIdAtPosition(
        controller.placements,
        firstReverseStep.firstPosition,
      );
      final secondBookId = _bookIdAtPosition(
        controller.placements,
        firstReverseStep.secondPosition,
      );
      controller.handleBookTap(firstBookId);
      controller.handleBookTap(secondBookId);
      await _waitForShortSwap();

      expect(
        _bookIdsBySlot(controller.placements),
        _bookIdsBySlot(
          _swapPlacementBooks(
            stage.initialPlacements,
            firstReverseStep.firstPosition,
            firstReverseStep.secondPosition,
          ),
        ),
      );
      expect(_bookIdsBySlot(stage.initialPlacements), initialStageOrder);
      expect(_bookIdsBySlot(stage.targetPlacements), targetStageOrder);
      expect(stage.clues.map((clue) => clue.id), clueIds);

      controller.restart();

      expect(_bookIdsBySlot(controller.placements), _generatedLevel1BookIds);
      expect(controller.moveCount, 0);
      expect(
        controller.satisfiedClueCount,
        _generatedLevel1InitialSatisfiedClueIds.length,
      );
      expect(controller.status, GameStatus.idle);
      expect(controller.selectedBookId, isNull);
      expect(controller.hasClearTriggered, isFalse);
      expect(controller.clearStepIndex, -1);

      controller.dispose();
    },
  );

  test(
    'game controller clears generated level 1 and can replay after restart',
    () async {
      final stage = _generatedStage(1);
      final controller = GameController.fromGeneratedStage(
        stage: stage,
        swapDuration: _shortSwapDuration,
        clueCompletionDelay: _shortClearDuration,
        clearBookStepDuration: _shortClearDuration,
        clearFinalGlowDuration: _shortClearDuration,
      );

      await _solveGeneratedControllerToClearing(controller);

      expect(controller.moveCount, stage.targetSwapCount);
      expect(controller.satisfiedClueCount, stage.clueCount);
      expect(controller.areAllCluesSatisfied, isTrue);
      expect(controller.status, GameStatus.clearing);
      expect(_bookIdsBySlot(controller.placements), _generatedLevel1TargetIds);

      await _finishControllerClear();
      expect(controller.status, GameStatus.cleared);

      controller.restart();

      expect(_bookIdsBySlot(controller.placements), _generatedLevel1BookIds);
      expect(controller.moveCount, 0);
      expect(
        controller.satisfiedClueCount,
        _generatedLevel1InitialSatisfiedClueIds.length,
      );
      expect(controller.status, GameStatus.idle);
      expect(controller.generatedStage, same(stage));

      await _solveGeneratedControllerToClearing(controller);
      await _finishControllerClear();

      expect(controller.status, GameStatus.cleared);
      expect(controller.moveCount, stage.targetSwapCount);
      expect(controller.generatedStage, same(stage));

      controller.dispose();
    },
  );

  testWidgets('game screen starts with no selected book', (tester) async {
    await tester.pumpWidget(MaterialApp(home: _gameScreen()));

    expect(find.text(AppStrings.selectFirstBook), findsOneWidget);
  });

  testWidgets('tapping a book selects it', (tester) async {
    await tester.pumpWidget(MaterialApp(home: _gameScreen()));
    final bookId = _generatedLevel1BookIds.last;
    final label = _bookLabelForId(1, bookId);

    await tester.tap(find.byKey(Key('book_$bookId')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        '${AppStrings.selectedBookPrefix} $label · ${AppStrings.selectSecondBook}',
      ),
      findsOneWidget,
    );
    expect(find.text('${AppStrings.moveCountPrefix} 0회'), findsOneWidget);
    expect(_visibleBookOrder(tester), _generatedLevel1BookIds);
  });

  testWidgets('selection effect lifts the tapped book', (tester) async {
    await tester.pumpWidget(MaterialApp(home: _gameScreen()));
    final bookId = _generatedLevel1BookIds.last;
    final initialTop = _bookTopOf(tester, bookId);

    await tester.tap(find.byKey(Key('book_$bookId')));
    await tester.pumpAndSettle();

    expect(_bookTopOf(tester, bookId), lessThan(initialTop));

    await tester.tap(find.byKey(Key('book_$bookId')));
    await tester.pumpAndSettle();

    expect(
      _bookTopOf(tester, bookId),
      moreOrLessEquals(initialTop, epsilon: 0.1),
    );
  });

  testWidgets('tapping the same book clears selection', (tester) async {
    await tester.pumpWidget(MaterialApp(home: _gameScreen()));
    final bookId = _generatedLevel1BookIds.last;

    await tester.tap(find.byKey(Key('book_$bookId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('book_$bookId')));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.selectFirstBook), findsOneWidget);
    expect(find.text('${AppStrings.moveCountPrefix} 0회'), findsOneWidget);
    expect(_visibleBookOrder(tester), _generatedLevel1BookIds);
  });

  testWidgets('restart button exists and resets selected book', (tester) async {
    await tester.pumpWidget(MaterialApp(home: _gameScreen()));

    expect(find.byKey(const Key('game_restart_button')), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('game_restart_button')))
          .onPressed,
      isNotNull,
    );

    final selectedBookId = _generatedLevel1BookIds.last;
    await tester.tap(find.byKey(Key('book_$selectedBookId')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        '${AppStrings.selectedBookPrefix} ${_bookLabelForId(1, selectedBookId)} · ${AppStrings.selectSecondBook}',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('game_restart_button')));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.selectFirstBook), findsOneWidget);
    expect(find.text('${AppStrings.moveCountPrefix} 0회'), findsOneWidget);
    expect(find.text(_initialClueTitle(1)), findsOneWidget);
    expect(_visibleBookOrder(tester), _generatedLevel1BookIds);
    _expectInitialGeneratedLevel1Checks();
  });

  testWidgets('valid swap shows animating status immediately', (tester) async {
    await tester.pumpWidget(MaterialApp(home: _gameScreen()));

    await _tapReverseSwapStep(
      tester,
      level: 1,
      reverseIndex: 0,
      finishSwap: false,
    );

    expect(find.text(AppStrings.swappingBooks), findsOneWidget);
    expect(find.text('${AppStrings.moveCountPrefix} 1회'), findsOneWidget);
    expect(find.text(AppStrings.selectFirstBook), findsNothing);

    await _finishSwap(tester);
  });

  testWidgets('books animate between swapped slot positions', (tester) async {
    await tester.pumpWidget(MaterialApp(home: _gameScreen()));
    final swapIds = _reverseSwapBookIds(level: 1, reverseIndex: 0);
    final firstStart = _bookCenterXOf(tester, swapIds[0]);
    final secondStart = _bookCenterXOf(tester, swapIds[1]);

    await tester.tap(find.byKey(Key('book_${swapIds[0]}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('book_${swapIds[1]}')));
    await tester.pump();
    await tester.pump(_halfSwapDuration);

    final firstMid = _bookCenterXOf(tester, swapIds[0]);
    final secondMid = _bookCenterXOf(tester, swapIds[1]);
    expect((firstMid - firstStart).abs(), greaterThan(0));
    expect((secondMid - secondStart).abs(), greaterThan(0));

    await _finishSwap(tester);
    expect(
      _bookCenterXOf(tester, swapIds[0]),
      moreOrLessEquals(secondStart, epsilon: 1),
    );
    expect(
      _bookCenterXOf(tester, swapIds[1]),
      moreOrLessEquals(firstStart, epsilon: 1),
    );
  });

  testWidgets('swap completion clears animation status and finalizes order', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: _gameScreen()));

    await _tapReverseSwapStep(
      tester,
      level: 1,
      reverseIndex: 0,
      finishSwap: false,
    );

    expect(find.text(AppStrings.swappingBooks), findsOneWidget);

    await _finishSwap(tester);

    expect(find.text(AppStrings.selectFirstBook), findsOneWidget);
    expect(find.text('${AppStrings.moveCountPrefix} 1회'), findsOneWidget);
    expect(
      _visibleBookOrder(tester),
      _bookIdsBySlot(
        _swapPlacementBooks(
          _generatedStage(1).initialPlacements,
          _generatedStage(1).swapHistory.last.firstPosition,
          _generatedStage(1).swapHistory.last.secondPosition,
        ),
      ),
    );
  });

  testWidgets('clues remain fixed after swapping books', (tester) async {
    await tester.pumpWidget(MaterialApp(home: _gameScreen()));

    await _tapReverseSwapStep(tester, level: 1, reverseIndex: 0);

    expect(find.text('${AppStrings.moveCountPrefix} 1회'), findsOneWidget);
    expect(find.textContaining(AppStrings.clueTitle), findsWidgets);
    _expectGeneratedLevel1CluesVisible();
  });

  testWidgets('restart restores initial board after a completed swap', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: _gameScreen()));

    await _tapReverseSwapStep(tester, level: 1, reverseIndex: 0);
    await _settleClueState(tester);

    expect(find.text('${AppStrings.moveCountPrefix} 1회'), findsOneWidget);
    expect(find.textContaining(AppStrings.clueTitle), findsWidgets);
    _expectOnlyGeneratedChecks(
      _stageSatisfiedClueIdsAfterReverseSwaps(level: 1, completedSwapCount: 1),
    );

    await tester.tap(find.byKey(const Key('game_restart_button')));
    await tester.pump();

    expect(_visibleBookOrder(tester), _generatedLevel1BookIds);
    expect(find.text('${AppStrings.moveCountPrefix} 0회'), findsOneWidget);
    expect(find.text(_initialClueTitle(1)), findsOneWidget);
    expect(find.text(AppStrings.selectFirstBook), findsOneWidget);
    expect(find.byKey(const Key('clear_result_overlay')), findsNothing);
    expect(find.byKey(const Key('bookshelf_clear_glow')), findsNothing);
    await _settleClueState(tester);
    _expectInitialGeneratedLevel1Checks();
  });

  testWidgets('clear flow starts after all clues are satisfied', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: _gameScreen()));

    expect(find.text(_initialClueTitle(1)), findsOneWidget);
    _expectInitialGeneratedLevel1Checks();

    await _tapReverseSwapStep(
      tester,
      level: 1,
      reverseIndex: 0,
      finishSwap: false,
    );

    expect(find.text(AppStrings.swappingBooks), findsOneWidget);
    expect(find.text(_initialClueTitle(1)), findsOneWidget);
    _expectInitialGeneratedLevel1Checks();

    await _finishSwap(tester);
    await _settleClueState(tester);

    expect(find.textContaining(AppStrings.clueTitle), findsWidgets);
    _expectOnlyGeneratedChecks(
      _stageSatisfiedClueIdsAfterReverseSwaps(level: 1, completedSwapCount: 1),
    );
    expect(find.byKey(const Key('clear_result_overlay')), findsNothing);

    await _tapReverseSwapStep(
      tester,
      level: 1,
      reverseIndex: 1,
      finishSwap: false,
    );

    expect(find.text(AppStrings.swappingBooks), findsOneWidget);
    expect(find.byKey(const Key('clear_result_overlay')), findsNothing);

    await _finishSwap(tester);

    expect(find.text(_clearedClueTitle(1)), findsOneWidget);
    expect(find.text(AppStrings.clearingBooks), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('game_restart_button')))
          .onPressed,
      isNull,
    );
    _expectOnlyGeneratedChecks(_generatedLevel1ClueIds);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byKey(const Key('clear_result_overlay')), findsNothing);
    expect(find.text(AppStrings.levelOne), findsOneWidget);

    final orderBeforeLockedTap = _visibleBookOrder(tester);
    await tester.tap(
      find.byKey(_level1ReverseSwapBookKey(1, 0)),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(find.text(_targetMoveCountTitle(1)), findsOneWidget);
    expect(_visibleBookOrder(tester), orderBeforeLockedTap);

    await _finishClear(tester);

    expect(find.text(AppStrings.clearedBooks), findsOneWidget);
    expect(find.byKey(const Key('clear_result_overlay')), findsOneWidget);
    expect(find.byKey(const Key('clear_result_card')), findsOneWidget);
    expect(find.byKey(const Key('clear_result_title')), findsOneWidget);
    expect(find.byKey(const Key('clear_retry_button')), findsOneWidget);
    expect(find.text(AppStrings.clearResultTitle), findsOneWidget);
    expect(find.text(AppStrings.retryButton), findsOneWidget);
    expect(find.text('Level 1'), findsWidgets);
    expect(find.text(_targetMoveCountTitle(1)), findsWidgets);
    expect(find.text(_clearedClueTitle(1)), findsOneWidget);
    expect(find.byKey(const Key('clear_result_overlay')), findsOneWidget);

    await tester.tap(
      find.byKey(_level1ReverseSwapBookKey(1, 0)),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(find.text(_targetMoveCountTitle(1)), findsWidgets);
    expect(_visibleBookOrder(tester), orderBeforeLockedTap);

    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('clear_result_overlay')), findsOneWidget);
    _expectGeneratedLevel1CluesVisible();
  });

  testWidgets('cleared overlay advances to level 2 without pushing a route', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home_continue_button')));
    await tester.pumpAndSettle();
    await _clearGeneratedLevel1Game(tester);

    expect(find.byKey(const Key('clear_result_overlay')), findsOneWidget);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('clear_result_overlay')), findsOneWidget);

    await tester.tap(find.byKey(const Key('clear_next_level_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('clear_result_overlay')), findsNothing);
    expect(find.text('Level 2'), findsOneWidget);
    expect(
      _visibleBookOrder(tester, _generatedLevel2BookIds),
      _generatedLevel2BookIds,
    );
    expect(find.text('${AppStrings.moveCountPrefix} 0회'), findsOneWidget);
    expect(find.text(_initialClueTitle(2)), findsOneWidget);
    for (final id in _generatedLevel1BookIds) {
      expect(find.byKey(Key('book_$id')), findsNothing);
    }
    _expectGeneratedLevel2CluesVisible();

    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.sound), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Level 2'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.appTitle), findsOneWidget);
  });

  testWidgets('clear retry restarts level and allows clearing again', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home_continue_button')));
    await tester.pumpAndSettle();
    await _clearGeneratedLevel1Game(tester);

    expect(find.byKey(const Key('clear_result_overlay')), findsOneWidget);

    await tester.tap(find.byKey(const Key('clear_retry_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('clear_result_overlay')), findsNothing);
    expect(find.byKey(const Key('bookshelf_clear_glow')), findsNothing);
    expect(find.text(AppStrings.levelOne), findsOneWidget);
    expect(find.text(AppStrings.selectFirstBook), findsOneWidget);
    expect(find.text('${AppStrings.moveCountPrefix} 0회'), findsOneWidget);
    expect(find.text(_initialClueTitle(1)), findsOneWidget);
    expect(_visibleBookOrder(tester), _generatedLevel1BookIds);
    _expectInitialGeneratedLevel1Checks();
    for (final id in _generatedLevel1BookIds) {
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

    await _clearGeneratedLevel1Game(tester);

    expect(find.byKey(const Key('clear_result_overlay')), findsOneWidget);
    expect(find.byKey(const Key('clear_result_overlay')), findsOneWidget);
    expect(find.text(_targetMoveCountTitle(1)), findsWidgets);
  });

  testWidgets('level 2 can be cleared, retried, and advanced to level 3', (
    tester,
  ) async {
    final generator = _SpyStageGenerator();
    final store = FakeGameProgressStore(
      progress: GameProgress.initial(generatorVersion: 1),
    );
    final progressController = GameProgressController(store: store);
    await progressController.load();

    await tester.pumpWidget(
      MaterialApp(
        home: _gameScreen(
          stageGenerator: generator,
          progressController: progressController,
        ),
      ),
    );

    await _goToGeneratedLevel2(tester);

    expect(generator.levels, [1, 2]);
    expect(generator.generatorVersions, [1, 1]);
    expect(find.text('Level 2'), findsOneWidget);
    expect(
      _visibleBookOrder(tester, _generatedLevel2BookIds),
      _generatedLevel2BookIds,
    );
    expect(find.text(_initialClueTitle(2)), findsOneWidget);
    expect(find.text('${AppStrings.moveCountPrefix} 0회'), findsOneWidget);
    _expectGeneratedLevel2CluesVisible();

    await _clearGeneratedLevel2Game(tester);

    expect(find.byKey(const Key('clear_result_overlay')), findsOneWidget);
    expect(find.text(AppStrings.clearResultTitle), findsOneWidget);
    expect(find.text('Level 2'), findsWidgets);
    expect(find.text(_clearedClueTitle(2)), findsOneWidget);
    expect(find.text(_targetMoveCountTitle(2)), findsWidgets);
    expect(
      _visibleBookOrder(tester, _generatedLevel2BookIds),
      _generatedLevel2TargetIds,
    );

    await tester.tap(find.byKey(const Key('clear_retry_button')));
    await tester.pumpAndSettle();

    expect(generator.levels, [1, 2]);
    expect(find.byKey(const Key('clear_result_overlay')), findsNothing);
    expect(find.text('Level 2'), findsOneWidget);
    expect(find.text(_initialClueTitle(2)), findsOneWidget);
    expect(find.text('${AppStrings.moveCountPrefix} 0회'), findsOneWidget);
    expect(
      _visibleBookOrder(tester, _generatedLevel2BookIds),
      _generatedLevel2BookIds,
    );

    await _clearGeneratedLevel2Game(tester);
    await tester.tap(find.byKey(const Key('clear_next_level_button')));
    await tester.pumpAndSettle();

    expect(generator.levels, [1, 2, 3]);
    expect(generator.generatorVersions, [1, 1, 1]);
    expect(find.byKey(const Key('clear_result_overlay')), findsNothing);
    expect(find.text('Level 3'), findsOneWidget);
    expect(find.text(_initialClueTitle(3)), findsOneWidget);
    expect(find.text('${AppStrings.moveCountPrefix} 0회'), findsOneWidget);
    expect(
      _visibleBookOrder(tester, _generatedLevel3BookIds),
      _generatedLevel3BookIds,
    );
  });

  testWidgets('level 2 restart keeps level and does not call generator', (
    tester,
  ) async {
    final generator = _SpyStageGenerator();
    final store = FakeGameProgressStore(
      progress: GameProgress.initial(generatorVersion: 1),
    );
    final progressController = GameProgressController(store: store);
    await progressController.load();

    await tester.pumpWidget(
      MaterialApp(
        home: _gameScreen(
          stageGenerator: generator,
          progressController: progressController,
        ),
      ),
    );

    await _goToGeneratedLevel2(tester);
    await _tapReverseSwapStep(tester, level: 2, reverseIndex: 0);
    await _settleClueState(tester);

    expect(find.text('${AppStrings.moveCountPrefix} 1회'), findsOneWidget);
    expect(generator.levels, [1, 2]);

    await tester.tap(find.byKey(const Key('game_restart_button')));
    await tester.pumpAndSettle();

    expect(find.text('Level 2'), findsOneWidget);
    expect(find.text('${AppStrings.moveCountPrefix} 0회'), findsOneWidget);
    expect(find.text(_initialClueTitle(2)), findsOneWidget);
    expect(
      _visibleBookOrder(tester, _generatedLevel2BookIds),
      _generatedLevel2BookIds,
    );
    expect(generator.levels, [1, 2]);
    expect(store.writes.map((progress) => progress.currentLevel), [2]);

    progressController.dispose();
  });

  testWidgets('level 1 to level 2 transition saves progress', (tester) async {
    final store = FakeGameProgressStore();

    await tester.pumpWidget(_app(progressStore: store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home_continue_button')));
    await tester.pumpAndSettle();
    await _clearGeneratedLevel1Game(tester);
    await tester.tap(find.byKey(const Key('clear_next_level_button')));
    await tester.pumpAndSettle();

    expect(find.text('Level 2'), findsOneWidget);
    expect(store.writes.map((progress) => progress.currentLevel), [1, 2]);
    expect(store.lastWrite?.highestUnlockedLevel, 2);
    expect(store.lastWrite?.generatorVersion, 1);
  });

  testWidgets('level 2 to level 3 saves progress in order', (tester) async {
    final store = FakeGameProgressStore(
      progress: GameProgress.initial(generatorVersion: 1),
    );
    final progressController = GameProgressController(store: store);
    await progressController.load();
    final generator = _SpyStageGenerator();

    await tester.pumpWidget(
      MaterialApp(
        home: _gameScreen(
          stageGenerator: generator,
          progressController: progressController,
        ),
      ),
    );

    await _goToGeneratedLevel2(tester);
    await _clearGeneratedLevel2Game(tester);
    await tester.tap(find.byKey(const Key('clear_next_level_button')));
    await tester.pumpAndSettle();

    expect(generator.levels, [1, 2, 3]);
    expect(store.writes.map((progress) => progress.currentLevel), [2, 3]);
    expect(progressController.currentLevel, 3);
    expect(find.text('Level 3'), findsOneWidget);

    progressController.dispose();
  });

  testWidgets('home shows latest progress after returning from level 2', (
    tester,
  ) async {
    final store = FakeGameProgressStore();

    await tester.pumpWidget(_app(progressStore: store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home_continue_button')));
    await tester.pumpAndSettle();
    await _goToGeneratedLevel2(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('계속하기 · Level 2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home_continue_button')));
    await tester.pumpAndSettle();

    expect(find.text('Level 2'), findsOneWidget);
    expect(find.text('${AppStrings.moveCountPrefix} 0회'), findsOneWidget);
    expect(
      _visibleBookOrder(tester, _generatedLevel2BookIds),
      _generatedLevel2BookIds,
    );
  });

  testWidgets('progress save failure keeps current result and can retry', (
    tester,
  ) async {
    final store = FakeGameProgressStore(
      progress: GameProgress.initial(generatorVersion: 1),
      writeErrors: [StateError('forced save failure')],
    );
    final progressController = GameProgressController(store: store);
    await progressController.load();
    final generator = _SpyStageGenerator();

    await tester.pumpWidget(
      MaterialApp(
        home: _gameScreen(
          stageGenerator: generator,
          progressController: progressController,
        ),
      ),
    );

    await _clearGeneratedLevel1Game(tester);
    await tester.tap(find.byKey(const Key('clear_next_level_button')));
    await tester.pumpAndSettle();

    expect(generator.levels, [1, 2]);
    expect(progressController.currentLevel, 1);
    expect(find.byKey(const Key('clear_result_overlay')), findsOneWidget);
    expect(find.byKey(const Key('clear_progress_save_error')), findsOneWidget);
    expect(find.text(AppStrings.progressSaveError), findsOneWidget);
    expect(find.text('Level 1'), findsWidgets);
    expect(find.text(_targetMoveCountTitle(1)), findsWidgets);
    expect(_visibleBookOrder(tester), _generatedLevel1TargetIds);

    await tester.tap(find.byKey(const Key('clear_next_level_button')));
    await tester.pumpAndSettle();

    expect(generator.levels, [1, 2, 2]);
    expect(progressController.currentLevel, 2);
    expect(find.byKey(const Key('clear_progress_save_error')), findsNothing);
    expect(find.text('Level 2'), findsOneWidget);

    progressController.dispose();
  });

  testWidgets('stage generation failure does not save progress', (
    tester,
  ) async {
    final store = FakeGameProgressStore(
      progress: GameProgress.initial(generatorVersion: 1),
    );
    final progressController = GameProgressController(store: store);
    await progressController.load();
    final generator = _SpyStageGenerator(
      errors: [null, _generationException()],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: _gameScreen(
          stageGenerator: generator,
          progressController: progressController,
        ),
      ),
    );

    await _clearGeneratedLevel1Game(tester);
    await tester.tap(find.byKey(const Key('clear_next_level_button')));
    await tester.pumpAndSettle();

    expect(generator.levels, [1, 2]);
    expect(store.writeCount, 0);
    expect(progressController.currentLevel, 1);
    expect(find.byKey(const Key('clear_result_overlay')), findsOneWidget);
    expect(find.byKey(const Key('clear_next_level_error')), findsOneWidget);

    progressController.dispose();
  });

  testWidgets('back navigation is safe during clearing and after cleared', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home_continue_button')));
    await tester.pumpAndSettle();
    await _tapReverseSwapStep(tester, level: 1, reverseIndex: 0);
    await _settleClueState(tester);
    await _tapReverseSwapStep(tester, level: 1, reverseIndex: 1);

    expect(find.text(AppStrings.clearingBooks), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _finishClear(tester);

    expect(find.text(AppStrings.appTitle), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('home_continue_button')));
    await tester.pumpAndSettle();
    await _clearGeneratedLevel1Game(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.appTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a clue card does not affect book selection or moves', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: _gameScreen()));

    final selectedBookId = _generatedLevel1BookIds.last;
    await tester.tap(find.byKey(Key('book_$selectedBookId')));
    await tester.pumpAndSettle();

    final clueFinder = find.byKey(Key('clue_${_generatedLevel1ClueIds.first}'));
    await tester.ensureVisible(clueFinder);
    await tester.pumpAndSettle();
    await tester.tap(clueFinder);
    await tester.pumpAndSettle();

    expect(
      find.text(
        '${AppStrings.selectedBookPrefix} ${_bookLabelForId(1, selectedBookId)} · ${AppStrings.selectSecondBook}',
      ),
      findsOneWidget,
    );
    expect(find.text('${AppStrings.moveCountPrefix} 0회'), findsOneWidget);
    expect(find.text(_initialClueTitle(1)), findsOneWidget);
    expect(_visibleBookOrder(tester), _generatedLevel1BookIds);
  });

  testWidgets('tapping empty game content clears selection', (tester) async {
    await tester.pumpWidget(MaterialApp(home: _gameScreen()));
    final selectedBookId = _generatedLevel1BookIds.first;

    await tester.tap(find.byKey(Key('book_$selectedBookId')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        '${AppStrings.selectedBookPrefix} ${_bookLabelForId(1, selectedBookId)} · ${AppStrings.selectSecondBook}',
      ),
      findsOneWidget,
    );

    final backgroundFinder = find.byKey(const Key('game_content_background'));
    final backgroundTopLeft = tester.getTopLeft(backgroundFinder);
    await tester.tapAt(backgroundTopLeft + const Offset(4, 4));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.selectFirstBook), findsOneWidget);
    expect(find.text('${AppStrings.moveCountPrefix} 0회'), findsOneWidget);
    expect(_visibleBookOrder(tester), _generatedLevel1BookIds);
  });

  testWidgets('rapid taps during animation are ignored', (tester) async {
    await tester.pumpWidget(MaterialApp(home: _gameScreen()));

    await _tapReverseSwapStep(
      tester,
      level: 1,
      reverseIndex: 0,
      finishSwap: false,
    );
    await tester.tap(
      find.byKey(Key('book_${_generatedLevel1BookIds.first}')),
      warnIfMissed: false,
    );
    await tester.pump();
    await tester.tap(
      find.byKey(Key('book_${_generatedLevel1BookIds.last}')),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(find.text(AppStrings.swappingBooks), findsOneWidget);
    expect(find.text('${AppStrings.moveCountPrefix} 1회'), findsOneWidget);

    await _finishSwap(tester);

    expect(find.text(AppStrings.selectFirstBook), findsOneWidget);
    expect(find.text('${AppStrings.moveCountPrefix} 1회'), findsOneWidget);
    expect(_visibleBookOrder(tester), isNot(_generatedLevel1BookIds));
  });

  testWidgets('two swaps update move count and final order', (tester) async {
    await tester.pumpWidget(MaterialApp(home: _gameScreen()));

    await _tapReverseSwapStep(tester, level: 1, reverseIndex: 0);
    await _tapReverseSwapStep(tester, level: 1, reverseIndex: 1);

    expect(find.text(_targetMoveCountTitle(1)), findsOneWidget);
    expect(find.text(_clearedClueTitle(1)), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    _expectOnlyGeneratedChecks(_generatedLevel1ClueIds);
    _expectGeneratedLevel1CluesVisible();
    expect(_visibleBookOrder(tester), _generatedLevel1TargetIds);
  });

  testWidgets('move count increments only after valid swaps', (tester) async {
    await tester.pumpWidget(MaterialApp(home: _gameScreen()));

    final swapIds = _reverseSwapBookIds(level: 1, reverseIndex: 0);
    await tester.tap(find.byKey(Key('book_${swapIds[0]}')));
    await tester.pumpAndSettle();
    expect(find.text('${AppStrings.moveCountPrefix} 0회'), findsOneWidget);
    await tester.tap(find.byKey(Key('book_${swapIds[1]}')));
    await _finishSwap(tester);

    expect(find.text('${AppStrings.moveCountPrefix} 1회'), findsOneWidget);
  });

  testWidgets('restart button is disabled while books are animating', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: _gameScreen()));

    await _tapReverseSwapStep(
      tester,
      level: 1,
      reverseIndex: 0,
      finishSwap: false,
    );

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
    await tester.pumpWidget(MaterialApp(home: _gameScreen()));

    for (final id in _generatedLevel1BookIds) {
      expect(find.byKey(Key('book_$id')), findsOneWidget);
      expect(find.byKey(Key('positioned_$id')), findsOneWidget);
    }

    await _tapReverseSwapStep(
      tester,
      level: 1,
      reverseIndex: 0,
      finishSwap: false,
    );

    for (final id in _generatedLevel1BookIds) {
      expect(find.byKey(Key('book_$id')), findsOneWidget);
      expect(find.byKey(Key('positioned_$id')), findsOneWidget);
    }

    await _finishSwap(tester);

    for (final id in _generatedLevel1BookIds) {
      expect(find.byKey(Key('book_$id')), findsOneWidget);
      expect(find.byKey(Key('positioned_$id')), findsOneWidget);
    }
    expect(find.textContaining(AppStrings.clueTitle), findsWidgets);
    _expectGeneratedLevel1CluesVisible();
  });

  testWidgets('generated level 1 initial book positions use initial order', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: _gameScreen()));

    expect(_visibleBookOrder(tester), _generatedLevel1BookIds);
    expect(_visibleBookOrder(tester), isNot(_generatedLevel1TargetIds));
    _expectBookCentersStrictlyIncreasing(tester, _generatedLevel1BookIds);
  });

  testWidgets('stage generator is called once across rebuilds and replay', (
    tester,
  ) async {
    final generator = _SpyStageGenerator();

    await tester.pumpWidget(
      MaterialApp(
        routes: {'/settings': (_) => _testSettingsScreen()},
        home: _gameScreen(stageGenerator: generator),
      ),
    );

    expect(generator.callCount, 1);
    await tester.pump();
    expect(generator.callCount, 1);

    await tester.tap(find.byKey(Key('book_${_generatedLevel1BookIds.last}')));
    await tester.pumpAndSettle();
    expect(generator.callCount, 1);

    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.sound), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(generator.callCount, 1);

    await tester.tap(find.byKey(const Key('game_restart_button')));
    await tester.pumpAndSettle();
    expect(generator.callCount, 1);

    await _clearGeneratedLevel1Game(tester);
    await tester.tap(find.byKey(const Key('clear_retry_button')));
    await tester.pumpAndSettle();

    expect(generator.callCount, 1);
    expect(find.byKey(const Key('clear_result_overlay')), findsNothing);
    expect(_visibleBookOrder(tester), _generatedLevel1BookIds);
    expect(find.text(_initialClueTitle(1)), findsOneWidget);
  });

  testWidgets('next level failure keeps current clear result and can retry', (
    tester,
  ) async {
    final generator = _SpyStageGenerator(
      errors: [null, _generationException()],
    );

    await tester.pumpWidget(
      MaterialApp(home: _gameScreen(stageGenerator: generator)),
    );

    await _clearGeneratedLevel1Game(tester);
    await tester.tap(find.byKey(const Key('clear_next_level_button')));
    await tester.pumpAndSettle();

    expect(generator.levels, [1, 2]);
    expect(find.byKey(const Key('game_generation_error')), findsNothing);
    expect(find.byKey(const Key('clear_result_overlay')), findsOneWidget);
    expect(find.byKey(const Key('clear_next_level_error')), findsOneWidget);
    expect(find.text(AppStrings.nextLevelPreparationError), findsOneWidget);
    expect(find.text('Level 1'), findsWidgets);
    expect(find.text(_targetMoveCountTitle(1)), findsWidgets);
    expect(find.text(_clearedClueTitle(1)), findsOneWidget);
    expect(_visibleBookOrder(tester), _generatedLevel1TargetIds);

    await tester.tap(find.byKey(const Key('clear_next_level_button')));
    await tester.pumpAndSettle();

    expect(generator.levels, [1, 2, 2]);
    expect(find.byKey(const Key('clear_result_overlay')), findsNothing);
    expect(find.byKey(const Key('clear_next_level_error')), findsNothing);
    expect(find.text('Level 2'), findsOneWidget);
    expect(
      _visibleBookOrder(tester, _generatedLevel2BookIds),
      _generatedLevel2BookIds,
    );
  });

  testWidgets('clear retry after next level failure replays current level', (
    tester,
  ) async {
    final generator = _SpyStageGenerator(
      errors: [null, _generationException()],
    );

    await tester.pumpWidget(
      MaterialApp(home: _gameScreen(stageGenerator: generator)),
    );

    await _clearGeneratedLevel1Game(tester);
    await tester.tap(find.byKey(const Key('clear_next_level_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('clear_next_level_error')), findsOneWidget);

    await tester.tap(find.byKey(const Key('clear_retry_button')));
    await tester.pumpAndSettle();

    expect(generator.levels, [1, 2]);
    expect(find.byKey(const Key('clear_result_overlay')), findsNothing);
    expect(find.byKey(const Key('clear_next_level_error')), findsNothing);
    expect(find.text(AppStrings.levelOne), findsOneWidget);
    expect(find.text('${AppStrings.moveCountPrefix} 0회'), findsOneWidget);
    expect(find.text(_initialClueTitle(1)), findsOneWidget);
    expect(_visibleBookOrder(tester), _generatedLevel1BookIds);
  });

  testWidgets('wrong next stage level is rejected without switching game', (
    tester,
  ) async {
    final generator = _SpyStageGenerator(
      onGenerate: (level, generatorVersion, callCount) {
        if (callCount == 2) {
          return const StageGenerator().generate(
            level: 3,
            generatorVersion: generatorVersion,
          );
        }
        return const StageGenerator().generate(
          level: level,
          generatorVersion: generatorVersion,
        );
      },
    );

    await tester.pumpWidget(
      MaterialApp(home: _gameScreen(stageGenerator: generator)),
    );

    await _clearGeneratedLevel1Game(tester);
    await tester.tap(find.byKey(const Key('clear_next_level_button')));
    await tester.pumpAndSettle();

    expect(generator.levels, [1, 2]);
    expect(find.byKey(const Key('clear_result_overlay')), findsOneWidget);
    expect(find.byKey(const Key('clear_next_level_error')), findsOneWidget);
    expect(find.text(AppStrings.nextLevelPreparationError), findsOneWidget);
    expect(find.text('Level 1'), findsWidgets);
    expect(find.text('Level 3'), findsNothing);
    expect(_visibleBookOrder(tester), _generatedLevel1TargetIds);
  });

  testWidgets('level 20 advances to level 21 T02 and saves progress', (
    tester,
  ) async {
    final store = FakeGameProgressStore(
      progress: GameProgress(
        schemaVersion: 1,
        currentLevel: 20,
        highestUnlockedLevel: 20,
        generatorVersion: 1,
      ),
    );
    final progressController = GameProgressController(store: store);
    await progressController.load();

    await tester.pumpWidget(
      MaterialApp(
        home: _gameScreen(level: 20, progressController: progressController),
      ),
    );

    expect(find.text('Level 20'), findsOneWidget);
    expect(
      _visibleBookOrder(tester, _generatedLevel20BookIds),
      _generatedLevel20BookIds,
    );

    await _clearGeneratedLevel20Game(tester);

    expect(find.byKey(const Key('clear_result_overlay')), findsOneWidget);
    expect(find.text('Level 20'), findsWidgets);
    expect(find.text(_targetMoveCountTitle(20)), findsWidgets);

    await tester.tap(find.byKey(const Key('clear_next_level_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('game_generation_error')), findsNothing);
    expect(find.byKey(const Key('clear_result_overlay')), findsNothing);
    expect(find.byKey(const Key('clear_next_level_error')), findsNothing);
    expect(find.text('Level 21'), findsOneWidget);
    expect(
      _visibleBookOrder(tester, _generatedLevel21BookIds),
      _generatedLevel21BookIds,
    );
    expect(find.text(_initialClueTitle(21)), findsOneWidget);
    expect(store.writeCount, 1);
    expect(progressController.currentLevel, 21);
    expect(progressController.highestUnlockedLevel, 21);

    progressController.dispose();
  });

  testWidgets('level 22 advances to level 23 T03 and saves progress', (
    tester,
  ) async {
    final store = FakeGameProgressStore(
      progress: GameProgress(
        schemaVersion: 1,
        currentLevel: 22,
        highestUnlockedLevel: 22,
        generatorVersion: 1,
      ),
    );
    final progressController = GameProgressController(store: store);
    await progressController.load();

    await tester.pumpWidget(
      MaterialApp(
        home: _gameScreen(level: 22, progressController: progressController),
      ),
    );

    expect(find.text('Level 22'), findsOneWidget);
    expect(
      _visibleBookOrder(tester, _generatedLevel22BookIds),
      _generatedLevel22BookIds,
    );

    await _clearGeneratedLevel22Game(tester);

    expect(find.byKey(const Key('clear_result_overlay')), findsOneWidget);
    expect(find.text('Level 22'), findsWidgets);
    expect(find.text(_targetMoveCountTitle(22)), findsWidgets);

    await tester.tap(find.byKey(const Key('clear_next_level_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('game_generation_error')), findsNothing);
    expect(find.byKey(const Key('clear_result_overlay')), findsNothing);
    expect(find.byKey(const Key('clear_next_level_error')), findsNothing);
    expect(find.text('Level 23'), findsOneWidget);
    expect(
      _visibleBookOrder(tester, _generatedLevel23BookIds),
      _generatedLevel23BookIds,
    );
    expect(find.text(_initialClueTitle(23)), findsOneWidget);
    _expectGeneratedCluesVisible(23);
    expect(store.writeCount, 1);
    expect(progressController.currentLevel, 23);
    expect(progressController.highestUnlockedLevel, 23);

    progressController.dispose();
  });

  testWidgets('level 50 advances to level 51 T04 and saves progress', (
    tester,
  ) async {
    final store = FakeGameProgressStore(
      progress: GameProgress(
        schemaVersion: 1,
        currentLevel: 50,
        highestUnlockedLevel: 50,
        generatorVersion: 1,
      ),
    );
    final progressController = GameProgressController(store: store);
    await progressController.load();

    await tester.pumpWidget(
      MaterialApp(
        home: _gameScreen(level: 50, progressController: progressController),
      ),
    );

    expect(find.text('Level 50'), findsOneWidget);
    expect(
      _visibleBookOrder(tester, _generatedLevel50BookIds),
      _generatedLevel50BookIds,
    );

    await _clearGeneratedLevel50Game(tester);

    expect(find.byKey(const Key('clear_result_overlay')), findsOneWidget);
    expect(find.text('Level 50'), findsWidgets);
    expect(find.text(_targetMoveCountTitle(50)), findsWidgets);

    await tester.tap(find.byKey(const Key('clear_next_level_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('game_generation_error')), findsNothing);
    expect(find.byKey(const Key('clear_result_overlay')), findsNothing);
    expect(find.byKey(const Key('clear_next_level_error')), findsNothing);
    expect(find.text('Level 51'), findsOneWidget);
    expect(find.byKey(const Key('bookshelf_tier_0')), findsOneWidget);
    expect(find.byKey(const Key('bookshelf_tier_1')), findsOneWidget);
    expect(
      _visibleBookGridOrder(tester, _generatedLevel51BookIds),
      _generatedLevel51BookIds,
    );
    expect(find.text(_initialClueTitle(51)), findsOneWidget);
    expect(store.writeCount, 1);
    expect(progressController.currentLevel, 51);
    expect(progressController.highestUnlockedLevel, 51);

    progressController.dispose();
  });

  testWidgets('level 100 advances to level 101 T05 without leaving the route', (
    tester,
  ) async {
    final store = FakeGameProgressStore(
      progress: GameProgress(
        schemaVersion: 1,
        currentLevel: 100,
        highestUnlockedLevel: 100,
        generatorVersion: 1,
      ),
    );
    final progressController = GameProgressController(store: store);
    await progressController.load();

    await tester.pumpWidget(
      MaterialApp(
        home: _gameScreen(level: 100, progressController: progressController),
      ),
    );

    expect(find.text('Level 100'), findsOneWidget);
    expect(
      _visibleBookGridOrder(tester, _generatedLevel100BookIds),
      _generatedLevel100BookIds,
    );

    await _clearGeneratedLevel100Game(tester);

    expect(find.byKey(const Key('clear_result_overlay')), findsOneWidget);
    expect(find.text('Level 100'), findsWidgets);
    expect(find.text(_targetMoveCountTitle(100)), findsWidgets);

    await tester.tap(find.byKey(const Key('clear_next_level_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('game_generation_error')), findsNothing);
    expect(find.byKey(const Key('clear_result_overlay')), findsNothing);
    expect(find.text('Level 101'), findsOneWidget);
    expect(find.byKey(const Key('bookshelf_tier_0')), findsOneWidget);
    expect(find.byKey(const Key('bookshelf_tier_1')), findsOneWidget);
    expect(
      _visibleBookGridOrder(tester, _generatedLevel101BookIds),
      _generatedLevel101BookIds,
    );
    expect(find.text(_initialClueTitle(101)), findsOneWidget);
    expect(find.text('${AppStrings.moveCountPrefix} 0회'), findsOneWidget);
    expect(store.writeCount, 1);
    expect(progressController.currentLevel, 101);
    expect(progressController.highestUnlockedLevel, 101);

    progressController.dispose();
  });

  testWidgets('level 200 advances to level 201 with generator version 2', (
    tester,
  ) async {
    final store = FakeGameProgressStore(
      progress: GameProgress(
        schemaVersion: 1,
        currentLevel: 200,
        highestUnlockedLevel: 200,
        generatorVersion: 1,
      ),
    );
    final progressController = GameProgressController(store: store);
    await progressController.load();

    await tester.pumpWidget(
      MaterialApp(
        home: _gameScreen(level: 200, progressController: progressController),
      ),
    );

    expect(find.text('Level 200'), findsOneWidget);
    expect(
      _visibleBookGridOrder(tester, _generatedLevel200BookIds),
      _generatedLevel200BookIds,
    );

    await _clearGeneratedStageByReverseSwaps(
      tester,
      stage: _generatedStage(200),
    );

    expect(find.byKey(const Key('clear_result_overlay')), findsOneWidget);
    expect(find.text('Level 200'), findsWidgets);
    expect(find.text(_targetMoveCountTitle(200)), findsWidgets);

    await tester.tap(find.byKey(const Key('clear_next_level_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('game_generation_error')), findsNothing);
    expect(find.byKey(const Key('clear_result_overlay')), findsNothing);
    expect(find.byKey(const Key('clear_next_level_error')), findsNothing);
    expect(find.text('Level 201'), findsOneWidget);
    expect(find.text('${AppStrings.moveCountPrefix} 0회'), findsOneWidget);
    for (final id in _stageInitialBookIds(201)) {
      expect(find.byKey(Key('book_$id')), findsOneWidget);
    }
    expect(store.writeCount, 1);
    expect(store.lastWrite?.currentLevel, 201);
    expect(store.lastWrite?.generatorVersion, 2);
    expect(progressController.currentLevel, 201);
    expect(progressController.highestUnlockedLevel, 201);
    expect(progressController.generatorVersion, 2);

    progressController.dispose();
  });

  testWidgets('settings navigation preserves generated game state', (
    tester,
  ) async {
    final generator = _SpyStageGenerator();

    await tester.pumpWidget(
      MaterialApp(
        routes: {'/settings': (_) => _testSettingsScreen()},
        home: _gameScreen(stageGenerator: generator),
      ),
    );

    await _tapReverseSwapStep(tester, level: 1, reverseIndex: 0);

    expect(find.text('${AppStrings.moveCountPrefix} 1회'), findsOneWidget);
    final orderAfterSwap = _visibleBookOrder(tester);

    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.sound), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(generator.callCount, 1);
    expect(find.text(AppStrings.levelOne), findsOneWidget);
    expect(find.text('${AppStrings.moveCountPrefix} 1회'), findsOneWidget);
    expect(_visibleBookOrder(tester), orderAfterSwap);
  });

  testWidgets('level 6 displays five generated books without overlap', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: _gameScreen(level: 6)));

    expect(find.text('Level 6'), findsOneWidget);
    for (final id in _generatedLevel6BookIds) {
      expect(find.byKey(Key('book_$id')), findsOneWidget);
    }
    for (final id in _generatedLevel1BookIds) {
      if (!_generatedLevel6BookIds.contains(id)) {
        expect(find.byKey(Key('book_$id')), findsNothing);
      }
    }
    expect(
      _visibleBookOrder(tester, _generatedLevel6BookIds),
      _generatedLevel6BookIds,
    );
    _expectBookCentersStrictlyIncreasing(tester, _generatedLevel6BookIds);
    _expectBooksDoNotOverlap(tester, _generatedLevel6BookIds);
    expect(find.byKey(const Key('clue_panel')), findsOneWidget);
    expect(find.byType(ClueCardWidget), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'small screen shows generated level 1 and level 6 without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(home: _gameScreen()));
      await tester.pumpAndSettle();

      _expectBooksDoNotOverlap(tester, _generatedLevel1BookIds);
      expect(find.byKey(const Key('clue_panel')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(MaterialApp(home: _gameScreen(level: 6)));
      await tester.pumpAndSettle();

      _expectBooksDoNotOverlap(tester, _generatedLevel6BookIds);
      expect(find.byKey(const Key('clue_panel')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(MaterialApp(home: _gameScreen(level: 51)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('bookshelf_tier_0')), findsOneWidget);
      expect(find.byKey(const Key('bookshelf_tier_1')), findsOneWidget);
      _expectGridBooksDoNotOverlap(tester, _generatedLevel51BookIds);
      expect(find.text(_initialClueTitle(51)), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('generation failure shows retryable error view without details', (
    tester,
  ) async {
    final generator = _SpyStageGenerator(errors: [_generationException()]);

    await tester.pumpWidget(
      MaterialApp(home: _gameScreen(stageGenerator: generator)),
    );

    expect(find.byKey(const Key('game_generation_error')), findsOneWidget);
    expect(find.text(AppStrings.generationErrorTitle), findsOneWidget);
    expect(find.text('Level 1을 생성하는 중 문제가 발생했습니다.'), findsOneWidget);
    expect(
      find.byKey(const Key('game_generation_retry_button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('game_generation_home_button')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('bookshelf_tier_0')), findsNothing);
    expect(find.byKey(const Key('clue_panel')), findsNothing);
    expect(find.byKey(const Key('clear_result_overlay')), findsNothing);
    expect(find.textContaining('3270846678'), findsNothing);
    expect(find.textContaining('forced generation failure'), findsNothing);
  });

  testWidgets('generation retry can recover into level 1 game', (tester) async {
    final generator = _SpyStageGenerator(errors: [_generationException()]);

    await tester.pumpWidget(
      MaterialApp(home: _gameScreen(stageGenerator: generator)),
    );

    expect(generator.callCount, 1);
    expect(find.byKey(const Key('game_generation_error')), findsOneWidget);

    await tester.tap(find.byKey(const Key('game_generation_retry_button')));
    await tester.pumpAndSettle();

    expect(generator.callCount, 2);
    expect(find.byKey(const Key('game_generation_error')), findsNothing);
    expect(find.text(AppStrings.levelOne), findsOneWidget);
    expect(_visibleBookOrder(tester), _generatedLevel1BookIds);
    expect(find.text(_initialClueTitle(1)), findsOneWidget);
  });

  testWidgets('generation error home button returns to home', (tester) async {
    final generator = _SpyStageGenerator(errors: [UnsupportedError('forced')]);

    await tester.pumpWidget(
      MaterialApp(
        routes: {'/game': (_) => _gameScreen(stageGenerator: generator)},
        home: const Scaffold(body: Text(AppStrings.appTitle)),
      ),
    );

    Navigator.of(
      tester.element(find.text(AppStrings.appTitle)),
    ).pushNamed('/game');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('game_generation_error')), findsOneWidget);
    await tester.tap(find.byKey(const Key('game_generation_home_button')));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.appTitle), findsOneWidget);
    expect(generator.callCount, 1);
  });

  testWidgets('level 51 displays the two-tier T04 game', (tester) async {
    await tester.pumpWidget(MaterialApp(home: _gameScreen(level: 51)));

    expect(find.byKey(const Key('game_generation_error')), findsNothing);
    expect(find.text('Level 51'), findsOneWidget);
    expect(find.byKey(const Key('bookshelf_tier_0')), findsOneWidget);
    expect(find.byKey(const Key('bookshelf_tier_1')), findsOneWidget);
    expect(find.byKey(const Key('bookshelf_tier_2')), findsNothing);
    expect(
      _visibleBookGridOrder(tester, _generatedLevel51BookIds),
      _generatedLevel51BookIds,
    );
    expect(find.text(_initialClueTitle(51)), findsOneWidget);
    expect(find.byType(ClueCardWidget), findsNWidgets(4));
    _expectGridBooksDoNotOverlap(tester, _generatedLevel51BookIds);
    expect(tester.takeException(), isNull);
  });

  testWidgets('level 51 clears through the known cross-tier solution', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: _gameScreen(level: 51)));

    await _clearGeneratedStageByReverseSwaps(
      tester,
      stage: _generatedStage(51),
    );

    expect(find.byKey(const Key('clear_result_overlay')), findsOneWidget);
    expect(find.text('Level 51'), findsWidgets);
    expect(find.text(_targetMoveCountTitle(51)), findsWidgets);
    expect(find.text(_clearedClueTitle(51)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('existing routing still works from game screen', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home_continue_button')));
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
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home_continue_button')));
    await tester.pumpAndSettle();
    await _tapReverseSwapStep(
      tester,
      level: 1,
      reverseIndex: 0,
      finishSwap: false,
    );
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
final _generatedStageFixtures = {
  for (final level in [1, 2, 3, 6, 20, 21, 22, 23, 50, 51, 100, 101, 200])
    level: const StageGenerator().generate(level: level),
};
final _generatedLevel1BookIds = _stageInitialBookIds(1);
final _generatedLevel1TargetIds = _stageTargetBookIds(1);
final _generatedLevel1ClueIds = _stageClueIds(1);
final _generatedLevel1InitialSatisfiedClueIds = _stageInitialSatisfiedClueIds(
  1,
);
final _generatedLevel2BookIds = _stageInitialBookIds(2);
final _generatedLevel2TargetIds = _stageTargetBookIds(2);
final _generatedLevel3BookIds = _stageInitialBookIds(3);
final _generatedLevel6BookIds = _stageInitialBookIds(6);
final _generatedLevel20BookIds = _stageInitialBookIds(20);
final _generatedLevel21BookIds = _stageInitialBookIds(21);
final _generatedLevel22BookIds = _stageInitialBookIds(22);
final _generatedLevel23BookIds = _stageInitialBookIds(23);
final _generatedLevel50BookIds = _stageInitialBookIds(50);
final _generatedLevel51BookIds = _stageInitialBookIds(51);
final _generatedLevel100BookIds = _stageInitialBookIds(100);
final _generatedLevel101BookIds = _stageInitialBookIds(101);
final _generatedLevel200BookIds = _stageInitialBookIds(200);

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

Future<void> _solveGeneratedControllerToClearing(
  GameController controller,
) async {
  final stage = controller.generatedStage;
  if (stage == null) {
    throw StateError('Generated stage is required.');
  }
  var placements = List<BookPlacement>.of(controller.placements);
  for (final step in stage.swapHistory.reversed) {
    final firstBookId = _bookIdAtPosition(placements, step.firstPosition);
    final secondBookId = _bookIdAtPosition(placements, step.secondPosition);
    controller.handleBookTap(firstBookId);
    controller.handleBookTap(secondBookId);
    await _waitForShortSwap();
    placements = _swapPlacementBooks(
      placements,
      step.firstPosition,
      step.secondPosition,
    );
  }
}

Future<void> _finishControllerClear() async {
  for (var i = 0; i < 8; i += 1) {
    await _waitForShortClear();
  }
}

GeneratedStage _generatedStage(int level) {
  final generatorVersion = const GeneratorVersionPolicy().versionForLevel(
    level,
  );
  return _generatedStageFixtures[level] ??
      const StageGenerator().generate(
        level: level,
        generatorVersion: generatorVersion,
      );
}

List<String> _stageInitialBookIds(int level) {
  return _bookIdsBySlot(_generatedStage(level).initialPlacements);
}

List<String> _stageTargetBookIds(int level) {
  return _bookIdsBySlot(_generatedStage(level).targetPlacements);
}

List<String> _stageClueIds(int level) {
  return [for (final clue in _generatedStage(level).clues) clue.id];
}

List<String> _stageInitialSatisfiedClueIds(int level) {
  final stage = _generatedStage(level);
  return const ClueEvaluator()
      .evaluateAll(clues: stage.clues, placements: stage.initialPlacements)
      .toList(growable: false);
}

List<String> _stageSatisfiedClueIdsAfterReverseSwaps({
  required int level,
  required int completedSwapCount,
}) {
  final stage = _generatedStage(level);
  var placements = List<BookPlacement>.of(stage.initialPlacements);
  final reverseSteps = stage.swapHistory.reversed.take(completedSwapCount);
  for (final step in reverseSteps) {
    placements = _swapPlacementBooks(
      placements,
      step.firstPosition,
      step.secondPosition,
    );
  }
  return const ClueEvaluator()
      .evaluateAll(clues: stage.clues, placements: placements)
      .toList(growable: false);
}

BookLogicApp _app({
  GameProgressStore? progressStore,
  LearningProgressStore? learningProgressStore,
  AppFeedbackSettingsStore? feedbackSettingsStore,
}) {
  final soundPlayer = FakeGameSoundPlayer();
  final hapticPlayer = FakeGameHapticPlayer();
  return BookLogicApp(
    progressStore: progressStore ?? FakeGameProgressStore(),
    learningProgressStore:
        learningProgressStore ??
        FakeLearningProgressStore(
          progress: LearningProgress(tutorialCompleted: true),
        ),
    feedbackSettingsStore:
        feedbackSettingsStore ??
        FakeAppFeedbackSettingsStore(settings: AppFeedbackSettings.defaults),
    soundPlayer: soundPlayer,
    hapticPlayer: hapticPlayer,
  );
}

SettingsScreen _testSettingsScreen({
  AppFeedbackSettings settings = AppFeedbackSettings.defaults,
  FakeGameSoundPlayer? soundPlayer,
  FakeGameHapticPlayer? hapticPlayer,
}) {
  final controller = AppFeedbackSettingsController(
    store: FakeAppFeedbackSettingsStore(settings: settings),
  );
  controller.initialize();
  return SettingsScreen(
    feedbackSettingsController: controller,
    soundPlayer: soundPlayer ?? FakeGameSoundPlayer(),
    hapticPlayer: hapticPlayer ?? FakeGameHapticPlayer(),
  );
}

GameScreen _gameScreen({
  int level = 1,
  int generatorVersion = GeneratorConfig.currentVersion,
  StageGenerator stageGenerator = const StageGenerator(),
  GameProgressController? progressController,
}) {
  return GameScreen(
    level: level,
    generatorVersion: generatorVersion,
    progressController:
        progressController ??
        _testProgressController(
          level: level,
          generatorVersion: generatorVersion,
        ),
    stageGenerator: stageGenerator,
  );
}

GameProgressController _testProgressController({
  int level = 1,
  int generatorVersion = GeneratorConfig.currentVersion,
  FakeGameProgressStore? store,
}) {
  final progress = GameProgress(
    schemaVersion: GameProgress.currentSchemaVersion,
    currentLevel: level,
    highestUnlockedLevel: level,
    generatorVersion: generatorVersion,
  );
  final controller = GameProgressController(
    store: store ?? FakeGameProgressStore(progress: progress),
  );
  controller.load();
  return controller;
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

Future<void> _finishClear(WidgetTester tester, [int? bookCount]) async {
  final clearBookCount = bookCount ?? _generatedLevel1BookIds.length;
  await tester.pump(AppDurations.clueCompletionDelay);
  for (var i = 0; i < clearBookCount; i += 1) {
    await tester.pump(AppDurations.clearBookStep);
  }
  await tester.pump(AppDurations.clearFinalGlow);
  await tester.pump(AppDurations.resultOverlay);
  await tester.pump();
}

Future<void> _clearGeneratedLevel1Game(WidgetTester tester) async {
  await _clearGeneratedStageByReverseSwaps(tester, stage: _generatedStage(1));
}

Future<void> _goToGeneratedLevel2(WidgetTester tester) async {
  await _clearGeneratedLevel1Game(tester);
  await tester.tap(find.byKey(const Key('clear_next_level_button')));
  await tester.pumpAndSettle();
}

Future<void> _clearGeneratedLevel2Game(WidgetTester tester) async {
  await _clearGeneratedStageByReverseSwaps(tester, stage: _generatedStage(2));
}

Future<void> _clearGeneratedLevel20Game(WidgetTester tester) async {
  await _clearGeneratedStageByReverseSwaps(tester, stage: _generatedStage(20));
}

Future<void> _clearGeneratedLevel22Game(WidgetTester tester) async {
  await _clearGeneratedStageByReverseSwaps(tester, stage: _generatedStage(22));
}

Future<void> _clearGeneratedLevel50Game(WidgetTester tester) async {
  await _clearGeneratedStageByReverseSwaps(tester, stage: _generatedStage(50));
}

Future<void> _clearGeneratedLevel100Game(WidgetTester tester) async {
  await _clearGeneratedStageByReverseSwaps(tester, stage: _generatedStage(100));
}

Future<void> _clearGeneratedStageByReverseSwaps(
  WidgetTester tester, {
  required GeneratedStage stage,
}) async {
  var placements = List<BookPlacement>.of(stage.initialPlacements);
  final reverseSteps = stage.swapHistory.reversed.toList();

  for (var index = 0; index < reverseSteps.length; index += 1) {
    final step = reverseSteps[index];
    final firstBookId = _bookIdAtPosition(placements, step.firstPosition);
    final secondBookId = _bookIdAtPosition(placements, step.secondPosition);

    await tester.tap(find.byKey(Key('book_$firstBookId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('book_$secondBookId')));
    await _finishSwap(tester);

    placements = _swapPlacementBooks(
      placements,
      step.firstPosition,
      step.secondPosition,
    );
    if (index == reverseSteps.length - 1) {
      await _finishClear(tester, stage.totalBookCount);
    } else {
      await _settleClueState(tester);
    }
  }
}

List<String> _reverseSwapBookIds({
  required int level,
  required int reverseIndex,
}) {
  final stage = _generatedStage(level);
  var placements = List<BookPlacement>.of(stage.initialPlacements);
  final reverseSteps = stage.swapHistory.reversed.toList();
  for (var index = 0; index < reverseIndex; index += 1) {
    final step = reverseSteps[index];
    placements = _swapPlacementBooks(
      placements,
      step.firstPosition,
      step.secondPosition,
    );
  }
  final step = reverseSteps[reverseIndex];
  return [
    _bookIdAtPosition(placements, step.firstPosition),
    _bookIdAtPosition(placements, step.secondPosition),
  ];
}

Future<void> _tapReverseSwapStep(
  WidgetTester tester, {
  required int level,
  required int reverseIndex,
  bool finishSwap = true,
}) async {
  final ids = _reverseSwapBookIds(level: level, reverseIndex: reverseIndex);
  await tester.tap(find.byKey(Key('book_${ids[0]}')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('book_${ids[1]}')));
  if (finishSwap) {
    await _finishSwap(tester);
  } else {
    await tester.pump();
  }
}

void _expectGeneratedLevel1CluesVisible() {
  _expectGeneratedCluesVisible(1);
}

void _expectGeneratedLevel2CluesVisible() {
  _expectGeneratedCluesVisible(2);
}

void _expectGeneratedCluesVisible(int level) {
  final stage = _generatedStage(level);
  final formatter = const ClueTextFormatter();
  final books = [
    for (final placement in stage.targetPlacements) placement.book,
  ];
  for (final clue in stage.clues) {
    expect(find.byKey(Key('clue_${clue.id}')), findsOneWidget);
    expect(
      find.text(formatter.format(clue: clue, books: books)),
      findsOneWidget,
    );
  }
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

void _expectInitialGeneratedLevel1Checks() {
  _expectOnlyGeneratedChecks(_generatedLevel1InitialSatisfiedClueIds);
}

void _expectOnlyGeneratedChecks(List<String> satisfiedIds) {
  for (final clueId in _generatedLevel1ClueIds) {
    final matcher = satisfiedIds.contains(clueId)
        ? findsOneWidget
        : findsNothing;
    expect(find.byKey(Key('clue_check_$clueId')), matcher);
  }
}

String _initialClueTitle(int level) {
  final stage = _generatedStage(level);
  return '${AppStrings.clueTitle} '
      '${_stageInitialSatisfiedClueIds(level).length}/${stage.clueCount}';
}

String _clearedClueTitle(int level) {
  final stage = _generatedStage(level);
  return '${AppStrings.clueTitle} ${stage.clueCount}/${stage.clueCount}';
}

String _moveCountTitle(int moveCount) {
  return '${AppStrings.moveCountPrefix} $moveCount회';
}

String _targetMoveCountTitle(int level) {
  return _moveCountTitle(_generatedStage(level).targetSwapCount);
}

Key _level1ReverseSwapBookKey(int reverseIndex, int bookIndex) {
  final bookId = _reverseSwapBookIds(
    level: 1,
    reverseIndex: reverseIndex,
  )[bookIndex];
  return Key('book_$bookId');
}

String _bookLabelForId(int level, String bookId) {
  final stage = _generatedStage(level);
  final book = stage.targetPlacements
      .map((placement) => placement.book)
      .singleWhere((candidate) => candidate.id == bookId);
  return const BookLabelFormatter().formatBook(book);
}

void _expectBookCentersStrictlyIncreasing(
  WidgetTester tester,
  List<String> bookIds,
) {
  var previousCenter = double.negativeInfinity;
  for (final bookId in bookIds) {
    final center = _bookCenterXOf(tester, bookId);
    expect(center, greaterThan(previousCenter), reason: bookId);
    previousCenter = center;
  }
}

void _expectBooksDoNotOverlap(WidgetTester tester, List<String> bookIds) {
  final rects = [
    for (final bookId in bookIds)
      tester.getRect(find.byKey(Key('book_$bookId'))),
  ]..sort((left, right) => left.left.compareTo(right.left));

  for (var index = 1; index < rects.length; index += 1) {
    expect(
      rects[index].left,
      greaterThanOrEqualTo(rects[index - 1].right - 0.5),
    );
  }
}

void _expectGridBooksDoNotOverlap(WidgetTester tester, List<String> bookIds) {
  final rects =
      [
        for (final bookId in bookIds)
          tester.getRect(find.byKey(Key('book_$bookId'))),
      ]..sort((left, right) {
        final topComparison = left.top.compareTo(right.top);
        if (topComparison != 0) {
          return topComparison;
        }
        return left.left.compareTo(right.left);
      });

  final rows = <List<Rect>>[];
  for (final rect in rects) {
    if (rows.isEmpty || (rows.last.first.top - rect.top).abs() > 1) {
      rows.add([rect]);
    } else {
      rows.last.add(rect);
    }
  }

  for (final row in rows) {
    row.sort((left, right) => left.left.compareTo(right.left));
    for (var index = 1; index < row.length; index += 1) {
      expect(row[index].left, greaterThanOrEqualTo(row[index - 1].right - 0.5));
    }
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

List<String> _visibleBookOrder(WidgetTester tester, [List<String>? bookIds]) {
  final ids = bookIds ?? _generatedLevel1BookIds;
  final entries = [
    for (final id in ids)
      MapEntry(id, tester.getCenter(find.byKey(Key('book_$id'))).dx),
  ]..sort((left, right) => left.value.compareTo(right.value));
  return [for (final entry in entries) entry.key];
}

List<String> _visibleBookGridOrder(WidgetTester tester, List<String> bookIds) {
  final entries =
      [
        for (final id in bookIds)
          MapEntry(id, tester.getCenter(find.byKey(Key('book_$id')))),
      ]..sort((left, right) {
        final yComparison = left.value.dy.compareTo(right.value.dy);
        if (yComparison != 0) {
          return yComparison;
        }
        return left.value.dx.compareTo(right.value.dx);
      });
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
    ..sort((left, right) {
      final tierComparison = left.position.tierIndex.compareTo(
        right.position.tierIndex,
      );
      if (tierComparison != 0) {
        return tierComparison;
      }
      return left.position.slotIndex.compareTo(right.position.slotIndex);
    });
  return [for (final placement in sortedPlacements) placement.book.id];
}

String _bookIdAtPosition(
  List<BookPlacement> placements,
  BookPosition position,
) {
  return placements
      .firstWhere((placement) => placement.position == position)
      .book
      .id;
}

List<BookPlacement> _swapPlacementBooks(
  List<BookPlacement> placements,
  BookPosition first,
  BookPosition second,
) {
  final firstPlacement = placements.firstWhere(
    (placement) => placement.position == first,
  );
  final secondPlacement = placements.firstWhere(
    (placement) => placement.position == second,
  );
  return [
    for (final placement in placements)
      if (placement.position == first)
        placement.copyWith(book: secondPlacement.book)
      else if (placement.position == second)
        placement.copyWith(book: firstPlacement.book)
      else
        placement,
  ];
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

class _SpyStageGenerator extends StageGenerator {
  _SpyStageGenerator({List<Object?> errors = const [], this.onGenerate})
    : _errors = List<Object?>.of(errors);

  final StageGenerator _delegate = const StageGenerator();
  final List<Object?> _errors;
  final GeneratedStage Function(int level, int generatorVersion, int callCount)?
  onGenerate;
  final levels = <int>[];
  final generatorVersions = <int>[];
  int callCount = 0;

  @override
  GeneratedStage generate({
    required int level,
    int generatorVersion = GeneratorConfig.currentVersion,
  }) {
    callCount += 1;
    levels.add(level);
    generatorVersions.add(generatorVersion);
    if (_errors.isNotEmpty) {
      final error = _errors.removeAt(0);
      if (error != null) {
        _throwGenerationError(error);
      }
    }
    final customGenerate = onGenerate;
    if (customGenerate != null) {
      return customGenerate(level, generatorVersion, callCount);
    }
    return _delegate.generate(level: level, generatorVersion: generatorVersion);
  }
}

Never _throwGenerationError(Object error) {
  if (error is StageGenerationException) {
    throw error;
  }
  if (error is UnsupportedError) {
    throw error;
  }
  if (error is ArgumentError) {
    throw error;
  }
  throw StateError(error.toString());
}

StageGenerationException _generationException() {
  return StageGenerationException(
    level: 1,
    generatorVersion: 1,
    failures: const [
      StageGenerationAttemptFailure(
        attempt: 0,
        seed: 3270846678,
        message: 'StateError: forced generation failure',
      ),
    ],
    fallbackMessage: 'StateError: forced generation failure',
  );
}
