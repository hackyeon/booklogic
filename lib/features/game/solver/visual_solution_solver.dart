import '../domain/book.dart';
import '../domain/book_placement.dart';
import '../domain/book_position.dart';
import '../domain/book_selector.dart';
import '../domain/clue.dart';
import '../domain/clue_evaluator.dart';
import '../generator/stage_spec.dart';
import 'clue_partial_state.dart';
import 'puzzle_solution_analysis.dart';
import 'visual_arrangement_signature.dart';

class VisualSolutionSolver {
  const VisualSolutionSolver({this.clueEvaluator = const ClueEvaluator()});

  static const int defaultMaximumDistinctSolutions = 32;
  static const int defaultMaximumVisitedNodes = 1000000;

  final ClueEvaluator clueEvaluator;

  PuzzleSolutionAnalysis solve({
    required StageSpec stageSpec,
    required List<BookPlacement> bookSet,
    required List<Clue> clues,
    List<BookPlacement>? targetPlacements,
    List<BookPlacement>? initialPlacements,
    int maximumDistinctSolutions = defaultMaximumDistinctSolutions,
    int maximumVisitedNodes = defaultMaximumVisitedNodes,
  }) {
    if (maximumDistinctSolutions < 1) {
      throw ArgumentError.value(
        maximumDistinctSolutions,
        'maximumDistinctSolutions',
        '1 이상이어야 합니다.',
      );
    }
    if (maximumVisitedNodes < 1) {
      throw ArgumentError.value(
        maximumVisitedNodes,
        'maximumVisitedNodes',
        '1 이상이어야 합니다.',
      );
    }
    if (bookSet.length != stageSpec.totalBookCount) {
      throw ArgumentError.value(
        bookSet.length,
        'bookSet',
        'StageSpec totalBookCount와 같아야 합니다.',
      );
    }

    final books = _sortedUniqueBooks(bookSet);
    final positions = _canonicalPositions(stageSpec);
    final unsupportedReason = _unsupportedReason(books: books, clues: clues);

    final targetIsSolution =
        targetPlacements != null &&
        _allCluesSatisfied(clues: clues, placements: targetPlacements);
    final initialIsSolution =
        initialPlacements != null &&
        _allCluesSatisfied(clues: clues, placements: initialPlacements);
    final targetSignature = targetPlacements == null
        ? null
        : VisualArrangementSignature.fromPlacements(
            tierCount: stageSpec.tierCount,
            booksPerTier: stageSpec.booksPerTier,
            placements: targetPlacements,
          );

    if (unsupportedReason != null) {
      return PuzzleSolutionAnalysis(
        targetIsSolution: targetIsSolution,
        initialIsSolution: initialIsSolution,
        distinctVisualSolutionCount: 0,
        isSolutionCountExact: false,
        reachedSolutionLimit: false,
        reachedNodeLimit: false,
        visitedNodeCount: 0,
        sampleSolutions: const [],
        targetSignature: targetSignature,
        unsupportedReason: unsupportedReason,
      );
    }

    final domains = _initialDomains(
      stageSpec: stageSpec,
      books: books,
      positions: positions,
      clues: clues,
    );
    final idReferencedBookIds = _bookIdSelectorIds(clues);
    final solutionsByKey = <String, VisualArrangementSignature>{};
    if (targetIsSolution && targetSignature != null) {
      solutionsByKey[targetSignature.stableKey] = targetSignature;
    }

    var visitedNodeCount = 0;
    var reachedNodeLimit = false;
    var reachedSolutionLimit =
        solutionsByKey.length >= maximumDistinctSolutions;
    final assignedPositionByBookId = <String, BookPosition>{};
    final usedPositionKeys = <String>{};

    void search() {
      if (reachedNodeLimit || reachedSolutionLimit) {
        return;
      }
      visitedNodeCount += 1;
      if (visitedNodeCount > maximumVisitedNodes) {
        reachedNodeLimit = true;
        return;
      }

      if (assignedPositionByBookId.length == books.length) {
        final placements = _placementsFromAssignment(
          books: books,
          assignedPositionByBookId: assignedPositionByBookId,
        );
        if (!_allCluesSatisfied(clues: clues, placements: placements)) {
          return;
        }
        final signature = VisualArrangementSignature.fromPlacements(
          tierCount: stageSpec.tierCount,
          booksPerTier: stageSpec.booksPerTier,
          placements: placements,
        );
        solutionsByKey.putIfAbsent(signature.stableKey, () => signature);
        if (solutionsByKey.length >= maximumDistinctSolutions) {
          reachedSolutionLimit = true;
        }
        return;
      }

      final nextBook = _selectNextBook(
        books: books,
        domains: domains,
        assignedPositionByBookId: assignedPositionByBookId,
        usedPositionKeys: usedPositionKeys,
        idReferencedBookIds: idReferencedBookIds,
      );
      if (nextBook == null) {
        return;
      }

      final domain = domains[nextBook.id] ?? positions;
      for (final position in domain) {
        final positionKey = _positionKey(position);
        if (usedPositionKeys.contains(positionKey)) {
          continue;
        }
        if (!_passesVisualSymmetry(
          book: nextBook,
          position: position,
          books: books,
          assignedPositionByBookId: assignedPositionByBookId,
          positions: positions,
        )) {
          continue;
        }

        assignedPositionByBookId[nextBook.id] = position;
        usedPositionKeys.add(positionKey);
        if (!_hasViolatedClue(
          stageSpec: stageSpec,
          books: books,
          clues: clues,
          assignedPositionByBookId: assignedPositionByBookId,
        )) {
          search();
        }
        assignedPositionByBookId.remove(nextBook.id);
        usedPositionKeys.remove(positionKey);

        if (reachedNodeLimit || reachedSolutionLimit) {
          return;
        }
      }
    }

    search();

    return PuzzleSolutionAnalysis(
      targetIsSolution: targetIsSolution,
      initialIsSolution: initialIsSolution,
      distinctVisualSolutionCount: solutionsByKey.length,
      isSolutionCountExact: !reachedSolutionLimit && !reachedNodeLimit,
      reachedSolutionLimit: reachedSolutionLimit,
      reachedNodeLimit: reachedNodeLimit,
      visitedNodeCount: visitedNodeCount,
      sampleSolutions: solutionsByKey.values.toList(growable: false),
      targetSignature: targetSignature,
      unsupportedReason: null,
    );
  }

  CluePartialState evaluatePartialClue({
    required StageSpec stageSpec,
    required List<BookPlacement> bookSet,
    required Clue clue,
    required Map<String, BookPosition> assignedPositionByBookId,
  }) {
    final books = _sortedUniqueBooks(bookSet);
    return _evaluatePartialClue(
      stageSpec: stageSpec,
      books: books,
      clue: clue,
      assignedPositionByBookId: assignedPositionByBookId,
    );
  }

  List<Book> _sortedUniqueBooks(List<BookPlacement> bookSet) {
    final ids = <String>{};
    final books = <Book>[];
    for (final placement in bookSet) {
      if (!ids.add(placement.book.id)) {
        throw ArgumentError.value(
          placement.book.id,
          'bookSet',
          '중복 Book.id가 있습니다.',
        );
      }
      books.add(placement.book);
    }
    books.sort((left, right) => left.id.compareTo(right.id));
    return books;
  }

  List<BookPosition> _canonicalPositions(StageSpec stageSpec) {
    return [
      for (var tierIndex = 0; tierIndex < stageSpec.tierCount; tierIndex += 1)
        for (
          var slotIndex = 0;
          slotIndex < stageSpec.booksPerTier;
          slotIndex += 1
        )
          BookPosition(tierIndex: tierIndex, slotIndex: slotIndex),
    ];
  }

  Map<String, List<BookPosition>> _initialDomains({
    required StageSpec stageSpec,
    required List<Book> books,
    required List<BookPosition> positions,
    required List<Clue> clues,
  }) {
    final domains = {
      for (final book in books) book.id: List<BookPosition>.of(positions),
    };

    void intersect(Book book, bool Function(BookPosition position) allow) {
      final current = domains[book.id]!;
      domains[book.id] = [
        for (final position in current)
          if (allow(position)) position,
      ];
    }

    for (final clue in clues) {
      switch (clue) {
        case TierAssignmentClue(:final subject, :final tierIndex):
          for (final book in _resolveBooks(subject, books)) {
            intersect(book, (position) => position.tierIndex == tierIndex);
          }
        case EdgePositionClue(:final subject, :final tierIndex, :final edge):
          final selected = _resolveBooks(subject, books);
          if (selected.length == 1) {
            final edgeSlot = _edgeSlot(stageSpec, edge);
            intersect(
              selected.single,
              (position) =>
                  position.tierIndex == tierIndex &&
                  position.slotIndex == edgeSlot,
            );
          }
        case BothEdgesClue(:final subject, :final tierIndex):
          final selected = _resolveBooks(subject, books);
          if (selected.length == 2) {
            final left = 0;
            final right = stageSpec.booksPerTier - 1;
            for (final book in selected) {
              intersect(
                book,
                (position) =>
                    position.tierIndex == tierIndex &&
                    (position.slotIndex == left || position.slotIndex == right),
              );
            }
          }
        case RelativeOrderClue():
        case AdjacentClue():
        case BetweenClue():
        case VerticalRelationClue():
        case NotAtEdgeClue():
        case DistanceClue():
        case SameTierClue():
          break;
      }
    }

    for (final entry in domains.entries) {
      entry.value.sort(_comparePosition);
    }
    return domains;
  }

  Book? _selectNextBook({
    required List<Book> books,
    required Map<String, List<BookPosition>> domains,
    required Map<String, BookPosition> assignedPositionByBookId,
    required Set<String> usedPositionKeys,
    required Set<String> idReferencedBookIds,
  }) {
    Book? best;
    var bestDomainSize = 1 << 30;
    for (final book in books) {
      if (assignedPositionByBookId.containsKey(book.id)) {
        continue;
      }
      final size = (domains[book.id] ?? const <BookPosition>[])
          .where(
            (position) => !usedPositionKeys.contains(_positionKey(position)),
          )
          .length;
      if (best == null ||
          size < bestDomainSize ||
          (size == bestDomainSize &&
              _bookTieBreak(
                    book,
                    best,
                    idReferencedBookIds: idReferencedBookIds,
                  ) <
                  0)) {
        best = book;
        bestDomainSize = size;
      }
    }
    return best;
  }

  int _bookTieBreak(
    Book left,
    Book right, {
    required Set<String> idReferencedBookIds,
  }) {
    final leftReferenced = idReferencedBookIds.contains(left.id);
    final rightReferenced = idReferencedBookIds.contains(right.id);
    if (leftReferenced != rightReferenced) {
      return leftReferenced ? -1 : 1;
    }
    return left.id.compareTo(right.id);
  }

  bool _passesVisualSymmetry({
    required Book book,
    required BookPosition position,
    required List<Book> books,
    required Map<String, BookPosition> assignedPositionByBookId,
    required List<BookPosition> positions,
  }) {
    final visualCode = VisualArrangementSignature.visualBookCode(book);
    final positionIndex = _positionIndex(position, positions);
    for (final other in books) {
      if (other.id == book.id ||
          VisualArrangementSignature.visualBookCode(other) != visualCode) {
        continue;
      }
      final otherPosition = assignedPositionByBookId[other.id];
      if (otherPosition == null) {
        continue;
      }
      final otherIndex = _positionIndex(otherPosition, positions);
      if (other.id.compareTo(book.id) < 0 && otherIndex > positionIndex) {
        return false;
      }
      if (other.id.compareTo(book.id) > 0 && otherIndex < positionIndex) {
        return false;
      }
    }
    return true;
  }

  bool _hasViolatedClue({
    required StageSpec stageSpec,
    required List<Book> books,
    required List<Clue> clues,
    required Map<String, BookPosition> assignedPositionByBookId,
  }) {
    for (final clue in clues) {
      final state = _evaluatePartialClue(
        stageSpec: stageSpec,
        books: books,
        clue: clue,
        assignedPositionByBookId: assignedPositionByBookId,
      );
      if (state == CluePartialState.violated) {
        return true;
      }
    }
    return false;
  }

  CluePartialState _evaluatePartialClue({
    required StageSpec stageSpec,
    required List<Book> books,
    required Clue clue,
    required Map<String, BookPosition> assignedPositionByBookId,
  }) {
    switch (clue) {
      case TierAssignmentClue(:final subject, :final tierIndex):
        final selected = _resolveBooks(subject, books);
        if (selected.isEmpty) {
          return CluePartialState.violated;
        }
        var allAssigned = true;
        for (final book in selected) {
          final position = assignedPositionByBookId[book.id];
          if (position == null) {
            allAssigned = false;
          } else if (position.tierIndex != tierIndex) {
            return CluePartialState.violated;
          }
        }
        return allAssigned
            ? CluePartialState.satisfied
            : CluePartialState.undetermined;
      case SameTierClue(:final first, :final second):
        final firstBooks = _resolveBooks(first, books);
        final secondBooks = _resolveBooks(second, books);
        if (firstBooks.isEmpty || secondBooks.isEmpty) {
          return CluePartialState.violated;
        }
        final firstIds = {for (final book in firstBooks) book.id};
        if (secondBooks.any((book) => firstIds.contains(book.id))) {
          return CluePartialState.violated;
        }
        final tiers = <int>{};
        var allAssigned = true;
        for (final book in [...firstBooks, ...secondBooks]) {
          final position = assignedPositionByBookId[book.id];
          if (position == null) {
            allAssigned = false;
          } else {
            tiers.add(position.tierIndex);
            if (tiers.length > 1) {
              return CluePartialState.violated;
            }
          }
        }
        return allAssigned && tiers.length == 1
            ? CluePartialState.satisfied
            : CluePartialState.undetermined;
      case EdgePositionClue(:final subject, :final tierIndex, :final edge):
        final selected = _resolveBooks(subject, books);
        if (selected.length != 1) {
          return CluePartialState.violated;
        }
        final position = assignedPositionByBookId[selected.single.id];
        if (position == null) {
          return CluePartialState.undetermined;
        }
        final edgeSlot = _edgeSlot(stageSpec, edge);
        if (position.tierIndex != tierIndex || position.slotIndex != edgeSlot) {
          return CluePartialState.violated;
        }
        return CluePartialState.satisfied;
      case BothEdgesClue(:final subject, :final tierIndex):
        final selected = _resolveBooks(subject, books);
        if (selected.length != 2) {
          return CluePartialState.violated;
        }
        final edgeSlots = {0, stageSpec.booksPerTier - 1};
        final assignedSlots = <int>{};
        var allAssigned = true;
        for (final book in selected) {
          final position = assignedPositionByBookId[book.id];
          if (position == null) {
            allAssigned = false;
            continue;
          }
          if (position.tierIndex != tierIndex ||
              !edgeSlots.contains(position.slotIndex)) {
            return CluePartialState.violated;
          }
          assignedSlots.add(position.slotIndex);
        }
        if (!allAssigned) {
          return CluePartialState.undetermined;
        }
        return _setEquals(assignedSlots, edgeSlots)
            ? CluePartialState.satisfied
            : CluePartialState.violated;
      case RelativeOrderClue():
      case AdjacentClue():
      case BetweenClue():
        return _evaluateWhenFullyAssigned(
          stageSpec: stageSpec,
          books: books,
          clue: clue,
          assignedPositionByBookId: assignedPositionByBookId,
        );
      case VerticalRelationClue():
        return _evaluateVerticalRelationPartial(
          stageSpec: stageSpec,
          books: books,
          clue: clue,
          assignedPositionByBookId: assignedPositionByBookId,
        );
      case NotAtEdgeClue():
        return _evaluateNotAtEdgePartial(
          stageSpec: stageSpec,
          books: books,
          clue: clue,
          assignedPositionByBookId: assignedPositionByBookId,
        );
      case DistanceClue():
        return _evaluateDistancePartial(
          stageSpec: stageSpec,
          books: books,
          clue: clue,
          assignedPositionByBookId: assignedPositionByBookId,
        );
    }
  }

  CluePartialState _evaluateVerticalRelationPartial({
    required StageSpec stageSpec,
    required List<Book> books,
    required VerticalRelationClue clue,
    required Map<String, BookPosition> assignedPositionByBookId,
  }) {
    final subject = _resolveBooks(clue.subject, books);
    final reference = _resolveBooks(clue.reference, books);
    if (subject.length != 1 ||
        reference.length != 1 ||
        subject.single.id == reference.single.id) {
      return CluePartialState.violated;
    }
    final subjectPosition = assignedPositionByBookId[subject.single.id];
    final referencePosition = assignedPositionByBookId[reference.single.id];
    if (subjectPosition != null && referencePosition != null) {
      return _verticalRelationSatisfied(
            subject: subjectPosition,
            reference: referencePosition,
            relation: clue.relation,
          )
          ? CluePartialState.satisfied
          : CluePartialState.violated;
    }
    if (subjectPosition != null) {
      final needed = _verticalCounterpart(
        position: subjectPosition,
        relation: clue.relation,
        fromSubject: true,
      );
      return _isAvailableCounterpart(
            stageSpec: stageSpec,
            position: needed,
            assignedPositionByBookId: assignedPositionByBookId,
            allowedBookIds: {subject.single.id, reference.single.id},
          )
          ? CluePartialState.undetermined
          : CluePartialState.violated;
    }
    if (referencePosition != null) {
      final needed = _verticalCounterpart(
        position: referencePosition,
        relation: clue.relation,
        fromSubject: false,
      );
      return _isAvailableCounterpart(
            stageSpec: stageSpec,
            position: needed,
            assignedPositionByBookId: assignedPositionByBookId,
            allowedBookIds: {subject.single.id, reference.single.id},
          )
          ? CluePartialState.undetermined
          : CluePartialState.violated;
    }
    final usedKeys = assignedPositionByBookId.values.map(_positionKey).toSet();
    for (var tierIndex = 0; tierIndex < stageSpec.tierCount; tierIndex += 1) {
      for (
        var slotIndex = 0;
        slotIndex < stageSpec.booksPerTier;
        slotIndex += 1
      ) {
        final subjectCandidate = BookPosition(
          tierIndex: tierIndex,
          slotIndex: slotIndex,
        );
        final referenceCandidate = _verticalCounterpart(
          position: subjectCandidate,
          relation: clue.relation,
          fromSubject: true,
        );
        if (_positionInBounds(stageSpec, subjectCandidate) &&
            referenceCandidate != null &&
            _positionInBounds(stageSpec, referenceCandidate) &&
            !usedKeys.contains(_positionKey(subjectCandidate)) &&
            !usedKeys.contains(_positionKey(referenceCandidate))) {
          return CluePartialState.undetermined;
        }
      }
    }
    return CluePartialState.violated;
  }

  CluePartialState _evaluateNotAtEdgePartial({
    required StageSpec stageSpec,
    required List<Book> books,
    required NotAtEdgeClue clue,
    required Map<String, BookPosition> assignedPositionByBookId,
  }) {
    if (clue.tierIndex < 0 || clue.tierIndex >= stageSpec.tierCount) {
      return CluePartialState.violated;
    }
    final selected = _resolveBooks(clue.subject, books);
    if (selected.isEmpty) {
      return CluePartialState.violated;
    }
    var unassignedCount = 0;
    for (final book in selected) {
      final position = assignedPositionByBookId[book.id];
      if (position == null) {
        unassignedCount += 1;
        continue;
      }
      if (!_isInteriorInTier(stageSpec, position, clue.tierIndex)) {
        return CluePartialState.violated;
      }
    }
    if (unassignedCount == 0) {
      return CluePartialState.satisfied;
    }
    final available = _availableInteriorPositions(
      stageSpec: stageSpec,
      tierIndex: clue.tierIndex,
      assignedPositionByBookId: assignedPositionByBookId,
    );
    return available.length >= unassignedCount
        ? CluePartialState.undetermined
        : CluePartialState.violated;
  }

  CluePartialState _evaluateDistancePartial({
    required StageSpec stageSpec,
    required List<Book> books,
    required DistanceClue clue,
    required Map<String, BookPosition> assignedPositionByBookId,
  }) {
    if (clue.booksBetween < 1 ||
        clue.tierIndex < 0 ||
        clue.tierIndex >= stageSpec.tierCount) {
      return CluePartialState.violated;
    }
    final first = _resolveBooks(clue.first, books);
    final second = _resolveBooks(clue.second, books);
    if (first.length != 1 ||
        second.length != 1 ||
        first.single.id == second.single.id) {
      return CluePartialState.violated;
    }
    final firstPosition = assignedPositionByBookId[first.single.id];
    final secondPosition = assignedPositionByBookId[second.single.id];
    if (firstPosition != null && secondPosition != null) {
      return _distanceSatisfied(
            first: firstPosition,
            second: secondPosition,
            tierIndex: clue.tierIndex,
            booksBetween: clue.booksBetween,
          )
          ? CluePartialState.satisfied
          : CluePartialState.violated;
    }
    if (firstPosition != null) {
      return _hasDistanceCounterpart(
            stageSpec: stageSpec,
            fixed: firstPosition,
            tierIndex: clue.tierIndex,
            booksBetween: clue.booksBetween,
            assignedPositionByBookId: assignedPositionByBookId,
            allowedBookIds: {first.single.id, second.single.id},
          )
          ? CluePartialState.undetermined
          : CluePartialState.violated;
    }
    if (secondPosition != null) {
      return _hasDistanceCounterpart(
            stageSpec: stageSpec,
            fixed: secondPosition,
            tierIndex: clue.tierIndex,
            booksBetween: clue.booksBetween,
            assignedPositionByBookId: assignedPositionByBookId,
            allowedBookIds: {first.single.id, second.single.id},
          )
          ? CluePartialState.undetermined
          : CluePartialState.violated;
    }
    final usedKeys = assignedPositionByBookId.values.map(_positionKey).toSet();
    final gap = clue.booksBetween + 1;
    for (
      var slotIndex = 0;
      slotIndex + gap < stageSpec.booksPerTier;
      slotIndex += 1
    ) {
      final left = BookPosition(
        tierIndex: clue.tierIndex,
        slotIndex: slotIndex,
      );
      final right = BookPosition(
        tierIndex: clue.tierIndex,
        slotIndex: slotIndex + gap,
      );
      if (!usedKeys.contains(_positionKey(left)) &&
          !usedKeys.contains(_positionKey(right))) {
        return CluePartialState.undetermined;
      }
    }
    return CluePartialState.violated;
  }

  CluePartialState _evaluateWhenFullyAssigned({
    required StageSpec stageSpec,
    required List<Book> books,
    required Clue clue,
    required Map<String, BookPosition> assignedPositionByBookId,
  }) {
    final selectedBooks = <Book>[];
    for (final selector in _selectorsFor(clue)) {
      final resolved = _resolveBooks(selector, books);
      if (resolved.isEmpty) {
        return CluePartialState.violated;
      }
      selectedBooks.addAll(resolved);
    }
    final uniqueBooks = <String, Book>{};
    for (final book in selectedBooks) {
      uniqueBooks[book.id] = book;
    }
    for (final book in uniqueBooks.values) {
      final position = assignedPositionByBookId[book.id];
      if (position == null) {
        return CluePartialState.undetermined;
      }
      if (_clueHasTier(clue) && position.tierIndex != _clueTierIndex(clue)) {
        return CluePartialState.violated;
      }
    }

    final placements = [
      for (final book in uniqueBooks.values)
        BookPlacement(book: book, position: assignedPositionByBookId[book.id]!),
    ];
    return clueEvaluator.evaluate(clue: clue, placements: placements)
        ? CluePartialState.satisfied
        : CluePartialState.violated;
  }

  List<BookPlacement> _placementsFromAssignment({
    required List<Book> books,
    required Map<String, BookPosition> assignedPositionByBookId,
  }) {
    return [
      for (final book in books)
        BookPlacement(book: book, position: assignedPositionByBookId[book.id]!),
    ];
  }

  bool _allCluesSatisfied({
    required List<Clue> clues,
    required List<BookPlacement> placements,
  }) {
    final satisfied = clueEvaluator.evaluateAll(
      clues: clues,
      placements: placements,
    );
    return satisfied.length == clues.length &&
        clues.every((clue) => satisfied.contains(clue.id));
  }

  String? _unsupportedReason({
    required List<Book> books,
    required List<Clue> clues,
  }) {
    final visualCounts = <String, int>{};
    final booksById = <String, Book>{};
    for (final book in books) {
      booksById[book.id] = book;
      visualCounts.update(
        VisualArrangementSignature.visualBookCode(book),
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    for (final id in _bookIdSelectorIds(clues)) {
      final book = booksById[id];
      if (book == null) {
        continue;
      }
      if ((visualCounts[VisualArrangementSignature.visualBookCode(book)] ?? 0) >
          1) {
        return 'unsupported_duplicate_id_selector';
      }
    }
    return null;
  }

  Set<String> _bookIdSelectorIds(List<Clue> clues) {
    return {
      for (final clue in clues)
        for (final selector in _selectorsFor(clue))
          if (selector is BookIdSelector) selector.bookId,
    };
  }

  List<BookSelector> _selectorsFor(Clue clue) {
    return switch (clue) {
      EdgePositionClue(:final subject) => [subject],
      BothEdgesClue(:final subject) => [subject],
      RelativeOrderClue(:final subject, :final reference) => [
        subject,
        reference,
      ],
      BetweenClue(:final subject, :final boundary) => [subject, boundary],
      TierAssignmentClue(:final subject) => [subject],
      SameTierClue(:final first, :final second) => [first, second],
      AdjacentClue(:final subject, :final reference) => [subject, reference],
      VerticalRelationClue(:final subject, :final reference) => [
        subject,
        reference,
      ],
      NotAtEdgeClue(:final subject) => [subject],
      DistanceClue(:final first, :final second) => [first, second],
    };
  }

  List<Book> _resolveBooks(BookSelector selector, List<Book> books) {
    final resolved = switch (selector) {
      BookIdSelector(:final bookId) =>
        books.where((book) => book.id == bookId).toList(),
      BookColorSelector(:final color) =>
        books.where((book) => book.color == color).toList(),
      BookSymbolSelector(:final symbol) =>
        books.where((book) => book.symbol == symbol).toList(),
      BookVisualSelector(:final color, :final symbol) =>
        books
            .where((book) => book.color == color && book.symbol == symbol)
            .toList(),
    };
    resolved.sort((left, right) => left.id.compareTo(right.id));
    return resolved;
  }

  bool _clueHasTier(Clue clue) {
    return switch (clue) {
      EdgePositionClue() ||
      BothEdgesClue() ||
      RelativeOrderClue() ||
      BetweenClue() ||
      TierAssignmentClue() ||
      AdjacentClue() ||
      NotAtEdgeClue() ||
      DistanceClue() => true,
      VerticalRelationClue() => false,
      SameTierClue() => false,
    };
  }

  int _clueTierIndex(Clue clue) {
    return switch (clue) {
      EdgePositionClue(:final tierIndex) => tierIndex,
      BothEdgesClue(:final tierIndex) => tierIndex,
      RelativeOrderClue(:final tierIndex) => tierIndex,
      BetweenClue(:final tierIndex) => tierIndex,
      TierAssignmentClue(:final tierIndex) => tierIndex,
      AdjacentClue(:final tierIndex) => tierIndex,
      NotAtEdgeClue(:final tierIndex) => tierIndex,
      DistanceClue(:final tierIndex) => tierIndex,
      VerticalRelationClue() => throw StateError(
        'VerticalRelationClue has no tierIndex.',
      ),
      SameTierClue() => throw StateError('SameTierClue has no tierIndex.'),
    };
  }

  bool _verticalRelationSatisfied({
    required BookPosition subject,
    required BookPosition reference,
    required VerticalRelation relation,
  }) {
    if (subject.slotIndex != reference.slotIndex) {
      return false;
    }
    return switch (relation) {
      VerticalRelation.immediatelyAbove =>
        subject.tierIndex + 1 == reference.tierIndex,
      VerticalRelation.immediatelyBelow =>
        subject.tierIndex == reference.tierIndex + 1,
    };
  }

  BookPosition? _verticalCounterpart({
    required BookPosition position,
    required VerticalRelation relation,
    required bool fromSubject,
  }) {
    final delta = switch ((relation, fromSubject)) {
      (VerticalRelation.immediatelyAbove, true) => 1,
      (VerticalRelation.immediatelyAbove, false) => -1,
      (VerticalRelation.immediatelyBelow, true) => -1,
      (VerticalRelation.immediatelyBelow, false) => 1,
    };
    final tierIndex = position.tierIndex + delta;
    if (tierIndex < 0) {
      return null;
    }
    return BookPosition(tierIndex: tierIndex, slotIndex: position.slotIndex);
  }

  bool _distanceSatisfied({
    required BookPosition first,
    required BookPosition second,
    required int tierIndex,
    required int booksBetween,
  }) {
    return first.tierIndex == tierIndex &&
        second.tierIndex == tierIndex &&
        (first.slotIndex - second.slotIndex).abs() - 1 == booksBetween;
  }

  bool _hasDistanceCounterpart({
    required StageSpec stageSpec,
    required BookPosition fixed,
    required int tierIndex,
    required int booksBetween,
    required Map<String, BookPosition> assignedPositionByBookId,
    required Set<String> allowedBookIds,
  }) {
    if (fixed.tierIndex != tierIndex) {
      return false;
    }
    final gap = booksBetween + 1;
    for (final slotIndex in [fixed.slotIndex - gap, fixed.slotIndex + gap]) {
      if (slotIndex < 0 || slotIndex >= stageSpec.booksPerTier) {
        continue;
      }
      final counterpart = BookPosition(
        tierIndex: tierIndex,
        slotIndex: slotIndex,
      );
      if (_isAvailableCounterpart(
        stageSpec: stageSpec,
        position: counterpart,
        assignedPositionByBookId: assignedPositionByBookId,
        allowedBookIds: allowedBookIds,
      )) {
        return true;
      }
    }
    return false;
  }

  bool _isAvailableCounterpart({
    required StageSpec stageSpec,
    required BookPosition? position,
    required Map<String, BookPosition> assignedPositionByBookId,
    required Set<String> allowedBookIds,
  }) {
    if (position == null) {
      return false;
    }
    if (!_positionInBounds(stageSpec, position)) {
      return false;
    }
    for (final entry in assignedPositionByBookId.entries) {
      if (entry.value == position && !allowedBookIds.contains(entry.key)) {
        return false;
      }
    }
    return true;
  }

  List<BookPosition> _availableInteriorPositions({
    required StageSpec stageSpec,
    required int tierIndex,
    required Map<String, BookPosition> assignedPositionByBookId,
  }) {
    final usedKeys = assignedPositionByBookId.values.map(_positionKey).toSet();
    return [
      for (
        var slotIndex = 1;
        slotIndex < stageSpec.booksPerTier - 1;
        slotIndex += 1
      )
        BookPosition(tierIndex: tierIndex, slotIndex: slotIndex),
    ].where((position) => !usedKeys.contains(_positionKey(position))).toList();
  }

  bool _isInteriorInTier(
    StageSpec stageSpec,
    BookPosition position,
    int tierIndex,
  ) {
    return position.tierIndex == tierIndex &&
        position.slotIndex > 0 &&
        position.slotIndex < stageSpec.booksPerTier - 1;
  }

  bool _positionInBounds(StageSpec stageSpec, BookPosition position) {
    return position.tierIndex >= 0 &&
        position.tierIndex < stageSpec.tierCount &&
        position.slotIndex >= 0 &&
        position.slotIndex < stageSpec.booksPerTier;
  }

  int _edgeSlot(StageSpec spec, ShelfEdge edge) {
    return switch (edge) {
      ShelfEdge.left => 0,
      ShelfEdge.right => spec.booksPerTier - 1,
    };
  }

  int _positionIndex(BookPosition position, List<BookPosition> positions) {
    for (var index = 0; index < positions.length; index += 1) {
      if (positions[index] == position) {
        return index;
      }
    }
    throw StateError('Missing canonical position.');
  }

  int _comparePosition(BookPosition left, BookPosition right) {
    final tierComparison = left.tierIndex.compareTo(right.tierIndex);
    if (tierComparison != 0) {
      return tierComparison;
    }
    return left.slotIndex.compareTo(right.slotIndex);
  }

  String _positionKey(BookPosition position) {
    return '${position.tierIndex}:${position.slotIndex}';
  }

  bool _setEquals(Set<int> left, Set<int> right) {
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
}
