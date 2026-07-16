import 'dart:convert';
import 'dart:io';

import 'package:booklogic/features/game/generator/generator_config.dart';
import 'package:booklogic/features/game/generator/quality/generation_candidate_quality.dart';
import 'package:booklogic/features/game/generator/quality/generation_candidate_ranker.dart';
import 'package:booklogic/features/game/generator/quality/puzzle_quality_analyzer.dart';
import 'package:booklogic/features/game/generator/quality/template_code.dart';
import 'package:booklogic/features/game/generator/stage_candidate_builder_router.dart';
import 'package:booklogic/features/game/generator/stage_spec_factory.dart';

void main() {
  const minimumLevel = 201;
  const maximumLevel = 400;
  const generatorVersion = GeneratorConfig.generatorVersion2;
  const maxAttempts = 8;
  const specFactory = StageSpecFactory();
  const router = StageCandidateBuilderRouter();
  const analyzer = PuzzleQualityAnalyzer(
    maximumVisitedNodes: 2000000,
    maximumReachabilityVisitedStates: 500000,
  );
  const ranker = GenerationCandidateRanker();

  final levelReports = <Map<String, Object?>>[];
  final preferredAttemptByLevel = <int, int>{};
  final templateCodeByLevel = <int, String>{};
  final visualSolutionCountByLevel = <int, int>{};
  final inexactLevels = <int>{};
  final initialSatisfiedByLevel = <int, int>{};
  final initialUnsatisfiedByLevel = <int, int>{};
  final targetSwapCountByLevel = <int, int>{};
  final solverVisitedNodesByLevel = <int, int>{};
  final easyDepthByLevel = <int, int>{};
  final changedLevels = <Map<String, Object?>>[];
  final attemptSelectionCounts = {
    for (var attempt = 0; attempt < maxAttempts; attempt += 1) attempt: 0,
  };
  var fallbackPassCount = 0;

  for (var level = minimumLevel; level <= maximumLevel; level += 1) {
    final stageSpec = specFactory.create(
      level: level,
      generatorVersion: generatorVersion,
    );
    final candidates = <GenerationCandidateQuality>[];
    final attemptReports = <Map<String, Object?>>[];

    for (var attempt = 0; attempt < maxAttempts; attempt += 1) {
      try {
        final stage = router.buildAttempt(
          stageSpec: stageSpec,
          generationAttempt: attempt,
        );
        final analysis = analyzer.analyze(stage);
        final candidate = GenerationCandidateQuality(
          stage: stage,
          analysis: analysis,
        );
        candidates.add(candidate);
        attemptReports.add(_candidateReport(candidate));
      } on StateError catch (error) {
        attemptReports.add(_failedAttemptReport(attempt, error));
      } on ArgumentError catch (error) {
        attemptReports.add(_failedAttemptReport(attempt, error));
      }
    }

    final hardPassCandidates = [
      for (final candidate in candidates)
        if (candidate.passesHardRequirements) candidate,
    ];

    if (hardPassCandidates.isEmpty) {
      final fallbackStage = router.buildFallback(stageSpec: stageSpec);
      final fallbackAnalysis = analyzer.analyze(fallbackStage);
      final fallbackCandidate = GenerationCandidateQuality(
        stage: fallbackStage,
        analysis: fallbackAnalysis,
      );
      if (fallbackCandidate.passesHardRequirements) {
        fallbackPassCount += 1;
      }
      stderr.writeln('No hard-pass attempt for level $level');
      stderr.writeln(jsonEncode(_candidateReport(fallbackCandidate)));
      exitCode = 1;
      return;
    }

    final selected = ranker.best(hardPassCandidates);
    final selectedAnalysis = selected.analysis;
    preferredAttemptByLevel[level] = selected.generationAttempt;
    templateCodeByLevel[level] = templateCode(selected.templateId);
    visualSolutionCountByLevel[level] =
        selectedAnalysis.solutionAnalysis.distinctVisualSolutionCount;
    if (!selectedAnalysis.solutionAnalysis.isSolutionCountExact) {
      inexactLevels.add(level);
    }
    initialSatisfiedByLevel[level] = selectedAnalysis.initialSatisfiedClueCount;
    initialUnsatisfiedByLevel[level] =
        selectedAnalysis.initialUnsatisfiedClueCount;
    targetSwapCountByLevel[level] = selectedAnalysis.targetSwapCount;
    solverVisitedNodesByLevel[level] =
        selectedAnalysis.solutionAnalysis.visitedNodeCount;
    easyDepthByLevel[level] = PuzzleQualityPolicy.easySolutionMaximumDepth(
      selected.stage.targetSwapCount,
    );
    attemptSelectionCounts[selected.generationAttempt] =
        (attemptSelectionCounts[selected.generationAttempt] ?? 0) + 1;

    final attemptZero = candidates
        .where((candidate) => candidate.generationAttempt == 0)
        .cast<GenerationCandidateQuality?>()
        .firstWhere((candidate) => candidate != null, orElse: () => null);
    if (selected.generationAttempt != 0) {
      changedLevels.add({
        'level': level,
        'templateId': templateCode(selected.templateId),
        'previousAttempt': 0,
        'preferredAttempt': selected.generationAttempt,
        'attempt0SolutionCount':
            attemptZero?.analysis.solutionAnalysis.distinctVisualSolutionCount,
        'preferredSolutionCount':
            selectedAnalysis.solutionAnalysis.distinctVisualSolutionCount,
        'attempt0UnsatisfiedClueCount':
            attemptZero?.analysis.initialUnsatisfiedClueCount,
        'preferredUnsatisfiedClueCount':
            selectedAnalysis.initialUnsatisfiedClueCount,
        'reason': _selectionReason(attemptZero, selected),
      });
    }

    levelReports.add({
      'level': level,
      'templateId': templateCode(selected.templateId),
      'preferredAttempt': selected.generationAttempt,
      'distinctVisualSolutionCount':
          selectedAnalysis.solutionAnalysis.distinctVisualSolutionCount,
      'solutionCountExact':
          selectedAnalysis.solutionAnalysis.isSolutionCountExact,
      'initialSatisfiedClueCount': selectedAnalysis.initialSatisfiedClueCount,
      'initialUnsatisfiedClueCount':
          selectedAnalysis.initialUnsatisfiedClueCount,
      'targetSwapCount': selectedAnalysis.targetSwapCount,
      'solverVisitedNodes': selectedAnalysis.solutionAnalysis.visitedNodeCount,
      'easySolutionMaximumDepth': PuzzleQualityPolicy.easySolutionMaximumDepth(
        selected.stage.targetSwapCount,
      ),
      'hardFailureReasons': selectedAnalysis.hardFailureReasons,
      'attempts': attemptReports,
    });
  }

  final checksum = manifestChecksum(
    preferredAttemptByLevel: preferredAttemptByLevel,
    templateCodeByLevel: templateCodeByLevel,
    visualSolutionCountByLevel: visualSolutionCountByLevel,
    inexactLevels: inexactLevels,
    initialSatisfiedByLevel: initialSatisfiedByLevel,
    initialUnsatisfiedByLevel: initialUnsatisfiedByLevel,
    solverVisitedNodesByLevel: solverVisitedNodesByLevel,
  );
  final report = <String, Object?>{
    'generatorVersion': generatorVersion,
    'minimumLevel': minimumLevel,
    'maximumLevel': maximumLevel,
    'manifestChecksum': checksum,
    'summary': _summary(
      levelReports: levelReports,
      changedLevels: changedLevels,
      attemptSelectionCounts: attemptSelectionCounts,
      fallbackPassCount: fallbackPassCount,
    ),
    'changedLevels': changedLevels,
    'levels': levelReports,
  };

  final manifestFile = File(
    'lib/features/game/generator/quality/generator_v2_quality_manifest.dart',
  );
  manifestFile.writeAsStringSync(
    _manifestSource(
      checksum: checksum,
      preferredAttemptByLevel: preferredAttemptByLevel,
      templateCodeByLevel: templateCodeByLevel,
      visualSolutionCountByLevel: visualSolutionCountByLevel,
      inexactLevels: inexactLevels,
      initialSatisfiedByLevel: initialSatisfiedByLevel,
      initialUnsatisfiedByLevel: initialUnsatisfiedByLevel,
      targetSwapCountByLevel: targetSwapCountByLevel,
      solverVisitedNodesByLevel: solverVisitedNodesByLevel,
      easyDepthByLevel: easyDepthByLevel,
    ),
  );

  final reportFile = File('tool/output/generator_v2_quality_report.json');
  reportFile.parent.createSync(recursive: true);
  reportFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(report),
  );

  stdout.writeln('Generated generator v2 quality manifest.');
  stdout.writeln('checksum: $checksum');
  stdout.writeln('changedLevels: ${changedLevels.length}');
  stdout.writeln('fallbackPassCount: $fallbackPassCount');
}

Map<String, Object?> _failedAttemptReport(int attempt, Object error) {
  return {'attempt': attempt, 'buildFailed': true, 'failure': error.toString()};
}

Map<String, Object?> _candidateReport(GenerationCandidateQuality candidate) {
  final analysis = candidate.analysis;
  return {
    'attempt': candidate.generationAttempt,
    'buildFailed': false,
    'hardFailureReasons': analysis.hardFailureReasons,
    'distinctVisualSolutionCount':
        analysis.solutionAnalysis.distinctVisualSolutionCount,
    'solutionCountExact': analysis.solutionAnalysis.isSolutionCountExact,
    'initialSatisfiedClueCount': analysis.initialSatisfiedClueCount,
    'initialUnsatisfiedClueCount': analysis.initialUnsatisfiedClueCount,
    'targetSwapCount': analysis.targetSwapCount,
    'solverVisitedNodes': analysis.solutionAnalysis.visitedNodeCount,
    'easySolutionFound': analysis.easySolutionCheck.foundSolution,
    'easySolutionMinimumDepth': analysis.easySolutionCheck.minimumDepth,
  };
}

String _selectionReason(
  GenerationCandidateQuality? attemptZero,
  GenerationCandidateQuality selected,
) {
  if (attemptZero == null || !attemptZero.passesHardRequirements) {
    return 'attempt_0_failed_hard_requirement';
  }
  if (!attemptZero.analysis.solutionAnalysis.isSolutionCountExact &&
      selected.analysis.solutionAnalysis.isSolutionCountExact) {
    return 'exact_solution_count';
  }
  if (selected.solutionCountForRanking < attemptZero.solutionCountForRanking) {
    return 'fewer_solutions';
  }
  if (selected.analysis.initialUnsatisfiedClueCount >
      attemptZero.analysis.initialUnsatisfiedClueCount) {
    return 'more_unsatisfied_clues';
  }
  return 'ranker_tiebreaker';
}

Map<String, Object?> _summary({
  required List<Map<String, Object?>> levelReports,
  required List<Map<String, Object?>> changedLevels,
  required Map<int, int> attemptSelectionCounts,
  required int fallbackPassCount,
}) {
  var uniqueCount = 0;
  var multipleCount = 0;
  var cappedCount = 0;
  var exactSolutionTotal = 0;
  var exactSolutionLevelCount = 0;
  var maxExactSolutions = 0;

  for (final level in levelReports) {
    final solutionCount = level['distinctVisualSolutionCount']! as int;
    final exact = level['solutionCountExact']! as bool;
    if (exact && solutionCount == 1) {
      uniqueCount += 1;
    } else if (exact) {
      multipleCount += 1;
    } else {
      cappedCount += 1;
    }
    if (exact) {
      exactSolutionTotal += solutionCount;
      exactSolutionLevelCount += 1;
      if (solutionCount > maxExactSolutions) {
        maxExactSolutions = solutionCount;
      }
    }
  }

  return {
    'levelCount': levelReports.length,
    'uniqueSolutionLevelCount': uniqueCount,
    'multipleSolutionLevelCount': multipleCount,
    'solutionCapReachedLevelCount': cappedCount,
    'averageExactSolutionCount': exactSolutionLevelCount == 0
        ? null
        : exactSolutionTotal / exactSolutionLevelCount,
    'maxExactSolutionCount': maxExactSolutions,
    'attemptSelectionCounts': {
      for (final entry in attemptSelectionCounts.entries)
        entry.key.toString(): entry.value,
    },
    'fallbackPassCount': fallbackPassCount,
    'changedLevelCount': changedLevels.length,
  };
}

String _manifestSource({
  required int checksum,
  required Map<int, int> preferredAttemptByLevel,
  required Map<int, String> templateCodeByLevel,
  required Map<int, int> visualSolutionCountByLevel,
  required Set<int> inexactLevels,
  required Map<int, int> initialSatisfiedByLevel,
  required Map<int, int> initialUnsatisfiedByLevel,
  required Map<int, int> targetSwapCountByLevel,
  required Map<int, int> solverVisitedNodesByLevel,
  required Map<int, int> easyDepthByLevel,
}) {
  return '''
// Generated by tool/generate_generator_v2_quality_manifest.dart.
// Do not edit by hand.

abstract final class GeneratorV2QualityManifest {
  static const int minimumLevel = 201;
  static const int maximumLevel = 400;
  static const int checksum = $checksum;

  static const Map<int, int> preferredAttemptByLevel = {
${_intMapEntries(preferredAttemptByLevel)}
  };

  static const Map<int, String> templateCodeByLevel = {
${_stringMapEntries(templateCodeByLevel)}
  };

  static const Map<int, int> visualSolutionCountByLevel = {
${_intMapEntries(visualSolutionCountByLevel)}
  };

  static const Set<int> inexactSolutionCountLevels = {
${_intSetEntries(inexactLevels)}
  };

  static const Map<int, int> initialSatisfiedClueCountByLevel = {
${_intMapEntries(initialSatisfiedByLevel)}
  };

  static const Map<int, int> initialUnsatisfiedClueCountByLevel = {
${_intMapEntries(initialUnsatisfiedByLevel)}
  };

  static const Map<int, int> targetSwapCountByLevel = {
${_intMapEntries(targetSwapCountByLevel)}
  };

  static const Map<int, int> solverVisitedNodeCountByLevel = {
${_intMapEntries(solverVisitedNodesByLevel)}
  };

  static const Map<int, int> easySolutionMaximumDepthByLevel = {
${_intMapEntries(easyDepthByLevel)}
  };
}
''';
}

String _intMapEntries(Map<int, int> values) {
  return values.entries
      .map((entry) => '    ${entry.key}: ${entry.value},')
      .join('\n');
}

String _stringMapEntries(Map<int, String> values) {
  return values.entries
      .map((entry) => "    ${entry.key}: '${entry.value}',")
      .join('\n');
}

String _intSetEntries(Set<int> values) {
  return values.map((value) => '    $value,').join('\n');
}

int manifestChecksum({
  required Map<int, int> preferredAttemptByLevel,
  required Map<int, String> templateCodeByLevel,
  required Map<int, int> visualSolutionCountByLevel,
  required Set<int> inexactLevels,
  required Map<int, int> initialSatisfiedByLevel,
  required Map<int, int> initialUnsatisfiedByLevel,
  required Map<int, int> solverVisitedNodesByLevel,
}) {
  final buffer = StringBuffer();
  for (final level in preferredAttemptByLevel.keys) {
    final exact = inexactLevels.contains(level) ? 'false' : 'true';
    buffer.write(
      '$level:${preferredAttemptByLevel[level]}:'
      '${templateCodeByLevel[level]}:'
      '${visualSolutionCountByLevel[level]}:$exact:'
      '${initialSatisfiedByLevel[level]}:'
      '${initialUnsatisfiedByLevel[level]}:'
      '${solverVisitedNodesByLevel[level]};',
    );
  }
  return _fnv1a32(buffer.toString());
}

int _fnv1a32(String input) {
  var hash = GeneratorConfig.fnvOffsetBasis;
  for (final codeUnit in input.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * GeneratorConfig.fnvPrime) & GeneratorConfig.uint32Mask;
  }
  return hash;
}
