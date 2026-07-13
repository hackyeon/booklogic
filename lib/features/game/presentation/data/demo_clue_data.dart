import '../../domain/book_selector.dart';
import '../../domain/clue.dart';

const List<Clue> demoClues = [
  EdgePositionClue(
    id: 'c02_blue_moon_left_edge',
    subject: BookIdSelector(bookId: 'blue_moon'),
    tierIndex: 0,
    edge: ShelfEdge.left,
  ),
  RelativeOrderClue(
    id: 'c04_green_cloud_right_of_yellow_key',
    subject: BookIdSelector(bookId: 'green_cloud'),
    reference: BookIdSelector(bookId: 'yellow_key'),
    tierIndex: 0,
    relation: HorizontalRelation.rightOf,
  ),
  AdjacentClue(
    id: 'c05_red_star_right_of_blue_moon',
    subject: BookIdSelector(bookId: 'red_star'),
    reference: BookIdSelector(bookId: 'blue_moon'),
    tierIndex: 0,
    direction: AdjacentDirection.immediatelyRightOf,
  ),
];
