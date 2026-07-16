import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../../core/feedback/domain/game_feedback_event.dart';
import '../../../core/constants/app_durations.dart';
import 'active_swap.dart';
import 'game_status.dart';
import '../domain/book.dart';
import '../domain/book_placement.dart';
import '../domain/clue.dart';
import '../domain/clue_evaluator.dart';
import '../generator/generated_stage.dart';
import '../generator/generator_config.dart';
import '../tutorial/application/clue_book_reference_resolver.dart';

class GameController extends ChangeNotifier {
  GameController({
    required List<BookPlacement> initialPlacements,
    List<Clue>? initialClues,
    List<Clue>? clues,
    int level = 1,
    Duration swapDuration = AppDurations.bookSwap,
    Duration clueBookHighlightDuration = AppDurations.clueBookHighlight,
    Duration clueCompletionDelay = AppDurations.clueCompletionDelay,
    Duration clearBookStepDuration = AppDurations.clearBookStep,
    Duration clearFinalGlowDuration = AppDurations.clearFinalGlow,
    ClueEvaluator clueEvaluator = const ClueEvaluator(),
    ClueBookReferenceResolver clueBookReferenceResolver =
        const ClueBookReferenceResolver(),
  }) : this._(
         initialPlacements: initialPlacements,
         clues: _resolveClues(initialClues: initialClues, clues: clues),
         level: level,
         generatedStage: null,
         swapDuration: swapDuration,
         clueBookHighlightDuration: clueBookHighlightDuration,
         clueCompletionDelay: clueCompletionDelay,
         clearBookStepDuration: clearBookStepDuration,
         clearFinalGlowDuration: clearFinalGlowDuration,
         clueEvaluator: clueEvaluator,
         clueBookReferenceResolver: clueBookReferenceResolver,
       );

  factory GameController.fromGeneratedStage({
    required GeneratedStage stage,
    ClueEvaluator clueEvaluator = const ClueEvaluator(),
    Duration swapDuration = AppDurations.bookSwap,
    Duration clueBookHighlightDuration = AppDurations.clueBookHighlight,
    Duration clueCompletionDelay = AppDurations.clueCompletionDelay,
    Duration clearBookStepDuration = AppDurations.clearBookStep,
    Duration clearFinalGlowDuration = AppDurations.clearFinalGlow,
    ClueBookReferenceResolver clueBookReferenceResolver =
        const ClueBookReferenceResolver(),
  }) {
    return GameController._(
      initialPlacements: stage.initialPlacements,
      clues: stage.clues,
      level: stage.level,
      generatedStage: stage,
      clueEvaluator: clueEvaluator,
      swapDuration: swapDuration,
      clueBookHighlightDuration: clueBookHighlightDuration,
      clueCompletionDelay: clueCompletionDelay,
      clearBookStepDuration: clearBookStepDuration,
      clearFinalGlowDuration: clearFinalGlowDuration,
      clueBookReferenceResolver: clueBookReferenceResolver,
    );
  }

  GameController._({
    required List<BookPlacement> initialPlacements,
    required List<Clue> clues,
    required int level,
    required GeneratedStage? generatedStage,
    required this.swapDuration,
    required this.clueBookHighlightDuration,
    required this.clueCompletionDelay,
    required this.clearBookStepDuration,
    required this.clearFinalGlowDuration,
    required ClueEvaluator clueEvaluator,
    required ClueBookReferenceResolver clueBookReferenceResolver,
  }) : _level = _validateLevel(level),
       _generatedStage = generatedStage,
       _layout = _validatePlacementLayout(
         initialPlacements: initialPlacements,
         generatedStage: generatedStage,
       ),
       _initialPlacements = List<BookPlacement>.unmodifiable(
         List<BookPlacement>.of(initialPlacements),
       ),
       _placements = List<BookPlacement>.of(initialPlacements),
       _clues = List<Clue>.unmodifiable(List<Clue>.of(clues)),
       _clueEvaluator = clueEvaluator,
       _clueBookReferenceResolver = clueBookReferenceResolver,
       _satisfiedClueIds = Set<String>.of(
         clueEvaluator.evaluateAll(clues: clues, placements: initialPlacements),
       );

  final int _level;
  final GeneratedStage? _generatedStage;
  final _BookshelfLayoutInfo _layout;
  final List<BookPlacement> _initialPlacements;
  List<BookPlacement> _placements;
  final List<Clue> _clues;
  final ClueEvaluator _clueEvaluator;
  final ClueBookReferenceResolver _clueBookReferenceResolver;
  final Duration swapDuration;
  final Duration clueBookHighlightDuration;
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
  Timer? _clueHighlightTimer;
  final StreamController<GameFeedbackEvent> _feedbackEventController =
      StreamController<GameFeedbackEvent>.broadcast(sync: true);
  String? _highlightedClueId;
  Set<String> _clueHighlightedBookIds = <String>{};
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

  Stream<GameFeedbackEvent> get feedbackEvents {
    return _feedbackEventController.stream;
  }

  GeneratedStage? get generatedStage => _generatedStage;

  bool get isGeneratedStageGame => _generatedStage != null;

  int get level => _level;

  int get generatorVersion {
    return _generatedStage?.generatorVersion ?? GeneratorConfig.currentVersion;
  }

  int get tierCount {
    return _generatedStage?.tierCount ?? _layout.tierCount;
  }

  int get booksPerTier {
    return _generatedStage?.booksPerTier ?? _layout.booksPerTier;
  }

  int get totalBookCount {
    return _placements.length;
  }

  Set<String> get satisfiedClueIds {
    return UnmodifiableSetView(_satisfiedClueIds);
  }

  String? get highlightedClueId => _highlightedClueId;

  Set<String> get clueHighlightedBookIds {
    return UnmodifiableSetView(_clueHighlightedBookIds);
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

  bool get isShelfGlowing {
    if (_status == GameStatus.cleared) {
      return true;
    }
    final activeBookId = clearActiveBookId;
    if (_status != GameStatus.clearing || activeBookId == null) {
      return false;
    }
    final orderedPlacements = _sortedPlacementsByPosition();
    return orderedPlacements.isNotEmpty &&
        orderedPlacements.last.book.id == activeBookId;
  }

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

  List<BookPlacement> placementsForTier(int tierIndex) {
    if (tierIndex < 0 || tierIndex >= tierCount) {
      throw RangeError.range(tierIndex, 0, tierCount - 1, 'tierIndex');
    }
    final tierPlacements =
        _placements
            .where((placement) => placement.position.tierIndex == tierIndex)
            .toList()
          ..sort(
            (left, right) =>
                left.position.slotIndex.compareTo(right.position.slotIndex),
          );
    return List<BookPlacement>.unmodifiable(tierPlacements);
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
      _emitFeedbackEvent(
        GameFeedbackEvent(
          type: GameFeedbackEventType.bookSelected,
          bookId: bookId,
        ),
      );
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
      _clearClueHighlight(notify: false);
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
      _emitFeedbackEvent(
        GameFeedbackEvent(type: GameFeedbackEventType.booksSwapped),
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
    _clearClueHighlight(notify: false);
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

  void highlightClue(String clueId) {
    if (!canAcceptGameInput) {
      return;
    }
    Clue? clue;
    for (final candidate in _clues) {
      if (candidate.id == clueId) {
        clue = candidate;
        break;
      }
    }
    if (clue == null) {
      return;
    }

    _cancelClueHighlightTimer();
    _highlightedClueId = clueId;
    _clueHighlightedBookIds = Set<String>.of(
      _clueBookReferenceResolver.resolveBookIds(
        clue: clue,
        placements: _placements,
      ),
    );
    notifyListeners();

    _clueHighlightTimer = Timer(clueBookHighlightDuration, () {
      _clueHighlightTimer = null;
      if (_isDisposed) {
        return;
      }
      _clearClueHighlight();
    });
  }

  void clearClueHighlight() {
    _clearClueHighlight();
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
      final previousSatisfiedClueIds = Set<String>.of(_satisfiedClueIds);
      final nextSatisfiedClueIds = Set<String>.of(
        _clueEvaluator.evaluateAll(clues: _clues, placements: _placements),
      );
      _satisfiedClueIds = nextSatisfiedClueIds;
      _activeSwap = null;
      if (_shouldStartClear()) {
        _clearClueHighlight(notify: false);
        _hasClearTriggered = true;
        _clearStepIndex = -1;
        _status = GameStatus.clearing;
        _emitFeedbackEvent(
          GameFeedbackEvent(type: GameFeedbackEventType.stageCleared),
        );
        notifyListeners();
        _startClearTimers();
        return;
      }
      _emitNewlySatisfiedClues(
        previousSatisfiedClueIds: previousSatisfiedClueIds,
        nextSatisfiedClueIds: nextSatisfiedClueIds,
      );
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

  void _cancelClueHighlightTimer() {
    _clueHighlightTimer?.cancel();
    _clueHighlightTimer = null;
  }

  void _cancelAllGameTimers() {
    _cancelSwapTimer();
    _cancelClearTimers();
    _cancelClueHighlightTimer();
  }

  void _clearClueHighlight({bool notify = true}) {
    _cancelClueHighlightTimer();
    if (_highlightedClueId == null && _clueHighlightedBookIds.isEmpty) {
      return;
    }
    _highlightedClueId = null;
    _clueHighlightedBookIds = <String>{};
    if (notify && !_isDisposed) {
      notifyListeners();
    }
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

  void _emitNewlySatisfiedClues({
    required Set<String> previousSatisfiedClueIds,
    required Set<String> nextSatisfiedClueIds,
  }) {
    final newlySatisfiedClueIds = <String>[];
    for (final clue in _clues) {
      if (nextSatisfiedClueIds.contains(clue.id) &&
          !previousSatisfiedClueIds.contains(clue.id)) {
        newlySatisfiedClueIds.add(clue.id);
      }
    }
    if (newlySatisfiedClueIds.isEmpty) {
      return;
    }
    _emitFeedbackEvent(
      GameFeedbackEvent(
        type: GameFeedbackEventType.cluesNewlySatisfied,
        clueIds: newlySatisfiedClueIds,
      ),
    );
  }

  void _emitFeedbackEvent(GameFeedbackEvent event) {
    if (_isDisposed || _feedbackEventController.isClosed) {
      return;
    }
    _feedbackEventController.add(event);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _cancelAllGameTimers();
    _highlightedClueId = null;
    _clueHighlightedBookIds = <String>{};
    _feedbackEventController.close();
    super.dispose();
  }
}

List<Clue> _resolveClues({List<Clue>? initialClues, List<Clue>? clues}) {
  if (initialClues != null && clues != null) {
    throw ArgumentError('initialClues와 clues 중 하나만 전달해야 합니다.');
  }
  final resolved = initialClues ?? clues;
  if (resolved == null) {
    throw ArgumentError('initialClues 또는 clues가 필요합니다.');
  }
  return resolved;
}

int _validateLevel(int level) {
  if (level < 1) {
    throw ArgumentError.value(level, 'level', '1 이상이어야 합니다.');
  }
  return level;
}

_BookshelfLayoutInfo _validatePlacementLayout({
  required List<BookPlacement> initialPlacements,
  required GeneratedStage? generatedStage,
}) {
  if (initialPlacements.isEmpty) {
    throw ArgumentError.value(
      initialPlacements,
      'initialPlacements',
      '최소 한 권 이상의 책이 필요합니다.',
    );
  }

  final bookIds = <String>{};
  final positionKeys = <String>{};
  var maxTierIndex = -1;
  var maxSlotIndex = -1;

  for (final placement in initialPlacements) {
    final position = placement.position;
    if (position.tierIndex < 0) {
      throw ArgumentError.value(
        position.tierIndex,
        'tierIndex',
        '0 이상이어야 합니다.',
      );
    }
    if (position.slotIndex < 0) {
      throw ArgumentError.value(
        position.slotIndex,
        'slotIndex',
        '0 이상이어야 합니다.',
      );
    }
    if (!bookIds.add(placement.book.id)) {
      throw ArgumentError.value(
        placement.book.id,
        'initialPlacements',
        'Book.id가 중복되었습니다.',
      );
    }
    final positionKey = '${position.tierIndex}:${position.slotIndex}';
    if (!positionKeys.add(positionKey)) {
      throw ArgumentError.value(
        positionKey,
        'initialPlacements',
        'BookPosition이 중복되었습니다.',
      );
    }
    if (position.tierIndex > maxTierIndex) {
      maxTierIndex = position.tierIndex;
    }
    if (position.slotIndex > maxSlotIndex) {
      maxSlotIndex = position.slotIndex;
    }
  }

  final tierCount = maxTierIndex + 1;
  final booksPerTier = maxSlotIndex + 1;
  if (tierCount < 1 || tierCount > 3) {
    throw ArgumentError.value(tierCount, 'tierCount', '1부터 3 사이여야 합니다.');
  }
  if (booksPerTier < 1 || booksPerTier > 6) {
    throw ArgumentError.value(booksPerTier, 'booksPerTier', '1부터 6 사이여야 합니다.');
  }
  if (initialPlacements.length != tierCount * booksPerTier) {
    throw ArgumentError.value(
      initialPlacements.length,
      'initialPlacements',
      '모든 단은 같은 booksPerTier를 빈 슬롯 없이 채워야 합니다.',
    );
  }

  for (var tierIndex = 0; tierIndex < tierCount; tierIndex += 1) {
    for (var slotIndex = 0; slotIndex < booksPerTier; slotIndex += 1) {
      if (!positionKeys.contains('$tierIndex:$slotIndex')) {
        throw ArgumentError.value(
          '$tierIndex:$slotIndex',
          'initialPlacements',
          '연속된 BookPosition이 누락되었습니다.',
        );
      }
    }
  }

  final stage = generatedStage;
  if (stage != null &&
      (stage.tierCount != tierCount ||
          stage.booksPerTier != booksPerTier ||
          stage.totalBookCount != initialPlacements.length)) {
    throw StateError('GeneratedStage layout does not match initialPlacements.');
  }

  return _BookshelfLayoutInfo(tierCount: tierCount, booksPerTier: booksPerTier);
}

class _BookshelfLayoutInfo {
  const _BookshelfLayoutInfo({
    required this.tierCount,
    required this.booksPerTier,
  });

  final int tierCount;
  final int booksPerTier;
}
