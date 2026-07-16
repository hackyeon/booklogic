import 'dart:io';

import 'package:booklogic/features/game/generator/generated_stage_validator.dart';
import 'package:booklogic/features/game/generator/generator_config.dart';
import 'package:booklogic/features/game/generator/quality/generation_candidate_quality.dart';
import 'package:booklogic/features/game/generator/quality/generation_candidate_ranker.dart';
import 'package:booklogic/features/game/generator/quality/generator_v1_quality_manifest.dart';
import 'package:booklogic/features/game/generator/quality/generator_v2_quality_manifest.dart';
import 'package:booklogic/features/game/generator/quality/puzzle_quality_analyzer.dart';
import 'package:booklogic/features/game/generator/quality/template_code.dart';
import 'package:booklogic/features/game/generator/stage_candidate_builder_router.dart';
import 'package:booklogic/features/game/generator/stage_generator.dart';
import 'package:booklogic/features/game/generator/stage_spec_factory.dart';

void main() {
  const generatorVersion = GeneratorConfig.generatorVersion2;
  const maxAttempts = 8;
  const specFactory = StageSpecFactory();
  const router = StageCandidateBuilderRouter();
  const analyzer = PuzzleQualityAnalyzer(
    maximumVisitedNodes: 2000000,
    maximumReachabilityVisitedStates: 500000,
  );
  const ranker = GenerationCandidateRanker();
  const generator = StageGenerator();
  const validator = GeneratedStageValidator();

  final failures = <String>[];
  if (GeneratorV1QualityManifest.checksum != 2127356086) {
    failures.add('v1_checksum_changed');
  }
  if (GeneratorV2QualityManifest.minimumLevel != 201 ||
      GeneratorV2QualityManifest.maximumLevel != 400 ||
      GeneratorV2QualityManifest.preferredAttemptByLevel.length != 200 ||
      GeneratorV2QualityManifest.templateCodeByLevel.length != 200 ||
      GeneratorV2QualityManifest.visualSolutionCountByLevel.length != 200) {
    failures.add('manifest_coverage');
  }

  for (
    var level = GeneratorV2QualityManifest.minimumLevel;
    level <= GeneratorV2QualityManifest.maximumLevel;
    level += 1
  ) {
    final preferredAttempt =
        GeneratorV2QualityManifest.preferredAttemptByLevel[level];
    if (preferredAttempt == null ||
        preferredAttempt < 0 ||
        preferredAttempt >= maxAttempts) {
      failures.add('level_${level}_missing_preferred_attempt');
      continue;
    }
    if (GeneratorV2QualityManifest.templateCodeByLevel[level] !=
        't06_vertical_pair') {
      failures.add('level_${level}_template_code_mismatch');
    }

    final spec = specFactory.create(
      level: level,
      generatorVersion: generatorVersion,
    );
    final candidates = <GenerationCandidateQuality>[];
    for (var attempt = 0; attempt < maxAttempts; attempt += 1) {
      try {
        final stage = router.buildAttempt(
          stageSpec: spec,
          generationAttempt: attempt,
        );
        candidates.add(
          GenerationCandidateQuality(
            stage: stage,
            analysis: analyzer.analyze(stage),
          ),
        );
      } on StateError {
        continue;
      } on ArgumentError {
        continue;
      }
    }

    final hardPass = [
      for (final candidate in candidates)
        if (candidate.passesHardRequirements) candidate,
    ];
    if (hardPass.isEmpty) {
      failures.add('level_${level}_no_hard_pass_candidate');
      continue;
    }
    final best = ranker.best(hardPass);
    if (best.generationAttempt != preferredAttempt) {
      failures.add(
        'level_${level}_preferred_attempt_mismatch_'
        'manifest_${preferredAttempt}_best_${best.generationAttempt}',
      );
    }
    if (templateCode(best.templateId) !=
        GeneratorV2QualityManifest.templateCodeByLevel[level]) {
      failures.add('level_${level}_selected_template_mismatch');
    }
    if (best.analysis.solutionAnalysis.distinctVisualSolutionCount !=
        GeneratorV2QualityManifest.visualSolutionCountByLevel[level]) {
      failures.add('level_${level}_solution_count_mismatch');
    }
    final isInexact = GeneratorV2QualityManifest.inexactSolutionCountLevels
        .contains(level);
    if (best.analysis.solutionAnalysis.isSolutionCountExact == isInexact) {
      failures.add('level_${level}_solution_exactness_mismatch');
    }
    if (best.analysis.initialSatisfiedClueCount !=
        GeneratorV2QualityManifest.initialSatisfiedClueCountByLevel[level]) {
      failures.add('level_${level}_initial_satisfied_mismatch');
    }
    if (best.analysis.initialUnsatisfiedClueCount !=
        GeneratorV2QualityManifest.initialUnsatisfiedClueCountByLevel[level]) {
      failures.add('level_${level}_initial_unsatisfied_mismatch');
    }
    if (best.analysis.solutionAnalysis.visitedNodeCount !=
        GeneratorV2QualityManifest.solverVisitedNodeCountByLevel[level]) {
      failures.add('level_${level}_visited_nodes_mismatch');
    }

    final generated = generator.generate(
      level: level,
      generatorVersion: generatorVersion,
    );
    if (generated.generationAttempt != preferredAttempt) {
      failures.add('level_${level}_stage_generator_attempt_mismatch');
    }
    if (validator.validate(generated).isInvalid) {
      failures.add('level_${level}_stage_generator_validation_failed');
    }
  }

  final checksum = _manifestChecksum();
  if (checksum != GeneratorV2QualityManifest.checksum) {
    failures.add(
      'checksum_mismatch_manifest_${GeneratorV2QualityManifest.checksum}_actual_$checksum',
    );
  }

  if (failures.isNotEmpty) {
    for (final failure in failures) {
      stderr.writeln(failure);
    }
    exitCode = 1;
    return;
  }

  stdout.writeln('Generator v2 quality manifest verified.');
  stdout.writeln('checksum: $checksum');
}

int _manifestChecksum() {
  final buffer = StringBuffer();
  for (
    var level = GeneratorV2QualityManifest.minimumLevel;
    level <= GeneratorV2QualityManifest.maximumLevel;
    level += 1
  ) {
    final exact =
        GeneratorV2QualityManifest.inexactSolutionCountLevels.contains(level)
        ? 'false'
        : 'true';
    buffer.write(
      '$level:${GeneratorV2QualityManifest.preferredAttemptByLevel[level]}:'
      '${GeneratorV2QualityManifest.templateCodeByLevel[level]}:'
      '${GeneratorV2QualityManifest.visualSolutionCountByLevel[level]}:'
      '$exact:'
      '${GeneratorV2QualityManifest.initialSatisfiedClueCountByLevel[level]}:'
      '${GeneratorV2QualityManifest.initialUnsatisfiedClueCountByLevel[level]}:'
      '${GeneratorV2QualityManifest.solverVisitedNodeCountByLevel[level]};',
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
