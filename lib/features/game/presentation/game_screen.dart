import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.levelOne),
        actions: [
          IconButton(
            tooltip: '재시작',
            iconSize: AppDimensions.iconSize,
            onPressed: () => _showNextStepSnackBar(context),
            icon: const Icon(Icons.restart_alt_rounded),
          ),
          IconButton(
            tooltip: AppStrings.settingsButton,
            iconSize: AppDimensions.iconSize,
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.settings),
            icon: const Icon(Icons.settings_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              Expanded(child: _GamePlaceholder()),
              SizedBox(height: AppDimensions.sectionSpacing),
              _CluePlaceholderPanel(),
            ],
          ),
        ),
      ),
    );
  }

  void _showNextStepSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text(AppStrings.nextStepMessage)));
  }
}

class _GamePlaceholder extends StatelessWidget {
  const _GamePlaceholder();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.sectionSpacing),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book_rounded,
            size: AppDimensions.iconSize * 2,
            color: AppColors.bookshelfBrown,
          ),
          const SizedBox(height: AppDimensions.mediumSpacing),
          Text(AppStrings.bookshelfArea, style: textTheme.titleLarge),
          const SizedBox(height: AppDimensions.smallSpacing),
          Text(
            AppStrings.gamePlaceholder,
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _CluePlaceholderPanel extends StatelessWidget {
  const _CluePlaceholderPanel();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.mediumSpacing),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(AppStrings.clueTitle, style: textTheme.titleLarge),
          const SizedBox(height: AppDimensions.smallSpacing),
          Text(AppStrings.cluePlaceholder, style: textTheme.bodyLarge),
        ],
      ),
    );
  }
}
