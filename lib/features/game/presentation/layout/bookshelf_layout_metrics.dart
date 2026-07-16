import 'dart:ui';

import '../../../../core/constants/app_dimensions.dart';
import '../../domain/book_position.dart';

class BookshelfLayoutMetrics {
  BookshelfLayoutMetrics({
    required this.size,
    required this.tierCount,
    required this.booksPerTier,
    this.horizontalPadding = 12,
    this.tierLabelWidth = 42,
    this.tierGap = 12,
    this.shelfPlankHeight = AppDimensions.bookshelfShelfHeight,
  }) {
    _validateLayout(tierCount: tierCount, booksPerTier: booksPerTier);
  }

  final Size size;
  final int tierCount;
  final int booksPerTier;
  final double horizontalPadding;
  final double tierLabelWidth;
  final double tierGap;
  final double shelfPlankHeight;

  static double preferredHeightFor(int tierCount) {
    if (tierCount < 1 || tierCount > 3) {
      throw ArgumentError.value(tierCount, 'tierCount', '1부터 3 사이여야 합니다.');
    }
    final tierExtent = _clampDouble(240 - (tierCount - 1) * 56, 128, 240);
    return tierExtent * tierCount + 12 * (tierCount - 1);
  }

  double get contentWidth {
    return _nonNegative(size.width - horizontalPadding * 2 - tierLabelWidth);
  }

  double get slotExtent {
    if (booksPerTier == 0) {
      return 0;
    }
    return contentWidth / booksPerTier;
  }

  double get tierExtent {
    if (tierCount == 0) {
      return 0;
    }
    return _nonNegative(size.height - tierGap * (tierCount - 1)) / tierCount;
  }

  double get bookWidth {
    final maxAllowedWidth = _nonNegative(slotExtent - 4);
    final maxWidth = maxAllowedWidth < 72 ? maxAllowedWidth : 72.0;
    return _clampDouble(slotExtent * 0.72, 0, maxWidth);
  }

  double get bookHeight {
    final maxAllowedHeight = _nonNegative(tierExtent - shelfPlankHeight - 14);
    final aspectHeight = bookWidth / AppDimensions.bookAspectRatio;
    final tierHeight = tierExtent * 0.68;
    final desiredHeight = aspectHeight < tierHeight ? aspectHeight : tierHeight;
    final maxHeight = maxAllowedHeight < 150 ? maxAllowedHeight : 150.0;
    return _clampDouble(desiredHeight, 0, maxHeight);
  }

  Rect bookRectFor(BookPosition position) {
    _validatePosition(position);
    final tierTop = position.tierIndex * (tierExtent + tierGap);
    final slotLeft =
        horizontalPadding + tierLabelWidth + position.slotIndex * slotExtent;
    final left = slotLeft + (slotExtent - bookWidth) / 2;
    final top = tierTop + (tierExtent - shelfPlankHeight - bookHeight) / 2;
    return Rect.fromLTWH(left, top, bookWidth, bookHeight);
  }

  Rect tierRect(int tierIndex) {
    if (tierIndex < 0 || tierIndex >= tierCount) {
      throw RangeError.range(tierIndex, 0, tierCount - 1, 'tierIndex');
    }
    return Rect.fromLTWH(
      horizontalPadding,
      tierIndex * (tierExtent + tierGap),
      _nonNegative(size.width - horizontalPadding * 2),
      tierExtent,
    );
  }

  Rect tierLabelRect(int tierIndex) {
    final tier = tierRect(tierIndex);
    return Rect.fromLTWH(tier.left, tier.top, tierLabelWidth, tier.height);
  }

  Rect shelfPlankRect(int tierIndex) {
    final tier = tierRect(tierIndex);
    return Rect.fromLTWH(
      horizontalPadding + tierLabelWidth,
      tier.bottom - shelfPlankHeight,
      contentWidth,
      shelfPlankHeight,
    );
  }

  void _validatePosition(BookPosition position) {
    if (position.tierIndex < 0 || position.tierIndex >= tierCount) {
      throw RangeError.range(position.tierIndex, 0, tierCount - 1, 'tierIndex');
    }
    if (position.slotIndex < 0 || position.slotIndex >= booksPerTier) {
      throw RangeError.range(
        position.slotIndex,
        0,
        booksPerTier - 1,
        'slotIndex',
      );
    }
  }

  static void _validateLayout({
    required int tierCount,
    required int booksPerTier,
  }) {
    if (tierCount < 1 || tierCount > 3) {
      throw ArgumentError.value(tierCount, 'tierCount', '1부터 3 사이여야 합니다.');
    }
    if (booksPerTier < 1 || booksPerTier > 6) {
      throw ArgumentError.value(
        booksPerTier,
        'booksPerTier',
        '1부터 6 사이여야 합니다.',
      );
    }
  }

  static double _clampDouble(double value, double min, double max) {
    if (max <= min) {
      return max < 0 ? 0 : max;
    }
    if (value < min) {
      return min;
    }
    if (value > max) {
      return max;
    }
    return value;
  }

  static double _nonNegative(double value) {
    return value < 0 ? 0 : value;
  }
}
