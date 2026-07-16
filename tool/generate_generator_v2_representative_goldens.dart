import 'dart:convert';
import 'dart:io';

import 'package:booklogic/features/game/domain/book.dart';
import 'package:booklogic/features/game/domain/book_placement.dart';
import 'package:booklogic/features/game/domain/book_position.dart';
import 'package:booklogic/features/game/domain/book_selector.dart';
import 'package:booklogic/features/game/domain/clue.dart';
import 'package:booklogic/features/game/generator/book_code.dart';
import 'package:booklogic/features/game/generator/book_swap_step.dart';
import 'package:booklogic/features/game/generator/difficulty_profile.dart';
import 'package:booklogic/features/game/generator/generated_stage.dart';
import 'package:booklogic/features/game/generator/generator_config.dart';
import 'package:booklogic/features/game/generator/quality/generator_v2_quality_manifest.dart';
import 'package:booklogic/features/game/generator/quality/puzzle_quality_analyzer.dart';
import 'package:booklogic/features/game/generator/quality/template_code.dart';
import 'package:booklogic/features/game/generator/stage_generator.dart';
import 'package:booklogic/features/game/generator/stage_spec.dart';

void main() {
  const levels = [201, 241, 281, 321, 400];
  const generator = StageGenerator();
  const analyzer = PuzzleQualityAnalyzer(
    maximumVisitedNodes: 2000000,
    maximumReachabilityVisitedStates: 500000,
  );

  final records = [
    for (final level in levels)
      _stageRecord(
        generator.generate(
          level: level,
          generatorVersion: GeneratorConfig.generatorVersion2,
        ),
        analyzer,
      ),
  ];

  final file = File('test/resources/generator_v2_representative_goldens.json');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(records));

  stdout.writeln('Generated generator v2 representative goldens.');
  stdout.writeln('levels: ${levels.join(', ')}');
}

Map<String, Object?> _stageRecord(
  GeneratedStage stage,
  PuzzleQualityAnalyzer analyzer,
) {
  final analysis = analyzer.analyze(stage);
  return {
    'level': stage.level,
    'generatorVersion': stage.generatorVersion,
    'stageSeed': stage.stageSpec.seed,
    'stageSpec': _stageSpecRecord(stage.stageSpec),
    'profileId': _profileCode(stage.stageSpec.profileId),
    'templateId': templateCode(stage.templateId),
    'preferredAttempt':
        GeneratorV2QualityManifest.preferredAttemptByLevel[stage.level],
    'generationAttempt': stage.generationAttempt,
    'generationAttemptSeed': stage.generationAttemptSeed,
    'targetPlacements': [
      for (final placement in stage.targetPlacements)
        _placementRecord(placement),
    ],
    'clues': [for (final clue in stage.clues) _clueRecord(clue)],
    'scrambleSeed': stage.scrambleSeed,
    'initialPlacements': [
      for (final placement in stage.initialPlacements)
        _placementRecord(placement),
    ],
    'swapHistory': [for (final step in stage.swapHistory) _swapRecord(step)],
    'initialSatisfiedClueCount': analysis.initialSatisfiedClueCount,
    'initialUnsatisfiedClueCount': analysis.initialUnsatisfiedClueCount,
    'minimumVisualSwapDistance': analysis.minimumSwapDistanceToTarget,
    'solution': {
      'distinctVisualSolutionCount':
          analysis.solutionAnalysis.distinctVisualSolutionCount,
      'solutionCountExact': analysis.solutionAnalysis.isSolutionCountExact,
      'solverVisitedNodes': analysis.solutionAnalysis.visitedNodeCount,
      'reachedNodeLimit': analysis.solutionAnalysis.reachedNodeLimit,
      'reachedSolutionLimit': analysis.solutionAnalysis.reachedSolutionLimit,
      'targetSignatureFound': analysis.solutionAnalysis.targetSignatureFound,
    },
  };
}

Map<String, Object?> _stageSpecRecord(StageSpec spec) {
  return {
    'generationKey': {
      'generatorVersion': spec.generationKey.generatorVersion,
      'level': spec.generationKey.level,
      'attempt': spec.generationKey.attempt,
    },
    'seed': spec.seed,
    'profileId': _profileCode(spec.profileId),
    'tierCount': spec.tierCount,
    'booksPerTier': spec.booksPerTier,
    'totalBookCount': spec.totalBookCount,
    'clueCount': spec.clueCount,
    'targetSwapCount': spec.targetSwapCount,
    'duplicateGroupCount': spec.duplicateGroupCount,
    'maxDuplicateCopies': spec.maxDuplicateCopies,
  };
}

Map<String, Object?> _placementRecord(BookPlacement placement) {
  return {
    'book': _bookRecord(placement.book),
    'position': _positionRecord(placement.position),
  };
}

Map<String, Object?> _bookRecord(Book book) {
  return {
    'id': book.id,
    'color': BookCode.color(book.color),
    'symbol': BookCode.symbol(book.symbol),
    'visualCode': BookCode.bookId(color: book.color, symbol: book.symbol),
  };
}

Map<String, int> _positionRecord(BookPosition position) {
  return {'tierIndex': position.tierIndex, 'slotIndex': position.slotIndex};
}

Map<String, Object?> _swapRecord(BookSwapStep step) {
  return {
    'stepIndex': step.stepIndex,
    'firstPosition': _positionRecord(step.firstPosition),
    'secondPosition': _positionRecord(step.secondPosition),
    'firstBookIdBeforeSwap': step.firstBookIdBeforeSwap,
    'secondBookIdBeforeSwap': step.secondBookIdBeforeSwap,
  };
}

Map<String, Object?> _clueRecord(Clue clue) {
  final base = {'id': clue.id, 'type': _clueTypeCode(clue)};
  return switch (clue) {
    EdgePositionClue(:final subject, :final tierIndex, :final edge) => {
      ...base,
      'subject': _selectorRecord(subject),
      'tierIndex': tierIndex,
      'edge': _edgeCode(edge),
    },
    BothEdgesClue(:final subject, :final tierIndex) => {
      ...base,
      'subject': _selectorRecord(subject),
      'tierIndex': tierIndex,
    },
    RelativeOrderClue(
      :final subject,
      :final reference,
      :final tierIndex,
      :final relation,
    ) =>
      {
        ...base,
        'subject': _selectorRecord(subject),
        'reference': _selectorRecord(reference),
        'tierIndex': tierIndex,
        'relation': _horizontalRelationCode(relation),
      },
    BetweenClue(:final subject, :final boundary, :final tierIndex) => {
      ...base,
      'subject': _selectorRecord(subject),
      'boundary': _selectorRecord(boundary),
      'tierIndex': tierIndex,
    },
    TierAssignmentClue(:final subject, :final tierIndex) => {
      ...base,
      'subject': _selectorRecord(subject),
      'tierIndex': tierIndex,
    },
    SameTierClue(:final first, :final second) => {
      ...base,
      'first': _selectorRecord(first),
      'second': _selectorRecord(second),
    },
    AdjacentClue(
      :final subject,
      :final reference,
      :final tierIndex,
      :final direction,
    ) =>
      {
        ...base,
        'subject': _selectorRecord(subject),
        'reference': _selectorRecord(reference),
        'tierIndex': tierIndex,
        'direction': _adjacentDirectionCode(direction),
      },
    VerticalRelationClue(:final subject, :final reference, :final relation) => {
      ...base,
      'subject': _selectorRecord(subject),
      'reference': _selectorRecord(reference),
      'relation': _verticalRelationCode(relation),
    },
    NotAtEdgeClue(:final subject, :final tierIndex) => {
      ...base,
      'subject': _selectorRecord(subject),
      'tierIndex': tierIndex,
    },
    DistanceClue(
      :final first,
      :final second,
      :final tierIndex,
      :final booksBetween,
    ) =>
      {
        ...base,
        'first': _selectorRecord(first),
        'second': _selectorRecord(second),
        'tierIndex': tierIndex,
        'booksBetween': booksBetween,
      },
  };
}

Map<String, Object?> _selectorRecord(BookSelector selector) {
  return switch (selector) {
    BookIdSelector(:final bookId) => {'type': 'book_id', 'bookId': bookId},
    BookColorSelector(:final color) => {
      'type': 'color',
      'color': BookCode.color(color),
    },
    BookSymbolSelector(:final symbol) => {
      'type': 'symbol',
      'symbol': BookCode.symbol(symbol),
    },
    BookVisualSelector(:final color, :final symbol) => {
      'type': 'visual',
      'color': BookCode.color(color),
      'symbol': BookCode.symbol(symbol),
      'visualCode': BookCode.bookId(color: color, symbol: symbol),
    },
  };
}

String _profileCode(DifficultyProfileId id) {
  return switch (id) {
    DifficultyProfileId.intro => 'intro',
    DifficultyProfileId.singleTierFive => 'single_tier_five',
    DifficultyProfileId.singleTierSix => 'single_tier_six',
    DifficultyProfileId.twoTierFour => 'two_tier_four',
    DifficultyProfileId.twoTierFive => 'two_tier_five',
    DifficultyProfileId.twelveBookMixed => 'twelve_book_mixed',
    DifficultyProfileId.advancedEndless => 'advanced_endless',
    DifficultyProfileId.verticalIntro2x6 => 'vertical_intro_2x6',
    DifficultyProfileId.verticalNegative2x6 => 'vertical_negative_2x6',
    DifficultyProfileId.verticalThreeTier3x4 => 'vertical_three_tier_3x4',
    DifficultyProfileId.fullAdvanced3x4 => 'full_advanced_3x4',
  };
}

String _clueTypeCode(Clue clue) {
  return switch (clue) {
    TierAssignmentClue() => 'tier_assignment',
    EdgePositionClue() => 'edge_position',
    BothEdgesClue() => 'both_edges',
    RelativeOrderClue() => 'relative_order',
    AdjacentClue() => 'adjacent',
    BetweenClue() => 'between',
    SameTierClue() => 'same_tier',
    VerticalRelationClue() => 'vertical_relation',
    NotAtEdgeClue() => 'not_at_edge',
    DistanceClue() => 'distance',
  };
}

String _edgeCode(ShelfEdge edge) {
  return switch (edge) {
    ShelfEdge.left => 'left',
    ShelfEdge.right => 'right',
  };
}

String _horizontalRelationCode(HorizontalRelation relation) {
  return switch (relation) {
    HorizontalRelation.leftOf => 'left_of',
    HorizontalRelation.rightOf => 'right_of',
  };
}

String _adjacentDirectionCode(AdjacentDirection direction) {
  return switch (direction) {
    AdjacentDirection.immediatelyLeftOf => 'immediately_left_of',
    AdjacentDirection.immediatelyRightOf => 'immediately_right_of',
  };
}

String _verticalRelationCode(VerticalRelation relation) {
  return switch (relation) {
    VerticalRelation.immediatelyAbove => 'immediately_above',
    VerticalRelation.immediatelyBelow => 'immediately_below',
  };
}
