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
    super.key,
  });

  final Book book;
  final double width;
  final double height;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isClearActive;

  @override
  Widget build(BuildContext context) {
    const labelFormatter = BookLabelFormatter();
    final visual = book.visual;
    final borderRadius = const BorderRadius.vertical(
      top: Radius.circular(AppDimensions.bookCornerRadius),
      bottom: Radius.circular(AppDimensions.smallSpacing),
    );
    final lift = isSelected
        ? AppDimensions.bookSelectionLift
        : isClearActive
        ? AppDimensions.bookClearLift
        : 0.0;
    final scale = isSelected
        ? AppDimensions.bookSelectedScale
        : isClearActive
        ? AppDimensions.bookClearScale
        : 1.0;
    final borderColor = isSelected
        ? AppColors.selectedBorder
        : isClearActive
        ? AppColors.clearAccent
        : visual.borderColor;
    final borderWidth = isSelected || isClearActive
        ? AppDimensions.bookSelectedBorderWidth
        : 1.0;
    final slideOffset = Offset(0, -lift / height);

    return Semantics(
      label: labelFormatter.formatBook(book),
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
                    color: isSelected
                        ? const Color(0x55000000)
                        : isClearActive
                        ? AppColors.clearGlow
                        : const Color(0x26000000),
                    blurRadius: isSelected || isClearActive ? 14 : 8,
                    offset: Offset(0, isSelected || isClearActive ? 7 : 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.smallSpacing,
                  vertical: AppDimensions.mediumSpacing,
                ),
                child: Column(
                  children: [
                    _BookDecorationLine(color: visual.foregroundColor),
                    const Spacer(),
                    Icon(
                      book.symbol.icon,
                      color: visual.foregroundColor,
                      size: width * 0.46,
                    ),
                    const Spacer(),
                    _BookDecorationLine(
                      color: visual.foregroundColor,
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
  const _BookDecorationLine({required this.color, this.widthFactor = 1});

  final Color color;
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 3,
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
        backgroundColor: Color(0xFF2F6FED),
        foregroundColor: Colors.white,
        borderColor: Color(0xFF1B4FAF),
      ),
      BookColor.red => const BookVisual(
        backgroundColor: Color(0xFFD94D4D),
        foregroundColor: Colors.white,
        borderColor: Color(0xFFA83232),
      ),
      BookColor.yellow => const BookVisual(
        backgroundColor: Color(0xFFE7B93E),
        foregroundColor: AppColors.textPrimary,
        borderColor: Color(0xFFC6921E),
      ),
      BookColor.green => const BookVisual(
        backgroundColor: Color(0xFF34A66A),
        foregroundColor: Colors.white,
        borderColor: Color(0xFF237849),
      ),
      BookColor.purple => const BookVisual(
        backgroundColor: Color(0xFF8560C8),
        foregroundColor: Colors.white,
        borderColor: Color(0xFF5F3EA1),
      ),
      BookColor.orange => const BookVisual(
        backgroundColor: Color(0xFFE47A32),
        foregroundColor: Colors.white,
        borderColor: Color(0xFFB8531F),
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
