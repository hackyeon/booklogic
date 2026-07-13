import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(
                AppStrings.appTitle,
                textAlign: TextAlign.center,
                style: textTheme.headlineLarge,
              ),
              const SizedBox(height: AppDimensions.smallSpacing),
              Text(
                AppStrings.appSubtitle,
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge,
              ),
              const SizedBox(height: AppDimensions.sectionSpacing),
              const _BookshelfPreview(),
              const Spacer(),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.game),
                child: const Text(AppStrings.continueButton),
              ),
              const SizedBox(height: AppDimensions.mediumSpacing),
              OutlinedButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.settings),
                child: const Text(AppStrings.settingsButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookshelfPreview extends StatelessWidget {
  const _BookshelfPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppDimensions.shelfHeight,
      padding: const EdgeInsets.all(AppDimensions.mediumSpacing),
      decoration: BoxDecoration(
        color: AppColors.bookshelfBrown,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
      ),
      child: Column(
        children: const [
          Expanded(child: _ShelfRow()),
          SizedBox(height: AppDimensions.smallSpacing),
          _ShelfBoard(),
          SizedBox(height: AppDimensions.mediumSpacing),
          Expanded(child: _ShelfRow(reverse: true)),
          SizedBox(height: AppDimensions.smallSpacing),
          _ShelfBoard(),
        ],
      ),
    );
  }
}

class _ShelfRow extends StatelessWidget {
  const _ShelfRow({this.reverse = false});

  final bool reverse;

  @override
  Widget build(BuildContext context) {
    final colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.surface,
      AppColors.textSecondary,
      AppColors.divider,
    ];
    final orderedColors = reverse ? colors.reversed.toList() : colors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final color in orderedColors)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.smallSpacing / 2,
            ),
            child: Container(
              width: AppDimensions.shelfBookWidth,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AppDimensions.smallSpacing),
              ),
            ),
          ),
      ],
    );
  }
}

class _ShelfBoard extends StatelessWidget {
  const _ShelfBoard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppDimensions.smallSpacing,
      decoration: BoxDecoration(
        color: AppColors.shelfDark,
        borderRadius: BorderRadius.circular(AppDimensions.smallSpacing),
      ),
    );
  }
}
