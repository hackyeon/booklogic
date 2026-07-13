enum BookColor { blue, red, yellow, green, purple, orange }

enum BookSymbol { moon, star, cloud, key, leaf, drop, sun, diamond }

class Book {
  const Book({required this.id, required this.color, required this.symbol});

  final String id;
  final BookColor color;
  final BookSymbol symbol;

  @override
  String toString() {
    return 'Book(id: $id, color: $color, symbol: $symbol)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Book &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            color == other.color &&
            symbol == other.symbol;
  }

  @override
  int get hashCode => Object.hash(id, color, symbol);
}
