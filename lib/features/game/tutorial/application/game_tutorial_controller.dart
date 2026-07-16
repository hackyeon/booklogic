import 'package:flutter/foundation.dart';

import '../../application/game_controller.dart';
import '../../application/game_status.dart';
import '../../generator/generated_stage.dart';
import '../domain/tutorial_plan.dart';
import '../domain/tutorial_policy.dart';
import '../domain/tutorial_step.dart';
import '../domain/tutorial_step_type.dart';
import 'tutorial_plan_factory.dart';

class GameTutorialController extends ChangeNotifier {
  GameTutorialController({
    this.policy = const TutorialPolicy(),
    this.planFactory = const TutorialPlanFactory(),
  });

  final TutorialPolicy policy;
  final TutorialPlanFactory planFactory;

  TutorialPlan? _plan;
  int _currentStepIndex = 0;
  bool _isWaitingForAnimation = false;
  bool _isWaitingForClueHighlight = false;
  int _moveCountAtStepStart = 0;
  bool _isDisposed = false;
  final Set<int> _sessionCompletedLevels = <int>{};

  TutorialPlan? get plan => _plan;

  int get currentStepIndex => _currentStepIndex;

  TutorialStep? get currentStep {
    final plan = _plan;
    if (plan == null || _currentStepIndex < 0) {
      return null;
    }
    if (_currentStepIndex >= plan.steps.length) {
      return null;
    }
    return plan.steps[_currentStepIndex];
  }

  bool get isActive => _plan != null;

  bool get isWaitingForAnimation => _isWaitingForAnimation;

  bool get isWaitingForClueHighlight => _isWaitingForClueHighlight;

  bool get blocksGameInput => currentStep?.blocksGameInput ?? false;

  bool get canSkip => currentStep?.allowSkip ?? false;

  Set<int> get sessionCompletedLevels {
    return Set<int>.unmodifiable(_sessionCompletedLevels);
  }

  void startForStage({
    required GeneratedStage stage,
    required bool tutorialCompleted,
  }) {
    if (!policy.shouldShowTutorial(
          level: stage.level,
          tutorialCompleted: tutorialCompleted,
        ) ||
        _sessionCompletedLevels.contains(stage.level)) {
      _clearPlan();
      return;
    }

    final nextPlan = planFactory.create(stage: stage);
    if (nextPlan == null) {
      _clearPlan();
      return;
    }

    _plan = nextPlan;
    _currentStepIndex = 0;
    _isWaitingForAnimation = false;
    _isWaitingForClueHighlight = false;
    _moveCountAtStepStart = 0;
    _notifySafely();
  }

  void restartCurrentLevelTutorial({
    required GeneratedStage stage,
    required bool tutorialCompleted,
  }) {
    startForStage(stage: stage, tutorialCompleted: tutorialCompleted);
  }

  bool canTapBook(String bookId, GameController gameController) {
    if (!isActive) {
      return true;
    }
    if (gameController.status != GameStatus.idle ||
        _isWaitingForAnimation ||
        _isWaitingForClueHighlight) {
      return false;
    }
    final step = currentStep;
    if (step == null) {
      return true;
    }
    return switch (step.type) {
      TutorialStepType.tapBook => bookId == step.expectedBookId,
      TutorialStepType.tapSecondBook =>
        bookId == step.expectedBookId || bookId == _previousExpectedBookId(),
      TutorialStepType.tapClueCard ||
      TutorialStepType.acknowledgeMessage ||
      TutorialStepType.freePlayIntroduction => !step.blocksGameInput,
    };
  }

  bool canTapClue(String clueId, GameController gameController) {
    if (!isActive) {
      return true;
    }
    if (gameController.status != GameStatus.idle ||
        _isWaitingForAnimation ||
        _isWaitingForClueHighlight) {
      return false;
    }
    final step = currentStep;
    return step?.type == TutorialStepType.tapClueCard &&
        clueId == step?.expectedClueId;
  }

  void onBookTapped(String bookId, GameController gameController) {
    final step = currentStep;
    if (step == null || !isActive) {
      return;
    }

    if (step.type == TutorialStepType.tapBook &&
        bookId == step.expectedBookId &&
        gameController.selectedBookId == bookId) {
      _moveCountAtStepStart = gameController.moveCount;
      _advanceOrComplete();
      return;
    }

    if (step.type != TutorialStepType.tapSecondBook) {
      return;
    }

    final firstBookId = _previousExpectedBookId();
    if (bookId == firstBookId && gameController.selectedBookId == null) {
      _currentStepIndex -= 1;
      if (_currentStepIndex < 0) {
        _currentStepIndex = 0;
      }
      _isWaitingForAnimation = false;
      _moveCountAtStepStart = gameController.moveCount;
      _notifySafely();
      return;
    }

    if (bookId == step.expectedBookId &&
        gameController.moveCount > _moveCountAtStepStart &&
        gameController.status == GameStatus.animating) {
      _isWaitingForAnimation = true;
      _notifySafely();
    }
  }

  void onClueTapped(String clueId, GameController gameController) {
    final step = currentStep;
    if (step == null ||
        step.type != TutorialStepType.tapClueCard ||
        clueId != step.expectedClueId ||
        gameController.status != GameStatus.idle) {
      return;
    }
    _isWaitingForClueHighlight = true;
    _notifySafely();
  }

  void onGameControllerChanged(GameController gameController) {
    if (!_isWaitingForAnimation || !isActive) {
      return;
    }
    if (gameController.status == GameStatus.idle &&
        gameController.moveCount > _moveCountAtStepStart) {
      _isWaitingForAnimation = false;
      _moveCountAtStepStart = gameController.moveCount;
      _advanceOrComplete();
    }
  }

  void onClueHighlightFinished() {
    if (!_isWaitingForClueHighlight || !isActive) {
      return;
    }
    _isWaitingForClueHighlight = false;
    _advanceOrComplete();
  }

  void acknowledgeCurrentStep() {
    final step = currentStep;
    if (step == null || !step.requiresAcknowledgement) {
      return;
    }
    _advanceOrComplete();
  }

  void completeCurrentLevelLesson() {
    final plan = _plan;
    if (plan != null) {
      _sessionCompletedLevels.add(plan.level);
    }
    _clearPlan();
  }

  void skipAllTutorials() {
    _clearPlan();
  }

  void _advanceOrComplete() {
    final plan = _plan;
    if (plan == null) {
      return;
    }
    if (_currentStepIndex >= plan.steps.length - 1) {
      completeCurrentLevelLesson();
      return;
    }
    _currentStepIndex += 1;
    _notifySafely();
  }

  String? _previousExpectedBookId() {
    final plan = _plan;
    if (plan == null || _currentStepIndex <= 0) {
      return null;
    }
    return plan.steps[_currentStepIndex - 1].expectedBookId;
  }

  void _clearPlan() {
    if (_plan == null &&
        !_isWaitingForAnimation &&
        !_isWaitingForClueHighlight) {
      return;
    }
    _plan = null;
    _currentStepIndex = 0;
    _isWaitingForAnimation = false;
    _isWaitingForClueHighlight = false;
    _moveCountAtStepStart = 0;
    _notifySafely();
  }

  void _notifySafely() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
