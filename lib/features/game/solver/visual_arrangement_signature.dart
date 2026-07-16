import '../domain/book.dart';
import '../domain/book_placement.dart';
import '../generator/book_code.dart';

class VisualArrangementSignature {
  VisualArrangementSignature({
    required this.tierCount,
    required this.booksPerTier,
    required List<String> visualBookCodes,
  }) : visualBookCodes = List<String>.unmodifiable(visualBookCodes) {
    if (tierCount < 1) {
      throw ArgumentError.value(tierCount, 'tierCount', '1 이상이어야 합니다.');
    }
    if (booksPerTier < 1) {
      throw ArgumentError.value(booksPerTier, 'booksPerTier', '1 이상이어야 합니다.');
    }
    if (visualBookCodes.length != tierCount * booksPerTier) {
      throw ArgumentError.value(
        visualBookCodes.length,
        'visualBookCodes',
        'tierCount * booksPerTier와 같아야 합니다.',
      );
    }
  }

  final int tierCount;
  final int booksPerTier;
  final List<String> visualBookCodes;

  factory VisualArrangementSignature.fromPlacements({
    required int tierCount,
    required int booksPerTier,
    required List<BookPlacement> placements,
  }) {
    final expectedCount = tierCount * booksPerTier;
    if (placements.length != expectedCount) {
      throw ArgumentError.value(
        placements.length,
        'placements',
        'tierCount * booksPerTier와 같아야 합니다.',
      );
    }

    final byFlatIndex = List<Book?>.filled(expectedCount, null);
    for (final placement in placements) {
      final position = placement.position;
      if (position.tierIndex < 0 ||
          position.tierIndex >= tierCount ||
          position.slotIndex < 0 ||
          position.slotIndex >= booksPerTier) {
        throw ArgumentError.value(
          '${position.tierIndex}:${position.slotIndex}',
          'placements',
          '범위를 벗어난 position입니다.',
        );
      }
      final flatIndex =
          (position.tierIndex * booksPerTier) + position.slotIndex;
      if (byFlatIndex[flatIndex] != null) {
        throw ArgumentError.value(
          '${position.tierIndex}:${position.slotIndex}',
          'placements',
          '중복 position입니다.',
        );
      }
      byFlatIndex[flatIndex] = placement.book;
    }

    if (byFlatIndex.any((book) => book == null)) {
      throw ArgumentError.value(
        placements,
        'placements',
        '누락된 canonical position이 있습니다.',
      );
    }

    return VisualArrangementSignature(
      tierCount: tierCount,
      booksPerTier: booksPerTier,
      visualBookCodes: [for (final book in byFlatIndex) visualBookCode(book!)],
    );
  }

  String get stableKey {
    return '${tierCount}x$booksPerTier|${visualBookCodes.join('|')}';
  }

  static String visualBookCode(Book book) {
    return BookCode.bookId(color: book.color, symbol: book.symbol);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VisualArrangementSignature &&
            runtimeType == other.runtimeType &&
            tierCount == other.tierCount &&
            booksPerTier == other.booksPerTier &&
            _listEquals(visualBookCodes, other.visualBookCodes);
  }

  @override
  int get hashCode {
    var result = Object.hash(runtimeType, tierCount, booksPerTier);
    for (final code in visualBookCodes) {
      result = Object.hash(result, code);
    }
    return result;
  }

  @override
  String toString() {
    return 'VisualArrangementSignature($stableKey)';
  }
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}
