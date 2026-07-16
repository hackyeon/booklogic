import 'package:flutter/foundation.dart';

import '../domain/learning_progress.dart';
import 'learning_progress_store.dart';

class LearningProgressController extends ChangeNotifier {
  LearningProgressController({required LearningProgressStore store})
    : _store = store;

  final LearningProgressStore _store;
  LearningProgress _progress = LearningProgress();
  LearningProgress? _lastSavedProgress;
  Future<void>? _initializeFuture;
  bool _isInitialized = false;
  bool _isDisposed = false;
  Object? _lastError;

  LearningProgress get progress => _progress;

  bool get isInitialized => _isInitialized;

  Object? get lastError => _lastError;

  bool get tutorialCompleted => _progress.tutorialCompleted;

  Set<String> get acknowledgedRuleCodes => _progress.acknowledgedRuleCodes;

  bool isRuleAcknowledged(String ruleCode) {
    return _progress.acknowledgedRuleCodes.contains(ruleCode);
  }

  Future<void> initialize({required int currentLevel}) {
    if (_isDisposed) {
      return Future<void>.value();
    }
    final existing = _initializeFuture;
    if (existing != null) {
      return existing;
    }
    if (_isInitialized) {
      return reconcileWithCurrentLevel(currentLevel);
    }

    final future = _initialize(currentLevel);
    _initializeFuture = future.whenComplete(() {
      _initializeFuture = null;
    });
    return _initializeFuture!;
  }

  Future<void> completeTutorial() async {
    if (_isDisposed || _progress.tutorialCompleted) {
      return;
    }
    await _setProgress(_progress.copyWith(tutorialCompleted: true));
  }

  Future<void> skipTutorial() {
    return completeTutorial();
  }

  Future<void> acknowledgeRules(Iterable<String> ruleCodes) async {
    if (_isDisposed) {
      return;
    }
    final nextCodes = Set<String>.of(_progress.acknowledgedRuleCodes);
    for (final code in ruleCodes) {
      final normalizedCode = code.trim();
      if (normalizedCode.isNotEmpty) {
        nextCodes.add(normalizedCode);
      }
    }
    if (_setEquals(nextCodes, _progress.acknowledgedRuleCodes)) {
      return;
    }
    await _setProgress(_progress.copyWith(acknowledgedRuleCodes: nextCodes));
  }

  Future<void> reconcileWithCurrentLevel(int currentLevel) async {
    if (_isDisposed || currentLevel <= 5 || _progress.tutorialCompleted) {
      return;
    }
    await _setProgress(_progress.copyWith(tutorialCompleted: true));
  }

  Future<void> _initialize(int currentLevel) async {
    try {
      _progress = await _store.load();
      _lastSavedProgress = _progress;
      _lastError = null;
    } catch (error) {
      _progress = LearningProgress();
      _lastSavedProgress = null;
      _lastError = error;
    }
    _isInitialized = true;
    _notifySafely();
    await reconcileWithCurrentLevel(currentLevel);
  }

  Future<void> _setProgress(LearningProgress nextProgress) async {
    if (_isDisposed || nextProgress == _progress) {
      return;
    }
    _progress = nextProgress;
    _notifySafely();

    if (nextProgress == _lastSavedProgress) {
      return;
    }

    try {
      await _store.save(nextProgress);
      _lastSavedProgress = nextProgress;
      _lastError = null;
    } catch (error) {
      _lastError = error;
    }
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

bool _setEquals(Set<String> left, Set<String> right) {
  if (left.length != right.length) {
    return false;
  }
  for (final value in left) {
    if (!right.contains(value)) {
      return false;
    }
  }
  return true;
}
