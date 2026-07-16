import 'package:booklogic/features/game/domain/book.dart';
import 'package:booklogic/features/game/domain/book_placement.dart';
import 'package:booklogic/features/game/domain/book_position.dart';
import 'package:booklogic/features/game/domain/book_selector.dart';
import 'package:booklogic/features/game/domain/clue.dart';

const multiTierTwoTierTargetPlacements = [
  BookPlacement(
    book: Book(id: 'blue_moon', color: BookColor.blue, symbol: BookSymbol.moon),
    position: BookPosition(tierIndex: 0, slotIndex: 0),
  ),
  BookPlacement(
    book: Book(id: 'red_star', color: BookColor.red, symbol: BookSymbol.star),
    position: BookPosition(tierIndex: 0, slotIndex: 1),
  ),
  BookPlacement(
    book: Book(
      id: 'yellow_key',
      color: BookColor.yellow,
      symbol: BookSymbol.key,
    ),
    position: BookPosition(tierIndex: 0, slotIndex: 2),
  ),
  BookPlacement(
    book: Book(
      id: 'green_cloud',
      color: BookColor.green,
      symbol: BookSymbol.cloud,
    ),
    position: BookPosition(tierIndex: 0, slotIndex: 3),
  ),
  BookPlacement(
    book: Book(
      id: 'purple_leaf',
      color: BookColor.purple,
      symbol: BookSymbol.leaf,
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
    book: Book(id: 'blue_sun', color: BookColor.blue, symbol: BookSymbol.sun),
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

const multiTierTwoTierInitialPlacements = [
  BookPlacement(
    book: Book(
      id: 'purple_leaf',
      color: BookColor.purple,
      symbol: BookSymbol.leaf,
    ),
    position: BookPosition(tierIndex: 0, slotIndex: 0),
  ),
  BookPlacement(
    book: Book(id: 'red_star', color: BookColor.red, symbol: BookSymbol.star),
    position: BookPosition(tierIndex: 0, slotIndex: 1),
  ),
  BookPlacement(
    book: Book(
      id: 'yellow_key',
      color: BookColor.yellow,
      symbol: BookSymbol.key,
    ),
    position: BookPosition(tierIndex: 0, slotIndex: 2),
  ),
  BookPlacement(
    book: Book(
      id: 'green_cloud',
      color: BookColor.green,
      symbol: BookSymbol.cloud,
    ),
    position: BookPosition(tierIndex: 0, slotIndex: 3),
  ),
  BookPlacement(
    book: Book(id: 'blue_moon', color: BookColor.blue, symbol: BookSymbol.moon),
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
    book: Book(id: 'blue_sun', color: BookColor.blue, symbol: BookSymbol.sun),
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

const multiTierTwoTierClues = [
  EdgePositionClue(
    id: 'mt_blue_moon_tier_0_left_edge',
    subject: BookIdSelector(bookId: 'blue_moon'),
    tierIndex: 0,
    edge: ShelfEdge.left,
  ),
  EdgePositionClue(
    id: 'mt_purple_leaf_tier_1_left_edge',
    subject: BookIdSelector(bookId: 'purple_leaf'),
    tierIndex: 1,
    edge: ShelfEdge.left,
  ),
  AdjacentClue(
    id: 'mt_red_diamond_right_of_blue_sun_tier_1',
    subject: BookIdSelector(bookId: 'red_diamond'),
    reference: BookIdSelector(bookId: 'blue_sun'),
    tierIndex: 1,
    direction: AdjacentDirection.immediatelyRightOf,
  ),
];

const multiTierThreeTierPlacements = [
  ...multiTierTwoTierTargetPlacements,
  BookPlacement(
    book: Book(
      id: 'green_moon',
      color: BookColor.green,
      symbol: BookSymbol.moon,
    ),
    position: BookPosition(tierIndex: 2, slotIndex: 0),
  ),
  BookPlacement(
    book: Book(
      id: 'purple_star',
      color: BookColor.purple,
      symbol: BookSymbol.star,
    ),
    position: BookPosition(tierIndex: 2, slotIndex: 1),
  ),
  BookPlacement(
    book: Book(
      id: 'orange_key',
      color: BookColor.orange,
      symbol: BookSymbol.key,
    ),
    position: BookPosition(tierIndex: 2, slotIndex: 2),
  ),
  BookPlacement(
    book: Book(
      id: 'yellow_cloud',
      color: BookColor.yellow,
      symbol: BookSymbol.cloud,
    ),
    position: BookPosition(tierIndex: 2, slotIndex: 3),
  ),
];

const multiTierDuplicateVisualPlacements = [
  BookPlacement(
    book: Book(
      id: 'orange_cloud_copy_01',
      color: BookColor.orange,
      symbol: BookSymbol.cloud,
    ),
    position: BookPosition(tierIndex: 0, slotIndex: 0),
  ),
  BookPlacement(
    book: Book(id: 'blue_moon', color: BookColor.blue, symbol: BookSymbol.moon),
    position: BookPosition(tierIndex: 0, slotIndex: 1),
  ),
  BookPlacement(
    book: Book(
      id: 'orange_cloud_copy_02',
      color: BookColor.orange,
      symbol: BookSymbol.cloud,
    ),
    position: BookPosition(tierIndex: 1, slotIndex: 0),
  ),
  BookPlacement(
    book: Book(id: 'red_star', color: BookColor.red, symbol: BookSymbol.star),
    position: BookPosition(tierIndex: 1, slotIndex: 1),
  ),
];

const multiTierThreeBySixPlacements = [
  BookPlacement(
    book: Book(id: 'blue_moon', color: BookColor.blue, symbol: BookSymbol.moon),
    position: BookPosition(tierIndex: 0, slotIndex: 0),
  ),
  BookPlacement(
    book: Book(id: 'blue_star', color: BookColor.blue, symbol: BookSymbol.star),
    position: BookPosition(tierIndex: 0, slotIndex: 1),
  ),
  BookPlacement(
    book: Book(
      id: 'blue_cloud',
      color: BookColor.blue,
      symbol: BookSymbol.cloud,
    ),
    position: BookPosition(tierIndex: 0, slotIndex: 2),
  ),
  BookPlacement(
    book: Book(id: 'red_moon', color: BookColor.red, symbol: BookSymbol.moon),
    position: BookPosition(tierIndex: 0, slotIndex: 3),
  ),
  BookPlacement(
    book: Book(id: 'red_star', color: BookColor.red, symbol: BookSymbol.star),
    position: BookPosition(tierIndex: 0, slotIndex: 4),
  ),
  BookPlacement(
    book: Book(id: 'red_cloud', color: BookColor.red, symbol: BookSymbol.cloud),
    position: BookPosition(tierIndex: 0, slotIndex: 5),
  ),
  BookPlacement(
    book: Book(
      id: 'yellow_moon',
      color: BookColor.yellow,
      symbol: BookSymbol.moon,
    ),
    position: BookPosition(tierIndex: 1, slotIndex: 0),
  ),
  BookPlacement(
    book: Book(
      id: 'yellow_star',
      color: BookColor.yellow,
      symbol: BookSymbol.star,
    ),
    position: BookPosition(tierIndex: 1, slotIndex: 1),
  ),
  BookPlacement(
    book: Book(
      id: 'yellow_cloud',
      color: BookColor.yellow,
      symbol: BookSymbol.cloud,
    ),
    position: BookPosition(tierIndex: 1, slotIndex: 2),
  ),
  BookPlacement(
    book: Book(
      id: 'green_moon',
      color: BookColor.green,
      symbol: BookSymbol.moon,
    ),
    position: BookPosition(tierIndex: 1, slotIndex: 3),
  ),
  BookPlacement(
    book: Book(
      id: 'green_star',
      color: BookColor.green,
      symbol: BookSymbol.star,
    ),
    position: BookPosition(tierIndex: 1, slotIndex: 4),
  ),
  BookPlacement(
    book: Book(
      id: 'green_cloud',
      color: BookColor.green,
      symbol: BookSymbol.cloud,
    ),
    position: BookPosition(tierIndex: 1, slotIndex: 5),
  ),
  BookPlacement(
    book: Book(
      id: 'purple_moon',
      color: BookColor.purple,
      symbol: BookSymbol.moon,
    ),
    position: BookPosition(tierIndex: 2, slotIndex: 0),
  ),
  BookPlacement(
    book: Book(
      id: 'purple_star',
      color: BookColor.purple,
      symbol: BookSymbol.star,
    ),
    position: BookPosition(tierIndex: 2, slotIndex: 1),
  ),
  BookPlacement(
    book: Book(
      id: 'purple_cloud',
      color: BookColor.purple,
      symbol: BookSymbol.cloud,
    ),
    position: BookPosition(tierIndex: 2, slotIndex: 2),
  ),
  BookPlacement(
    book: Book(
      id: 'orange_moon',
      color: BookColor.orange,
      symbol: BookSymbol.moon,
    ),
    position: BookPosition(tierIndex: 2, slotIndex: 3),
  ),
  BookPlacement(
    book: Book(
      id: 'orange_star',
      color: BookColor.orange,
      symbol: BookSymbol.star,
    ),
    position: BookPosition(tierIndex: 2, slotIndex: 4),
  ),
  BookPlacement(
    book: Book(
      id: 'orange_cloud',
      color: BookColor.orange,
      symbol: BookSymbol.cloud,
    ),
    position: BookPosition(tierIndex: 2, slotIndex: 5),
  ),
];
