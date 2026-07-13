import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_durations.dart';
import 'active_swap.dart';
import 'game_status.dart';
import '../domain/book.dart';
import '../domain/book_placement.dart';
import '../domain/clue.dart';
import '../domain/clue_evaluator.dart';

class GameController extends ChangeNotifier {
  GameController({
    required List<BookPlacement> initialPlacements,
    required List<Clue> initialClues,
    this.swapDuration = AppDurations.bookSwap,
    this.clueCompletionDelay = AppDurations.clueCompletionDelay,
    this.clearBookStepDuration = AppDurations.clearBookStep,
    this.clearFinalGlowDuration = AppDurations.clearFinalGlow,
    ClueEvaluator clueEvaluator = const ClueEvaluator(),
  }) : _initialPlacements = List<BookPlacement>.unmodifiable(
         List<BookPlacement>.of(initialPlacements),
       ),
       _placements = List<BookPlacement>.of(initialPlacements),
       _clues = List<Clue>.of(initialClues),
       _clueEvaluator = clueEvaluator,
       _satisfiedClueIds = Set<String>.of(
         clueEvaluator.evaluateAll(
           clues: initialClues,
           placements: initialPlacements,
         ),
       );

  final List<BookPlacement> _initialPlacements;
  List<BookPlacement> _placements;
  final List<Clue> _clues;
  final ClueEvaluator _clueEvaluator;
  final Duration swapDuration;
  final Duration clueCompletionDelay;
  final Duration clearBookStepDuration;
  final Duration clearFinalGlowDuration;
  Set<String> _satisfiedClueIds;
  String? _selectedBookId;
  int _moveCount = 0;
  GameStatus _status = GameStatus.idle;
  ActiveSwap? _activeSwap;
  Timer? _swapTimer;
  Timer? _clearStartTimer;
  Timer? _clearStepTimer;
  Timer? _clearFinishTimer;
  bool _hasClearTriggered = false;
  int _clearStepIndex = -1;
  int _boardRevision = 0;
  bool _isDisposed = false;

  UnmodifiableListView<BookPlacement> get placements {
    return UnmodifiableListView(_placements);
  }

  UnmodifiableListView<BookPlacement> get initialPlacements {
    return UnmodifiableListView(_initialPlacements);
  }

  UnmodifiableListView<Clue> get clues {
    return UnmodifiableListView(_clues);
  }

  Set<String> get satisfiedClueIds {
    return UnmodifiableSetView(_satisfiedClueIds);
  }

  int get satisfiedClueCount => _satisfiedClueIds.length;

  bool get areAllCluesSatisfied {
    if (_clues.isEmpty || _satisfiedClueIds.length != _clues.length) {
      return false;
    }
    return _clues.every((clue) => _satisfiedClueIds.contains(clue.id));
  }

  String? get selectedBookId => _selectedBookId;

  int get moveCount => _moveCount;

  GameStatus get status => _status;

  bool get isAnimating => _status == GameStatus.animating;

  bool get isClearing => _status == GameStatus.clearing;

  bool get isCleared => _status == GameStatus.cleared;

  bool get canAcceptGameInput => _status == GameStatus.idle;

  bool get canAcceptInput => canAcceptGameInput;

  bool get isInputLocked => _status != GameStatus.idle;

  bool get canRestart {
    return _status == GameStatus.idle || _status == GameStatus.cleared;
  }

  ActiveSwap? get activeSwap => _activeSwap;

  bool get hasClearTriggered => _hasClearTriggered;

  int get clearStepIndex => _clearStepIndex;

  int get boardRevision => _boardRevision;

  String? get clearActiveBookId {
    if (_status != GameStatus.clearing || _clearStepIndex < 0) {
      return null;
    }

    final sortedPlacements = _sortedPlacementsByPosition();
    if (_clearStepIndex >= sortedPlacements.length) {
      return null;
    }
    return sortedPlacements[_clearStepIndex].book.id;
  }

  bool isClueSatisfied(String clueId) {
    return _satisfiedClueIds.contains(clueId);
  }

  void handleBookTap(String bookId) {
    if (!canAcceptGameInput) {
      return;
    }

    final tappedIndex = _indexOfBook(bookId);
    if (tappedIndex == -1) {
      return;
    }

    final selectedBookId = _selectedBookId;
    if (selectedBookId == null) {
      _selectedBookId = bookId;
      notifyListeners();
      return;
    }

    if (selectedBookId == bookId) {
      _selectedBookId = null;
      notifyListeners();
      return;
    }

    final selectedIndex = _indexOfBook(selectedBookId);
    if (selectedIndex == -1) {
      _selectedBookId = null;
      notifyListeners();
      return;
    }

    final selectedPlacement = _placements[selectedIndex];
    final tappedPlacement = _placements[tappedIndex];

    if (!_isVisuallyIdentical(selectedPlacement.book, tappedPlacement.book)) {
      final selectedPosition = selectedPlacement.position;
      final tappedPosition = tappedPlacement.position;
      _placements[selectedIndex] = selectedPlacement.copyWith(
        position: tappedPosition,
      );
      _placements[tappedIndex] = tappedPlacement.copyWith(
        position: selectedPosition,
      );
      _moveCount += 1;
      _activeSwap = ActiveSwap(
        firstBookId: selectedPlacement.book.id,
        secondBookId: tappedPlacement.book.id,
      );
      _status = GameStatus.animating;
      _startSwapTimer();
    }

    _selectedBookId = null;
    notifyListeners();
  }

  void cancelSelection() {
    if (!canAcceptGameInput || _selectedBookId == null) {
      return;
    }

    _selectedBookId = null;
    notifyListeners();
  }

  void restart() {
    if (_isDisposed || !canRestart) {
      return;
    }

    _cancelAllGameTimers();
    _placements = List<BookPlacement>.of(_initialPlacements);
    _selectedBookId = null;
    _moveCount = 0;
    _activeSwap = null;
    _clearStepIndex = -1;
    _hasClearTriggered = false;
    _satisfiedClueIds = Set<String>.of(
      _clueEvaluator.evaluateAll(clues: _clues, placements: _initialPlacements),
    );
    _status = GameStatus.idle;
    _boardRevision += 1;
    notifyListeners();
  }

  bool isBookSelected(String bookId) {
    return _selectedBookId == bookId;
  }

  int _indexOfBook(String bookId) {
    return _placements.indexWhere((placement) => placement.book.id == bookId);
  }

  bool _isVisuallyIdentical(Book first, Book second) {
    return first.color == second.color && first.symbol == second.symbol;
  }

  void _startSwapTimer() {
    _cancelSwapTimer();
    _swapTimer = Timer(swapDuration, () {
      _swapTimer = null;
      if (_isDisposed) {
        return;
      }
      _satisfiedClueIds = Set<String>.of(
        _clueEvaluator.evaluateAll(clues: _clues, placements: _placements),
      );
      _activeSwap = null;
      if (_shouldStartClear()) {
        _hasClearTriggered = true;
        _clearStepIndex = -1;
        _status = GameStatus.clearing;
        notifyListeners();
        _startClearTimers();
        return;
      }
      _status = GameStatus.idle;
      notifyListeners();
    });
  }

  bool _shouldStartClear() {
    return _status == GameStatus.animating &&
        !_hasClearTriggered &&
        areAllCluesSatisfied;
  }

  void _startClearTimers() {
    _cancelClearTimers();
    _clearStartTimer = Timer(clueCompletionDelay, () {
      _clearStartTimer = null;
      if (_isDisposed || _status != GameStatus.clearing) {
        return;
      }
      _startClearBookSteps();
    });
  }

  void _startClearBookSteps() {
    final sortedPlacements = _sortedPlacementsByPosition();
    if (sortedPlacements.isEmpty) {
      _startClearFinishTimer();
      return;
    }

    _clearStepIndex = 0;
    notifyListeners();
    if (sortedPlacements.length == 1) {
      _startClearFinishTimer();
      return;
    }

    _clearStepTimer = Timer.periodic(clearBookStepDuration, (timer) {
      if (_isDisposed || _status != GameStatus.clearing) {
        timer.cancel();
        _clearStepTimer = null;
        return;
      }

      final nextStepIndex = _clearStepIndex + 1;
      if (nextStepIndex >= sortedPlacements.length) {
        timer.cancel();
        _clearStepTimer = null;
        _startClearFinishTimer();
        return;
      }
      _clearStepIndex = nextStepIndex;
      notifyListeners();
    });
  }

  void _startClearFinishTimer() {
    _clearFinishTimer?.cancel();
    _clearFinishTimer = null;
    _clearFinishTimer = Timer(clearFinalGlowDuration, () {
      _clearFinishTimer = null;
      if (_isDisposed || _status != GameStatus.clearing) {
        return;
      }
      _status = GameStatus.cleared;
      _activeSwap = null;
      _selectedBookId = null;
      notifyListeners();
    });
  }

  void _cancelSwapTimer() {
    _swapTimer?.cancel();
    _swapTimer = null;
  }

  void _cancelClearTimers() {
    _clearStartTimer?.cancel();
    _clearStartTimer = null;
    _clearStepTimer?.cancel();
    _clearStepTimer = null;
    _clearFinishTimer?.cancel();
    _clearFinishTimer = null;
  }

  void _cancelAllGameTimers() {
    _cancelSwapTimer();
    _cancelClearTimers();
  }

  List<BookPlacement> _sortedPlacementsByPosition() {
    return _placements.toList()..sort((left, right) {
      final tierComparison = left.position.tierIndex.compareTo(
        right.position.tierIndex,
      );
      if (tierComparison != 0) {
        return tierComparison;
      }
      return left.position.slotIndex.compareTo(right.position.slotIndex);
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _cancelAllGameTimers();
    super.dispose();
  }
}
