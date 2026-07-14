import '../domain/book.dart';
import 'book_code.dart';

class BookCatalog {
  const BookCatalog();

  static const List<BookColor> canonicalColors = [
    BookColor.blue,
    BookColor.red,
    BookColor.yellow,
    BookColor.green,
    BookColor.purple,
    BookColor.orange,
  ];

  static const List<BookSymbol> canonicalSymbols = [
    BookSymbol.moon,
    BookSymbol.star,
    BookSymbol.cloud,
    BookSymbol.key,
    BookSymbol.leaf,
    BookSymbol.drop,
    BookSymbol.sun,
    BookSymbol.diamond,
  ];

  static final List<Book> _books = List<Book>.unmodifiable([
    for (final color in canonicalColors)
      for (final symbol in canonicalSymbols)
        Book(
          id: BookCode.bookId(color: color, symbol: symbol),
          color: color,
          symbol: symbol,
        ),
  ]);

  List<Book> get books => _books;
}
