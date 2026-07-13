import 'book.dart';

sealed class BookSelector {
  const BookSelector();
}

final class BookIdSelector extends BookSelector {
  const BookIdSelector({required this.bookId}) : assert(bookId.length > 0);

  final String bookId;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BookIdSelector &&
            runtimeType == other.runtimeType &&
            bookId == other.bookId;
  }

  @override
  int get hashCode => Object.hash(runtimeType, bookId);

  @override
  String toString() {
    return 'BookIdSelector(bookId: $bookId)';
  }
}

final class BookColorSelector extends BookSelector {
  const BookColorSelector({required this.color});

  final BookColor color;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BookColorSelector &&
            runtimeType == other.runtimeType &&
            color == other.color;
  }

  @override
  int get hashCode => Object.hash(runtimeType, color);

  @override
  String toString() {
    return 'BookColorSelector(color: $color)';
  }
}

final class BookSymbolSelector extends BookSelector {
  const BookSymbolSelector({required this.symbol});

  final BookSymbol symbol;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BookSymbolSelector &&
            runtimeType == other.runtimeType &&
            symbol == other.symbol;
  }

  @override
  int get hashCode => Object.hash(runtimeType, symbol);

  @override
  String toString() {
    return 'BookSymbolSelector(symbol: $symbol)';
  }
}
