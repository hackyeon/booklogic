import 'package:flutter_test/flutter_test.dart';

import 'package:booklogic/features/game/generator/generated_stage.dart';
import 'package:booklogic/features/game/generator/generator_config.dart';
import 'package:booklogic/features/game/generator/quality/generation_candidate_quality.dart';
import 'package:booklogic/features/game/generator/quality/generation_candidate_ranker.dart';
import 'package:booklogic/features/game/generator/quality/generator_v1_quality_manifest.dart';
import 'package:booklogic/features/game/generator/quality/puzzle_quality_analysis.dart';
import 'package:booklogic/features/game/generator/quality/puzzle_quality_analyzer.dart';
import 'package:booklogic/features/game/generator/quality/template_code.dart';
import 'package:booklogic/features/game/generator/puzzle_template_resolver.dart';
import 'package:booklogic/features/game/generator/stage_candidate_builder_router.dart';
import 'package:booklogic/features/game/generator/stage_generator.dart';
import 'package:booklogic/features/game/generator/stage_permutation_analyzer.dart';
import 'package:booklogic/features/game/generator/stage_spec_factory.dart';
import 'package:booklogic/features/game/solver/puzzle_solution_analysis.dart';
import 'package:booklogic/features/game/solver/visual_swap_reachability_checker.dart';

void main() {
  group('GeneratorV1QualityManifest', () {
    test('covers exactly levels 1 through 200 with normal attempts', () {
      const specFactory = StageSpecFactory();
      const resolver = PuzzleTemplateResolver();

      expect(GeneratorV1QualityManifest.minimumLevel, 1);
      expect(GeneratorV1QualityManifest.maximumLevel, 200);
      expect(
        GeneratorV1QualityManifest.preferredAttemptByLevel,
        hasLength(200),
      );

      for (var level = 1; level <= 200; level += 1) {
        final attempt =
            GeneratorV1QualityManifest.preferredAttemptByLevel[level];
        expect(attempt, isNotNull, reason: 'level $level');
        expect(attempt, inInclusiveRange(0, 7), reason: 'level $level');
        expect(
          GeneratorV1QualityManifest.templateCodeByLevel[level],
          templateCode(resolver.resolve(specFactory.create(level: level))),
          reason: 'level $level',
        );
      }
    });

    test('checksum matches manifest content', () {
      expect(_manifestChecksum(), GeneratorV1QualityManifest.checksum);
      expect(GeneratorV1QualityManifest.checksum, 2127356086);
    });

    test('StageGenerator returns the manifest-selected router candidate', () {
      const generator = StageGenerator();
      const router = StageCandidateBuilderRouter();
      const specFactory = StageSpecFactory();

      for (var level = 1; level <= 200; level += 1) {
        final stage = generator.generate(level: level);
        final expected = router.buildAttempt(
          stageSpec: specFactory.create(level: level),
          generationAttempt:
              GeneratorV1QualityManifest.preferredAttemptByLevel[level]!,
        );

        expect(stage, expected, reason: 'level $level');
        expect(stage.isFallback, isFalse, reason: 'level $level');
      }
    });
  });

  group('GenerationCandidateRanker', () {
    const ranker = GenerationCandidateRanker();
    const specFactory = StageSpecFactory();
    const router = StageCandidateBuilderRouter();

    test('prefers hard pass candidates over hard failures', () {
      final pass = _candidate(
        router.buildAttempt(
          stageSpec: specFactory.create(level: 1),
          generationAttempt: 0,
        ),
        solutionCount: 2,
      );
      final fail = _candidate(
        router.buildAttempt(
          stageSpec: specFactory.create(level: 1),
          generationAttempt: 1,
        ),
        solutionCount: 1,
        failures: const ['target_is_not_solution'],
      );

      expect(ranker.best([fail, pass]), pass);
    });

    test('ranks exact and smaller solution counts first', () {
      final exactOne = _candidate(
        router.buildAttempt(
          stageSpec: specFactory.create(level: 1),
          generationAttempt: 0,
        ),
        solutionCount: 1,
      );
      final exactTwo = _candidate(
        router.buildAttempt(
          stageSpec: specFactory.create(level: 1),
          generationAttempt: 1,
        ),
        solutionCount: 2,
      );
      final exactFour = _candidate(
        router.buildAttempt(
          stageSpec: specFactory.create(level: 1),
          generationAttempt: 2,
        ),
        solutionCount: 4,
      );
      final capped = _candidate(
        router.buildAttempt(
          stageSpec: specFactory.create(level: 1),
          generationAttempt: 3,
        ),
        solutionCount: 32,
        exact: false,
      );

      expect(ranker.best([exactTwo, exactOne]), exactOne);
      expect(ranker.best([exactFour, exactTwo]), exactTwo);
      expect(ranker.best([capped, exactFour]), exactFour);
      expect(ranker.compare(exactOne, exactTwo), lessThan(0));
      expect(ranker.compare(exactTwo, exactFour), lessThan(0));
      expect(ranker.compare(exactOne, exactFour), lessThan(0));
    });

    test(
      'uses unsatisfied clues, satisfied clues, then attempt as tie breakers',
      () {
        final moreUnsatisfied = _candidate(
          router.buildAttempt(
            stageSpec: specFactory.create(level: 1),
            generationAttempt: 2,
          ),
          solutionCount: 2,
          satisfied: 1,
          unsatisfied: 4,
        );
        final fewerUnsatisfied = _candidate(
          router.buildAttempt(
            stageSpec: specFactory.create(level: 1),
            generationAttempt: 3,
          ),
          solutionCount: 2,
          satisfied: 2,
          unsatisfied: 3,
        );
        final attemptOne = _candidate(
          router.buildAttempt(
            stageSpec: specFactory.create(level: 1),
            generationAttempt: 1,
          ),
          solutionCount: 2,
          satisfied: 1,
          unsatisfied: 4,
        );

        expect(
          ranker.best([fewerUnsatisfied, moreUnsatisfied]),
          moreUnsatisfied,
        );
        expect(ranker.best([moreUnsatisfied, attemptOne]), attemptOne);
      },
    );
  });

  group('PuzzleQualityAnalyzer', () {
    const analyzer = PuzzleQualityAnalyzer();
    const generator = StageGenerator();
    const permutationAnalyzer = StagePermutationAnalyzer();

    test('analyzes representative manifest-selected stages', () {
      for (final level in [1, 21, 23, 51, 101, 200]) {
        final stage = generator.generate(level: level);
        final analysis = analyzer.analyze(stage);

        expect(analysis.solutionAnalysis.targetIsSolution, isTrue);
        expect(analysis.solutionAnalysis.initialIsSolution, isFalse);
        expect(
          analysis.solutionAnalysis.distinctVisualSolutionCount,
          greaterThanOrEqualTo(1),
        );
        expect(analysis.solutionAnalysis.targetSignatureFound, isTrue);
        expect(analysis.solutionAnalysis.unsupportedReason, isNull);
        expect(analysis.solutionAnalysis.reachedNodeLimit, isFalse);
        expect(analysis.easySolutionCheck.reachedStateLimit, isFalse);
        expect(
          analysis.initialUnsatisfiedClueCount,
          greaterThanOrEqualTo(
            PuzzleQualityPolicy.minimumUnsatisfiedClues(stage.templateId),
          ),
        );
        expect(
          analysis.minimumSwapDistanceToTarget,
          permutationAnalyzer.minimumVisualSwapDistance(
            target: stage.targetPlacements,
            current: stage.initialPlacements,
          ),
        );
        expect(analysis.hardFailureReasons, isEmpty);
      }
    });
  });
}

GenerationCandidateQuality _candidate(
  GeneratedStage stage, {
  required int solutionCount,
  bool exact = true,
  int satisfied = 0,
  int unsatisfied = 3,
  List<String> failures = const [],
}) {
  return GenerationCandidateQuality(
    stage: stage,
    analysis: PuzzleQualityAnalysis(
      solutionAnalysis: PuzzleSolutionAnalysis(
        targetIsSolution: true,
        initialIsSolution: false,
        distinctVisualSolutionCount: solutionCount,
        isSolutionCountExact: exact,
        reachedSolutionLimit: !exact,
        reachedNodeLimit: false,
        visitedNodeCount: 1,
        sampleSolutions: const [],
        targetSignature: null,
        unsupportedReason: null,
      ),
      easySolutionCheck: const VisualSwapReachabilityResult(
        foundSolution: false,
        minimumDepth: null,
        visitedStateCount: 1,
        reachedStateLimit: false,
        solutionSignature: null,
      ),
      totalClueCount: satisfied + unsatisfied,
      initialSatisfiedClueCount: satisfied,
      initialUnsatisfiedClueCount: unsatisfied,
      targetSwapCount: 1,
      minimumSwapDistanceToTarget: 1,
      generationAttempt: stage.generationAttempt,
      isFallback: false,
      hardFailureReasons: failures,
    ),
  );
}

int _manifestChecksum() {
  final buffer = StringBuffer();
  for (var level = 1; level <= 200; level += 1) {
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
