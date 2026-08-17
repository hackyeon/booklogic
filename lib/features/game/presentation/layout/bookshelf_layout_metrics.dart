import 'dart:ui';

import '../../../../core/constants/app_dimensions.dart';
import '../../domain/book_position.dart';

class BookshelfLayoutMetrics {
  BookshelfLayoutMetrics({
    required this.size,
    required this.tierCount,
    required this.booksPerTier,
    this.horizontalPadding = 8,
    this.tierLabelWidth = 44,
    this.tierGap = AppDimensions.shelfTierGap,
    this.shelfPlankHeight = AppDimensions.bookshelfShelfHeight,
    this.shelfHorizontalExtension = AppDimensions.shelfHorizontalExtension,
    this.bookShelfGap = 0,
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
  final double shelfHorizontalExtension;
  final double bookShelfGap;

  static Size contentSizeFor({
    required Size availableSize,
    required int tierCount,
    required int booksPerTier,
  }) {
    _validateLayout(tierCount: tierCount, booksPerTier: booksPerTier);
    final availableWidth = availableSize.width.isFinite
        ? _nonNegative(availableSize.width)
        : AppDimensions.bookshelfMaxWidth;
    final width = preferredWidthFor(
      booksPerTier: booksPerTier,
      availableWidth: availableWidth,
    );
    final bookWidth = _baseBookWidthFor(
      width: width,
      booksPerTier: booksPerTier,
    );
    final bookHeight = bookWidth / AppDimensions.bookAspectRatio;
    final tierHeight =
        AppDimensions.shelfLabelHeight +
        AppDimensions.shelfLabelGap +
        bookHeight +
        AppDimensions.bookshelfShelfHeight;
    final desiredHeight =
        tierHeight * tierCount + AppDimensions.shelfTierGap * (tierCount - 1);
    final height = availableSize.height.isFinite
        ? _clampDouble(desiredHeight, 0, availableSize.height)
        : desiredHeight;
    return Size(width, height);
  }

  static double preferredWidthFor({
    required int booksPerTier,
    required double availableWidth,
  }) {
    _validateLayout(tierCount: 1, booksPerTier: booksPerTier);
    final desiredWidth =
        booksPerTier * AppDimensions.shelfPreferredSlotExtent +
        (AppDimensions.shelfHorizontalExtension + 8) * 2;
    return _clampDouble(
      desiredWidth,
      0,
      availableWidth < AppDimensions.bookshelfMaxWidth
          ? availableWidth
          : AppDimensions.bookshelfMaxWidth,
    );
  }

  static double preferredHeightFor(int tierCount) {
    if (tierCount < 1 || tierCount > 3) {
      throw ArgumentError.value(tierCount, 'tierCount', '1부터 3 사이여야 합니다.');
    }
    final maxBookHeight =
        AppDimensions.shelfMaxBookWidth / AppDimensions.bookAspectRatio;
    final tierExtent =
        AppDimensions.shelfLabelHeight +
        AppDimensions.shelfLabelGap +
        maxBookHeight +
        AppDimensions.bookshelfShelfHeight;
    return tierExtent * tierCount +
        AppDimensions.shelfTierGap * (tierCount - 1);
  }

  Rect get availableRect => Offset.zero & size;

  Rect get actualShelfRect => Rect.fromLTWH(
    0,
    0,
    size.width,
    tierExtent * tierCount + effectiveTierGap * (tierCount - 1),
  );

  double get verticalScale {
    final desiredHeight = _desiredContentHeight;
    if (desiredHeight <= 0 || size.height >= desiredHeight) {
      return 1;
    }
    return _clampDouble(size.height / desiredHeight, 0, 1);
  }

  double get effectiveTierGap => tierGap * verticalScale;

  double get effectiveShelfPlankHeight => shelfPlankHeight * verticalScale;

  double get effectiveTierLabelHeight =>
      AppDimensions.shelfLabelHeight * verticalScale;

  double get effectiveTierLabelGap =>
      AppDimensions.shelfLabelGap * verticalScale;

  double get contentWidth {
    return _nonNegative(
      size.width - horizontalPadding * 2 - shelfHorizontalExtension * 2,
    );
  }

  double get slotExtent {
    if (booksPerTier == 0) {
      return 0;
    }
    return contentWidth / booksPerTier;
  }

  double get tierExtent {
    return effectiveTierLabelHeight +
        effectiveTierLabelGap +
        bookHeight +
        effectiveShelfPlankHeight;
  }

  double get bookWidth {
    return _baseBookWidth * verticalScale;
  }

  double get bookHeight {
    return bookWidth / AppDimensions.bookAspectRatio;
  }

  Rect bookRectFor(BookPosition position) {
    _validatePosition(position);
    final tierTop = position.tierIndex * (tierExtent + effectiveTierGap);
    final slotLeft =
        horizontalPadding +
        shelfHorizontalExtension +
        position.slotIndex * slotExtent;
    final left = slotLeft + (slotExtent - bookWidth) / 2;
    final plankTop = tierTop + tierExtent - effectiveShelfPlankHeight;
    final top = plankTop - bookShelfGap - bookHeight;
    return Rect.fromLTWH(left, top, bookWidth, bookHeight);
  }

  Rect tierRect(int tierIndex) {
    if (tierIndex < 0 || tierIndex >= tierCount) {
      throw RangeError.range(tierIndex, 0, tierCount - 1, 'tierIndex');
    }
    return Rect.fromLTWH(
      horizontalPadding,
      tierIndex * (tierExtent + effectiveTierGap),
      _nonNegative(size.width - horizontalPadding * 2),
      tierExtent,
    );
  }

  Rect tierLabelRect(int tierIndex) {
    final tier = tierRect(tierIndex);
    return Rect.fromLTWH(
      tier.left + shelfHorizontalExtension,
      tier.top,
      tierLabelWidth,
      effectiveTierLabelHeight,
    );
  }

  Rect shelfPlankRect(int tierIndex) {
    final tier = tierRect(tierIndex);
    return Rect.fromLTWH(
      horizontalPadding,
      tier.bottom - effectiveShelfPlankHeight,
      _nonNegative(size.width - horizontalPadding * 2),
      effectiveShelfPlankHeight,
    );
  }

  double get _baseBookWidth => _baseBookWidthFor(
    width: size.width,
    booksPerTier: booksPerTier,
    horizontalPadding: horizontalPadding,
    shelfHorizontalExtension: shelfHorizontalExtension,
  );

  double get _desiredContentHeight {
    final baseBookHeight = _baseBookWidth / AppDimensions.bookAspectRatio;
    final baseTierHeight =
        AppDimensions.shelfLabelHeight +
        AppDimensions.shelfLabelGap +
        baseBookHeight +
        shelfPlankHeight;
    return baseTierHeight * tierCount + tierGap * (tierCount - 1);
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

  static double _baseBookWidthFor({
    required double width,
    required int booksPerTier,
    double horizontalPadding = 8,
    double shelfHorizontalExtension = AppDimensions.shelfHorizontalExtension,
  }) {
    final rowWidth = _nonNegative(
      width - horizontalPadding * 2 - shelfHorizontalExtension * 2,
    );
    final slotWidth = rowWidth / booksPerTier;
    return _clampDouble(slotWidth * 0.72, 0, AppDimensions.shelfMaxBookWidth);
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
