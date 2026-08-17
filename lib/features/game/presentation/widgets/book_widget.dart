import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_durations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/book.dart';
import '../formatters/book_label_formatter.dart';

class BookWidget extends StatelessWidget {
  const BookWidget({
    required this.book,
    required this.width,
    required this.height,
    required this.isSelected,
    required this.onTap,
    this.isClearActive = false,
    this.isClueHighlighted = false,
    this.semanticsValue,
    super.key,
  });

  final Book book;
  final double width;
  final double height;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isClearActive;
  final bool isClueHighlighted;
  final String? semanticsValue;

  @override
  Widget build(BuildContext context) {
    const labelFormatter = BookLabelFormatter();
    final visual = book.visual;
    final borderRadius = const BorderRadius.vertical(
      top: Radius.circular(AppDimensions.bookCornerRadius),
      bottom: Radius.circular(AppDimensions.smallSpacing),
    );
    final lift = isClearActive
        ? AppDimensions.bookClearLift
        : isSelected
        ? AppDimensions.bookSelectionLift
        : isClueHighlighted
        ? AppDimensions.smallSpacing
        : 0.0;
    final scale = isClearActive
        ? AppDimensions.bookClearScale
        : isSelected
        ? AppDimensions.bookSelectedScale
        : isClueHighlighted
        ? 1.035
        : 1.0;
    final borderColor = isClearActive
        ? AppColors.clearAccent
        : isSelected
        ? AppColors.selectedBorder
        : isClueHighlighted
        ? AppColors.clueHighlight
        : visual.borderColor;
    final borderWidth = isClearActive || isSelected
        ? AppDimensions.bookSelectedBorderWidth
        : isClueHighlighted
        ? 2.0
        : 1.0;
    final slideOffset = Offset(0, -lift / height);
    final horizontalPadding = width < 52 ? 4.0 : AppDimensions.smallSpacing;
    final verticalPadding = height < 68 ? 4.0 : AppDimensions.mediumSpacing;
    final decorationLineHeight = height < 56 ? 2.0 : 3.0;
    final availableIconHeight =
        height - verticalPadding * 2 - decorationLineHeight * 2 - 4;
    final preferredIconSize = width * 0.46;
    final iconSize = availableIconHeight <= 0
        ? 0.0
        : preferredIconSize > availableIconHeight
        ? availableIconHeight
        : preferredIconSize;

    return Semantics(
      label: labelFormatter.formatBook(book),
      value: semanticsValue,
      button: true,
      selected: isSelected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedSlide(
          offset: lift > 0 ? slideOffset : Offset.zero,
          duration: AppDurations.bookSelectionDuration,
          curve: Curves.easeOut,
          child: AnimatedScale(
            scale: scale,
            duration: AppDurations.bookSelectionDuration,
            curve: Curves.easeOut,
            child: AnimatedContainer(
              key: Key('book_${book.id}'),
              duration: AppDurations.bookSelectionDuration,
              curve: Curves.easeOut,
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: visual.backgroundColor,
                borderRadius: borderRadius,
                border: Border.all(color: borderColor, width: borderWidth),
                boxShadow: [
                  BoxShadow(
                    color: isClearActive
                        ? AppColors.clearGlow
                        : isSelected
                        ? AppColors.selectedBookShadow
                        : isClueHighlighted
                        ? AppColors.clueHighlight.withValues(alpha: 0.34)
                        : AppColors.bookShadow,
                    blurRadius: isClearActive || isSelected
                        ? 11
                        : isClueHighlighted
                        ? 9
                        : 5,
                    offset: Offset(
                      0,
                      isClearActive || isSelected
                          ? 4
                          : isClueHighlighted
                          ? 3
                          : 2,
                    ),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: Column(
                  children: [
                    _BookDecorationLine(
                      color: visual.foregroundColor,
                      height: decorationLineHeight,
                    ),
                    const Spacer(),
                    Icon(
                      book.symbol.icon,
                      color: visual.foregroundColor,
                      size: iconSize,
                    ),
                    const Spacer(),
                    _BookDecorationLine(
                      color: visual.foregroundColor,
                      height: decorationLineHeight,
                      widthFactor: 0.58,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BookDecorationLine extends StatelessWidget {
  const _BookDecorationLine({
    required this.color,
    required this.height,
    this.widthFactor = 1,
  });

  final Color color;
  final double height;
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class BookVisual {
  const BookVisual({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
}

extension BookColorVisualExtension on BookColor {
  BookVisual get visual {
    return switch (this) {
      BookColor.blue => const BookVisual(
        backgroundColor: AppColors.bookBlue,
        foregroundColor: AppColors.onStrongColor,
        borderColor: AppColors.bookBlueEdge,
      ),
      BookColor.red => const BookVisual(
        backgroundColor: AppColors.bookRed,
        foregroundColor: AppColors.onStrongColor,
        borderColor: AppColors.bookRedEdge,
      ),
      BookColor.yellow => const BookVisual(
        backgroundColor: AppColors.bookYellow,
        foregroundColor: AppColors.textPrimary,
        borderColor: AppColors.bookYellowEdge,
      ),
      BookColor.green => const BookVisual(
        backgroundColor: AppColors.bookGreen,
        foregroundColor: AppColors.onStrongColor,
        borderColor: AppColors.bookGreenEdge,
      ),
      BookColor.purple => const BookVisual(
        backgroundColor: AppColors.bookPurple,
        foregroundColor: AppColors.onStrongColor,
        borderColor: AppColors.bookPurpleEdge,
      ),
      BookColor.orange => const BookVisual(
        backgroundColor: AppColors.bookOrange,
        foregroundColor: AppColors.onStrongColor,
        borderColor: AppColors.bookOrangeEdge,
      ),
    };
  }
}

extension BookSymbolIconExtension on BookSymbol {
  IconData get icon {
    return switch (this) {
      BookSymbol.moon => Icons.nightlight_round,
      BookSymbol.star => Icons.star_outline,
      BookSymbol.cloud => Icons.cloud_outlined,
      BookSymbol.key => Icons.key_outlined,
      BookSymbol.leaf => Icons.eco_outlined,
      BookSymbol.drop => Icons.water_drop_outlined,
      BookSymbol.sun => Icons.wb_sunny_outlined,
      BookSymbol.diamond => Icons.diamond_outlined,
    };
  }
}

extension BookPresentationVisualExtension on Book {
  BookVisual get visual => color.visual;
}
