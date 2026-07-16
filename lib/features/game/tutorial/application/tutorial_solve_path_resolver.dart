import '../../domain/book_placement.dart';
import '../../domain/book_position.dart';
import '../../generator/generated_stage.dart';

class TutorialSwapTarget {
  const TutorialSwapTarget({
    required this.firstPosition,
    required this.secondPosition,
    required this.firstBookId,
    required this.secondBookId,
  });

  final BookPosition firstPosition;
  final BookPosition secondPosition;
  final String firstBookId;
  final String secondBookId;
}

class TutorialSolvePathResolver {
  const TutorialSolvePathResolver();

  TutorialSwapTarget? resolveFirstSwap(GeneratedStage stage) {
    if (stage.swapHistory.isEmpty) {
      return null;
    }

    final step = stage.swapHistory.last;
    if (step.firstPosition == step.secondPosition) {
      return null;
    }

    final firstPlacement = _placementAt(stage, step.firstPosition);
    final secondPlacement = _placementAt(stage, step.secondPosition);
    if (firstPlacement == null || secondPlacement == null) {
      return null;
    }

    final firstBook = firstPlacement.book;
    final secondBook = secondPlacement.book;
    if (firstBook.id == secondBook.id) {
      return null;
    }
    if (firstBook.color == secondBook.color &&
        firstBook.symbol == secondBook.symbol) {
      return null;
    }

    return TutorialSwapTarget(
      firstPosition: step.firstPosition,
      secondPosition: step.secondPosition,
      firstBookId: firstBook.id,
      secondBookId: secondBook.id,
    );
  }

  BookPlacement? _placementAt(GeneratedStage stage, BookPosition position) {
    for (final placement in stage.initialPlacements) {
      if (placement.position == position) {
        return placement;
      }
    }
    return null;
  }
}
