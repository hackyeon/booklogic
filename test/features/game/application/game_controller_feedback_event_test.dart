import 'package:flutter_test/flutter_test.dart';

import 'package:booklogic/core/feedback/domain/game_feedback_event.dart';
import 'package:booklogic/features/game/application/game_controller.dart';
import 'package:booklogic/features/game/application/game_status.dart';
import 'package:booklogic/features/game/domain/book.dart';
import 'package:booklogic/features/game/domain/book_placement.dart';
import 'package:booklogic/features/game/domain/book_position.dart';
import 'package:booklogic/features/game/domain/book_selector.dart';
import 'package:booklogic/features/game/domain/clue.dart';

void main() {
  test('emits bookSelected once and skips cancel events', () {
    final controller = _controller(clues: const []);
    final events = <GameFeedbackEvent>[];
    final subscription = controller.feedbackEvents.listen(events.add);

    controller.handleBookTap('blue_moon');
    controller.handleBookTap('blue_moon');
    controller.cancelSelection();
    controller.handleBookTap('unknown');

    expect(events.map((event) => event.type), [
      GameFeedbackEventType.bookSelected,
    ]);
    expect(events.single.bookId, 'blue_moon');

    subscription.cancel();
    controller.dispose();
  });

  test(
    'emits booksSwapped for valid swaps and not identical visual attempts',
    () {
      final controller = _controller(clues: const []);
      final events = <GameFeedbackEvent>[];
      final subscription = controller.feedbackEvents.listen(events.add);

      controller.handleBookTap('blue_moon');
      controller.handleBookTap('red_star');

      expect(controller.status, GameStatus.animating);
      expect(controller.moveCount, 1);
      expect(events.map((event) => event.type), [
        GameFeedbackEventType.bookSelected,
        GameFeedbackEventType.booksSwapped,
      ]);

      subscription.cancel();
      controller.dispose();

      final identicalController = GameController(
        initialPlacements: const [
          BookPlacement(
            book: Book(
              id: 'copy_1',
              color: BookColor.blue,
              symbol: BookSymbol.moon,
            ),
            position: BookPosition(tierIndex: 0, slotIndex: 0),
          ),
          BookPlacement(
            book: Book(
              id: 'copy_2',
              color: BookColor.blue,
              symbol: BookSymbol.moon,
            ),
            position: BookPosition(tierIndex: 0, slotIndex: 1),
          ),
        ],
        clues: const [],
      );
      final identicalEvents = <GameFeedbackEvent>[];
      final identicalSubscription = identicalController.feedbackEvents.listen(
        identicalEvents.add,
      );

      identicalController.handleBookTap('copy_1');
      identicalController.handleBookTap('copy_2');

      expect(identicalController.moveCount, 0);
      expect(identicalEvents.map((event) => event.type), [
        GameFeedbackEventType.bookSelected,
      ]);

      identicalSubscription.cancel();
      identicalController.dispose();
    },
  );

  test(
    'emits newly satisfied clues after animation and in clue order',
    () async {
      final controller = _controller(
        clues: const [
          EdgePositionClue(
            id: 'new_1',
            subject: BookIdSelector(bookId: 'blue_moon'),
            tierIndex: 0,
            edge: ShelfEdge.left,
          ),
          EdgePositionClue(
            id: 'new_2',
            subject: BookIdSelector(bookId: 'blue_moon'),
            tierIndex: 0,
            edge: ShelfEdge.left,
          ),
          EdgePositionClue(
            id: 'previous',
            subject: BookIdSelector(bookId: 'red_star'),
            tierIndex: 0,
            edge: ShelfEdge.left,
          ),
        ],
      );
      final events = <GameFeedbackEvent>[];
      final subscription = controller.feedbackEvents.listen(events.add);

      controller.handleBookTap('blue_moon');
      controller.handleBookTap('red_star');
      expect(
        events.any(
          (event) => event.type == GameFeedbackEventType.cluesNewlySatisfied,
        ),
        isFalse,
      );

      await Future<void>.delayed(const Duration(milliseconds: 2));

      final clueEvent = events.singleWhere(
        (event) => event.type == GameFeedbackEventType.cluesNewlySatisfied,
      );
      expect(clueEvent.clueIds, ['new_1', 'new_2']);

      subscription.cancel();
      controller.dispose();
    },
  );

  test(
    'emits stageCleared once and suppresses clue satisfied event on clear',
    () async {
      final controller = _controller(
        clues: const [
          EdgePositionClue(
            id: 'clear',
            subject: BookIdSelector(bookId: 'blue_moon'),
            tierIndex: 0,
            edge: ShelfEdge.left,
          ),
        ],
      );
      final events = <GameFeedbackEvent>[];
      final subscription = controller.feedbackEvents.listen(events.add);

      controller.handleBookTap('blue_moon');
      controller.handleBookTap('red_star');
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(events.map((event) => event.type), [
        GameFeedbackEventType.bookSelected,
        GameFeedbackEventType.booksSwapped,
        GameFeedbackEventType.stageCleared,
      ]);
      expect(
        events.where(
          (event) => event.type == GameFeedbackEventType.cluesNewlySatisfied,
        ),
        isEmpty,
      );

      subscription.cancel();
      controller.dispose();
    },
  );
}

GameController _controller({required List<Clue> clues}) {
  return GameController(
    initialPlacements: const [
      BookPlacement(
        book: Book(
          id: 'red_star',
          color: BookColor.red,
          symbol: BookSymbol.star,
        ),
        position: BookPosition(tierIndex: 0, slotIndex: 0),
      ),
      BookPlacement(
        book: Book(
          id: 'blue_moon',
          color: BookColor.blue,
          symbol: BookSymbol.moon,
        ),
        position: BookPosition(tierIndex: 0, slotIndex: 1),
      ),
    ],
    clues: clues,
    swapDuration: const Duration(milliseconds: 1),
    clueCompletionDelay: const Duration(milliseconds: 1),
    clearBookStepDuration: const Duration(milliseconds: 1),
    clearFinalGlowDuration: const Duration(milliseconds: 1),
  );
}
