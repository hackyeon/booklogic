import '../../domain/book.dart';
import '../../domain/book_placement.dart';
import '../../domain/book_position.dart';

const demoBookshelfPlacements = <BookPlacement>[
  BookPlacement(
    book: Book(
      id: 'green_cloud',
      color: BookColor.green,
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
      id: 'yellow_key',
      color: BookColor.yellow,
      symbol: BookSymbol.key,
    ),
    position: BookPosition(tierIndex: 0, slotIndex: 2),
  ),
  BookPlacement(
    book: Book(id: 'red_star', color: BookColor.red, symbol: BookSymbol.star),
    position: BookPosition(tierIndex: 0, slotIndex: 3),
  ),
];
