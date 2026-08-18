import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_routes.dart';
import '../../../core/ads/application/ad_session_coordinator.dart';
import '../../../core/ads/interstitial/next_level_ad_gate.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_durations.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/feedback/application/app_feedback_settings_controller.dart';
import '../../../core/feedback/application/game_feedback_coordinator.dart';
import '../../../core/feedback/haptic/game_haptic_player.dart';
import '../../../core/feedback/sound/game_sound_player.dart';
import '../../../core/progress/game_progress_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../application/game_controller.dart';
import '../application/game_status.dart';
import '../domain/book.dart';
import '../domain/book_placement.dart';
import '../generator/generator_config.dart';
import '../generator/generated_stage.dart';
import '../generator/generator_version_policy.dart';
import '../generator/stage_generation_exception.dart';
import '../generator/stage_generator.dart';
import '../tutorial/application/game_tutorial_controller.dart';
import '../tutorial/application/learning_progress_controller.dart';
import '../tutorial/data/shared_preferences_learning_progress_store.dart';
import '../tutorial/domain/rule_introduction.dart';
import '../tutorial/domain/tutorial_step.dart';
import '../tutorial/domain/tutorial_step_type.dart';
import '../tutorial/domain/tutorial_target.dart';
import '../tutorial/presentation/rule_introduction_overlay.dart';
import '../tutorial/presentation/tutorial_coach_mark_overlay.dart';
import '../tutorial/presentation/tutorial_target_registry.dart';
import '../tutorial/presentation/tutorial_target_widget.dart';
import 'formatters/book_label_formatter.dart';
import 'formatters/clue_text_formatter.dart';
import 'widgets/bookshelf_widget.dart';
import 'widgets/clue_bottom_sheet.dart';
import 'widgets/clue_summary_button.dart';
import 'widgets/clear_result_overlay.dart';
import 'widgets/game_generation_error_view.dart';
import 'widgets/game_header.dart';
import 'widgets/game_status_bar.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    required this.progressController,
    this.level = 1,
    this.generatorVersion = GeneratorConfig.currentVersion,
    this.stageGenerator = const StageGenerator(),
    this.generatorVersionPolicy = const GeneratorVersionPolicy(),
    this.learningProgressController,
    this.feedbackSettingsController,
    this.soundPlayer,
    this.hapticPlayer,
    this.nextLevelAdGate,
    this.adSessionCoordinator,
    this.enableTutorial = false,
    super.key,
  });

  final GameProgressController progressController;
  final int level;
  final int generatorVersion;
  final StageGenerator stageGenerator;
  final GeneratorVersionPolicy generatorVersionPolicy;
  final LearningProgressController? learningProgressController;
  final AppFeedbackSettingsController? feedbackSettingsController;
  final GameSoundPlayer? soundPlayer;
  final GameHapticPlayer? hapticPlayer;
  final NextLevelAdGate? nextLevelAdGate;
  final AdSessionCoordinator? adSessionCoordinator;
  final bool enableTutorial;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  GameController? _controller;
  late final GameTutorialController _tutorialController;
  late final TutorialTargetRegistry _tutorialTargetRegistry;
  GameFeedbackCoordinator? _feedbackCoordinator;
  LearningProgressController? _ownedLearningProgressController;
  Object? _generationError;
  bool _isGenerating = false;
  late int _currentLevel;
  bool _isPreparingNextLevel = false;
  String? _nextLevelErrorMessage;
  bool _isProgressSaveError = false;
  int _stageSessionRevision = 0;
  int _clearLearningHandledRevision = -1;
  bool _learningProgressReady = false;
  List<RuleIntroduction> _ruleIntroductionQueue = const [];
  int _ruleIntroductionIndex = 0;
  bool _isClueBottomSheetOpen = false;

  @override
  void initState() {
    super.initState();
    _tutorialController = GameTutorialController();
    _tutorialTargetRegistry = TutorialTargetRegistry();
    final feedbackSettingsController = widget.feedbackSettingsController;
    final soundPlayer = widget.soundPlayer;
    final hapticPlayer = widget.hapticPlayer;
    if (feedbackSettingsController != null &&
        soundPlayer != null &&
        hapticPlayer != null) {
      _feedbackCoordinator = GameFeedbackCoordinator(
        settingsController: feedbackSettingsController,
        soundPlayer: soundPlayer,
        hapticPlayer: hapticPlayer,
      );
    }
    if (widget.enableTutorial && widget.learningProgressController == null) {
      _ownedLearningProgressController = LearningProgressController(
        store: SharedPreferencesLearningProgressStore(),
      );
    }
    _learningProgressController?.addListener(_handleLearningProgressChanged);
    _learningProgressReady = !widget.enableTutorial;
    _currentLevel = widget.level;
    _generateStage(notify: false);
    widget.adSessionCoordinator?.onGameScreenEntered(_currentLevel);
    unawaited(_initializeLearningProgress());
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
      widget.adSessionCoordinator?.updateCurrentLevel(_currentLevel);
    }
    if (oldWidget.adSessionCoordinator != widget.adSessionCoordinator) {
      oldWidget.adSessionCoordinator?.onGameScreenLeft();
      widget.adSessionCoordinator?.onGameScreenEntered(_currentLevel);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_handleGameControllerChanged);
    _controller?.dispose();
    _controller = null;
    widget.adSessionCoordinator?.onGameScreenLeft();
    _tutorialController.dispose();
    unawaited(_feedbackCoordinator?.dispose());
    _learningProgressController?.removeListener(_handleLearningProgressChanged);
    _ownedLearningProgressController?.dispose();
    _tutorialTargetRegistry.clear();
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
      animation: Listenable.merge([controller, _tutorialController]),
      builder: (context, _) {
        return _buildGame(context, controller);
      },
    );
  }

  LearningProgressController? get _learningProgressController {
    return widget.learningProgressController ??
        _ownedLearningProgressController;
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
        previousController?.removeListener(_handleGameControllerChanged);
        _controller = nextController;
        nextController.addListener(_handleGameControllerChanged);
        _feedbackCoordinator?.attach(nextController);
        _currentLevel = stage.level;
        _stageSessionRevision += 1;
        _clearLearningHandledRevision = -1;
        _tutorialTargetRegistry.clear();
        _generationError = null;
        _nextLevelErrorMessage = null;
        _isProgressSaveError = false;
        _isPreparingNextLevel = false;
        _configureStageGuides();
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
    previousController?.removeListener(_handleGameControllerChanged);
    unawaited(_feedbackCoordinator?.stop());
    _controller = null;
    _tutorialController.skipAllTutorials();
    _ruleIntroductionQueue = const [];
    _ruleIntroductionIndex = 0;
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
      await _showAdBeforeNextLevelIfReady(
        completedLevel: currentController.level,
        nextLevel: nextLevel,
      );
      if (!mounted) {
        nextController.dispose();
        return;
      }

      setState(() {
        currentController.removeListener(_handleGameControllerChanged);
        _controller = nextController;
        nextController!.addListener(_handleGameControllerChanged);
        _feedbackCoordinator?.attach(nextController);
        _currentLevel = nextStage.level;
        _stageSessionRevision += 1;
        _clearLearningHandledRevision = -1;
        _tutorialTargetRegistry.clear();
        _isPreparingNextLevel = false;
        _nextLevelErrorMessage = null;
        _isProgressSaveError = false;
        _generationError = null;
        _configureStageGuides();
      });

      widget.adSessionCoordinator?.updateCurrentLevel(nextStage.level);
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

  Future<void> _showAdBeforeNextLevelIfReady({
    required int completedLevel,
    required int nextLevel,
  }) async {
    final gate = widget.nextLevelAdGate;
    if (gate == null) {
      return;
    }
    try {
      await gate.showBeforeTransition(
        completedLevel: completedLevel,
        nextLevel: nextLevel,
      );
    } catch (_) {
      // Ad failures must not block the already-saved level transition.
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

  void _restartCurrentLevel() {
    final controller = _controller;
    if (controller == null || controller.status != GameStatus.idle) {
      return;
    }
    controller.restart();
    _configureStageGuides();
  }

  void _goHome(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Widget _buildGame(BuildContext context, GameController controller) {
    final shouldShowTutorialOverlay = _shouldShowMainTutorialOverlay(
      controller,
    );
    final gameScaffold = Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            GameHeader(
              level: controller.level,
              onBack: () => Navigator.of(context).maybePop(),
              settingsEnabled: !controller.isInputLocked && !_blocksChromeInput,
              onSettings: () =>
                  Navigator.of(context).pushNamed(AppRoutes.settings),
            ),
            Expanded(
              child: Stack(
                children: [
                  GestureDetector(
                    key: const Key('game_content_background'),
                    behavior: HitTestBehavior.opaque,
                    onTap: controller.cancelSelection,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimensions.screenPadding,
                        4,
                        AppDimensions.screenPadding,
                        AppDimensions.gameSectionGap,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _GameInstruction(),
                          const SizedBox(height: AppDimensions.gameSectionGap),
                          Expanded(
                            child: KeyedSubtree(
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
                                clueHighlightedBookIds:
                                    controller.clueHighlightedBookIds,
                                tutorialTargetRegistry: _tutorialTargetRegistry,
                                onBookTap: _handleBookTap,
                                onEmptyTap: _handleEmptyTap,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppDimensions.gameSectionGap),
                          GameStatusBar(
                            moveCount: controller.moveCount,
                            selectionText: _selectionTextFor(controller),
                            clueSummaryButton: _buildClueSummaryButton(
                              controller,
                            ),
                            restartEnabled:
                                controller.status == GameStatus.idle &&
                                !_blocksChromeInput,
                            onRestart: _restartCurrentLevel,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!controller.isCleared && _currentRuleIntroduction != null)
                    RuleIntroductionOverlay(
                      introduction: _currentRuleIntroduction!,
                      onAcknowledge: _acknowledgeCurrentRuleIntroduction,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      key: const Key('game_system_ui_style'),
      value: controller.isCleared
          ? AppTheme.clearResultSystemUiOverlayStyle
          : shouldShowTutorialOverlay
          ? AppTheme.tutorialSystemUiOverlayStyle
          : AppTheme.systemUiOverlayStyle,
      child: Stack(
        key: const Key('game_screen_route_stack'),
        fit: StackFit.expand,
        children: [
          gameScaffold,
          if (shouldShowTutorialOverlay)
            TutorialCoachMarkOverlay(
              key: const Key('game_tutorial_route_overlay'),
              registry: _tutorialTargetRegistry,
              step: _tutorialController.currentStep!,
              stepIndex: _tutorialController.currentStepIndex,
              totalStepCount: _tutorialController.plan!.steps.length,
              onAcknowledge: _tutorialController.acknowledgeCurrentStep,
              onSkipConfirmed: _skipTutorial,
              onTargetTap:
                  _tutorialController.currentStep?.type ==
                      TutorialStepType.tapClueSummary
                  ? () => unawaited(_openClueBottomSheet())
                  : null,
              blockBackgroundInteraction: true,
              useRootSafeInsets: true,
            ),
          if (controller.isCleared)
            ClearResultOverlay(
              key: const Key('game_clear_result_route_overlay'),
              level: controller.level,
              moveCount: controller.moveCount,
              isPreparingNextLevel: _isPreparingNextLevel,
              nextLevelErrorMessage: _nextLevelErrorMessage,
              isProgressSaveError: _isProgressSaveError,
              onHome: () => _goHome(context),
              onNextLevel: _prepareNextLevel,
            ),
        ],
      ),
    );
  }

  RuleIntroduction? get _currentRuleIntroduction {
    if (_tutorialController.isActive ||
        _ruleIntroductionIndex < 0 ||
        _ruleIntroductionIndex >= _ruleIntroductionQueue.length) {
      return null;
    }
    return _ruleIntroductionQueue[_ruleIntroductionIndex];
  }

  bool get _blocksChromeInput {
    return _tutorialController.blocksGameInput ||
        _currentRuleIntroduction != null ||
        _isClueBottomSheetOpen;
  }

  Future<void> _initializeLearningProgress() async {
    if (!widget.enableTutorial) {
      return;
    }
    final learningController = _learningProgressController;
    if (learningController == null) {
      return;
    }
    await learningController.initialize(currentLevel: _currentLevel);
    if (!mounted) {
      return;
    }
    setState(() {
      _learningProgressReady = true;
      _configureStageGuides();
    });
  }

  void _configureStageGuides() {
    final controller = _controller;
    final stage = controller?.generatedStage;
    if (!widget.enableTutorial ||
        !_learningProgressReady ||
        controller == null ||
        stage == null) {
      _tutorialController.skipAllTutorials();
      _ruleIntroductionQueue = const [];
      _ruleIntroductionIndex = 0;
      return;
    }

    final learningController = _learningProgressController;
    final tutorialCompleted = learningController?.tutorialCompleted ?? true;
    _tutorialController.startForStage(
      stage: stage,
      tutorialCompleted: tutorialCompleted,
    );

    if (_tutorialController.isActive || stage.level <= 5) {
      _ruleIntroductionQueue = const [];
      _ruleIntroductionIndex = 0;
      return;
    }

    _ruleIntroductionQueue = _buildRuleIntroductionQueue(controller);
    _ruleIntroductionIndex = 0;
  }

  List<RuleIntroduction> _buildRuleIntroductionQueue(
    GameController controller,
  ) {
    final stage = controller.generatedStage;
    final learningController = _learningProgressController;
    if (stage == null || learningController == null) {
      return const [];
    }

    final formatter = const ClueTextFormatter();
    final books = _stageBooks(stage.initialPlacements);
    final queuedRuleCodes = <String>{};
    final introductions = <RuleIntroduction>[];

    for (final clue in stage.clues) {
      final ruleCode = stableRuleCodeForClue(clue);
      if (learningController.isRuleAcknowledged(ruleCode) ||
          !queuedRuleCodes.add(ruleCode)) {
        continue;
      }
      introductions.add(
        RuleIntroduction(
          ruleCode: ruleCode,
          title: ruleTitleForClueType(clue.type),
          description: ruleDescriptionForClueType(clue.type),
          exampleClueText: formatter.format(clue: clue, books: books),
          clueType: clue.type,
        ),
      );
    }

    return List<RuleIntroduction>.unmodifiable(introductions);
  }

  Widget _buildClueSummaryButton(GameController controller) {
    final summaryButton = ClueSummaryButton(
      satisfiedCount: controller.satisfiedClueCount,
      totalCount: controller.clues.length,
      enabled: _canOpenClueBottomSheet(controller),
      onPressed: () => unawaited(_openClueBottomSheet()),
    );

    if (!widget.enableTutorial) {
      return summaryButton;
    }
    return TutorialTargetWidget(
      registry: _tutorialTargetRegistry,
      targetId: const TutorialTarget.cluePanelToggle().targetId!,
      child: summaryButton,
    );
  }

  bool _canOpenClueBottomSheet(GameController controller) {
    if (_isClueBottomSheetOpen ||
        _currentRuleIntroduction != null ||
        controller.status != GameStatus.idle ||
        controller.isCleared) {
      return false;
    }
    return _tutorialController.canOpenClueSheet(controller);
  }

  Future<void> _openClueBottomSheet() async {
    final controller = _controller;
    if (controller == null || !_canOpenClueBottomSheet(controller)) {
      return;
    }

    _tutorialController.onClueSummaryOpened(controller);
    if (!mounted) {
      return;
    }
    setState(() {
      _isClueBottomSheetOpen = true;
    });

    final selectedClueId = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      barrierColor: AppColors.modalScrim,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return AnimatedBuilder(
          animation: Listenable.merge([controller, _tutorialController]),
          builder: (context, _) {
            return ClueBottomSheet(
              clues: controller.clues,
              books: _stageBooks(controller.placements),
              satisfiedClueIds: controller.satisfiedClueIds,
              highlightedClueId: controller.highlightedClueId,
              tutorialTargetRegistry: _tutorialTargetRegistry,
              tutorialStep: _bottomSheetTutorialStep,
              tutorialStepIndex: _tutorialController.currentStepIndex,
              tutorialStepCount: _tutorialController.plan?.steps.length ?? 0,
              onTutorialAcknowledge: _tutorialController.acknowledgeCurrentStep,
              onTutorialSkipConfirmed: () {
                _skipTutorialFromBottomSheet(bottomSheetContext);
              },
              canSelectClue: (clueId) {
                return _tutorialController.canTapClue(clueId, controller);
              },
            );
          },
        );
      },
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _isClueBottomSheetOpen = false;
    });

    final activeController = _controller;
    if (activeController == null) {
      return;
    }
    if (selectedClueId == null) {
      _tutorialController.onClueSheetDismissed();
      return;
    }
    await Future<void>.delayed(AppDurations.resultOverlay);
    if (!mounted) {
      return;
    }
    _handleClueTap(selectedClueId);
  }

  TutorialStep? get _bottomSheetTutorialStep {
    if (_tutorialController.isWaitingForClueHighlight) {
      return null;
    }
    final step = _tutorialController.currentStep;
    if (step == null || step.target.type != TutorialTargetType.clueCard) {
      return null;
    }
    return step;
  }

  bool _shouldShowMainTutorialOverlay(GameController controller) {
    if (controller.isCleared ||
        !_tutorialController.isActive ||
        _tutorialController.isWaitingForClueHighlight) {
      return false;
    }
    final step = _tutorialController.currentStep;
    if (step == null) {
      return false;
    }
    if (_isClueBottomSheetOpen &&
        step.target.type == TutorialTargetType.clueCard) {
      return false;
    }
    return true;
  }

  void _handleBookTap(String bookId) {
    final controller = _controller;
    if (controller == null || _currentRuleIntroduction != null) {
      return;
    }
    if (!_tutorialController.canTapBook(bookId, controller)) {
      return;
    }
    controller.handleBookTap(bookId);
    _tutorialController.onBookTapped(bookId, controller);
  }

  void _handleClueTap(String clueId) {
    final controller = _controller;
    if (controller == null ||
        _currentRuleIntroduction != null ||
        controller.status != GameStatus.idle) {
      return;
    }
    if (!_tutorialController.canTapClue(clueId, controller)) {
      return;
    }
    controller.highlightClue(clueId);
    _tutorialController.onClueTapped(clueId, controller);
  }

  void _handleEmptyTap() {
    final controller = _controller;
    if (controller == null ||
        _currentRuleIntroduction != null ||
        _tutorialController.blocksGameInput) {
      return;
    }
    controller.cancelSelection();
  }

  void _handleLearningProgressChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      _configureStageGuides();
    });
  }

  void _handleGameControllerChanged() {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    _tutorialController.onGameControllerChanged(controller);
    if (_tutorialController.isWaitingForClueHighlight &&
        controller.status == GameStatus.idle &&
        controller.highlightedClueId == null) {
      _tutorialController.onClueHighlightFinished();
    }

    if (controller.isCleared &&
        _clearLearningHandledRevision != _stageSessionRevision) {
      _clearLearningHandledRevision = _stageSessionRevision;
      unawaited(_handleStageCleared(controller));
    }
  }

  Future<void> _handleStageCleared(GameController controller) async {
    final stage = controller.generatedStage;
    final learningController = _learningProgressController;
    if (!widget.enableTutorial || stage == null || learningController == null) {
      return;
    }

    if (stage.level <= 5) {
      await learningController.acknowledgeRules(_ruleCodesForStage(stage));
    }
    if (stage.level == 5) {
      await learningController.completeTutorial();
    }
  }

  Iterable<String> _ruleCodesForStage(GeneratedStage stage) sync* {
    for (final clue in stage.clues) {
      yield stableRuleCodeForClue(clue);
    }
  }

  void _acknowledgeCurrentRuleIntroduction() {
    final introduction = _currentRuleIntroduction;
    final learningController = _learningProgressController;
    if (introduction == null || learningController == null) {
      return;
    }
    setState(() {
      _ruleIntroductionIndex += 1;
    });
    unawaited(learningController.acknowledgeRules([introduction.ruleCode]));
  }

  void _skipTutorial() {
    _tutorialController.skipAllTutorials();
    unawaited(_learningProgressController?.skipTutorial());
    setState(() {
      _ruleIntroductionQueue = const [];
      _ruleIntroductionIndex = 0;
    });
  }

  void _skipTutorialFromBottomSheet(BuildContext bottomSheetContext) {
    if (bottomSheetContext.mounted) {
      final bottomSheetRoute = ModalRoute.of(bottomSheetContext);
      if (bottomSheetRoute?.isCurrent == true) {
        Navigator.of(bottomSheetContext).pop();
      }
    }
    _skipTutorial();
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

  String _selectionTextFor(GameController controller) {
    final selectedBookName = _selectedBookName(controller);
    return switch (controller.status) {
      GameStatus.animating => AppStrings.swappingBooks,
      GameStatus.clearing => AppStrings.clearingBooks,
      GameStatus.cleared => AppStrings.clearedBooks,
      GameStatus.idle =>
        selectedBookName == null
            ? AppStrings.selectFirstBook
            : '${AppStrings.selectedBookPrefix} $selectedBookName · ${AppStrings.selectSecondBook}',
    };
  }

  String? _selectedBookName(GameController controller) {
    final selectedBookId = controller.selectedBookId;
    if (selectedBookId == null) {
      return null;
    }

    const formatter = BookLabelFormatter();
    for (final placement in controller.placements) {
      if (placement.book.id == selectedBookId) {
        return formatter.formatBook(placement.book);
      }
    }
    return null;
  }
}

class _GameInstruction extends StatelessWidget {
  const _GameInstruction();

  @override
  Widget build(BuildContext context) {
    return Text(
      AppStrings.gameSelectionInstruction,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodyLarge,
    );
  }
}
