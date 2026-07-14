import '../domain/book.dart';

abstract final class BookCode {
  static String color(BookColor color) {
    return switch (color) {
      BookColor.blue => 'blue',
      BookColor.red => 'red',
      BookColor.yellow => 'yellow',
      BookColor.green => 'green',
      BookColor.purple => 'purple',
      BookColor.orange => 'orange',
    };
  }

  static String symbol(BookSymbol symbol) {
    return switch (symbol) {
      BookSymbol.moon => 'moon',
      BookSymbol.star => 'star',
      BookSymbol.cloud => 'cloud',
      BookSymbol.key => 'key',
      BookSymbol.leaf => 'leaf',
      BookSymbol.drop => 'drop',
      BookSymbol.sun => 'sun',
      BookSymbol.diamond => 'diamond',
    };
  }

  static String bookId({required BookColor color, required BookSymbol symbol}) {
    return '${BookCode.color(color)}_${BookCode.symbol(symbol)}';
  }
}
