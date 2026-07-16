import 'dart:io';

import 'package:booklogic/features/game/generator/generator_config.dart';
import 'package:booklogic/features/game/generator/quality/generation_candidate_quality.dart';
import 'package:booklogic/features/game/generator/quality/generation_candidate_ranker.dart';
import 'package:booklogic/features/game/generator/quality/generator_v1_quality_manifest.dart';
import 'package:booklogic/features/game/generator/quality/puzzle_quality_analyzer.dart';
import 'package:booklogic/features/game/generator/stage_candidate_builder_router.dart';
import 'package:booklogic/features/game/generator/stage_spec_factory.dart';

void main() {
  const maxAttempts = 8;
  const specFactory = StageSpecFactory();
  const router = StageCandidateBuilderRouter();
  const analyzer = PuzzleQualityAnalyzer();
  const ranker = GenerationCandidateRanker();

  final failures = <String>[];
  if (GeneratorV1QualityManifest.minimumLevel != 1 ||
      GeneratorV1QualityManifest.maximumLevel != 200 ||
      GeneratorV1QualityManifest.preferredAttemptByLevel.length != 200) {
    failures.add('manifest_coverage');
  }

  for (
    var level = GeneratorV1QualityManifest.minimumLevel;
    level <= GeneratorV1QualityManifest.maximumLevel;
    level += 1
  ) {
    final preferredAttempt =
        GeneratorV1QualityManifest.preferredAttemptByLevel[level];
    if (preferredAttempt == null ||
        preferredAttempt < 0 ||
        preferredAttempt >= maxAttempts) {
      failures.add('level_${level}_missing_preferred_attempt');
      continue;
    }

    final spec = specFactory.create(level: level);
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
    if (best.analysis.solutionAnalysis.distinctVisualSolutionCount !=
        GeneratorV1QualityManifest.visualSolutionCountByLevel[level]) {
      failures.add('level_${level}_solution_count_mismatch');
    }
    if (!best.passesHardRequirements) {
      failures.add('level_${level}_hard_requirement_failed');
    }
  }

  final checksum = _manifestChecksum();
  if (checksum != GeneratorV1QualityManifest.checksum) {
    failures.add(
      'checksum_mismatch_manifest_${GeneratorV1QualityManifest.checksum}_actual_$checksum',
    );
  }

  if (failures.isNotEmpty) {
    for (final failure in failures) {
      stderr.writeln(failure);
    }
    exitCode = 1;
    return;
  }

  stdout.writeln('Generator v1 quality manifest verified.');
  stdout.writeln('checksum: $checksum');
}

int _manifestChecksum() {
  final buffer = StringBuffer();
  for (
    var level = GeneratorV1QualityManifest.minimumLevel;
    level <= GeneratorV1QualityManifest.maximumLevel;
    level += 1
  ) {
    final exact =
        GeneratorV1QualityManifest.inexactSolutionCountLevels.contains(level)
        ? 'false'
        : 'true';
    buffer.write(
      '$level:${GeneratorV1QualityManifest.preferredAttemptByLevel[level]}:'
      '${GeneratorV1QualityManifest.visualSolutionCountByLevel[level]}:'
      '$exact;',
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
