import '../../solver/puzzle_solution_analysis.dart';
import '../../solver/visual_swap_reachability_checker.dart';

class PuzzleQualityAnalysis {
  PuzzleQualityAnalysis({
    required this.solutionAnalysis,
    required this.easySolutionCheck,
    required this.totalClueCount,
    required this.initialSatisfiedClueCount,
    required this.initialUnsatisfiedClueCount,
    required this.targetSwapCount,
    required this.minimumSwapDistanceToTarget,
    required this.generationAttempt,
    required this.isFallback,
    required List<String> hardFailureReasons,
  }) : hardFailureReasons = List<String>.unmodifiable(hardFailureReasons);

  final PuzzleSolutionAnalysis solutionAnalysis;
  final VisualSwapReachabilityResult easySolutionCheck;
  final int totalClueCount;
  final int initialSatisfiedClueCount;
  final int initialUnsatisfiedClueCount;
  final int targetSwapCount;
  final int minimumSwapDistanceToTarget;
  final int generationAttempt;
  final bool isFallback;
  final List<String> hardFailureReasons;

  bool get passesHardRequirements => hardFailureReasons.isEmpty;

  bool get hasUniqueVisualSolution {
    return solutionAnalysis.isSolutionCountExact &&
        solutionAnalysis.distinctVisualSolutionCount == 1;
  }

  bool get hasMultipleVisualSolutions {
    return solutionAnalysis.distinctVisualSolutionCount > 1;
  }

  bool get isHighlyAmbiguous {
    return !solutionAnalysis.isSolutionCountExact ||
        solutionAnalysis.reachedSolutionLimit;
  }
}
