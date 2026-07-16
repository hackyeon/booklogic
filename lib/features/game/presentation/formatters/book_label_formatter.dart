import '../../domain/book.dart';
import '../../domain/book_selector.dart';

class BookLabelFormatter {
  const BookLabelFormatter();

  String formatBook(Book book) {
    return '${_colorLabel(book.color)} ${_symbolLabel(book.symbol)} 책';
  }

  String formatColor(BookColor color) {
    return _colorLabel(color);
  }

  String formatSymbol(BookSymbol symbol) {
    return _symbolLabel(symbol);
  }

  String formatSelector({
    required BookSelector selector,
    required List<Book> books,
  }) {
    return switch (selector) {
      BookIdSelector(:final bookId) => _formatBookId(bookId, books),
      BookColorSelector(:final color) => '모든 ${_colorLabel(color)} 책',
      BookSymbolSelector(:final symbol) => '모든 ${_symbolLabel(symbol)} 문양 책',
      BookVisualSelector(:final color, :final symbol) =>
        '모든 ${_colorLabel(color)} ${_symbolLabel(symbol)} 책',
    };
  }

  String _formatBookId(String bookId, List<Book> books) {
    for (final book in books) {
      if (book.id == bookId) {
        return formatBook(book);
      }
    }
    return '알 수 없는 책($bookId)';
  }

  String _colorLabel(BookColor color) {
    return switch (color) {
      BookColor.blue => '파란',
      BookColor.red => '빨간',
      BookColor.yellow => '노란',
      BookColor.green => '초록',
      BookColor.purple => '보라',
      BookColor.orange => '주황',
    };
  }

  String _symbolLabel(BookSymbol symbol) {
    return switch (symbol) {
      BookSymbol.moon => '달',
      BookSymbol.star => '별',
      BookSymbol.cloud => '구름',
      BookSymbol.key => '열쇠',
      BookSymbol.leaf => '잎',
      BookSymbol.drop => '물방울',
      BookSymbol.sun => '태양',
      BookSymbol.diamond => '다이아몬드',
    };
  }
}
