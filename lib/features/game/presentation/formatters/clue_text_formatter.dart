import '../../domain/book.dart';
import '../../domain/book_selector.dart';
import '../../domain/clue.dart';
import 'book_label_formatter.dart';

class ClueTextFormatter {
  const ClueTextFormatter({
    this.bookLabelFormatter = const BookLabelFormatter(),
  });

  final BookLabelFormatter bookLabelFormatter;

  String format({required Clue clue, required List<Book> books}) {
    return switch (clue) {
      EdgePositionClue(:final subject, :final tierIndex, :final edge) =>
        '${_subjectText(subject, books)}은 ${_tierLabel(tierIndex)}의 '
            '${_edgeText(edge)} 끝에 있다.',
      RelativeOrderClue(
        :final subject,
        :final reference,
        :final tierIndex,
        :final relation,
      ) =>
        '${_subjectText(subject, books)}은 ${_tierLabel(tierIndex)}에서 '
            '${_referenceText(reference, books)}보다 ${_relationText(relation)}에 있다.',
      AdjacentClue(
        :final subject,
        :final reference,
        :final tierIndex,
        :final direction,
      ) =>
        '${_subjectText(subject, books)}은 ${_tierLabel(tierIndex)}에서 '
            '${_referenceText(reference, books)} 바로 ${_adjacentText(direction)}에 있다.',
    };
  }

  String _subjectText(BookSelector selector, List<Book> books) {
    return bookLabelFormatter.formatSelector(selector: selector, books: books);
  }

  String _referenceText(BookSelector selector, List<Book> books) {
    return bookLabelFormatter.formatSelector(selector: selector, books: books);
  }

  String _tierLabel(int tierIndex) {
    return '${tierIndex + 1}단';
  }

  String _edgeText(ShelfEdge edge) {
    return switch (edge) {
      ShelfEdge.left => '왼쪽',
      ShelfEdge.right => '오른쪽',
    };
  }

  String _relationText(HorizontalRelation relation) {
    return switch (relation) {
      HorizontalRelation.leftOf => '왼쪽',
      HorizontalRelation.rightOf => '오른쪽',
    };
  }

  String _adjacentText(AdjacentDirection direction) {
    return switch (direction) {
      AdjacentDirection.immediatelyLeftOf => '왼쪽',
      AdjacentDirection.immediatelyRightOf => '오른쪽',
    };
  }
}
