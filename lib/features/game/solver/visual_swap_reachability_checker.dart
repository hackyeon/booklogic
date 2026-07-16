import 'dart:collection';

import '../domain/book.dart';
import '../domain/book_placement.dart';
import '../domain/book_position.dart';
import '../domain/clue.dart';
import '../domain/clue_evaluator.dart';
import '../generator/stage_spec.dart';
import 'visual_arrangement_signature.dart';

class VisualSwapReachabilityResult {
  const VisualSwapReachabilityResult({
    required this.foundSolution,
    required this.minimumDepth,
    required this.visitedStateCount,
    required this.reachedStateLimit,
    required this.solutionSignature,
  });

  final bool foundSolution;
  final int? minimumDepth;
  final int visitedStateCount;
  final bool reachedStateLimit;
  final VisualArrangementSignature? solutionSignature;
}

class VisualSwapReachabilityChecker {
  const VisualSwapReachabilityChecker({
    this.clueEvaluator = const ClueEvaluator(),
  });

  final ClueEvaluator clueEvaluator;

  VisualSwapReachabilityResult check({
    required StageSpec stageSpec,
    required List<BookPlacement> initialPlacements,
    required List<Clue> clues,
    required int maximumDepth,
    int maximumVisitedStates = 250000,
  }) {
    if (maximumDepth < 0) {
      throw ArgumentError.value(maximumDepth, 'maximumDepth', '0 이상이어야 합니다.');
    }
    if (maximumVisitedStates < 1) {
      throw ArgumentError.value(
        maximumVisitedStates,
        'maximumVisitedStates',
        '1 이상이어야 합니다.',
      );
    }

    final sortedInitial = _sortedPlacements(initialPlacements);
    final startBooks = [for (final placement in sortedInitial) placement.book];
    final positions = [
      for (final placement in sortedInitial) placement.position,
    ];
    final startSignature = _signatureForBooks(
      stageSpec: stageSpec,
      books: startBooks,
      positions: positions,
    );
    if (_allCluesSatisfied(
      clues: clues,
      placements: _placementsForBooks(books: startBooks, positions: positions),
    )) {
      return VisualSwapReachabilityResult(
        foundSolution: true,
        minimumDepth: 0,
        visitedStateCount: 1,
        reachedStateLimit: false,
        solutionSignature: startSignature,
      );
    }

    final queue = Queue<_ReachabilityNode>()
      ..add(_ReachabilityNode(books: startBooks, depth: 0));
    final visitedKeys = <String>{startSignature.stableKey};
    var visitedStateCount = 1;
    var reachedStateLimit = false;

    while (queue.isNotEmpty) {
      final node = queue.removeFirst();
      if (node.depth >= maximumDepth) {
        continue;
      }

      for (var first = 0; first < node.books.length - 1; first += 1) {
        for (var second = first + 1; second < node.books.length; second += 1) {
          final firstBook = node.books[first];
          final secondBook = node.books[second];
          if (_visualCode(firstBook) == _visualCode(secondBook)) {
            continue;
          }

          final nextBooks = List<Book>.of(node.books);
          nextBooks[first] = secondBook;
          nextBooks[second] = firstBook;
          final signature = _signatureForBooks(
            stageSpec: stageSpec,
            books: nextBooks,
            positions: positions,
          );
          if (!visitedKeys.add(signature.stableKey)) {
            continue;
          }
          visitedStateCount += 1;
          if (visitedStateCount > maximumVisitedStates) {
            reachedStateLimit = true;
            return VisualSwapReachabilityResult(
              foundSolution: false,
              minimumDepth: null,
              visitedStateCount: visitedStateCount,
              reachedStateLimit: reachedStateLimit,
              solutionSignature: null,
            );
          }

          final placements = _placementsForBooks(
            books: nextBooks,
            positions: positions,
          );
          final nextDepth = node.depth + 1;
          if (_allCluesSatisfied(clues: clues, placements: placements)) {
            return VisualSwapReachabilityResult(
              foundSolution: true,
              minimumDepth: nextDepth,
              visitedStateCount: visitedStateCount,
              reachedStateLimit: false,
              solutionSignature: signature,
            );
          }
          queue.add(_ReachabilityNode(books: nextBooks, depth: nextDepth));
        }
      }
    }

    return VisualSwapReachabilityResult(
      foundSolution: false,
      minimumDepth: null,
      visitedStateCount: visitedStateCount,
      reachedStateLimit: reachedStateLimit,
      solutionSignature: null,
    );
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

  VisualArrangementSignature _signatureForBooks({
    required StageSpec stageSpec,
    required List<Book> books,
    required List<BookPosition> positions,
  }) {
    return VisualArrangementSignature.fromPlacements(
      tierCount: stageSpec.tierCount,
      booksPerTier: stageSpec.booksPerTier,
      placements: _placementsForBooks(books: books, positions: positions),
    );
  }

  List<BookPlacement> _placementsForBooks({
    required List<Book> books,
    required List<BookPosition> positions,
  }) {
    return [
      for (var index = 0; index < books.length; index += 1)
        BookPlacement(book: books[index], position: positions[index]),
    ];
  }

  List<BookPlacement> _sortedPlacements(List<BookPlacement> placements) {
    final sorted = List<BookPlacement>.of(placements);
    sorted.sort(_comparePlacementPosition);
    return sorted;
  }

  int _comparePlacementPosition(BookPlacement left, BookPlacement right) {
    final tierComparison = left.position.tierIndex.compareTo(
      right.position.tierIndex,
    );
    if (tierComparison != 0) {
      return tierComparison;
    }
    return left.position.slotIndex.compareTo(right.position.slotIndex);
  }

  String _visualCode(Book book) {
    return VisualArrangementSignature.visualBookCode(book);
  }
}

class _ReachabilityNode {
  const _ReachabilityNode({required this.books, required this.depth});

  final List<Book> books;
  final int depth;
}
