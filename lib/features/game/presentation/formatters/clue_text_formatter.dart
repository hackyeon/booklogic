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
      BothEdgesClue(:final subject, :final tierIndex) =>
        '두 ${_selectorColorText(subject)} 책은 ${_tierLabel(tierIndex)}의 '
            '양 끝에 있다.',
      RelativeOrderClue(
        :final subject,
        :final reference,
        :final tierIndex,
        :final relation,
      ) =>
        '${_subjectText(subject, books)}은 ${_tierLabel(tierIndex)}에서 '
            '${_referenceText(reference, books)}보다 ${_relationText(relation)}에 있다.',
      BetweenClue(:final subject, :final boundary, :final tierIndex) =>
        '${_subjectText(subject, books)}은 ${_tierLabel(tierIndex)}에서 '
            '두 ${_selectorColorText(boundary)} 책 사이에 있다.',
      TierAssignmentClue(:final subject, :final tierIndex) =>
        '${_subjectText(subject, books)}은 ${_tierLabel(tierIndex)}에 있다.',
      SameTierClue(:final first, :final second) =>
        '${_subjectText(first, books)}과 ${_subjectText(second, books)}은 '
            '같은 단에 있다.',
      AdjacentClue(
        :final subject,
        :final reference,
        :final tierIndex,
        :final direction,
      ) =>
        '${_subjectText(subject, books)}은 ${_tierLabel(tierIndex)}에서 '
            '${_adjacentReferenceText(reference, books)} 바로 ${_adjacentText(direction)}에 있다.',
      VerticalRelationClue(:final subject, :final reference, :final relation) =>
        '${_subjectText(subject, books)}은 ${_referenceText(reference, books)} '
            '바로 ${_verticalRelationText(relation)}에 있다.',
      NotAtEdgeClue(:final subject, :final tierIndex) =>
        '${_subjectText(subject, books)}은 ${_tierLabel(tierIndex)}의 '
            '끝 칸에 있지 않다.',
      DistanceClue(:final first, :final second, :final booksBetween) =>
        '${_subjectText(first, books)}과 ${_subjectText(second, books)} '
            '사이에는 책이 ${_bookCountText(booksBetween)} 있다.',
    };
  }

  String _subjectText(BookSelector selector, List<Book> books) {
    return bookLabelFormatter.formatSelector(selector: selector, books: books);
  }

  String _referenceText(BookSelector selector, List<Book> books) {
    return bookLabelFormatter.formatSelector(selector: selector, books: books);
  }

  String _adjacentReferenceText(BookSelector selector, List<Book> books) {
    return switch (selector) {
      BookColorSelector(:final color) =>
        '두 ${bookLabelFormatter.formatColor(color)} 책 묶음',
      _ => _referenceText(selector, books),
    };
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

  String _verticalRelationText(VerticalRelation relation) {
    return switch (relation) {
      VerticalRelation.immediatelyAbove => '위',
      VerticalRelation.immediatelyBelow => '아래',
    };
  }

  String _bookCountText(int count) {
    return switch (count) {
      1 => '한 권',
      2 => '두 권',
      3 => '세 권',
      _ => '$count권',
    };
  }

  String _selectorColorText(BookSelector selector) {
    return switch (selector) {
      BookColorSelector(:final color) => bookLabelFormatter.formatColor(color),
      _ => bookLabelFormatter.formatSelector(
        selector: selector,
        books: const [],
      ),
    };
  }
}
