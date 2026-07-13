import 'book.dart';
import 'book_position.dart';

class BookPlacement {
  const BookPlacement({required this.book, required this.position});

  final Book book;
  final BookPosition position;

  BookPlacement copyWith({Book? book, BookPosition? position}) {
    return BookPlacement(
      book: book ?? this.book,
      position: position ?? this.position,
    );
  }
}
