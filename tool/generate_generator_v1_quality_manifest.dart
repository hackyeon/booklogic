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
  const minimumLevel = 1;
  const maximumLevel = 200;
  const maxAttempts = 8;
  const specFactory = StageSpecFactory();
  const router = StageCandidateBuilderRouter();
  const analyzer = PuzzleQualityAnalyzer();
  const ranker = GenerationCandidateRanker();

  final levelReports = <Map<String, Object?>>[];
  final preferredAttemptByLevel = <int, int>{};
  final visualSolutionCountByLevel = <int, int>{};
  final inexactLevels = <int>{};
  final templateCodeByLevel = <int, String>{};
  final initialSatisfiedByLevel = <int, int>{};
  final initialUnsatisfiedByLevel = <int, int>{};
  final targetSwapCountByLevel = <int, int>{};
  final solverVisitedNodesByLevel = <int, int>{};
  final easyDepthByLevel = <int, int>{};
  final changedLevels = <Map<String, Object?>>[];
  final attemptSelectionCounts = {
    for (var attempt = 0; attempt < maxAttempts; attempt += 1) attempt: 0,
  };
  var fallbackCount = 0;

  for (var level = minimumLevel; level <= maximumLevel; level += 1) {
    final stageSpec = specFactory.create(level: level);
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
        attemptReports.add({
          'attempt': attempt,
          'buildFailed': true,
          'failure': error.toString(),
        });
      } on ArgumentError catch (error) {
        attemptReports.add({
          'attempt': attempt,
          'buildFailed': true,
          'failure': error.toString(),
        });
      }
    }

    final hardPassCandidates = [
      for (final candidate in candidates)
        if (candidate.passesHardRequirements) candidate,
    ];

    GenerationCandidateQuality selected;
    if (hardPassCandidates.isNotEmpty) {
      selected = ranker.best(hardPassCandidates);
    } else {
      fallbackCount += 1;
      final fallbackStage = router.buildFallback(stageSpec: stageSpec);
      final fallbackAnalysis = analyzer.analyze(fallbackStage);
      selected = GenerationCandidateQuality(
        stage: fallbackStage,
        analysis: fallbackAnalysis,
      );
      if (!selected.passesHardRequirements) {
        stderr.writeln('No valid candidate for level $level');
        stderr.writeln(jsonEncode(_candidateReport(selected)));
        exitCode = 1;
        return;
      }
    }

    final selectedAnalysis = selected.analysis;
    preferredAttemptByLevel[level] = selected.generationAttempt;
    visualSolutionCountByLevel[level] =
        selectedAnalysis.solutionAnalysis.distinctVisualSolutionCount;
    if (!selectedAnalysis.solutionAnalysis.isSolutionCountExact) {
      inexactLevels.add(level);
    }
    templateCodeByLevel[level] = templateCode(selected.templateId);
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

  final checksum = _manifestChecksum(
    preferredAttemptByLevel: preferredAttemptByLevel,
    visualSolutionCountByLevel: visualSolutionCountByLevel,
    inexactLevels: inexactLevels,
  );
  final report = <String, Object?>{
    'generatorVersion': GeneratorConfig.currentVersion,
    'minimumLevel': minimumLevel,
    'maximumLevel': maximumLevel,
    'manifestChecksum': checksum,
    'summary': _summary(
      levelReports: levelReports,
      changedLevels: changedLevels,
      attemptSelectionCounts: attemptSelectionCounts,
      fallbackCount: fallbackCount,
    ),
    'changedLevels': changedLevels,
    'levels': levelReports,
  };

  final manifestFile = File(
    'lib/features/game/generator/quality/generator_v1_quality_manifest.dart',
  );
  manifestFile.writeAsStringSync(
    _manifestSource(
      checksum: checksum,
      preferredAttemptByLevel: preferredAttemptByLevel,
      visualSolutionCountByLevel: visualSolutionCountByLevel,
      inexactLevels: inexactLevels,
      templateCodeByLevel: templateCodeByLevel,
      initialSatisfiedByLevel: initialSatisfiedByLevel,
      initialUnsatisfiedByLevel: initialUnsatisfiedByLevel,
      targetSwapCountByLevel: targetSwapCountByLevel,
      solverVisitedNodesByLevel: solverVisitedNodesByLevel,
      easyDepthByLevel: easyDepthByLevel,
    ),
  );

  final reportFile = File('tool/output/generator_v1_quality_report.json');
  reportFile.parent.createSync(recursive: true);
  reportFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(report),
  );

  stdout.writeln('Generated generator v1 quality manifest.');
  stdout.writeln('checksum: $checksum');
  stdout.writeln('changedLevels: ${changedLevels.length}');
  stdout.writeln('fallbackCount: $fallbackCount');
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
  required int fallbackCount,
}) {
  var uniqueCount = 0;
  var multipleCount = 0;
  var cappedCount = 0;
  var exactSolutionTotal = 0;
  var exactSolutionLevelCount = 0;
  var maxExactSolutions = 0;
  final byTemplate = <String, Map<String, int>>{};

  for (final level in levelReports) {
    final templateId = level['templateId']! as String;
    final solutionCount = level['distinctVisualSolutionCount']! as int;
    final exact = level['solutionCountExact']! as bool;
    final templateStats = byTemplate.putIfAbsent(
      templateId,
      () => {
        'levels': 0,
        'unique': 0,
        'multiple': 0,
        'capped': 0,
        'maxExactSolutions': 0,
      },
    );
    templateStats['levels'] = templateStats['levels']! + 1;
    if (exact && solutionCount == 1) {
      uniqueCount += 1;
      templateStats['unique'] = templateStats['unique']! + 1;
    } else if (exact) {
      multipleCount += 1;
      templateStats['multiple'] = templateStats['multiple']! + 1;
    } else {
      cappedCount += 1;
      templateStats['capped'] = templateStats['capped']! + 1;
    }
    if (exact) {
      exactSolutionTotal += solutionCount;
      exactSolutionLevelCount += 1;
      if (solutionCount > maxExactSolutions) {
        maxExactSolutions = solutionCount;
      }
      if (solutionCount > templateStats['maxExactSolutions']!) {
        templateStats['maxExactSolutions'] = solutionCount;
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
    'byTemplate': byTemplate,
    'attemptSelectionCounts': {
      for (final entry in attemptSelectionCounts.entries)
        entry.key.toString(): entry.value,
    },
    'fallbackCount': fallbackCount,
    'changedLevelCount': changedLevels.length,
  };
}

String _manifestSource({
  required int checksum,
  required Map<int, int> preferredAttemptByLevel,
  required Map<int, int> visualSolutionCountByLevel,
  required Set<int> inexactLevels,
  required Map<int, String> templateCodeByLevel,
  required Map<int, int> initialSatisfiedByLevel,
  required Map<int, int> initialUnsatisfiedByLevel,
  required Map<int, int> targetSwapCountByLevel,
  required Map<int, int> solverVisitedNodesByLevel,
  required Map<int, int> easyDepthByLevel,
}) {
  return '''
// Generated by tool/generate_generator_v1_quality_manifest.dart.
// Do not edit by hand.

abstract final class GeneratorV1QualityManifest {
  static const int minimumLevel = 1;
  static const int maximumLevel = 200;
  static const int checksum = $checksum;

  static const Map<int, int> preferredAttemptByLevel = {
${_intMapEntries(preferredAttemptByLevel)}
  };

  static const Map<int, int> visualSolutionCountByLevel = {
${_intMapEntries(visualSolutionCountByLevel)}
  };

  static const Set<int> inexactSolutionCountLevels = {
${_intSetEntries(inexactLevels)}
  };

  static const Map<int, String> templateCodeByLevel = {
${_stringMapEntries(templateCodeByLevel)}
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

  static const Map<int, int> solverVisitedNodesByLevel = {
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

int _manifestChecksum({
  required Map<int, int> preferredAttemptByLevel,
  required Map<int, int> visualSolutionCountByLevel,
  required Set<int> inexactLevels,
}) {
  final buffer = StringBuffer();
  for (final level in preferredAttemptByLevel.keys) {
    final exact = inexactLevels.contains(level) ? 'false' : 'true';
    buffer.write(
      '$level:${preferredAttemptByLevel[level]}:'
      '${visualSolutionCountByLevel[level]}:$exact;',
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
