import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/progress/game_progress_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../application/game_controller.dart';
import '../application/game_status.dart';
import '../domain/book.dart';
import '../domain/book_placement.dart';
import '../generator/generator_config.dart';
import '../generator/generator_version_policy.dart';
import '../generator/stage_generation_exception.dart';
import '../generator/stage_generator.dart';
import 'formatters/book_label_formatter.dart';
import 'widgets/bookshelf_widget.dart';
import 'widgets/clue_panel_widget.dart';
import 'widgets/clear_result_overlay.dart';
import 'widgets/game_generation_error_view.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    required this.progressController,
    this.level = 1,
    this.generatorVersion = GeneratorConfig.currentVersion,
    this.stageGenerator = const StageGenerator(),
    this.generatorVersionPolicy = const GeneratorVersionPolicy(),
    super.key,
  });

  final GameProgressController progressController;
  final int level;
  final int generatorVersion;
  final StageGenerator stageGenerator;
  final GeneratorVersionPolicy generatorVersionPolicy;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  GameController? _controller;
  Object? _generationError;
  bool _isGenerating = false;
  late int _currentLevel;
  bool _isPreparingNextLevel = false;
  String? _nextLevelErrorMessage;
  bool _isProgressSaveError = false;
  int _stageSessionRevision = 0;

  @override
  void initState() {
    super.initState();
    _currentLevel = widget.level;
    _generateStage(notify: false);
  }

  @override
  void didUpdateWidget(covariant GameScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.level != widget.level ||
        oldWidget.generatorVersion != widget.generatorVersion ||
        oldWidget.stageGenerator != widget.stageGenerator ||
        oldWidget.generatorVersionPolicy != widget.generatorVersionPolicy) {
      _currentLevel = widget.level;
      _generateStage(notify: false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_generationError != null) {
      return _buildGenerationError(context);
    }
    if (controller == null) {
      return _buildLoading();
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return _buildGame(context, controller);
      },
    );
  }

  void _generateStage({required bool notify}) {
    if (_isGenerating) {
      return;
    }

    void perform() {
      _isGenerating = true;
      try {
        final stage = widget.stageGenerator.generate(
          level: _currentLevel,
          generatorVersion: widget.generatorVersion,
        );
        if (stage.level != _currentLevel ||
            stage.generatorVersion != widget.generatorVersion) {
          throw StateError('Generated initial stage metadata mismatch.');
        }
        final nextController = GameController.fromGeneratedStage(stage: stage);
        final previousController = _controller;
        _controller = nextController;
        _currentLevel = stage.level;
        _stageSessionRevision += 1;
        _generationError = null;
        _nextLevelErrorMessage = null;
        _isProgressSaveError = false;
        _isPreparingNextLevel = false;
        previousController?.dispose();
      } on StageGenerationException catch (error) {
        _replaceControllerWithError(error);
      } on UnsupportedError catch (error) {
        _replaceControllerWithError(error);
      } on ArgumentError catch (error) {
        _replaceControllerWithError(error);
      } on StateError catch (error) {
        _replaceControllerWithError(error);
      } finally {
        _isGenerating = false;
      }
    }

    if (notify && mounted) {
      setState(perform);
    } else {
      perform();
    }
  }

  void _replaceControllerWithError(Object error) {
    final previousController = _controller;
    _controller = null;
    _generationError = error;
    _nextLevelErrorMessage = null;
    _isProgressSaveError = false;
    _isPreparingNextLevel = false;
    previousController?.dispose();
  }

  Future<void> _prepareNextLevel() async {
    final currentController = _controller;
    if (currentController == null ||
        _isPreparingNextLevel ||
        currentController.status != GameStatus.cleared ||
        !currentController.areAllCluesSatisfied ||
        !currentController.isGeneratedStageGame) {
      return;
    }

    final nextLevel = currentController.level + 1;

    setState(() {
      _isPreparingNextLevel = true;
      _nextLevelErrorMessage = null;
      _isProgressSaveError = false;
    });

    GameController? nextController;
    var progressSaveStarted = false;

    try {
      final generatorVersion = widget.generatorVersionPolicy.versionForLevel(
        nextLevel,
      );
      final nextStage = widget.stageGenerator.generate(
        level: nextLevel,
        generatorVersion: generatorVersion,
      );
      if (nextStage.level != nextLevel) {
        throw StateError(
          'Requested Level $nextLevel, but generated Level ${nextStage.level}.',
        );
      }
      if (nextStage.generatorVersion != generatorVersion) {
        throw StateError('Generator version mismatch.');
      }

      nextController = GameController.fromGeneratedStage(stage: nextStage);
      progressSaveStarted = true;
      await widget.progressController.advanceToLevel(
        level: nextLevel,
        generatorVersion: generatorVersion,
      );
      if (!mounted) {
        nextController.dispose();
        return;
      }

      setState(() {
        _controller = nextController;
        _currentLevel = nextStage.level;
        _stageSessionRevision += 1;
        _isPreparingNextLevel = false;
        _nextLevelErrorMessage = null;
        _isProgressSaveError = false;
        _generationError = null;
      });

      currentController.dispose();
    } on StageGenerationException {
      nextController?.dispose();
      _handleNextLevelFailure(
        nextLevel: nextLevel,
        message: AppStrings.nextLevelPreparationError,
        isProgressSaveError: false,
      );
    } on UnsupportedError {
      nextController?.dispose();
      _handleNextLevelFailure(
        nextLevel: nextLevel,
        message: 'Level $nextLevel은 아직 이용할 수 없습니다.',
        isProgressSaveError: false,
      );
    } on ArgumentError {
      nextController?.dispose();
      _handleNextLevelFailure(
        nextLevel: nextLevel,
        message: progressSaveStarted
            ? AppStrings.progressSaveError
            : AppStrings.nextLevelPreparationError,
        isProgressSaveError: progressSaveStarted,
      );
    } on StateError {
      nextController?.dispose();
      _handleNextLevelFailure(
        nextLevel: nextLevel,
        message: progressSaveStarted
            ? AppStrings.progressSaveError
            : AppStrings.nextLevelPreparationError,
        isProgressSaveError: progressSaveStarted,
      );
    }
  }

  void _handleNextLevelFailure({
    required int nextLevel,
    required String message,
    required bool isProgressSaveError,
  }) {
    if (!mounted) {
      return;
    }
    setState(() {
      _isPreparingNextLevel = false;
      _nextLevelErrorMessage = message;
      _isProgressSaveError = isProgressSaveError;
    });
  }

  void _retryCurrentLevel() {
    if (_isPreparingNextLevel) {
      return;
    }
    if (_nextLevelErrorMessage != null) {
      setState(() {
        _nextLevelErrorMessage = null;
        _isProgressSaveError = false;
      });
    }
    _controller?.restart();
  }

  void _goHome(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Scaffold _buildGame(BuildContext context, GameController controller) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Level ${controller.level}',
          key: const Key('game_level_label'),
        ),
        actions: [
          IconButton(
            key: const Key('game_restart_button'),
            tooltip: '재시작',
            iconSize: AppDimensions.iconSize,
            onPressed: controller.status == GameStatus.idle
                ? controller.restart
                : null,
            icon: const Icon(Icons.restart_alt_rounded),
          ),
          IconButton(
            tooltip: AppStrings.settingsButton,
            iconSize: AppDimensions.iconSize,
            onPressed: controller.isInputLocked
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
              onTap: controller.cancelSelection,
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
                            const SizedBox(height: AppDimensions.mediumSpacing),
                            const _GameInstruction(),
                            const SizedBox(
                              height: AppDimensions.sectionSpacing,
                            ),
                            KeyedSubtree(
                              key: ValueKey(
                                'game_stage_${controller.level}_'
                                '$_stageSessionRevision'
                                '_bookshelf_revision_${controller.boardRevision}',
                              ),
                              child: BookshelfWidget(
                                placements: controller.placements,
                                tierCount: controller.tierCount,
                                booksPerTier: controller.booksPerTier,
                                selectedBookId: controller.selectedBookId,
                                isAnimating: controller.isAnimating,
                                activeSwap: controller.activeSwap,
                                isInteractionLocked: controller.isInputLocked,
                                isClearing: controller.isClearing,
                                isCleared: controller.isCleared,
                                clearActiveBookId: controller.clearActiveBookId,
                                isShelfGlowing: controller.isShelfGlowing,
                                onBookTap: controller.handleBookTap,
                                onEmptyTap: controller.cancelSelection,
                              ),
                            ),
                            const SizedBox(height: AppDimensions.mediumSpacing),
                            _GameStatusBar(controller: controller),
                            const SizedBox(height: AppDimensions.smallSpacing),
                            const _InteractionPlaceholder(),
                            const SizedBox(
                              height: AppDimensions.sectionSpacing,
                            ),
                            CluePanelWidget(
                              clues: controller.clues,
                              books: _stageBooks(controller.placements),
                              satisfiedClueIds: controller.satisfiedClueIds,
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
          if (controller.isCleared)
            ClearResultOverlay(
              level: controller.level,
              moveCount: controller.moveCount,
              isPreparingNextLevel: _isPreparingNextLevel,
              nextLevelErrorMessage: _nextLevelErrorMessage,
              isProgressSaveError: _isProgressSaveError,
              onRetry: _retryCurrentLevel,
              onHome: () => _goHome(context),
              onNextLevel: _prepareNextLevel,
            ),
        ],
      ),
    );
  }

  Scaffold _buildGenerationError(BuildContext context) {
    return Scaffold(
      body: GameGenerationErrorView(
        level: _currentLevel,
        isRetrying: _isGenerating,
        onRetry: () => _generateStage(notify: true),
        onHome: () => _goHome(context),
      ),
    );
  }

  Scaffold _buildLoading() {
    return const Scaffold(
      body: SafeArea(child: Center(child: Text(AppStrings.generationLoading))),
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
