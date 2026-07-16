import '../../domain/clue_evaluator.dart';
import '../../solver/puzzle_solution_analysis.dart';
import '../../solver/visual_solution_solver.dart';
import '../../solver/visual_swap_reachability_checker.dart';
import '../generated_stage.dart';
import '../generated_stage_validator.dart';
import '../puzzle_template_id.dart';
import '../stage_permutation_analyzer.dart';
import 'puzzle_quality_analysis.dart';

abstract final class PuzzleQualityPolicy {
  static int minimumUnsatisfiedClues(PuzzleTemplateId templateId) {
    return switch (templateId) {
      PuzzleTemplateId.t01AnchorChain => 1,
      PuzzleTemplateId.t02EdgeSandwich => 2,
      PuzzleTemplateId.t03AdjacentBlocks => 2,
      PuzzleTemplateId.t04TierGrouping => 2,
      PuzzleTemplateId.t05TierOrder => 3,
      PuzzleTemplateId.t06VerticalPair => 3,
    };
  }

  static int easySolutionMaximumDepth(int targetSwapCount) {
    if (targetSwapCount <= 1) {
      return 0;
    }
    if (targetSwapCount == 2) {
      return 1;
    }
    return 2;
  }
}

class PuzzleQualityAnalyzer {
  const PuzzleQualityAnalyzer({
    this.solutionSolver = const VisualSolutionSolver(),
    this.reachabilityChecker = const VisualSwapReachabilityChecker(),
    this.permutationAnalyzer = const StagePermutationAnalyzer(),
    this.stageValidator = const GeneratedStageValidator(),
    this.clueEvaluator = const ClueEvaluator(),
    this.maximumDistinctSolutions =
        VisualSolutionSolver.defaultMaximumDistinctSolutions,
    this.maximumVisitedNodes = VisualSolutionSolver.defaultMaximumVisitedNodes,
    this.maximumReachabilityVisitedStates = 250000,
  });

  final VisualSolutionSolver solutionSolver;
  final VisualSwapReachabilityChecker reachabilityChecker;
  final StagePermutationAnalyzer permutationAnalyzer;
  final GeneratedStageValidator stageValidator;
  final ClueEvaluator clueEvaluator;
  final int maximumDistinctSolutions;
  final int maximumVisitedNodes;
  final int maximumReachabilityVisitedStates;

  PuzzleQualityAnalysis analyze(GeneratedStage stage) {
    final hardFailures = <String>[];
    final validation = stageValidator.validate(stage);
    if (validation.isInvalid) {
      hardFailures.add('stage_validation_failed');
    }

    final targetSatisfiedIds = clueEvaluator.evaluateAll(
      clues: stage.clues,
      placements: stage.targetPlacements,
    );
    final initialSatisfiedIds = clueEvaluator.evaluateAll(
      clues: stage.clues,
      placements: stage.initialPlacements,
    );
    final targetIsSolution = targetSatisfiedIds.length == stage.clues.length;
    final initialIsSolution = initialSatisfiedIds.length == stage.clues.length;
    final initialSatisfiedClueCount = initialSatisfiedIds.length;
    final initialUnsatisfiedClueCount =
        stage.clues.length - initialSatisfiedClueCount;

    if (!targetIsSolution) {
      hardFailures.add('target_is_not_solution');
    }
    if (initialIsSolution) {
      hardFailures.add('initial_is_already_solution');
    }

    var minimumSwapDistanceToTarget = -1;
    try {
      minimumSwapDistanceToTarget = permutationAnalyzer
          .minimumVisualSwapDistance(
            target: stage.targetPlacements,
            current: stage.initialPlacements,
          );
      if (minimumSwapDistanceToTarget != stage.targetSwapCount) {
        hardFailures.add('target_swap_distance_mismatch');
      }
    } on StateError {
      hardFailures.add('target_swap_distance_mismatch');
    } on ArgumentError {
      hardFailures.add('target_swap_distance_mismatch');
    }

    PuzzleSolutionAnalysis solutionAnalysis;
    try {
      solutionAnalysis = solutionSolver.solve(
        stageSpec: stage.stageSpec,
        bookSet: stage.targetPlacements,
        clues: stage.clues,
        targetPlacements: stage.targetPlacements,
        initialPlacements: stage.initialPlacements,
        maximumDistinctSolutions: maximumDistinctSolutions,
        maximumVisitedNodes: maximumVisitedNodes,
      );
    } on ArgumentError {
      solutionAnalysis = _failedSolutionAnalysis(
        targetIsSolution: targetIsSolution,
        initialIsSolution: initialIsSolution,
        unsupportedReason: 'solver_argument_error',
      );
    } on StateError {
      solutionAnalysis = _failedSolutionAnalysis(
        targetIsSolution: targetIsSolution,
        initialIsSolution: initialIsSolution,
        unsupportedReason: 'solver_state_error',
      );
    } on FormatException {
      solutionAnalysis = _failedSolutionAnalysis(
        targetIsSolution: targetIsSolution,
        initialIsSolution: initialIsSolution,
        unsupportedReason: 'solver_format_error',
      );
    }

    final unsupportedReason = solutionAnalysis.unsupportedReason;
    if (unsupportedReason != null) {
      hardFailures.add(unsupportedReason);
    }
    if (solutionAnalysis.distinctVisualSolutionCount < 1) {
      hardFailures.add('no_visual_solution');
    }
    if (solutionAnalysis.reachedNodeLimit) {
      hardFailures.add('solver_node_limit_reached');
    }
    if (!solutionAnalysis.targetSignatureFound) {
      hardFailures.add('target_solution_not_found');
    }

    final easyDepth = PuzzleQualityPolicy.easySolutionMaximumDepth(
      stage.targetSwapCount,
    );
    VisualSwapReachabilityResult easySolutionCheck;
    try {
      easySolutionCheck = reachabilityChecker.check(
        stageSpec: stage.stageSpec,
        initialPlacements: stage.initialPlacements,
        clues: stage.clues,
        maximumDepth: easyDepth,
        maximumVisitedStates: maximumReachabilityVisitedStates,
      );
    } on ArgumentError {
      easySolutionCheck = const VisualSwapReachabilityResult(
        foundSolution: false,
        minimumDepth: null,
        visitedStateCount: 0,
        reachedStateLimit: true,
        solutionSignature: null,
      );
    } on StateError {
      easySolutionCheck = const VisualSwapReachabilityResult(
        foundSolution: false,
        minimumDepth: null,
        visitedStateCount: 0,
        reachedStateLimit: true,
        solutionSignature: null,
      );
    }
    if (easySolutionCheck.reachedStateLimit) {
      hardFailures.add('reachability_state_limit_reached');
    }

    final minimumUnsatisfied = PuzzleQualityPolicy.minimumUnsatisfiedClues(
      stage.templateId,
    );
    if (initialUnsatisfiedClueCount < minimumUnsatisfied) {
      hardFailures.add('too_few_unsatisfied_clues');
    }

    return PuzzleQualityAnalysis(
      solutionAnalysis: solutionAnalysis,
      easySolutionCheck: easySolutionCheck,
      totalClueCount: stage.clues.length,
      initialSatisfiedClueCount: initialSatisfiedClueCount,
      initialUnsatisfiedClueCount: initialUnsatisfiedClueCount,
      targetSwapCount: stage.targetSwapCount,
      minimumSwapDistanceToTarget: minimumSwapDistanceToTarget,
      generationAttempt: stage.generationAttempt,
      isFallback: stage.isFallback,
      hardFailureReasons: _uniqueInOrder(hardFailures),
    );
  }

  PuzzleSolutionAnalysis _failedSolutionAnalysis({
    required bool targetIsSolution,
    required bool initialIsSolution,
    required String unsupportedReason,
  }) {
    return PuzzleSolutionAnalysis(
      targetIsSolution: targetIsSolution,
      initialIsSolution: initialIsSolution,
      distinctVisualSolutionCount: 0,
      isSolutionCountExact: false,
      reachedSolutionLimit: false,
      reachedNodeLimit: false,
      visitedNodeCount: 0,
      sampleSolutions: const [],
      targetSignature: null,
      unsupportedReason: unsupportedReason,
    );
  }

  List<String> _uniqueInOrder(List<String> values) {
    final seen = <String>{};
    return [
      for (final value in values)
        if (seen.add(value)) value,
    ];
  }
}
