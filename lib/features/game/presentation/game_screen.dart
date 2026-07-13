import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../application/game_controller.dart';
import '../application/game_status.dart';
import '../domain/book.dart';
import '../domain/book_placement.dart';
import 'data/demo_bookshelf_data.dart';
import 'data/demo_clue_data.dart';
import 'formatters/book_label_formatter.dart';
import 'widgets/bookshelf_widget.dart';
import 'widgets/clue_panel_widget.dart';
import 'widgets/clear_result_overlay.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameController _controller;

  @override
  void initState() {
    super.initState();
    _controller = GameController(
      initialPlacements: demoBookshelfPlacements,
      initialClues: demoClues,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(AppStrings.levelOne),
            actions: [
              IconButton(
                key: const Key('game_restart_button'),
                tooltip: '재시작',
                iconSize: AppDimensions.iconSize,
                onPressed: _controller.status == GameStatus.idle
                    ? _controller.restart
                    : null,
                icon: const Icon(Icons.restart_alt_rounded),
              ),
              IconButton(
                tooltip: AppStrings.settingsButton,
                iconSize: AppDimensions.iconSize,
                onPressed: _controller.isInputLocked
                    ? null
                    : () => Navigator.of(context).pushNamed(AppRoutes.settings),
                icon: const Icon(Icons.settings_rounded),
              ),
            ],
          ),
          body: Stack(
            children: [
              SafeArea(
                child: GestureDetector(
                  key: const Key('game_content_background'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _controller.cancelSelection,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(
                              AppDimensions.screenPadding,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(
                                  height: AppDimensions.mediumSpacing,
                                ),
                                const _GameInstruction(),
                                const SizedBox(
                                  height: AppDimensions.sectionSpacing,
                                ),
                                KeyedSubtree(
                                  key: ValueKey(
                                    'bookshelf_revision_${_controller.boardRevision}',
                                  ),
                                  child: BookshelfWidget(
                                    placements: _controller.placements,
                                    selectedBookId: _controller.selectedBookId,
                                    isAnimating: _controller.isAnimating,
                                    activeSwap: _controller.activeSwap,
                                    isInteractionLocked:
                                        _controller.isInputLocked,
                                    isClearing: _controller.isClearing,
                                    isCleared: _controller.isCleared,
                                    clearActiveBookId:
                                        _controller.clearActiveBookId,
                                    onBookTap: _controller.handleBookTap,
                                  ),
                                ),
                                const SizedBox(
                                  height: AppDimensions.mediumSpacing,
                                ),
                                _GameStatusBar(controller: _controller),
                                const SizedBox(
                                  height: AppDimensions.smallSpacing,
                                ),
                                const _InteractionPlaceholder(),
                                const SizedBox(
                                  height: AppDimensions.sectionSpacing,
                                ),
                                CluePanelWidget(
                                  clues: _controller.clues,
                                  books: _stageBooks(_controller.placements),
                                  satisfiedClueIds:
                                      _controller.satisfiedClueIds,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (_controller.isCleared)
                ClearResultOverlay(
                  level: 1,
                  moveCount: _controller.moveCount,
                  onRetry: _controller.restart,
                  onHome: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  onNextLevel: () => _showNextLevelSnackBar(context),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showNextLevelSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text(AppStrings.nextLevelNextStepMessage)),
      );
  }

  List<Book> _stageBooks(List<BookPlacement> placements) {
    final seenBookIds = <String>{};
    final books = <Book>[];

    for (final placement in placements) {
      if (seenBookIds.add(placement.book.id)) {
        books.add(placement.book);
      }
    }
    return books;
  }
}

class _GameInstruction extends StatelessWidget {
  const _GameInstruction();

  @override
  Widget build(BuildContext context) {
    return Text(
      AppStrings.gameInstruction,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.titleLarge,
    );
  }
}

class _GameStatusBar extends StatelessWidget {
  const _GameStatusBar({required this.controller});

  final GameController controller;
  static const _bookLabelFormatter = BookLabelFormatter();

  @override
  Widget build(BuildContext context) {
    final selectedBookName = _selectedBookName();
    final selectionText = switch (controller.status) {
      GameStatus.animating => AppStrings.swappingBooks,
      GameStatus.clearing => AppStrings.clearingBooks,
      GameStatus.cleared => AppStrings.clearedBooks,
      GameStatus.idle =>
        selectedBookName == null
            ? AppStrings.selectFirstBook
            : '${AppStrings.selectedBookPrefix} $selectedBookName · ${AppStrings.selectSecondBook}',
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.mediumSpacing,
        vertical: AppDimensions.smallSpacing,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.swap_horiz_rounded, color: AppColors.primary),
              const SizedBox(width: AppDimensions.smallSpacing),
              Text('${AppStrings.moveCountPrefix} ${controller.moveCount}회'),
              const Spacer(),
              const Icon(Icons.fact_check_outlined, color: AppColors.primary),
              const SizedBox(width: AppDimensions.smallSpacing),
              Text(
                '${AppStrings.clueTitle} '
                '${controller.satisfiedClueCount}/${controller.clues.length}',
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.smallSpacing),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              selectionText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }

  String? _selectedBookName() {
    final selectedBookId = controller.selectedBookId;
    if (selectedBookId == null) {
      return null;
    }

    for (final placement in controller.placements) {
      if (placement.book.id == selectedBookId) {
        return _bookLabelFormatter.formatBook(placement.book);
      }
    }
    return null;
  }
}

class _InteractionPlaceholder extends StatelessWidget {
  const _InteractionPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Text(
      AppStrings.gameSelectionInstruction,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyLarge,
    );
  }
}
