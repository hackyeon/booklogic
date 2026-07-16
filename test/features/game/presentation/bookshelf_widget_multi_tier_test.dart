import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:booklogic/core/constants/app_durations.dart';
import 'package:booklogic/features/game/application/game_controller.dart';
import 'package:booklogic/features/game/domain/book_placement.dart';
import 'package:booklogic/features/game/presentation/widgets/bookshelf_widget.dart';

import '../fixtures/multi_tier_game_fixture.dart';

void main() {
  group('BookshelfWidget multi-tier layout', () {
    testWidgets('renders two tiers with aligned slots and no overlap', (
      tester,
    ) async {
      await tester.pumpWidget(
        _shelfApp(
          placements: multiTierTwoTierInitialPlacements,
          tierCount: 2,
          booksPerTier: 4,
        ),
      );

      expect(find.byKey(const Key('bookshelf_tier_0')), findsOneWidget);
      expect(find.byKey(const Key('bookshelf_tier_1')), findsOneWidget);
      expect(find.byKey(const Key('bookshelf_tier_2')), findsNothing);
      expect(find.byKey(const Key('bookshelf_tier_label_0')), findsOneWidget);
      expect(find.byKey(const Key('bookshelf_tier_label_1')), findsOneWidget);
      expect(find.text('1단'), findsOneWidget);
      expect(find.text('2단'), findsOneWidget);
      for (final id in _ids(multiTierTwoTierInitialPlacements)) {
        expect(find.byKey(Key('book_$id')), findsOneWidget);
      }

      expect(
        _bookCenterXOf(tester, 'purple_leaf'),
        moreOrLessEquals(_bookCenterXOf(tester, 'blue_moon'), epsilon: 1),
      );
      expect(
        _bookTopOf(tester, 'blue_moon'),
        greaterThan(_bookTopOf(tester, 'purple_leaf')),
      );
      _expectBooksDoNotOverlap(tester, _ids(multiTierTwoTierInitialPlacements));
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders three tiers with stable labels and keys', (
      tester,
    ) async {
      await tester.pumpWidget(
        _shelfApp(
          placements: multiTierThreeTierPlacements,
          tierCount: 3,
          booksPerTier: 4,
        ),
      );

      expect(find.byKey(const Key('bookshelf_tier_0')), findsOneWidget);
      expect(find.byKey(const Key('bookshelf_tier_1')), findsOneWidget);
      expect(find.byKey(const Key('bookshelf_tier_2')), findsOneWidget);
      expect(find.text('1단'), findsOneWidget);
      expect(find.text('2단'), findsOneWidget);
      expect(find.text('3단'), findsOneWidget);
      for (final id in _ids(multiTierThreeTierPlacements)) {
        expect(find.byKey(Key('book_$id')), findsOneWidget);
      }

      expect(
        _bookTopOf(tester, 'purple_leaf'),
        greaterThan(_bookTopOf(tester, 'blue_moon')),
      );
      expect(
        _bookTopOf(tester, 'green_moon'),
        greaterThan(_bookTopOf(tester, 'purple_leaf')),
      );
      expect(
        _bookCenterXOf(tester, 'blue_moon'),
        moreOrLessEquals(_bookCenterXOf(tester, 'purple_leaf'), epsilon: 1),
      );
      _expectBooksDoNotOverlap(tester, _ids(multiTierThreeTierPlacements));
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders the maximum three by six layout on a small screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _shelfApp(
          placements: multiTierThreeBySixPlacements,
          tierCount: 3,
          booksPerTier: 6,
        ),
      );

      expect(find.byKey(const Key('bookshelf_tier_0')), findsOneWidget);
      expect(find.byKey(const Key('bookshelf_tier_1')), findsOneWidget);
      expect(find.byKey(const Key('bookshelf_tier_2')), findsOneWidget);
      for (final id in _ids(multiTierThreeBySixPlacements)) {
        expect(find.byKey(Key('book_$id')), findsOneWidget);
      }
      _expectBooksDoNotOverlap(tester, _ids(multiTierThreeBySixPlacements));
      expect(tester.takeException(), isNull);
    });
  });

  group('BookshelfWidget cross-tier interaction', () {
    testWidgets('animates a vertical cross-tier swap', (tester) async {
      final controller = _twoTierController();
      await tester.pumpWidget(_controllerShelfApp(controller));

      final blueStart = tester.getRect(find.byKey(const Key('book_blue_moon')));
      final purpleStart = tester.getRect(
        find.byKey(const Key('book_purple_leaf')),
      );

      await tester.tap(find.byKey(const Key('book_blue_moon')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('book_purple_leaf')));
      await tester.pump();

      expect(controller.isAnimating, isTrue);
      expect(controller.isInputLocked, isTrue);

      await tester.pump(const Duration(milliseconds: 110));
      final blueMid = tester.getRect(find.byKey(const Key('book_blue_moon')));
      final purpleMid = tester.getRect(
        find.byKey(const Key('book_purple_leaf')),
      );

      expect(blueMid.top, lessThan(blueStart.top));
      expect(blueMid.top, greaterThanOrEqualTo(purpleStart.top));
      expect(purpleMid.top, greaterThan(purpleStart.top));
      expect(purpleMid.top, lessThanOrEqualTo(blueStart.top));

      await tester.pump(AppDurations.bookSwap);
      await tester.pump(const Duration(milliseconds: 5));

      expect(_bookTopOf(tester, 'blue_moon'), lessThan(blueStart.top));
      expect(_bookTopOf(tester, 'purple_leaf'), greaterThan(purpleStart.top));
      expect(controller.satisfiedClueCount, 3);
      controller.dispose();
    });

    testWidgets('animates a diagonal cross-tier swap', (tester) async {
      final controller = _diagonalController();
      await tester.pumpWidget(_controllerShelfApp(controller));

      final greenStart = tester.getRect(
        find.byKey(const Key('book_green_cloud')),
      );
      final purpleStart = tester.getRect(
        find.byKey(const Key('book_purple_leaf')),
      );

      await tester.tap(find.byKey(const Key('book_green_cloud')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('book_purple_leaf')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));

      final greenMid = tester.getRect(
        find.byKey(const Key('book_green_cloud')),
      );
      final purpleMid = tester.getRect(
        find.byKey(const Key('book_purple_leaf')),
      );

      expect(greenMid.left, lessThan(greenStart.left));
      expect(greenMid.top, greaterThan(greenStart.top));
      expect(purpleMid.left, greaterThan(purpleStart.left));
      expect(purpleMid.top, lessThan(purpleStart.top));

      await tester.pump(AppDurations.bookSwap);
      await tester.pump(const Duration(milliseconds: 5));

      expect(_bookCenterXOf(tester, 'green_cloud'), lessThan(greenStart.left));
      expect(_bookTopOf(tester, 'green_cloud'), greaterThan(greenStart.top));
      expect(
        _bookCenterXOf(tester, 'purple_leaf'),
        greaterThan(purpleStart.right),
      );
      expect(_bookTopOf(tester, 'purple_leaf'), lessThan(purpleStart.top));
      controller.dispose();
    });

    testWidgets('empty shelf and label taps clear selection', (tester) async {
      final controller = _twoTierController();
      await tester.pumpWidget(_controllerShelfApp(controller));

      await tester.tap(find.byKey(const Key('book_blue_moon')));
      await tester.pumpAndSettle();
      expect(controller.selectedBookId, 'blue_moon');

      await tester.tap(find.byKey(const Key('bookshelf_tier_label_0')));
      await tester.pumpAndSettle();
      expect(controller.selectedBookId, isNull);
      expect(controller.moveCount, 0);

      await tester.tap(find.byKey(const Key('book_blue_moon')));
      await tester.pumpAndSettle();
      expect(controller.selectedBookId, 'blue_moon');

      await tester.tap(find.byKey(const Key('bookshelf_empty_tap_area')));
      await tester.pumpAndSettle();
      expect(controller.selectedBookId, isNull);
      expect(controller.moveCount, 0);
      controller.dispose();
    });

    testWidgets('semantics position values update after cross-tier swap', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      late final GameController controller;
      try {
        controller = _twoTierLayoutController();
        await tester.pumpWidget(_controllerShelfApp(controller));

        _expectBookSemantics(tester, 'blue_moon', '파란 달 책', '2단 1번째 칸');
        _expectBookSemantics(tester, 'purple_leaf', '보라 잎 책', '1단 1번째 칸');

        await tester.tap(find.byKey(const Key('book_blue_moon')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('book_purple_leaf')));
        await tester.pump(AppDurations.bookSwap);
        await tester.pump(const Duration(milliseconds: 5));

        _expectBookSemantics(tester, 'blue_moon', '파란 달 책', '1단 1번째 칸');
        _expectBookSemantics(tester, 'purple_leaf', '보라 잎 책', '2단 1번째 칸');
      } finally {
        controller.dispose();
        semantics.dispose();
      }
    });
  });
}

Widget _shelfApp({
  required List<BookPlacement> placements,
  required int tierCount,
  required int booksPerTier,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: BookshelfWidget(
          placements: placements,
          tierCount: tierCount,
          booksPerTier: booksPerTier,
          selectedBookId: null,
          onBookTap: (_) {},
          onEmptyTap: () {},
          isAnimating: false,
          activeSwap: null,
          isInteractionLocked: false,
          isClearing: false,
          isCleared: false,
          clearActiveBookId: null,
          isShelfGlowing: false,
        ),
      ),
    ),
  );
}

Widget _controllerShelfApp(GameController controller) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            return BookshelfWidget(
              placements: controller.placements,
              tierCount: controller.tierCount,
              booksPerTier: controller.booksPerTier,
              selectedBookId: controller.selectedBookId,
              onBookTap: controller.handleBookTap,
              onEmptyTap: controller.cancelSelection,
              isAnimating: controller.isAnimating,
              activeSwap: controller.activeSwap,
              isInteractionLocked: controller.isInputLocked,
              isClearing: controller.isClearing,
              isCleared: controller.isCleared,
              clearActiveBookId: controller.clearActiveBookId,
              isShelfGlowing: controller.isShelfGlowing,
            );
          },
        ),
      ),
    ),
  );
}

GameController _twoTierController() {
  return GameController(
    initialPlacements: multiTierTwoTierInitialPlacements,
    clues: multiTierTwoTierClues,
    swapDuration: AppDurations.bookSwap,
    clueCompletionDelay: const Duration(seconds: 30),
    clearBookStepDuration: const Duration(seconds: 30),
    clearFinalGlowDuration: const Duration(seconds: 30),
  );
}

GameController _diagonalController() {
  return GameController(
    initialPlacements: multiTierTwoTierTargetPlacements,
    clues: const [],
    swapDuration: AppDurations.bookSwap,
    clueCompletionDelay: const Duration(seconds: 30),
    clearBookStepDuration: const Duration(seconds: 30),
    clearFinalGlowDuration: const Duration(seconds: 30),
  );
}

GameController _twoTierLayoutController() {
  return GameController(
    initialPlacements: multiTierTwoTierInitialPlacements,
    clues: const [],
    swapDuration: AppDurations.bookSwap,
    clueCompletionDelay: const Duration(seconds: 30),
    clearBookStepDuration: const Duration(seconds: 30),
    clearFinalGlowDuration: const Duration(seconds: 30),
  );
}

List<String> _ids(List<BookPlacement> placements) {
  return [for (final placement in placements) placement.book.id];
}

double _bookCenterXOf(WidgetTester tester, String bookId) {
  return tester.getCenter(find.byKey(Key('book_$bookId'))).dx;
}

double _bookTopOf(WidgetTester tester, String bookId) {
  return tester.getTopLeft(find.byKey(Key('book_$bookId'))).dy;
}

void _expectBooksDoNotOverlap(WidgetTester tester, List<String> bookIds) {
  final rects = [
    for (final bookId in bookIds)
      tester.getRect(find.byKey(Key('book_$bookId'))),
  ];
  for (var leftIndex = 0; leftIndex < rects.length; leftIndex += 1) {
    for (
      var rightIndex = leftIndex + 1;
      rightIndex < rects.length;
      rightIndex += 1
    ) {
      expect(
        rects[leftIndex].overlaps(rects[rightIndex]),
        isFalse,
        reason: '${bookIds[leftIndex]} overlaps ${bookIds[rightIndex]}',
      );
    }
  }
}

void _expectBookSemantics(
  WidgetTester tester,
  String bookId,
  String label,
  String value,
) {
  final semantics = tester.getSemantics(find.byKey(Key('book_$bookId')));
  expect(semantics.label, label);
  expect(semantics.value, value);
}
