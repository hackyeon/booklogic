import '../domain/book.dart';
import 'book_code.dart';

abstract final class BookInstanceCode {
  static final RegExp _duplicateCopyPattern = RegExp(
    r'^([a-z]+)_[a-z]+_copy_\d{2}$',
  );

  static String duplicateCopyId({
    required BookColor color,
    required BookSymbol symbol,
    required int copyNumber,
  }) {
    _validateCopyNumber(copyNumber);
    final copyCode = copyNumber.toString().padLeft(2, '0');
    return '${BookCode.bookId(color: color, symbol: symbol)}_copy_$copyCode';
  }

  static bool isDuplicateCopyId(String id) {
    if (!_duplicateCopyPattern.hasMatch(id)) {
      return false;
    }
    return copyNumber(id) != null;
  }

  static bool matchesBook(Book book) {
    final baseId = BookCode.bookId(color: book.color, symbol: book.symbol);
    if (book.id == baseId) {
      return true;
    }
    final copyNumberValue = copyNumber(book.id);
    if (copyNumberValue == null) {
      return false;
    }
    return book.id ==
        duplicateCopyId(
          color: book.color,
          symbol: book.symbol,
          copyNumber: copyNumberValue,
        );
  }

  static int? copyNumber(String id) {
    final baseId = _baseId(id);
    if (baseId == null) {
      return null;
    }
    final copyText = id.substring(baseId.length + '_copy_'.length);
    final copyNumber = int.tryParse(copyText);
    if (copyNumber == null || copyNumber < 1 || copyNumber > 99) {
      return null;
    }
    if (copyText != copyNumber.toString().padLeft(2, '0')) {
      return null;
    }
    return copyNumber;
  }

  static String? baseId(String id) {
    return _baseId(id);
  }

  static String? _baseId(String id) {
    final copyMarker = id.lastIndexOf('_copy_');
    if (copyMarker == -1) {
      return null;
    }
    final baseId = id.substring(0, copyMarker);
    final copyText = id.substring(copyMarker + '_copy_'.length);
    if (!RegExp(r'^[a-z]+_[a-z]+$').hasMatch(baseId) ||
        !RegExp(r'^\d{2}$').hasMatch(copyText)) {
      return null;
    }
    return baseId;
  }

  static void _validateCopyNumber(int copyNumber) {
    if (copyNumber < 1 || copyNumber > 99) {
      throw ArgumentError.value(copyNumber, 'copyNumber', '1부터 99 사이여야 합니다.');
    }
  }
}
