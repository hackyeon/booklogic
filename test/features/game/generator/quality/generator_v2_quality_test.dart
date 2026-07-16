import 'package:flutter_test/flutter_test.dart';

import 'package:booklogic/features/game/domain/clue.dart';
import 'package:booklogic/features/game/generator/generated_stage_validator.dart';
import 'package:booklogic/features/game/generator/generator_config.dart';
import 'package:booklogic/features/game/generator/quality/generator_v1_quality_manifest.dart';
import 'package:booklogic/features/game/generator/quality/generator_v2_quality_manifest.dart';
import 'package:booklogic/features/game/generator/quality/puzzle_quality_analyzer.dart';
import 'package:booklogic/features/game/generator/quality/template_code.dart';
import 'package:booklogic/features/game/generator/puzzle_template_id.dart';
import 'package:booklogic/features/game/generator/stage_candidate_builder_router.dart';
import 'package:booklogic/features/game/generator/stage_generator.dart';
import 'package:booklogic/features/game/generator/stage_spec_factory.dart';

void main() {
  group('GeneratorV2QualityManifest', () {
    test('covers exactly levels 201 through 400 with normal attempts', () {
      expect(GeneratorV2QualityManifest.minimumLevel, 201);
      expect(GeneratorV2QualityManifest.maximumLevel, 400);
      expect(
        GeneratorV2QualityManifest.preferredAttemptByLevel,
        hasLength(200),
      );
      expect(GeneratorV2QualityManifest.templateCodeByLevel, hasLength(200));
      expect(
        GeneratorV2QualityManifest.visualSolutionCountByLevel,
        hasLength(200),
      );

      for (var level = 201; level <= 400; level += 1) {
        final attempt =
            GeneratorV2QualityManifest.preferredAttemptByLevel[level];
        expect(attempt, isNotNull, reason: 'level $level');
        expect(attempt, inInclusiveRange(0, 7), reason: 'level $level');
        expect(
          GeneratorV2QualityManifest.templateCodeByLevel[level],
          't06_vertical_pair',
          reason: 'level $level',
        );
      }
    });

    test('checksum matches manifest content and v1 checksum is unchanged', () {
      expect(_manifestChecksum(), GeneratorV2QualityManifest.checksum);
      expect(GeneratorV1QualityManifest.checksum, 2127356086);
    });

    test('StageGenerator returns manifest-selected T06 attempts', () {
      const generator = StageGenerator();
      const router = StageCandidateBuilderRouter();
      const specFactory = StageSpecFactory();

      for (final level in [201, 241, 281, 321, 400]) {
        final stage = generator.generate(
          level: level,
          generatorVersion: GeneratorConfig.generatorVersion2,
        );
        final spec = specFactory.create(
          level: level,
          generatorVersion: GeneratorConfig.generatorVersion2,
        );
        final expected = router.buildAttempt(
          stageSpec: spec,
          generationAttempt:
              GeneratorV2QualityManifest.preferredAttemptByLevel[level]!,
        );

        expect(stage, expected, reason: 'level $level');
        expect(stage.templateId, PuzzleTemplateId.t06VerticalPair);
        expect(templateCode(stage.templateId), 't06_vertical_pair');
        expect(stage.generatorVersion, GeneratorConfig.generatorVersion2);
        expect(stage.totalBookCount, 12);
      }
    });

    test('generates valid T06 stages for every v2 level', () {
      const generator = StageGenerator();
      const validator = GeneratedStageValidator();

      for (var level = 201; level <= 400; level += 1) {
        final stage = generator.generate(
          level: level,
          generatorVersion: GeneratorConfig.generatorVersion2,
        );
        final validation = validator.validate(stage);
        expect(validation.isValid, isTrue, reason: 'level $level');
        expect(stage.templateId, PuzzleTemplateId.t06VerticalPair);
        expect(stage.totalBookCount, 12);
        expect(stage.isFallback, isFalse);
      }
    });
  });

  group('T06 representative quality', () {
    const analyzer = PuzzleQualityAnalyzer(
      maximumVisitedNodes: 2000000,
      maximumReachabilityVisitedStates: 500000,
    );
    const generator = StageGenerator();

    test('analyzes representative manifest-selected stages', () {
      for (final level in [201, 241, 281, 321, 400]) {
        final stage = generator.generate(
          level: level,
          generatorVersion: GeneratorConfig.generatorVersion2,
        );
        final analysis = analyzer.analyze(stage);

        expect(analysis.solutionAnalysis.targetIsSolution, isTrue);
        expect(analysis.solutionAnalysis.initialIsSolution, isFalse);
        expect(
          analysis.solutionAnalysis.distinctVisualSolutionCount,
          GeneratorV2QualityManifest.visualSolutionCountByLevel[level],
        );
        expect(
          analysis.solutionAnalysis.distinctVisualSolutionCount,
          greaterThanOrEqualTo(1),
        );
        expect(
          analysis.solutionAnalysis.isSolutionCountExact,
          !GeneratorV2QualityManifest.inexactSolutionCountLevels.contains(
            level,
          ),
        );
        expect(analysis.solutionAnalysis.targetSignatureFound, isTrue);
        expect(analysis.solutionAnalysis.unsupportedReason, isNull);
        expect(analysis.solutionAnalysis.reachedNodeLimit, isFalse);
        expect(analysis.easySolutionCheck.reachedStateLimit, isFalse);
        expect(analysis.hardFailureReasons, isEmpty);
        expect(
          analysis.initialSatisfiedClueCount,
          GeneratorV2QualityManifest.initialSatisfiedClueCountByLevel[level],
        );
        expect(
          analysis.initialUnsatisfiedClueCount,
          greaterThanOrEqualTo(level < 281 ? 3 : 4),
        );
        expect(stage.clues.whereType<VerticalRelationClue>(), isNotEmpty);
        if (level >= 241) {
          expect(stage.clues.whereType<NotAtEdgeClue>(), isNotEmpty);
        }
        if (level >= 321) {
          expect(stage.clues.whereType<DistanceClue>(), isNotEmpty);
        }
      }
    });
  });
}

int _manifestChecksum() {
  final buffer = StringBuffer();
  for (var level = 201; level <= 400; level += 1) {
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
