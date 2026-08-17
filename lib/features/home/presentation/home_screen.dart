import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/persistence/application/persistence_health_controller.dart';
import '../../../core/progress/game_progress_controller.dart';
import '../../../core/theme/app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.progressController,
    this.persistenceHealthController,
    super.key,
  });

  final GameProgressController progressController;
  final PersistenceHealthController? persistenceHealthController;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    widget.persistenceHealthController?.addListener(_handleHealthChanged);
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.persistenceHealthController !=
        widget.persistenceHealthController) {
      oldWidget.persistenceHealthController?.removeListener(
        _handleHealthChanged,
      );
      widget.persistenceHealthController?.addListener(_handleHealthChanged);
    }
  }

  @override
  void dispose() {
    widget.persistenceHealthController?.removeListener(_handleHealthChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    _schedulePersistenceNotice();

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
              AnimatedBuilder(
                animation: progressController,
                builder: (context, _) {
                  final isLoading =
                      widget.progressController.status ==
                          GameProgressStatus.initial ||
                      widget.progressController.isLoading;
                  final level = widget.progressController.currentLevel;
                  final continueLabel = '계속하기 · Level $level';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (isLoading) ...[
                        Semantics(
                          liveRegion: true,
                          child: const Text(
                            AppStrings.progressLoading,
                            key: Key('game_progress_loading'),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.smallSpacing),
                      ],
                      if (!isLoading &&
                          widget.progressController.lastError != null) ...[
                        const Text(
                          AppStrings.progressLoadWarning,
                          key: Key('home_progress_load_warning'),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppDimensions.smallSpacing),
                      ],
                      Semantics(
                        button: true,
                        enabled: !isLoading,
                        label: '계속하기, Level $level',
                        child: FilledButton(
                          key: const Key('home_continue_button'),
                          onPressed: isLoading
                              ? null
                              : () => Navigator.of(
                                  context,
                                ).pushNamed(AppRoutes.game),
                          child: Text(
                            continueLabel,
                            key: const Key('home_progress_level'),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppDimensions.mediumSpacing),
              OutlinedButton(
                key: const Key('home_settings_button'),
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.settings),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.settings_rounded),
                    SizedBox(width: AppDimensions.smallSpacing),
                    Text(AppStrings.settingsButton),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  GameProgressController get progressController => widget.progressController;

  void _handleHealthChanged() {
    _schedulePersistenceNotice();
  }

  void _schedulePersistenceNotice() {
    final healthController = widget.persistenceHealthController;
    if (healthController == null) {
      return;
    }
    final message = healthController.noticeMessage;
    if (message == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || healthController.noticeMessage == null) {
        return;
      }
      healthController.consumeNotice();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    });
  }
}

class _BookshelfPreview extends StatelessWidget {
  const _BookshelfPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('home_bookshelf_illustration'),
      height: AppDimensions.shelfHeight,
      padding: const EdgeInsets.all(AppDimensions.mediumSpacing),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        border: Border.all(color: AppColors.divider),
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
    const colors = [
      AppColors.bookBlue,
      AppColors.bookRed,
      AppColors.bookYellow,
      AppColors.bookGreen,
      AppColors.bookPurple,
    ];
    final orderedColors = reverse ? colors.reversed.toList() : colors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < orderedColors.length; index++)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.smallSpacing / 2,
            ),
            child: FractionallySizedBox(
              heightFactor: index.isEven ? 0.9 : 1,
              child: Container(
                width: AppDimensions.shelfBookWidth,
                decoration: BoxDecoration(
                  color: orderedColors[index],
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppDimensions.smallSpacing),
                    bottom: Radius.circular(4),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.bookShadow,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
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
    return SizedBox(
      height: 12,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.shelf,
                borderRadius: BorderRadius.circular(6),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shelfShadow,
                    blurRadius: 5,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            left: 4,
            top: 1,
            right: 4,
            height: 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.shelfHighlight,
                borderRadius: BorderRadius.all(Radius.circular(2)),
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.shelfEdge,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(6)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
