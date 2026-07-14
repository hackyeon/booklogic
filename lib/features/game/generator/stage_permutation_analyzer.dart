import '../domain/book_placement.dart';
import '../domain/book_position.dart';
import 'book_swap_step.dart';

class StagePermutationAnalyzer {
  const StagePermutationAnalyzer();

  int minimumSwapDistance({
    required List<BookPlacement> target,
    required List<BookPlacement> current,
  }) {
    final sortedTarget = _sortedPlacements(target);
    final sortedCurrent = _sortedPlacements(current);
    if (sortedTarget.length != sortedCurrent.length) {
      throw ArgumentError('target and current must have the same length.');
    }

    final targetIndexes = <String, int>{};
    for (var index = 0; index < sortedTarget.length; index += 1) {
      final bookId = sortedTarget[index].book.id;
      if (targetIndexes.containsKey(bookId)) {
        throw StateError('target contains duplicate book ids.');
      }
      targetIndexes[bookId] = index;
    }

    final currentIds = <String>{};
    final permutation = <int>[];
    for (final placement in sortedCurrent) {
      final bookId = placement.book.id;
      final targetIndex = targetIndexes[bookId];
      if (targetIndex == null) {
        throw StateError('current contains a book id outside target.');
      }
      if (!currentIds.add(bookId)) {
        throw StateError('current contains duplicate book ids.');
      }
      permutation.add(targetIndex);
    }
    if (currentIds.length != targetIndexes.length) {
      throw StateError('current and target book sets differ.');
    }

    final visited = List<bool>.filled(permutation.length, false);
    var cycleCount = 0;
    for (var index = 0; index < permutation.length; index += 1) {
      if (visited[index]) {
        continue;
      }
      cycleCount += 1;
      var currentIndex = index;
      while (!visited[currentIndex]) {
        visited[currentIndex] = true;
        currentIndex = permutation[currentIndex];
      }
    }
    return permutation.length - cycleCount;
  }

  List<BookPlacement> replayForward({
    required List<BookPlacement> start,
    required List<BookSwapStep> swapHistory,
  }) {
    final steps = List<BookSwapStep>.of(swapHistory)
      ..sort((left, right) => left.stepIndex.compareTo(right.stepIndex));
    return _replay(start: start, steps: steps);
  }

  List<BookPlacement> replayReverse({
    required List<BookPlacement> start,
    required List<BookSwapStep> swapHistory,
  }) {
    final steps = List<BookSwapStep>.of(swapHistory)
      ..sort((left, right) => right.stepIndex.compareTo(left.stepIndex));
    return _replay(start: start, steps: steps);
  }

  bool hasSameBookOrder({
    required List<BookPlacement> first,
    required List<BookPlacement> second,
  }) {
    final sortedFirst = _sortedPlacements(first);
    final sortedSecond = _sortedPlacements(second);
    if (sortedFirst.length != sortedSecond.length) {
      return false;
    }
    for (var index = 0; index < sortedFirst.length; index += 1) {
      if (sortedFirst[index].book.id != sortedSecond[index].book.id) {
        return false;
      }
    }
    return true;
  }

  List<BookPlacement> _replay({
    required List<BookPlacement> start,
    required List<BookSwapStep> steps,
  }) {
    final sortedStart = _sortedPlacements(start);
    final positions = [for (final placement in sortedStart) placement.position];
    final workingBooks = [for (final placement in sortedStart) placement.book];

    for (final step in steps) {
      final firstIndex = _positionIndex(positions, step.firstPosition);
      final secondIndex = _positionIndex(positions, step.secondPosition);
      if (firstIndex == null || secondIndex == null) {
        throw StateError('swap step references a missing position.');
      }
      if (firstIndex == secondIndex) {
        throw StateError('swap step references the same position.');
      }
      final temporary = workingBooks[firstIndex];
      workingBooks[firstIndex] = workingBooks[secondIndex];
      workingBooks[secondIndex] = temporary;
    }

    return [
      for (var index = 0; index < workingBooks.length; index += 1)
        BookPlacement(book: workingBooks[index], position: positions[index]),
    ];
  }

  int? _positionIndex(List<BookPosition> positions, BookPosition position) {
    for (var index = 0; index < positions.length; index += 1) {
      if (positions[index] == position) {
        return index;
      }
    }
    return null;
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
}
