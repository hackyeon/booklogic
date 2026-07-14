import '../domain/book_position.dart';

class BookSwapStep {
  const BookSwapStep({
    required this.stepIndex,
    required this.firstPosition,
    required this.secondPosition,
    required this.firstBookIdBeforeSwap,
    required this.secondBookIdBeforeSwap,
  }) : assert(stepIndex >= 0),
       assert(firstBookIdBeforeSwap.length > 0),
       assert(secondBookIdBeforeSwap.length > 0);

  final int stepIndex;
  final BookPosition firstPosition;
  final BookPosition secondPosition;
  final String firstBookIdBeforeSwap;
  final String secondBookIdBeforeSwap;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BookSwapStep &&
            runtimeType == other.runtimeType &&
            stepIndex == other.stepIndex &&
            firstPosition == other.firstPosition &&
            secondPosition == other.secondPosition &&
            firstBookIdBeforeSwap == other.firstBookIdBeforeSwap &&
            secondBookIdBeforeSwap == other.secondBookIdBeforeSwap;
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      stepIndex,
      firstPosition,
      secondPosition,
      firstBookIdBeforeSwap,
      secondBookIdBeforeSwap,
    );
  }

  @override
  String toString() {
    return 'BookSwapStep('
        'stepIndex: $stepIndex, '
        'firstPosition: $firstPosition, '
        'secondPosition: $secondPosition, '
        'firstBookIdBeforeSwap: $firstBookIdBeforeSwap, '
        'secondBookIdBeforeSwap: $secondBookIdBeforeSwap'
        ')';
  }
}
