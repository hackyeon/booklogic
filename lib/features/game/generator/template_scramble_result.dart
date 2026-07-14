import '../domain/book_placement.dart';
import 'book_swap_step.dart';
import 'template_solution.dart';

class TemplateScrambleResult {
  TemplateScrambleResult({
    required this.solution,
    required this.scrambleSeed,
    required List<BookPlacement> initialPlacements,
    required List<BookSwapStep> swapHistory,
  }) : initialPlacements = List<BookPlacement>.unmodifiable(initialPlacements),
       swapHistory = List<BookSwapStep>.unmodifiable(swapHistory);

  final TemplateSolution solution;
  final int scrambleSeed;
  final List<BookPlacement> initialPlacements;
  final List<BookSwapStep> swapHistory;

  List<BookPlacement> get targetPlacements => solution.targetPlacements;

  int get level => solution.stageSpec.level;

  int get targetSwapCount => solution.stageSpec.targetSwapCount;

  int get totalBookCount => initialPlacements.length;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TemplateScrambleResult &&
            runtimeType == other.runtimeType &&
            solution == other.solution &&
            scrambleSeed == other.scrambleSeed &&
            _placementListEquals(other.initialPlacements, initialPlacements) &&
            _listEquals(other.swapHistory, swapHistory);
  }

  @override
  int get hashCode {
    var result = Object.hash(runtimeType, solution, scrambleSeed);
    for (final placement in initialPlacements) {
      result = _combineHash(result, placement.book.hashCode);
      result = _combineHash(result, placement.position.hashCode);
    }
    for (final step in swapHistory) {
      result = _combineHash(result, step.hashCode);
    }
    return result;
  }

  @override
  String toString() {
    return 'TemplateScrambleResult('
        'level: $level, '
        'scrambleSeed: $scrambleSeed, '
        'totalBookCount: $totalBookCount, '
        'targetSwapCount: $targetSwapCount, '
        'swapHistoryLength: ${swapHistory.length}'
        ')';
  }
}

bool _placementListEquals(List<BookPlacement> left, List<BookPlacement> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    final leftPlacement = left[index];
    final rightPlacement = right[index];
    if (leftPlacement.book != rightPlacement.book ||
        leftPlacement.position != rightPlacement.position) {
      return false;
    }
  }
  return true;
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

int _combineHash(int current, int value) {
  return ((current * 31) + value) & 0x1FFFFFFF;
}
