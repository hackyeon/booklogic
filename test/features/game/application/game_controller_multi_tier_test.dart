import 'package:flutter_test/flutter_test.dart';

import 'package:booklogic/features/game/application/game_controller.dart';
import 'package:booklogic/features/game/application/game_status.dart';
import 'package:booklogic/features/game/domain/book.dart';
import 'package:booklogic/features/game/domain/book_placement.dart';
import 'package:booklogic/features/game/domain/book_position.dart';
import 'package:booklogic/features/game/domain/book_selector.dart';
import 'package:booklogic/features/game/domain/clue.dart';
import 'package:booklogic/features/game/domain/clue_evaluator.dart';
import 'package:booklogic/features/game/generator/stage_generator.dart';

import '../fixtures/multi_tier_game_fixture.dart';

void main() {
  group('GameController multi-tier layout', () {
    test('reports one, two, and three tier layouts', () {
      final oneTier = GameController(
        initialPlacements: multiTierTwoTierInitialPlacements.take(4).toList(),
        clues: const [],
      );
      final twoTier = _twoTierController();
      final threeTier = GameController(
        initialPlacements: multiTierThreeTierPlacements,
        clues: const [],
      );

      expect(oneTier.tierCount, 1);
      expect(oneTier.booksPerTier, 4);
      expect(oneTier.totalBookCount, 4);
      expect(twoTier.tierCount, 2);
      expect(twoTier.booksPerTier, 4);
      expect(twoTier.totalBookCount, 8);
      expect(threeTier.tierCount, 3);
      expect(threeTier.booksPerTier, 4);
      expect(threeTier.totalBookCount, 12);

      oneTier.dispose();
      twoTier.dispose();
      threeTier.dispose();
    });

    test('rejects invalid placement layouts', () {
      expect(
        () => BookPosition(tierIndex: -1, slotIndex: 0),
        throwsAssertionError,
      );
      expect(
        () => BookPosition(tierIndex: 0, slotIndex: -1),
        throwsAssertionError,
      );
      expect(
        () => GameController(
          initialPlacements: [
            _placement('blue_moon', BookColor.blue, BookSymbol.moon, 0, 0),
            _placement('red_star', BookColor.red, BookSymbol.star, 0, 0),
          ],
          clues: const [],
        ),
        throwsArgumentError,
      );
      expect(
        () => GameController(
          initialPlacements: [
            _placement('blue_moon', BookColor.blue, BookSymbol.moon, 0, 0),
            _placement('red_star', BookColor.red, BookSymbol.star, 0, 2),
          ],
          clues: const [],
        ),
        throwsArgumentError,
      );
      expect(
        () => GameController(
          initialPlacements: [
            _placement('blue_moon', BookColor.blue, BookSymbol.moon, 0, 0),
            _placement('red_star', BookColor.red, BookSymbol.star, 0, 1),
            _placement('yellow_key', BookColor.yellow, BookSymbol.key, 1, 0),
          ],
          clues: const [],
        ),
        throwsArgumentError,
      );
      expect(
        () => GameController(
          initialPlacements: [
            _placement('b0', BookColor.blue, BookSymbol.moon, 0, 0),
            _placement('b1', BookColor.red, BookSymbol.moon, 1, 0),
            _placement('b2', BookColor.yellow, BookSymbol.moon, 2, 0),
            _placement('b3', BookColor.green, BookSymbol.moon, 3, 0),
          ],
          clues: const [],
        ),
        throwsArgumentError,
      );
      expect(
        () => GameController(
          initialPlacements: [
            for (var slot = 0; slot < 7; slot += 1)
              _placement(
                'wide_$slot',
                BookColor.blue,
                BookSymbol.values[slot],
                0,
                slot,
              ),
          ],
          clues: const [],
        ),
        throwsArgumentError,
      );
    });

    test('returns immutable placements for a tier in slot order', () {
      final controller = GameController(
        initialPlacements: multiTierTwoTierInitialPlacements.reversed.toList(),
        clues: multiTierTwoTierClues,
      );

      expect(_ids(controller.placementsForTier(0)), [
        'purple_leaf',
        'red_star',
        'yellow_key',
        'green_cloud',
      ]);
      expect(_ids(controller.placementsForTier(1)), [
        'blue_moon',
        'orange_drop',
        'blue_sun',
        'red_diamond',
      ]);
      expect(
        () => controller.placementsForTier(0).clear(),
        throwsUnsupportedError,
      );
      expect(() => controller.placementsForTier(2), throwsRangeError);

      controller.dispose();
    });
  });

  group('GameController cross-tier interaction', () {
    test('swaps books across tiers and reevaluates after animation', () async {
      final controller = _twoTierController();

      expect(controller.satisfiedClueCount, 1);
      expect(_positionOf(controller.placements, 'blue_moon'), _position(1, 0));
      expect(
        _positionOf(controller.placements, 'purple_leaf'),
        _position(0, 0),
      );

      controller.handleBookTap('blue_moon');
      controller.handleBookTap('purple_leaf');

      expect(controller.status, GameStatus.animating);
      expect(controller.moveCount, 1);
      expect(controller.activeSwap, isNotNull);
      expect(controller.satisfiedClueCount, 1);
      expect(_positionOf(controller.placements, 'blue_moon'), _position(0, 0));
      expect(
        _positionOf(controller.placements, 'purple_leaf'),
        _position(1, 0),
      );

      controller.handleBookTap('red_star');
      expect(controller.selectedBookId, isNull);
      expect(controller.moveCount, 1);

      await _waitForShortSwap();

      expect(controller.activeSwap, isNull);
      expect(controller.satisfiedClueCount, 3);
      expect(controller.status, GameStatus.clearing);
      expect(controller.hasClearTriggered, isTrue);

      controller.dispose();
    });

    test('ignores visually identical swaps across tiers', () async {
      final controller = GameController(
        initialPlacements: multiTierDuplicateVisualPlacements,
        clues: const [],
        swapDuration: _shortSwapDuration,
      );
      final initialPositions = _positionsById(controller.placements);

      controller.handleBookTap('orange_cloud_copy_01');
      controller.handleBookTap('orange_cloud_copy_02');

      expect(controller.moveCount, 0);
      expect(controller.status, GameStatus.idle);
      expect(controller.activeSwap, isNull);
      expect(controller.selectedBookId, isNull);
      expect(_positionsById(controller.placements), initialPositions);

      await _waitForShortSwap();
      expect(controller.status, GameStatus.idle);
      controller.dispose();
    });

    test('restart restores all tier and slot positions', () async {
      final controller = _twoTierController();
      final initialPositions = _positionsById(controller.initialPlacements);

      controller.handleBookTap('blue_moon');
      controller.handleBookTap('green_cloud');
      await _waitForShortSwap();

      expect(controller.moveCount, 1);
      expect(_positionsById(controller.placements), isNot(initialPositions));
      final boardRevision = controller.boardRevision;

      controller.restart();

      expect(_positionsById(controller.placements), initialPositions);
      expect(controller.moveCount, 0);
      expect(controller.status, GameStatus.idle);
      expect(controller.selectedBookId, isNull);
      expect(controller.activeSwap, isNull);
      expect(controller.satisfiedClueCount, 1);
      expect(controller.boardRevision, boardRevision + 1);
      expect(_positionsById(controller.initialPlacements), initialPositions);

      controller.dispose();
    });

    test('clear highlight order is canonical by tier and slot', () async {
      final controller = GameController(
        initialPlacements: multiTierTwoTierInitialPlacements.reversed.toList(),
        clues: multiTierTwoTierClues,
        swapDuration: _shortSwapDuration,
        clueCompletionDelay: _shortClearDuration,
        clearBookStepDuration: _shortClearDuration,
        clearFinalGlowDuration: _shortClearDuration,
      );
      final observedActiveBookIds = <String>[];
      controller.addListener(() {
        final activeBookId = controller.clearActiveBookId;
        if (activeBookId != null &&
            (observedActiveBookIds.isEmpty ||
                observedActiveBookIds.last != activeBookId)) {
          observedActiveBookIds.add(activeBookId);
        }
      });

      controller.handleBookTap('blue_moon');
      controller.handleBookTap('purple_leaf');
      await _waitForShortSwap();

      for (var index = 0; index < 12; index += 1) {
        await _waitForShortClear();
      }

      expect(observedActiveBookIds, [
        'blue_moon',
        'red_star',
        'yellow_key',
        'green_cloud',
        'purple_leaf',
        'orange_drop',
        'blue_sun',
        'red_diamond',
      ]);
      expect(controller.status, GameStatus.cleared);
      expect(controller.isShelfGlowing, isTrue);

      controller.dispose();
    });

    test(
      'three-tier clear order walks every tier from left to right',
      () async {
        final controller = GameController(
          initialPlacements: multiTierThreeTierPlacements.reversed.toList(),
          clues: const [
            EdgePositionClue(
              id: 'green_moon_tier_2_left_edge',
              subject: BookIdSelector(bookId: 'green_moon'),
              tierIndex: 2,
              edge: ShelfEdge.left,
            ),
          ],
          swapDuration: _shortSwapDuration,
          clueCompletionDelay: _shortClearDuration,
          clearBookStepDuration: _shortClearDuration,
          clearFinalGlowDuration: _shortClearDuration,
        );
        final observedActiveBookIds = <String>[];
        controller.addListener(() {
          final activeBookId = controller.clearActiveBookId;
          if (activeBookId != null &&
              (observedActiveBookIds.isEmpty ||
                  observedActiveBookIds.last != activeBookId)) {
            observedActiveBookIds.add(activeBookId);
          }
        });

        controller.handleBookTap('green_moon');
        controller.handleBookTap('orange_drop');
        await _waitForShortSwap();
        controller.handleBookTap('green_moon');
        controller.handleBookTap('orange_drop');
        await _waitForShortSwap();

        for (var index = 0; index < 16; index += 1) {
          await _waitForShortClear();
        }

        expect(observedActiveBookIds, [
          'blue_moon',
          'red_star',
          'yellow_key',
          'green_cloud',
          'purple_leaf',
          'orange_drop',
          'blue_sun',
          'red_diamond',
          'green_moon',
          'purple_star',
          'orange_key',
          'yellow_cloud',
        ]);

        controller.dispose();
      },
    );

    test('level 51 generated stage clears in the known three swaps', () async {
      final stage = const StageGenerator().generate(level: 51);
      final controller = GameController.fromGeneratedStage(
        stage: stage,
        swapDuration: _shortSwapDuration,
        clueCompletionDelay: _shortClearDuration,
        clearBookStepDuration: _shortClearDuration,
        clearFinalGlowDuration: _shortClearDuration,
      );
      final initialSatisfiedClueCount = const ClueEvaluator()
          .evaluateAll(clues: stage.clues, placements: stage.initialPlacements)
          .length;

      expect(controller.level, 51);
      expect(controller.tierCount, 2);
      expect(controller.booksPerTier, 4);
      expect(controller.totalBookCount, 8);
      expect(controller.clues, hasLength(stage.clueCount));
      expect(controller.satisfiedClueCount, initialSatisfiedClueCount);
      expect(controller.moveCount, 0);
      expect(controller.status, GameStatus.idle);
      expect(
        _ids(controller.placementsForTier(0)),
        _ids(
          stage.initialPlacements
              .where((placement) => placement.position.tierIndex == 0)
              .toList(),
        ),
      );
      expect(
        _ids(controller.placementsForTier(1)),
        _ids(
          stage.initialPlacements
              .where((placement) => placement.position.tierIndex == 1)
              .toList(),
        ),
      );

      for (final step in stage.swapHistory.reversed) {
        _swapByPosition(controller, step.firstPosition, step.secondPosition);
        await _waitForShortSwap();
      }

      expect(controller.moveCount, stage.targetSwapCount);
      expect(controller.satisfiedClueCount, stage.clueCount);
      expect(controller.status, GameStatus.clearing);

      for (var index = 0; index < 12; index += 1) {
        await _waitForShortClear();
      }

      expect(controller.status, GameStatus.cleared);
      controller.dispose();
    });

    test('level 53 generated duplicate visual books do not swap', () async {
      final stage = const StageGenerator().generate(level: 53);
      final controller = GameController.fromGeneratedStage(
        stage: stage,
        swapDuration: _shortSwapDuration,
      );
      final initialPositions = _positionsById(controller.placements);

      final duplicatePlacements = _duplicateVisualPlacements(
        controller.placements,
      );
      expect(duplicatePlacements, hasLength(greaterThanOrEqualTo(2)));

      controller.handleBookTap(duplicatePlacements[0].book.id);
      controller.handleBookTap(duplicatePlacements[1].book.id);

      expect(controller.moveCount, 0);
      expect(controller.status, GameStatus.idle);
      expect(controller.activeSwap, isNull);
      expect(controller.selectedBookId, isNull);
      expect(_positionsById(controller.placements), initialPositions);

      await _waitForShortSwap();
      expect(controller.status, GameStatus.idle);
      controller.dispose();
    });
  });
}

const _shortSwapDuration = Duration(milliseconds: 1);
const _shortClearDuration = Duration(milliseconds: 2);

GameController _twoTierController() {
  return GameController(
    initialPlacements: multiTierTwoTierInitialPlacements,
    clues: multiTierTwoTierClues,
    swapDuration: _shortSwapDuration,
    clueCompletionDelay: _shortClearDuration,
    clearBookStepDuration: _shortClearDuration,
    clearFinalGlowDuration: _shortClearDuration,
  );
}

Future<void> _waitForShortSwap() {
  return Future<void>.delayed(const Duration(milliseconds: 5));
}

Future<void> _waitForShortClear() {
  return Future<void>.delayed(const Duration(milliseconds: 4));
}

BookPlacement _placement(
  String id,
  BookColor color,
  BookSymbol symbol,
  int tierIndex,
  int slotIndex,
) {
  return BookPlacement(
    book: Book(id: id, color: color, symbol: symbol),
    position: BookPosition(tierIndex: tierIndex, slotIndex: slotIndex),
  );
}

BookPosition _position(int tierIndex, int slotIndex) {
  return BookPosition(tierIndex: tierIndex, slotIndex: slotIndex);
}

BookPosition _positionOf(Iterable<BookPlacement> placements, String id) {
  return placements.firstWhere((placement) => placement.book.id == id).position;
}

Map<String, BookPosition> _positionsById(Iterable<BookPlacement> placements) {
  return {
    for (final placement in placements) placement.book.id: placement.position,
  };
}

List<BookPlacement> _duplicateVisualPlacements(
  Iterable<BookPlacement> placements,
) {
  final placementsByVisual = <String, List<BookPlacement>>{};
  for (final placement in placements) {
    final key = '${placement.book.color.name}_${placement.book.symbol.name}';
    placementsByVisual.putIfAbsent(key, () => []).add(placement);
  }
  return placementsByVisual.values.firstWhere(
    (placements) => placements.length > 1,
  );
}

List<String> _ids(List<BookPlacement> placements) {
  return [for (final placement in placements) placement.book.id];
}

void _swapByPosition(
  GameController controller,
  BookPosition first,
  BookPosition second,
) {
  controller.handleBookTap(_bookIdAt(controller.placements, first));
  controller.handleBookTap(_bookIdAt(controller.placements, second));
}

String _bookIdAt(Iterable<BookPlacement> placements, BookPosition position) {
  return placements
      .firstWhere((placement) => placement.position == position)
      .book
      .id;
}
