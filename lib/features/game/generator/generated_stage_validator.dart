import '../domain/book.dart';
import '../domain/book_placement.dart';
import '../domain/book_position.dart';
import '../domain/book_selector.dart';
import '../domain/book_selector_resolver.dart';
import '../domain/clue.dart';
import '../domain/clue_evaluator.dart';
import 'book_code.dart';
import 'book_instance_code.dart';
import 'book_swap_step.dart';
import 'difficulty_profile.dart';
import 'generated_stage.dart';
import 'generator_config.dart';
import 'puzzle_template_id.dart';
import 'stage_permutation_analyzer.dart';
import 'stage_seed_factory.dart';
import 'stage_validation_issue.dart';
import 'stage_validation_result.dart';
import 't04_tier_grouping_support.dart';
import 't05_tier_order_support.dart';
import 't06_layout_plan.dart';
import 't06_rule_profile_resolver.dart';

class GeneratedStageValidator {
  const GeneratedStageValidator({
    this.clueEvaluator = const ClueEvaluator(),
    this.selectorResolver = const BookSelectorResolver(),
    this.permutationAnalyzer = const StagePermutationAnalyzer(),
    this.stageSeedFactory = const StageSeedFactory(),
  });

  final ClueEvaluator clueEvaluator;
  final BookSelectorResolver selectorResolver;
  final StagePermutationAnalyzer permutationAnalyzer;
  final StageSeedFactory stageSeedFactory;

  StageValidationResult validate(GeneratedStage stage) {
    final issues = <StageValidationIssue>[];

    _validateTemplateAndSpec(stage, issues);
    _validateGenerationAttempt(stage, issues);
    _validatePlacements(
      placements: stage.targetPlacements,
      expectedCount: stage.totalBookCount,
      code: StageValidationIssueCode.invalidTargetPlacements,
      label: 'targetPlacements',
      stage: stage,
      issues: issues,
    );
    _validatePlacements(
      placements: stage.initialPlacements,
      expectedCount: stage.totalBookCount,
      code: StageValidationIssueCode.invalidInitialPlacements,
      label: 'initialPlacements',
      stage: stage,
      issues: issues,
    );
    _validateBookUniqueness(stage.targetPlacements, issues, 'target', stage);
    _validateBookUniqueness(stage.initialPlacements, issues, 'initial', stage);
    _validateBookSet(stage, issues);
    _validateTemplateTargetStructure(stage, issues);
    _validateClues(stage, issues);
    _validateTargetSatisfaction(stage, issues);
    _validateInitialIncomplete(stage, issues);
    _validateScrambleSeed(stage, issues);
    _validateSwapHistory(stage, issues);
    _validateT04InitialAndSwap(stage, issues);
    _validateT05InitialAndSwap(stage, issues);
    _validateT06InitialAndSwap(stage, issues);
    _validateReplay(stage, issues);
    _validateMinimumSwapDistance(stage, issues);

    return StageValidationResult(issues: issues);
  }

  void _validateGenerationAttempt(
    GeneratedStage stage,
    List<StageValidationIssue> issues,
  ) {
    final key = stage.generationAttemptKey;
    if (key.generatorVersion != stage.stageSpec.generatorVersion ||
        key.level != stage.stageSpec.level ||
        key.attempt < 0) {
      _add(
        issues,
        StageValidationIssueCode.invalidGenerationAttemptKey,
        'generationAttemptKey does not match StageSpec.',
      );
    }

    try {
      final expectedSeed = stageSeedFactory.create(key);
      if (stage.generationAttemptSeed < 1 ||
          stage.generationAttemptSeed > GeneratorConfig.uint32Mask ||
          stage.generationAttemptSeed != expectedSeed) {
        _add(
          issues,
          StageValidationIssueCode.invalidGenerationAttemptSeed,
          'generationAttemptSeed does not match generationAttemptKey.',
          stage.generationAttemptSeed.toString(),
        );
      }
    } on ArgumentError catch (error) {
      _add(
        issues,
        StageValidationIssueCode.invalidGenerationAttemptSeed,
        'generationAttemptSeed could not be validated: $error',
      );
    }

    if (stage.isFallback && key.attempt == 0) {
      _add(
        issues,
        StageValidationIssueCode.invalidFallbackMetadata,
        'Fallback stages must use generation attempt 1 or greater.',
      );
    }
  }

  void _validateTemplateAndSpec(
    GeneratedStage stage,
    List<StageValidationIssue> issues,
  ) {
    final spec = stage.stageSpec;
    final expectedVersion = spec.level <= 200
        ? GeneratorConfig.generatorVersion1
        : spec.level <= 400
        ? GeneratorConfig.generatorVersion2
        : null;
    if (expectedVersion == null ||
        spec.generatorVersion != expectedVersion ||
        stage.generatorVersion != expectedVersion) {
      _add(
        issues,
        StageValidationIssueCode.invalidGeneratorVersionLevelPair,
        'GeneratedStage level and generatorVersion do not match policy.',
      );
    }
    switch (stage.templateId) {
      case PuzzleTemplateId.t01AnchorChain:
        if (spec.level < 1 ||
            spec.generatorVersion < 1 ||
            spec.generationKey.attempt != 0 ||
            spec.tierCount != 1 ||
            spec.totalBookCount < 4 ||
            spec.totalBookCount > 6 ||
            spec.duplicateGroupCount != 0 ||
            spec.targetSwapCount < 1 ||
            spec.targetSwapCount > spec.totalBookCount - 1) {
          _add(
            issues,
            StageValidationIssueCode.invalidStageSpec,
            'StageSpec is outside T01 generated stage constraints.',
          );
        }
      case PuzzleTemplateId.t02EdgeSandwich:
        if (spec.level < 21 ||
            spec.level > 50 ||
            spec.generatorVersion < 1 ||
            spec.generationKey.attempt != 0 ||
            spec.tierCount != 1 ||
            spec.booksPerTier != 6 ||
            spec.totalBookCount != 6 ||
            spec.duplicateGroupCount != 1 ||
            spec.maxDuplicateCopies < 2 ||
            spec.clueCount < 4 ||
            spec.clueCount > 5 ||
            spec.targetSwapCount < 3 ||
            spec.targetSwapCount > 4) {
          _add(
            issues,
            StageValidationIssueCode.invalidStageSpec,
            'StageSpec is outside T02 generated stage constraints.',
          );
        }
      case PuzzleTemplateId.t03AdjacentBlocks:
        if (spec.level < 23 ||
            spec.level > 47 ||
            (spec.level - 23) % 4 != 0 ||
            spec.generatorVersion < 1 ||
            spec.generationKey.attempt != 0 ||
            spec.tierCount != 1 ||
            spec.booksPerTier != 6 ||
            spec.totalBookCount != 6 ||
            spec.duplicateGroupCount != 1 ||
            spec.maxDuplicateCopies < 2 ||
            spec.clueCount < 4 ||
            spec.clueCount > 5 ||
            spec.targetSwapCount < 3 ||
            spec.targetSwapCount > 4) {
          _add(
            issues,
            StageValidationIssueCode.invalidStageSpec,
            'StageSpec is outside T03 generated stage constraints.',
          );
        }
      case PuzzleTemplateId.t04TierGrouping:
        if (spec.level < 51 ||
            spec.level > 100 ||
            spec.generatorVersion < 1 ||
            spec.generationKey.attempt != 0 ||
            spec.tierCount != 2 ||
            spec.booksPerTier != 4 ||
            spec.totalBookCount != 8 ||
            (spec.duplicateGroupCount != 0 && spec.duplicateGroupCount != 1) ||
            spec.maxDuplicateCopies < 2 ||
            spec.clueCount < 4 ||
            spec.clueCount > 6 ||
            spec.targetSwapCount < 3 ||
            spec.targetSwapCount > 5) {
          _add(
            issues,
            StageValidationIssueCode.invalidStageSpec,
            'StageSpec is outside T04 generated stage constraints.',
          );
        }
      case PuzzleTemplateId.t05TierOrder:
        if (spec.level < 101 ||
            spec.level > 200 ||
            spec.generatorVersion < 1 ||
            spec.generationKey.attempt != 0 ||
            spec.tierCount != 2 ||
            spec.booksPerTier != 5 ||
            spec.totalBookCount != 10 ||
            (spec.duplicateGroupCount != 1 && spec.duplicateGroupCount != 2) ||
            spec.maxDuplicateCopies < 2 ||
            spec.clueCount < 5 ||
            spec.clueCount > 7 ||
            spec.targetSwapCount < 4 ||
            spec.targetSwapCount > 6) {
          _add(
            issues,
            StageValidationIssueCode.invalidStageSpec,
            'StageSpec is outside T05 generated stage constraints.',
          );
        }
      case PuzzleTemplateId.t06VerticalPair:
        if (spec.level < 201 ||
            spec.level > 400 ||
            spec.generatorVersion != GeneratorConfig.generatorVersion2 ||
            spec.generationKey.attempt != 0 ||
            spec.totalBookCount != 12 ||
            !((spec.tierCount == 2 && spec.booksPerTier == 6) ||
                (spec.tierCount == 3 && spec.booksPerTier == 4)) ||
            spec.duplicateGroupCount < 1 ||
            spec.duplicateGroupCount > 3 ||
            spec.maxDuplicateCopies != 2 ||
            spec.clueCount < 6 ||
            spec.clueCount > 8 ||
            spec.targetSwapCount < 6 ||
            spec.targetSwapCount > 8) {
          _add(
            issues,
            StageValidationIssueCode.invalidStageSpec,
            'StageSpec is outside T06 generated stage constraints.',
          );
        }
    }
  }

  void _validatePlacements({
    required List<BookPlacement> placements,
    required int expectedCount,
    required StageValidationIssueCode code,
    required String label,
    required GeneratedStage stage,
    required List<StageValidationIssue> issues,
  }) {
    if (placements.length != expectedCount) {
      _add(issues, code, '$label length does not match StageSpec.');
    }

    final positionKeys = <String>{};
    for (var index = 0; index < placements.length; index += 1) {
      final placement = placements[index];
      final book = placement.book;
      final position = placement.position;
      final expectedTierIndex = index ~/ stage.booksPerTier;
      final expectedSlotIndex = index % stage.booksPerTier;
      if (position.tierIndex < 0 ||
          position.tierIndex >= stage.tierCount ||
          position.slotIndex < 0 ||
          position.slotIndex >= stage.booksPerTier) {
        _add(
          issues,
          code,
          '$label contains an out-of-range position.',
          book.id,
        );
      }
      if (position.tierIndex != expectedTierIndex ||
          position.slotIndex != expectedSlotIndex) {
        _add(
          issues,
          code,
          '$label is not stored in canonical tier/slot order.',
          book.id,
        );
      }
      if (!positionKeys.add('${position.tierIndex}:${position.slotIndex}')) {
        _add(issues, code, '$label contains duplicate positions.', book.id);
      }
      if (book.id.isEmpty) {
        _add(issues, code, '$label contains an empty Book.id.');
      } else if (!_bookIdMatchesTemplate(book, stage.templateId)) {
        _add(
          issues,
          code,
          '$label contains a Book.id that does not match visual data.',
          book.id,
        );
      }
    }

    for (var tierIndex = 0; tierIndex < stage.tierCount; tierIndex += 1) {
      for (var slotIndex = 0; slotIndex < stage.booksPerTier; slotIndex += 1) {
        if (!positionKeys.contains('$tierIndex:$slotIndex')) {
          _add(
            issues,
            code,
            '$label is missing tier $tierIndex slot $slotIndex.',
          );
        }
      }
    }
  }

  void _validateBookUniqueness(
    List<BookPlacement> placements,
    List<StageValidationIssue> issues,
    String label,
    GeneratedStage stage,
  ) {
    final ids = <String>{};
    final visualCounts = <String, int>{};
    for (final placement in placements) {
      final book = placement.book;
      if (!ids.add(book.id)) {
        _add(
          issues,
          StageValidationIssueCode.duplicateBookId,
          '$label contains duplicate Book.id.',
          book.id,
        );
      }
      final visualKey = _visualKey(book);
      visualCounts.update(visualKey, (count) => count + 1, ifAbsent: () => 1);
    }

    switch (stage.templateId) {
      case PuzzleTemplateId.t01AnchorChain:
        for (final entry in visualCounts.entries) {
          if (entry.value > 1) {
            _add(
              issues,
              StageValidationIssueCode.duplicateVisualBook,
              '$label contains duplicate color + symbol.',
              entry.key,
            );
          }
        }
      case PuzzleTemplateId.t02EdgeSandwich:
      case PuzzleTemplateId.t03AdjacentBlocks:
        final duplicateGroups = visualCounts.entries
            .where((entry) => entry.value > 1)
            .toList();
        if (duplicateGroups.length != 1 || duplicateGroups.single.value != 2) {
          _add(
            issues,
            StageValidationIssueCode.invalidDuplicateStructure,
            '$label must contain exactly one duplicate visual pair.',
          );
        }
      case PuzzleTemplateId.t04TierGrouping:
        final duplicateGroups = visualCounts.entries
            .where((entry) => entry.value > 1)
            .toList();
        final expectedDuplicateGroups = stage.stageSpec.duplicateGroupCount;
        if (duplicateGroups.length != expectedDuplicateGroups ||
            duplicateGroups.any((entry) => entry.value != 2)) {
          _add(
            issues,
            StageValidationIssueCode.invalidDuplicateStructure,
            '$label duplicate visual structure does not match StageSpec.',
          );
        }
      case PuzzleTemplateId.t05TierOrder:
      case PuzzleTemplateId.t06VerticalPair:
        final duplicateGroups = visualCounts.entries
            .where((entry) => entry.value > 1)
            .toList();
        final expectedDuplicateGroups = stage.stageSpec.duplicateGroupCount;
        if (duplicateGroups.length != expectedDuplicateGroups ||
            duplicateGroups.any((entry) => entry.value != 2)) {
          _add(
            issues,
            StageValidationIssueCode.invalidDuplicateStructure,
            '$label duplicate visual structure does not match StageSpec.',
          );
        }
    }
  }

  void _validateBookSet(
    GeneratedStage stage,
    List<StageValidationIssue> issues,
  ) {
    final targetBooks = _bookMap(stage.targetPlacements);
    final initialBooks = _bookMap(stage.initialPlacements);
    var matches = targetBooks.length == initialBooks.length;
    for (final entry in targetBooks.entries) {
      final initialBook = initialBooks[entry.key];
      if (initialBook == null ||
          initialBook.color != entry.value.color ||
          initialBook.symbol != entry.value.symbol) {
        matches = false;
        break;
      }
    }
    if (!matches) {
      _add(
        issues,
        StageValidationIssueCode.mismatchedBookSet,
        'Target and initial placements do not contain the same books.',
      );
    }
  }

  void _validateClues(GeneratedStage stage, List<StageValidationIssue> issues) {
    final clueCountIsValid = switch (stage.templateId) {
      PuzzleTemplateId.t01AnchorChain =>
        stage.clues.length == stage.stageSpec.clueCount &&
            stage.clues.length >= 2 &&
            stage.clues.length <= stage.totalBookCount - 1,
      PuzzleTemplateId.t02EdgeSandwich =>
        stage.clues.length == stage.stageSpec.clueCount &&
            stage.clues.length >= 4 &&
            stage.clues.length <= 5,
      PuzzleTemplateId.t03AdjacentBlocks =>
        stage.clues.length == stage.stageSpec.clueCount &&
            stage.clues.length >= 4 &&
            stage.clues.length <= 5,
      PuzzleTemplateId.t04TierGrouping =>
        stage.clues.length == stage.stageSpec.clueCount &&
            stage.clues.length >= 4 &&
            stage.clues.length <= 6,
      PuzzleTemplateId.t05TierOrder =>
        stage.clues.length == stage.stageSpec.clueCount &&
            stage.clues.length >= 5 &&
            stage.clues.length <= 7,
      PuzzleTemplateId.t06VerticalPair =>
        stage.clues.length == stage.stageSpec.clueCount &&
            stage.clues.length >= 6 &&
            stage.clues.length <= 8,
    };
    if (!clueCountIsValid) {
      _add(
        issues,
        StageValidationIssueCode.invalidClueCount,
        'Clue count is outside StageSpec or template bounds.',
      );
    }

    final clueIds = <String>{};
    for (var index = 0; index < stage.clues.length; index += 1) {
      final clue = stage.clues[index];
      if (clue.id.isEmpty || !RegExp(r'^[a-z0-9_]+$').hasMatch(clue.id)) {
        _add(
          issues,
          StageValidationIssueCode.invalidClueId,
          'Clue.id has an invalid format.',
          clue.id,
        );
      }
      if (!clueIds.add(clue.id)) {
        _add(
          issues,
          StageValidationIssueCode.duplicateClueId,
          'Clue.id is duplicated.',
          clue.id,
        );
      }
      _validateClueStructure(
        stage: stage,
        index: index,
        clue: clue,
        issues: issues,
      );
      _validateClueSelectors(stage: stage, clue: clue, issues: issues);
    }
  }

  void _validateClueStructure({
    required GeneratedStage stage,
    required int index,
    required Clue clue,
    required List<StageValidationIssue> issues,
  }) {
    switch (stage.templateId) {
      case PuzzleTemplateId.t01AnchorChain:
        _validateT01ClueStructure(index: index, clue: clue, issues: issues);
      case PuzzleTemplateId.t02EdgeSandwich:
        _validateT02ClueStructure(
          stage: stage,
          index: index,
          clue: clue,
          issues: issues,
        );
      case PuzzleTemplateId.t03AdjacentBlocks:
        _validateT03ClueStructure(
          stage: stage,
          index: index,
          clue: clue,
          issues: issues,
        );
      case PuzzleTemplateId.t04TierGrouping:
        _validateT04ClueStructure(
          stage: stage,
          index: index,
          clue: clue,
          issues: issues,
        );
      case PuzzleTemplateId.t05TierOrder:
        _validateT05ClueStructure(
          stage: stage,
          index: index,
          clue: clue,
          issues: issues,
        );
      case PuzzleTemplateId.t06VerticalPair:
        _validateT06ClueStructure(
          stage: stage,
          index: index,
          clue: clue,
          issues: issues,
        );
    }
  }

  void _validateT01ClueStructure({
    required int index,
    required Clue clue,
    required List<StageValidationIssue> issues,
  }) {
    switch (clue) {
      case EdgePositionClue(:final subject, :final tierIndex, :final edge):
        if (index != 0 || tierIndex != 0 || edge != ShelfEdge.left) {
          _add(
            issues,
            StageValidationIssueCode.invalidClueStructure,
            'T01 first clue must be a left edge clue.',
            clue.id,
          );
        }
        _validateBookIdSelector(subject, clue.id, issues);
      case AdjacentClue(
        :final subject,
        :final reference,
        :final tierIndex,
        :final direction,
      ):
        if (index != 1 ||
            tierIndex != 0 ||
            direction != AdjacentDirection.immediatelyRightOf) {
          _add(
            issues,
            StageValidationIssueCode.invalidClueStructure,
            'T01 second clue must be an immediately-right-of clue.',
            clue.id,
          );
        }
        _validateBookIdSelector(subject, clue.id, issues);
        _validateBookIdSelector(reference, clue.id, issues);
      case RelativeOrderClue(
        :final subject,
        :final reference,
        :final tierIndex,
        :final relation,
      ):
        if (index < 2 ||
            tierIndex != 0 ||
            relation != HorizontalRelation.leftOf) {
          _add(
            issues,
            StageValidationIssueCode.invalidClueStructure,
            'T01 later clues must be left-of relative order clues.',
            clue.id,
          );
        }
        _validateBookIdSelector(subject, clue.id, issues);
        _validateBookIdSelector(reference, clue.id, issues);
      case BothEdgesClue():
        _add(
          issues,
          StageValidationIssueCode.invalidClueStructure,
          'T01 clues must not use BothEdgesClue.',
          clue.id,
        );
      case BetweenClue():
        _add(
          issues,
          StageValidationIssueCode.invalidClueStructure,
          'T01 clues must not use BetweenClue.',
          clue.id,
        );
      case TierAssignmentClue():
        _add(
          issues,
          StageValidationIssueCode.invalidClueStructure,
          'T01 clues must not use TierAssignmentClue.',
          clue.id,
        );
      case SameTierClue():
        _add(
          issues,
          StageValidationIssueCode.invalidClueStructure,
          'T01 clues must not use SameTierClue.',
          clue.id,
        );
      case VerticalRelationClue():
      case NotAtEdgeClue():
      case DistanceClue():
        _add(
          issues,
          StageValidationIssueCode.invalidClueStructure,
          'T01 clues must not use T06-only clue types.',
          clue.id,
        );
    }
  }

  void _validateT02ClueStructure({
    required GeneratedStage stage,
    required int index,
    required Clue clue,
    required List<StageValidationIssue> issues,
  }) {
    final shape = _t02TargetShape(stage.targetPlacements);
    if (shape == null) {
      _add(
        issues,
        StageValidationIssueCode.invalidT02ClueStructure,
        'T02 clue structure cannot be validated without a valid target.',
        clue.id,
      );
      return;
    }

    if (_matchesT02Clue(index: index, clue: clue, shape: shape)) {
      return;
    }

    _add(
      issues,
      StageValidationIssueCode.invalidT02ClueStructure,
      'T02 clue does not match the fixed clue sequence.',
      clue.id,
    );
  }

  void _validateT03ClueStructure({
    required GeneratedStage stage,
    required int index,
    required Clue clue,
    required List<StageValidationIssue> issues,
  }) {
    final shape = _t03TargetShape(stage.targetPlacements);
    if (shape == null) {
      _add(
        issues,
        StageValidationIssueCode.invalidT03ClueStructure,
        'T03 clue structure cannot be validated without a valid target.',
        clue.id,
      );
      return;
    }

    if (_matchesT03Clue(index: index, clue: clue, shape: shape)) {
      return;
    }

    _add(
      issues,
      StageValidationIssueCode.invalidT03ClueStructure,
      'T03 clue does not match the fixed clue sequence.',
      clue.id,
    );
  }

  void _validateT04ClueStructure({
    required GeneratedStage stage,
    required int index,
    required Clue clue,
    required List<StageValidationIssue> issues,
  }) {
    final shape = T04TierGroupingShape.fromPlacements(
      stage.targetPlacements,
      duplicateGroupCount: stage.stageSpec.duplicateGroupCount,
    );
    if (shape == null) {
      _add(
        issues,
        StageValidationIssueCode.invalidT04ClueStructure,
        'T04 clue structure cannot be validated without a valid target.',
        clue.id,
      );
      return;
    }

    if (_matchesT04Clue(index: index, clue: clue, shape: shape)) {
      return;
    }

    _add(
      issues,
      StageValidationIssueCode.invalidT04ClueStructure,
      'T04 clue does not match the fixed clue sequence.',
      clue.id,
    );
  }

  void _validateT05ClueStructure({
    required GeneratedStage stage,
    required int index,
    required Clue clue,
    required List<StageValidationIssue> issues,
  }) {
    final shape = T05TierOrderShape.fromPlacements(
      stage.targetPlacements,
      duplicateGroupCount: stage.stageSpec.duplicateGroupCount,
    );
    if (shape == null) {
      _add(
        issues,
        StageValidationIssueCode.invalidT05ClueStructure,
        'T05 clue structure cannot be validated without a valid target.',
        clue.id,
      );
      return;
    }

    if (_matchesT05Clue(index: index, clue: clue, shape: shape)) {
      return;
    }

    _add(
      issues,
      StageValidationIssueCode.invalidT05ClueStructure,
      'T05 clue does not match the fixed clue sequence.',
      clue.id,
    );
  }

  void _validateT06ClueStructure({
    required GeneratedStage stage,
    required int index,
    required Clue clue,
    required List<StageValidationIssue> issues,
  }) {
    final profile = const T06RuleProfileResolver().resolve(stage.level);
    final allowed = switch (profile.id) {
      DifficultyProfileId.verticalIntro2x6 => switch (index) {
        0 || 1 => clue is VerticalRelationClue,
        2 => clue is SameTierClue,
        3 => clue is RelativeOrderClue,
        4 => clue is AdjacentClue,
        5 => clue is TierAssignmentClue,
        _ => false,
      },
      DifficultyProfileId.verticalNegative2x6 => switch (index) {
        0 || 1 => clue is VerticalRelationClue,
        2 => clue is NotAtEdgeClue,
        3 => clue is SameTierClue,
        4 => clue is RelativeOrderClue,
        5 => clue is AdjacentClue,
        6 => clue is TierAssignmentClue,
        _ => false,
      },
      DifficultyProfileId.verticalThreeTier3x4 => switch (index) {
        0 || 1 || 2 || 3 => clue is VerticalRelationClue,
        4 => clue is NotAtEdgeClue,
        5 => clue is RelativeOrderClue,
        6 => clue is SameTierClue,
        _ => false,
      },
      DifficultyProfileId.fullAdvanced3x4 => switch (index) {
        0 || 1 || 2 || 3 => clue is VerticalRelationClue,
        4 => clue is NotAtEdgeClue,
        5 => clue is DistanceClue,
        6 => clue is RelativeOrderClue,
        7 => clue is SameTierClue,
        _ => false,
      },
      _ => false,
    };
    if (!allowed) {
      _add(
        issues,
        StageValidationIssueCode.invalidT06ClueStructure,
        'T06 clue does not match the profile clue sequence.',
        clue.id,
      );
      return;
    }
    switch (clue) {
      case VerticalRelationClue(:final subject, :final reference):
        _validateSingleTargetSelector(stage, subject, clue.id, issues);
        _validateSingleTargetSelector(stage, reference, clue.id, issues);
      case NotAtEdgeClue(:final subject):
        final resolved = selectorResolver.resolve(
          selector: subject,
          placements: stage.targetPlacements,
        );
        if (resolved.isEmpty) {
          _add(
            issues,
            StageValidationIssueCode.invalidT06ClueStructure,
            'T06 C09 selector must resolve at least one target book.',
            clue.id,
          );
        }
      case DistanceClue(:final first, :final second, :final booksBetween):
        if (booksBetween < 1) {
          _add(
            issues,
            StageValidationIssueCode.invalidT06ClueStructure,
            'T06 C10 booksBetween must be at least 1.',
            clue.id,
          );
        }
        _validateSingleTargetSelector(stage, first, clue.id, issues);
        _validateSingleTargetSelector(stage, second, clue.id, issues);
      default:
        return;
    }
  }

  void _validateSingleTargetSelector(
    GeneratedStage stage,
    BookSelector selector,
    String clueId,
    List<StageValidationIssue> issues,
  ) {
    final resolved = selectorResolver.resolve(
      selector: selector,
      placements: stage.targetPlacements,
    );
    if (resolved.length != 1) {
      _add(
        issues,
        StageValidationIssueCode.invalidT06ClueStructure,
        'T06 selector must resolve exactly one target book.',
        clueId,
      );
    }
  }

  void _validateBookIdSelector(
    BookSelector selector,
    String clueId,
    List<StageValidationIssue> issues,
  ) {
    if (selector is! BookIdSelector) {
      _add(
        issues,
        StageValidationIssueCode.invalidClueStructure,
        'T01 clues must use BookIdSelector.',
        clueId,
      );
    }
  }

  void _validateClueSelectors({
    required GeneratedStage stage,
    required Clue clue,
    required List<StageValidationIssue> issues,
  }) {
    for (final selector in _selectorsFor(clue)) {
      final targetResolved = selectorResolver.resolve(
        selector: selector,
        placements: stage.targetPlacements,
      );
      final initialResolved = selectorResolver.resolve(
        selector: selector,
        placements: stage.initialPlacements,
      );
      if (!_selectorCardinalityIsAllowed(
        templateId: stage.templateId,
        clue: clue,
        selector: selector,
        targetCount: targetResolved.length,
        initialCount: initialResolved.length,
      )) {
        _add(
          issues,
          StageValidationIssueCode.unresolvedClueSelector,
          'Clue selector resolves an invalid number of books.',
          clue.id,
        );
      }
    }
  }

  void _validateTargetSatisfaction(
    GeneratedStage stage,
    List<StageValidationIssue> issues,
  ) {
    if (!_allCluesSatisfied(
      clues: stage.clues,
      placements: stage.targetPlacements,
    )) {
      _add(
        issues,
        StageValidationIssueCode.targetDoesNotSatisfyAllClues,
        'Target placements do not satisfy every clue.',
      );
    }
  }

  void _validateInitialIncomplete(
    GeneratedStage stage,
    List<StageValidationIssue> issues,
  ) {
    if (_allCluesSatisfied(
      clues: stage.clues,
      placements: stage.initialPlacements,
    )) {
      _add(
        issues,
        StageValidationIssueCode.initialAlreadySatisfiesAllClues,
        'Initial placements already satisfy every clue.',
      );
    } else if (_hasSameTemplateOrder(stage)) {
      _add(
        issues,
        StageValidationIssueCode.initialAlreadySatisfiesAllClues,
        'Initial placements match target placements.',
      );
    }
  }

  void _validateScrambleSeed(
    GeneratedStage stage,
    List<StageValidationIssue> issues,
  ) {
    final expectedSeed = _expectedScrambleSeed(
      stage.generationAttemptSeed,
      stage.templateId,
    );
    if (stage.scrambleSeed < 1 ||
        stage.scrambleSeed > GeneratorConfig.uint32Mask ||
        stage.scrambleSeed != expectedSeed) {
      _add(
        issues,
        StageValidationIssueCode.invalidScrambleSeed,
        'Scramble seed does not match template seed rule.',
        stage.scrambleSeed.toString(),
      );
    }
  }

  void _validateSwapHistory(
    GeneratedStage stage,
    List<StageValidationIssue> issues,
  ) {
    if (stage.swapHistory.length != stage.targetSwapCount ||
        stage.swapHistory.isEmpty) {
      _add(
        issues,
        StageValidationIssueCode.invalidSwapHistoryCount,
        'swapHistory length does not match targetSwapCount.',
      );
    }

    for (var index = 0; index < stage.swapHistory.length; index += 1) {
      final step = stage.swapHistory[index];
      if (step.stepIndex != index) {
        _add(
          issues,
          StageValidationIssueCode.invalidSwapStep,
          'swapHistory stepIndex must be stored in 0-based order.',
          step.stepIndex.toString(),
        );
      }
      if (!_isValidSwapPosition(
            position: step.firstPosition,
            tierCount: stage.tierCount,
            booksPerTier: stage.booksPerTier,
          ) ||
          !_isValidSwapPosition(
            position: step.secondPosition,
            tierCount: stage.tierCount,
            booksPerTier: stage.booksPerTier,
          ) ||
          step.firstPosition == step.secondPosition) {
        _add(
          issues,
          StageValidationIssueCode.invalidSwapStep,
          'swapHistory contains an invalid swap position.',
          step.stepIndex.toString(),
        );
      }
    }

    _validateSwapBookRecords(stage, issues);
  }

  void _validateSwapBookRecords(
    GeneratedStage stage,
    List<StageValidationIssue> issues,
  ) {
    final sortedTarget = _sortedPlacements(stage.targetPlacements);
    final positions = [
      for (final placement in sortedTarget) placement.position,
    ];
    final workingBooks = [for (final placement in sortedTarget) placement.book];
    final sortedSteps = List<BookSwapStep>.of(stage.swapHistory)
      ..sort((left, right) => left.stepIndex.compareTo(right.stepIndex));

    for (final step in sortedSteps) {
      final firstIndex = _positionIndex(positions, step.firstPosition);
      final secondIndex = _positionIndex(positions, step.secondPosition);
      if (firstIndex == null ||
          secondIndex == null ||
          firstIndex == secondIndex) {
        continue;
      }
      final firstBook = workingBooks[firstIndex];
      final secondBook = workingBooks[secondIndex];
      if (firstBook.id != step.firstBookIdBeforeSwap ||
          secondBook.id != step.secondBookIdBeforeSwap) {
        _add(
          issues,
          StageValidationIssueCode.swapHistoryBookMismatch,
          'swapHistory Book ID record does not match replay state.',
          step.stepIndex.toString(),
        );
      }
      if (_visualKey(firstBook) == _visualKey(secondBook)) {
        _add(
          issues,
          StageValidationIssueCode.identicalVisualBookSwap,
          'swapHistory swaps visually identical books.',
          step.stepIndex.toString(),
        );
      }
      workingBooks[firstIndex] = secondBook;
      workingBooks[secondIndex] = firstBook;
    }
  }

  void _validateReplay(
    GeneratedStage stage,
    List<StageValidationIssue> issues,
  ) {
    try {
      final forward = permutationAnalyzer.replayForward(
        start: stage.targetPlacements,
        swapHistory: stage.swapHistory,
      );
      if (!permutationAnalyzer.hasSameBookOrder(
        first: forward,
        second: stage.initialPlacements,
      )) {
        _add(
          issues,
          StageValidationIssueCode.forwardReplayMismatch,
          'Forward replay does not match initial placements.',
        );
      }
    } catch (error) {
      _add(
        issues,
        StageValidationIssueCode.forwardReplayMismatch,
        'Forward replay failed: $error',
      );
    }

    try {
      final reverse = permutationAnalyzer.replayReverse(
        start: stage.initialPlacements,
        swapHistory: stage.swapHistory,
      );
      if (!permutationAnalyzer.hasSameBookOrder(
        first: reverse,
        second: stage.targetPlacements,
      )) {
        _add(
          issues,
          StageValidationIssueCode.reverseReplayMismatch,
          'Reverse replay does not match target placements.',
        );
      }
    } catch (error) {
      _add(
        issues,
        StageValidationIssueCode.reverseReplayMismatch,
        'Reverse replay failed: $error',
      );
    }
  }

  void _validateMinimumSwapDistance(
    GeneratedStage stage,
    List<StageValidationIssue> issues,
  ) {
    try {
      final distance = switch (stage.templateId) {
        PuzzleTemplateId.t01AnchorChain =>
          permutationAnalyzer.minimumSwapDistance(
            target: stage.targetPlacements,
            current: stage.initialPlacements,
          ),
        PuzzleTemplateId.t02EdgeSandwich =>
          permutationAnalyzer.minimumVisualSwapDistance(
            target: stage.targetPlacements,
            current: stage.initialPlacements,
          ),
        PuzzleTemplateId.t03AdjacentBlocks =>
          permutationAnalyzer.minimumVisualSwapDistance(
            target: stage.targetPlacements,
            current: stage.initialPlacements,
          ),
        PuzzleTemplateId.t04TierGrouping =>
          permutationAnalyzer.minimumVisualSwapDistance(
            target: stage.targetPlacements,
            current: stage.initialPlacements,
          ),
        PuzzleTemplateId.t05TierOrder =>
          permutationAnalyzer.minimumVisualSwapDistance(
            target: stage.targetPlacements,
            current: stage.initialPlacements,
          ),
        PuzzleTemplateId.t06VerticalPair =>
          permutationAnalyzer.minimumVisualSwapDistance(
            target: stage.targetPlacements,
            current: stage.initialPlacements,
          ),
      };
      if (distance != stage.targetSwapCount) {
        _add(
          issues,
          _minimumDistanceIssueCode(stage.templateId),
          'Minimum swap distance $distance does not match targetSwapCount '
          '${stage.targetSwapCount}.',
        );
      }
    } catch (error) {
      _add(
        issues,
        _minimumDistanceIssueCode(stage.templateId),
        'Minimum swap distance failed: $error',
      );
    }
  }

  void _validateT04InitialAndSwap(
    GeneratedStage stage,
    List<StageValidationIssue> issues,
  ) {
    if (stage.templateId != PuzzleTemplateId.t04TierGrouping) {
      return;
    }
    if (!_hasCrossTierSwap(stage.swapHistory)) {
      _add(
        issues,
        StageValidationIssueCode.invalidSwapStep,
        'T04 swapHistory must contain at least one cross-tier swap.',
      );
    }

    final tierAssignmentClues = [
      for (final clue in stage.clues)
        if (clue is TierAssignmentClue) clue,
    ];
    if (tierAssignmentClues.isEmpty) {
      _add(
        issues,
        StageValidationIssueCode.invalidT04ClueStructure,
        'T04 must include TierAssignmentClue candidates.',
      );
      return;
    }
    final hasUnsatisfiedTierAssignment = tierAssignmentClues.any(
      (clue) => !clueEvaluator.evaluate(
        clue: clue,
        placements: stage.initialPlacements,
      ),
    );
    if (!hasUnsatisfiedTierAssignment) {
      _add(
        issues,
        StageValidationIssueCode.invalidT04ClueStructure,
        'T04 initial placements must break at least one C01 clue.',
      );
    }
  }

  void _validateT05InitialAndSwap(
    GeneratedStage stage,
    List<StageValidationIssue> issues,
  ) {
    if (stage.templateId != PuzzleTemplateId.t05TierOrder) {
      return;
    }
    if (!_hasCrossTierSwap(stage.swapHistory)) {
      _add(
        issues,
        StageValidationIssueCode.invalidT05ScrambleQuality,
        'T05 swapHistory must contain at least one cross-tier swap.',
      );
    }

    final tierAssignmentClues = [
      for (final clue in stage.clues)
        if (clue is TierAssignmentClue) clue,
    ];
    if (tierAssignmentClues.isEmpty) {
      _add(
        issues,
        StageValidationIssueCode.invalidT05ClueStructure,
        'T05 must include TierAssignmentClue candidates.',
      );
      return;
    }
    final hasUnsatisfiedTierAssignment = tierAssignmentClues.any(
      (clue) => !clueEvaluator.evaluate(
        clue: clue,
        placements: stage.initialPlacements,
      ),
    );
    if (!hasUnsatisfiedTierAssignment) {
      _add(
        issues,
        StageValidationIssueCode.invalidT05ScrambleQuality,
        'T05 initial placements must break at least one C01 clue.',
      );
    }
    if (!_hasUnsatisfiedTierOrder(
      stage: stage,
      firstIndex: 0,
      secondIndex: 1,
    )) {
      _add(
        issues,
        StageValidationIssueCode.invalidT05ScrambleQuality,
        'T05 initial placements must break a top tier order clue.',
      );
    }
    if (!_hasUnsatisfiedTierOrder(
      stage: stage,
      firstIndex: 2,
      secondIndex: 3,
    )) {
      _add(
        issues,
        StageValidationIssueCode.invalidT05ScrambleQuality,
        'T05 initial placements must break a bottom tier order clue.',
      );
    }
  }

  void _validateT06InitialAndSwap(
    GeneratedStage stage,
    List<StageValidationIssue> issues,
  ) {
    if (stage.templateId != PuzzleTemplateId.t06VerticalPair) {
      return;
    }
    final profile = const T06RuleProfileResolver().resolve(stage.level);
    final crossTierCount = stage.swapHistory
        .where(
          (step) =>
              step.firstPosition.tierIndex != step.secondPosition.tierIndex,
        )
        .length;
    if (crossTierCount < profile.minimumCrossTierSwapCount) {
      _add(
        issues,
        StageValidationIssueCode.invalidT06ScrambleQuality,
        'T06 swapHistory does not include enough cross-tier swaps.',
      );
    }
    final initialSatisfied = clueEvaluator.evaluateAll(
      clues: stage.clues,
      placements: stage.initialPlacements,
    );
    if (stage.clues.length - initialSatisfied.length <
        profile.minimumUnsatisfiedClueCount) {
      _add(
        issues,
        StageValidationIssueCode.invalidT06ScrambleQuality,
        'T06 initial placements do not break enough clues.',
      );
    }
    if (!_hasInitialFalse<VerticalRelationClue>(stage, initialSatisfied)) {
      _add(
        issues,
        StageValidationIssueCode.invalidT06ScrambleQuality,
        'T06 initial placements must break at least one C08 clue.',
      );
    }
    if (profile.usesNotAtEdge &&
        !_hasInitialFalse<NotAtEdgeClue>(stage, initialSatisfied)) {
      _add(
        issues,
        StageValidationIssueCode.invalidT06ScrambleQuality,
        'T06 initial placements must break at least one C09 clue.',
      );
    }
    if (profile.usesDistance &&
        !_hasInitialFalse<DistanceClue>(stage, initialSatisfied)) {
      _add(
        issues,
        StageValidationIssueCode.invalidT06ScrambleQuality,
        'T06 initial placements must break the C10 clue.',
      );
    }
  }

  bool _hasInitialFalse<T extends Clue>(
    GeneratedStage stage,
    Set<String> initialSatisfied,
  ) {
    for (final clue in stage.clues) {
      if (clue is T && !initialSatisfied.contains(clue.id)) {
        return true;
      }
    }
    return false;
  }

  bool _hasUnsatisfiedTierOrder({
    required GeneratedStage stage,
    required int firstIndex,
    required int secondIndex,
  }) {
    if (stage.clues.length <= secondIndex) {
      return false;
    }
    final firstSatisfied = clueEvaluator.evaluate(
      clue: stage.clues[firstIndex],
      placements: stage.initialPlacements,
    );
    final secondSatisfied = clueEvaluator.evaluate(
      clue: stage.clues[secondIndex],
      placements: stage.initialPlacements,
    );
    return !(firstSatisfied && secondSatisfied);
  }

  bool _hasCrossTierSwap(List<BookSwapStep> swapHistory) {
    for (final step in swapHistory) {
      if (step.firstPosition.tierIndex != step.secondPosition.tierIndex) {
        return true;
      }
    }
    return false;
  }

  bool _allCluesSatisfied({
    required List<Clue> clues,
    required List<BookPlacement> placements,
  }) {
    final satisfiedIds = clueEvaluator.evaluateAll(
      clues: clues,
      placements: placements,
    );
    if (satisfiedIds.length != clues.length) {
      return false;
    }
    for (final clue in clues) {
      if (!satisfiedIds.contains(clue.id)) {
        return false;
      }
    }
    return true;
  }

  List<BookSelector> _selectorsFor(Clue clue) {
    return switch (clue) {
      EdgePositionClue(:final subject) => [subject],
      BothEdgesClue(:final subject) => [subject],
      AdjacentClue(:final subject, :final reference) => [subject, reference],
      RelativeOrderClue(:final subject, :final reference) => [
        subject,
        reference,
      ],
      BetweenClue(:final subject, :final boundary) => [subject, boundary],
      TierAssignmentClue(:final subject) => [subject],
      SameTierClue(:final first, :final second) => [first, second],
      VerticalRelationClue(:final subject, :final reference) => [
        subject,
        reference,
      ],
      NotAtEdgeClue(:final subject) => [subject],
      DistanceClue(:final first, :final second) => [first, second],
    };
  }

  bool _isValidSwapPosition({
    required BookPosition position,
    required int tierCount,
    required int booksPerTier,
  }) {
    return position.tierIndex >= 0 &&
        position.tierIndex < tierCount &&
        position.slotIndex >= 0 &&
        position.slotIndex < booksPerTier;
  }

  List<BookPlacement> _sortedPlacements(List<BookPlacement> placements) {
    final sorted = List<BookPlacement>.of(placements);
    sorted.sort(_comparePlacementPosition);
    return sorted;
  }

  int _comparePlacementPosition(BookPlacement left, BookPlacement right) {
    final tierComparison = left.position.tierIndex.compareTo(
      right.position.tierIndex,
    );
    if (tierComparison != 0) {
      return tierComparison;
    }
    return left.position.slotIndex.compareTo(right.position.slotIndex);
  }

  int? _positionIndex(List<BookPosition> positions, BookPosition position) {
    for (var index = 0; index < positions.length; index += 1) {
      if (positions[index] == position) {
        return index;
      }
    }
    return null;
  }

  Map<String, Book> _bookMap(List<BookPlacement> placements) {
    final result = <String, Book>{};
    for (final placement in placements) {
      result[placement.book.id] = placement.book;
    }
    return result;
  }

  String _visualKey(Book book) {
    return BookCode.bookId(color: book.color, symbol: book.symbol);
  }

  bool _bookIdMatchesTemplate(Book book, PuzzleTemplateId templateId) {
    return switch (templateId) {
      PuzzleTemplateId.t01AnchorChain =>
        book.id == BookCode.bookId(color: book.color, symbol: book.symbol),
      PuzzleTemplateId.t02EdgeSandwich => BookInstanceCode.matchesBook(book),
      PuzzleTemplateId.t03AdjacentBlocks => BookInstanceCode.matchesBook(book),
      PuzzleTemplateId.t04TierGrouping => BookInstanceCode.matchesBook(book),
      PuzzleTemplateId.t05TierOrder => BookInstanceCode.matchesBook(book),
      PuzzleTemplateId.t06VerticalPair => BookInstanceCode.matchesBook(book),
    };
  }

  void _validateTemplateTargetStructure(
    GeneratedStage stage,
    List<StageValidationIssue> issues,
  ) {
    switch (stage.templateId) {
      case PuzzleTemplateId.t01AnchorChain:
        return;
      case PuzzleTemplateId.t02EdgeSandwich:
        if (_t02TargetShape(stage.targetPlacements) == null) {
          _add(
            issues,
            StageValidationIssueCode.invalidT02TargetStructure,
            'T02 target must match the Edge Sandwich structure.',
          );
        }
      case PuzzleTemplateId.t03AdjacentBlocks:
        if (_t03TargetShape(stage.targetPlacements) == null) {
          _add(
            issues,
            StageValidationIssueCode.invalidT03TargetStructure,
            'T03 target must match the Adjacent Blocks structure.',
          );
        }
      case PuzzleTemplateId.t04TierGrouping:
        if (T04TierGroupingShape.fromPlacements(
              stage.targetPlacements,
              duplicateGroupCount: stage.stageSpec.duplicateGroupCount,
            ) ==
            null) {
          _add(
            issues,
            StageValidationIssueCode.invalidT04TargetStructure,
            'T04 target must match the Tier Grouping structure.',
          );
        }
      case PuzzleTemplateId.t05TierOrder:
        if (T05TierOrderShape.fromPlacements(
              stage.targetPlacements,
              duplicateGroupCount: stage.stageSpec.duplicateGroupCount,
            ) ==
            null) {
          _add(
            issues,
            StageValidationIssueCode.invalidT05TargetStructure,
            'T05 target must match the Tier Order structure.',
          );
        }
      case PuzzleTemplateId.t06VerticalPair:
        if (!_isValidT06Target(stage)) {
          _add(
            issues,
            StageValidationIssueCode.invalidT06TargetStructure,
            'T06 target must match the Vertical Pair structure.',
          );
        }
    }
  }

  bool _isValidT06Target(GeneratedStage stage) {
    if (stage.totalBookCount != 12 ||
        !((stage.tierCount == 2 && stage.booksPerTier == 6) ||
            (stage.tierCount == 3 && stage.booksPerTier == 4))) {
      return false;
    }
    final plan = T06LayoutPlan.fromStageSpec(stage.stageSpec);
    final duplicatePositionKeys = {
      for (final position in plan.duplicatePositionPairs)
        '${position.tierIndex}:${position.slotIndex}',
    };
    final byVisual = <String, List<BookPlacement>>{};
    for (final placement in stage.targetPlacements) {
      byVisual.putIfAbsent(_visualKey(placement.book), () => []).add(placement);
    }
    final duplicateGroups = byVisual.values
        .where((placements) => placements.length > 1)
        .toList();
    if (duplicateGroups.length != stage.stageSpec.duplicateGroupCount ||
        duplicateGroups.any((placements) => placements.length != 2)) {
      return false;
    }
    for (final group in duplicateGroups) {
      for (final placement in group) {
        final key =
            '${placement.position.tierIndex}:${placement.position.slotIndex}';
        if (!duplicatePositionKeys.contains(key)) {
          return false;
        }
      }
    }
    for (final placement in stage.targetPlacements) {
      if (plan.verticalAnchorColumns.contains(placement.position.slotIndex) &&
          (byVisual[_visualKey(placement.book)]?.length ?? 0) != 1) {
        return false;
      }
    }
    return true;
  }

  _T02TargetShape? _t02TargetShape(List<BookPlacement> placements) {
    final sorted = _sortedPlacements(placements);
    if (sorted.length != 6) {
      return null;
    }
    for (var index = 0; index < sorted.length; index += 1) {
      if (sorted[index].position.tierIndex != 0 ||
          sorted[index].position.slotIndex != index) {
        return null;
      }
    }

    final edgeLeft = sorted[0].book;
    final fillerA = sorted[1].book;
    final fillerB = sorted[2].book;
    final duplicateCopy01 = sorted[3].book;
    final duplicateCopy02 = sorted[4].book;
    final edgeRight = sorted[5].book;

    if (edgeLeft.color != edgeRight.color ||
        edgeLeft.symbol == edgeRight.symbol) {
      return null;
    }
    if (_visualKey(duplicateCopy01) != _visualKey(duplicateCopy02)) {
      return null;
    }
    if (duplicateCopy01.id !=
            BookInstanceCode.duplicateCopyId(
              color: duplicateCopy01.color,
              symbol: duplicateCopy01.symbol,
              copyNumber: 1,
            ) ||
        duplicateCopy02.id !=
            BookInstanceCode.duplicateCopyId(
              color: duplicateCopy02.color,
              symbol: duplicateCopy02.symbol,
              copyNumber: 2,
            )) {
      return null;
    }
    if (duplicateCopy01.color == edgeLeft.color ||
        fillerA.color == edgeLeft.color ||
        fillerA.color == duplicateCopy01.color ||
        fillerB.color == edgeLeft.color ||
        fillerB.color == duplicateCopy01.color ||
        fillerB.color == fillerA.color) {
      return null;
    }
    return _T02TargetShape(
      edgeLeft: edgeLeft,
      fillerA: fillerA,
      fillerB: fillerB,
      duplicateCopy01: duplicateCopy01,
      duplicateCopy02: duplicateCopy02,
      edgeRight: edgeRight,
    );
  }

  _T03TargetShape? _t03TargetShape(List<BookPlacement> placements) {
    final sorted = _sortedPlacements(placements);
    if (sorted.length != 6) {
      return null;
    }
    for (var index = 0; index < sorted.length; index += 1) {
      if (sorted[index].position.tierIndex != 0 ||
          sorted[index].position.slotIndex != index) {
        return null;
      }
    }

    final blockAFirst = sorted[0].book;
    final blockAMiddle = sorted[1].book;
    final blockALast = sorted[2].book;
    final duplicateCopy01 = sorted[3].book;
    final duplicateCopy02 = sorted[4].book;
    final blockBEnd = sorted[5].book;

    if (blockAFirst.id !=
            BookCode.bookId(
              color: blockAFirst.color,
              symbol: blockAFirst.symbol,
            ) ||
        blockAMiddle.id !=
            BookCode.bookId(
              color: blockAMiddle.color,
              symbol: blockAMiddle.symbol,
            ) ||
        blockALast.id !=
            BookCode.bookId(
              color: blockALast.color,
              symbol: blockALast.symbol,
            ) ||
        blockBEnd.id !=
            BookCode.bookId(color: blockBEnd.color, symbol: blockBEnd.symbol)) {
      return null;
    }
    if (_visualKey(duplicateCopy01) != _visualKey(duplicateCopy02)) {
      return null;
    }
    if (duplicateCopy01.id !=
            BookInstanceCode.duplicateCopyId(
              color: duplicateCopy01.color,
              symbol: duplicateCopy01.symbol,
              copyNumber: 1,
            ) ||
        duplicateCopy02.id !=
            BookInstanceCode.duplicateCopyId(
              color: duplicateCopy02.color,
              symbol: duplicateCopy02.symbol,
              copyNumber: 2,
            )) {
      return null;
    }
    final colors = {
      blockAFirst.color,
      blockAMiddle.color,
      blockALast.color,
      duplicateCopy01.color,
      blockBEnd.color,
    };
    if (colors.length != 5) {
      return null;
    }

    return _T03TargetShape(
      blockAFirst: blockAFirst,
      blockAMiddle: blockAMiddle,
      blockALast: blockALast,
      duplicateCopy01: duplicateCopy01,
      duplicateCopy02: duplicateCopy02,
      blockBEnd: blockBEnd,
    );
  }

  bool _matchesT02Clue({
    required int index,
    required Clue clue,
    required _T02TargetShape shape,
  }) {
    switch (index) {
      case 0:
        return clue is BothEdgesClue &&
            clue.tierIndex == 0 &&
            clue.subject == BookColorSelector(color: shape.edgeColor) &&
            clue.id ==
                't02_c03_00_${BookCode.color(shape.edgeColor)}_both_edges';
      case 1:
        return clue is BetweenClue &&
            clue.tierIndex == 0 &&
            clue.subject == BookColorSelector(color: shape.duplicateColor) &&
            clue.boundary == BookColorSelector(color: shape.edgeColor) &&
            clue.id ==
                't02_c06_01_${BookCode.color(shape.duplicateColor)}_between_${BookCode.color(shape.edgeColor)}';
      case 2:
        return clue is AdjacentClue &&
            clue.tierIndex == 0 &&
            clue.direction == AdjacentDirection.immediatelyRightOf &&
            clue.subject == BookIdSelector(bookId: shape.fillerB.id) &&
            clue.reference == BookIdSelector(bookId: shape.fillerA.id) &&
            clue.id ==
                't02_c05_02_${shape.fillerB.id}_immediately_right_of_${shape.fillerA.id}';
      case 3:
        return clue is RelativeOrderClue &&
            clue.tierIndex == 0 &&
            clue.relation == HorizontalRelation.leftOf &&
            clue.subject == BookIdSelector(bookId: shape.edgeLeft.id) &&
            clue.reference == BookIdSelector(bookId: shape.edgeRight.id) &&
            clue.id ==
                't02_c04_03_${shape.edgeLeft.id}_left_of_${shape.edgeRight.id}';
      case 4:
        return clue is RelativeOrderClue &&
            clue.tierIndex == 0 &&
            clue.relation == HorizontalRelation.leftOf &&
            clue.subject == BookIdSelector(bookId: shape.fillerB.id) &&
            clue.reference == BookColorSelector(color: shape.duplicateColor) &&
            clue.id ==
                't02_c04_04_${shape.fillerB.id}_left_of_${BookCode.color(shape.duplicateColor)}_group';
      default:
        return false;
    }
  }

  bool _matchesT03Clue({
    required int index,
    required Clue clue,
    required _T03TargetShape shape,
  }) {
    final duplicateColorCode = BookCode.color(shape.duplicateColor);
    switch (index) {
      case 0:
        return clue is AdjacentClue &&
            clue.tierIndex == 0 &&
            clue.direction == AdjacentDirection.immediatelyRightOf &&
            clue.subject == BookIdSelector(bookId: shape.blockAMiddle.id) &&
            clue.reference == BookIdSelector(bookId: shape.blockAFirst.id) &&
            clue.id ==
                't03_c05_00_${shape.blockAMiddle.id}_immediately_right_of_${shape.blockAFirst.id}';
      case 1:
        return clue is AdjacentClue &&
            clue.tierIndex == 0 &&
            clue.direction == AdjacentDirection.immediatelyRightOf &&
            clue.subject == BookIdSelector(bookId: shape.blockALast.id) &&
            clue.reference == BookIdSelector(bookId: shape.blockAMiddle.id) &&
            clue.id ==
                't03_c05_01_${shape.blockALast.id}_immediately_right_of_${shape.blockAMiddle.id}';
      case 2:
        return clue is AdjacentClue &&
            clue.tierIndex == 0 &&
            clue.direction == AdjacentDirection.immediatelyRightOf &&
            clue.subject == BookIdSelector(bookId: shape.blockBEnd.id) &&
            clue.reference == BookColorSelector(color: shape.duplicateColor) &&
            clue.id ==
                't03_c05_02_${shape.blockBEnd.id}_immediately_right_of_${duplicateColorCode}_group';
      case 3:
        return clue is RelativeOrderClue &&
            clue.tierIndex == 0 &&
            clue.relation == HorizontalRelation.leftOf &&
            clue.subject == BookIdSelector(bookId: shape.blockALast.id) &&
            clue.reference == BookColorSelector(color: shape.duplicateColor) &&
            clue.id ==
                't03_c04_03_${shape.blockALast.id}_left_of_${duplicateColorCode}_group';
      case 4:
        return clue is RelativeOrderClue &&
            clue.tierIndex == 0 &&
            clue.relation == HorizontalRelation.leftOf &&
            clue.subject == BookIdSelector(bookId: shape.blockAFirst.id) &&
            clue.reference == BookIdSelector(bookId: shape.blockBEnd.id) &&
            clue.id ==
                't03_c04_04_${shape.blockAFirst.id}_left_of_${shape.blockBEnd.id}';
      default:
        return false;
    }
  }

  bool _matchesT04Clue({
    required int index,
    required Clue clue,
    required T04TierGroupingShape shape,
  }) {
    final topEdgeColorCode = BookCode.color(shape.topEdgeColor);
    final topMiddleColorCode = BookCode.color(shape.topMiddleColor);
    final bottomEdgeColorCode = BookCode.color(shape.bottomEdgeColor);
    switch (index) {
      case 0:
        return clue is TierAssignmentClue &&
            clue.tierIndex == 0 &&
            clue.subject == BookColorSelector(color: shape.topEdgeColor) &&
            clue.id == 't04_c01_00_${topEdgeColorCode}_tier_0';
      case 1:
        return clue is TierAssignmentClue &&
            clue.tierIndex == 1 &&
            clue.subject == BookColorSelector(color: shape.bottomEdgeColor) &&
            clue.id == 't04_c01_01_${bottomEdgeColorCode}_tier_1';
      case 2:
        return clue is BothEdgesClue &&
            clue.tierIndex == 0 &&
            clue.subject == BookColorSelector(color: shape.topEdgeColor) &&
            clue.id == 't04_c03_02_${topEdgeColorCode}_both_edges_tier_0';
      case 3:
        return clue is BetweenClue &&
            clue.tierIndex == 0 &&
            clue.subject == BookColorSelector(color: shape.topMiddleColor) &&
            clue.boundary == BookColorSelector(color: shape.topEdgeColor) &&
            clue.id ==
                't04_c06_03_${topMiddleColorCode}_between_${topEdgeColorCode}_tier_0';
      case 4:
        return clue is SameTierClue &&
            clue.first == BookIdSelector(bookId: shape.bottomInnerLeft.id) &&
            clue.second == BookIdSelector(bookId: shape.bottomInnerRight.id) &&
            clue.id ==
                't04_c07_04_${shape.bottomInnerLeft.id}_same_tier_as_${shape.bottomInnerRight.id}';
      case 5:
        return clue is RelativeOrderClue &&
            clue.tierIndex == 1 &&
            clue.relation == HorizontalRelation.leftOf &&
            clue.subject == BookIdSelector(bookId: shape.bottomInnerLeft.id) &&
            clue.reference ==
                BookIdSelector(bookId: shape.bottomInnerRight.id) &&
            clue.id ==
                't04_c04_05_${shape.bottomInnerLeft.id}_left_of_${shape.bottomInnerRight.id}_tier_1';
      default:
        return false;
    }
  }

  bool _matchesT05Clue({
    required int index,
    required Clue clue,
    required T05TierOrderShape shape,
  }) {
    final topEdgeColorCode = BookCode.color(shape.topEdgeColor);
    final topBlockColorCode = BookCode.color(shape.topBlockColor);
    final bottomEdgeColorCode = BookCode.color(shape.bottomEdgeColor);
    final bottomBlockColorCode = BookCode.color(shape.bottomBlockColor);
    switch (index) {
      case 0:
        return clue is BothEdgesClue &&
            clue.tierIndex == 0 &&
            clue.subject == BookColorSelector(color: shape.topEdgeColor) &&
            clue.id == 't05_c03_00_${topEdgeColorCode}_both_edges_tier_0';
      case 1:
        return clue is AdjacentClue &&
            clue.tierIndex == 0 &&
            clue.direction == AdjacentDirection.immediatelyRightOf &&
            clue.subject == BookIdSelector(bookId: shape.topCenter.id) &&
            clue.reference == BookColorSelector(color: shape.topBlockColor) &&
            clue.id ==
                't05_c05_01_${shape.topCenter.id}_immediately_right_of_${topBlockColorCode}_group_tier_0';
      case 2:
        return clue is BothEdgesClue &&
            clue.tierIndex == 1 &&
            clue.subject == BookColorSelector(color: shape.bottomEdgeColor) &&
            clue.id == 't05_c03_02_${bottomEdgeColorCode}_both_edges_tier_1';
      case 3:
        return clue is AdjacentClue &&
            clue.tierIndex == 1 &&
            clue.direction == AdjacentDirection.immediatelyRightOf &&
            clue.subject == BookIdSelector(bookId: shape.bottomCenter.id) &&
            clue.reference ==
                BookColorSelector(color: shape.bottomBlockColor) &&
            clue.id ==
                't05_c05_03_${shape.bottomCenter.id}_immediately_right_of_${bottomBlockColorCode}_group_tier_1';
      case 4:
        return clue is TierAssignmentClue &&
            clue.tierIndex == 0 &&
            clue.subject == BookColorSelector(color: shape.topBlockColor) &&
            clue.id == 't05_c01_04_${topBlockColorCode}_tier_0';
      case 5:
        return clue is TierAssignmentClue &&
            clue.tierIndex == 1 &&
            clue.subject == BookColorSelector(color: shape.bottomBlockColor) &&
            clue.id == 't05_c01_05_${bottomBlockColorCode}_tier_1';
      case 6:
        return clue is RelativeOrderClue &&
            clue.tierIndex == 1 &&
            clue.relation == HorizontalRelation.leftOf &&
            clue.subject == BookColorSelector(color: shape.bottomBlockColor) &&
            clue.reference == BookIdSelector(bookId: shape.bottomCenter.id) &&
            clue.id ==
                't05_c04_06_${bottomBlockColorCode}_group_left_of_${shape.bottomCenter.id}_tier_1';
      default:
        return false;
    }
  }

  bool _selectorCardinalityIsAllowed({
    required PuzzleTemplateId templateId,
    required Clue clue,
    required BookSelector selector,
    required int targetCount,
    required int initialCount,
  }) {
    if (targetCount == 0 || initialCount == 0) {
      return false;
    }
    switch (templateId) {
      case PuzzleTemplateId.t01AnchorChain:
        return targetCount == 1 && initialCount == 1;
      case PuzzleTemplateId.t02EdgeSandwich:
        if (selector is BookIdSelector) {
          return targetCount == 1 && initialCount == 1;
        }
        if (clue is BothEdgesClue && identical(selector, clue.subject)) {
          return targetCount == 2 && initialCount == 2;
        }
        if (clue is BetweenClue &&
            (identical(selector, clue.subject) ||
                identical(selector, clue.boundary))) {
          return targetCount == 2 && initialCount == 2;
        }
        if (clue is RelativeOrderClue &&
            identical(selector, clue.reference) &&
            selector is BookColorSelector) {
          return targetCount == 2 && initialCount == 2;
        }
        return false;
      case PuzzleTemplateId.t03AdjacentBlocks:
        if (selector is BookIdSelector) {
          return targetCount == 1 && initialCount == 1;
        }
        if (clue is AdjacentClue &&
            identical(selector, clue.reference) &&
            selector is BookColorSelector) {
          return targetCount == 2 && initialCount == 2;
        }
        if (clue is RelativeOrderClue &&
            identical(selector, clue.reference) &&
            selector is BookColorSelector) {
          return targetCount == 2 && initialCount == 2;
        }
        return false;
      case PuzzleTemplateId.t04TierGrouping:
        if (selector is BookIdSelector) {
          return targetCount == 1 && initialCount == 1;
        }
        if (clue is TierAssignmentClue &&
            identical(selector, clue.subject) &&
            selector is BookColorSelector) {
          return targetCount == 2 && initialCount == 2;
        }
        if (clue is BothEdgesClue &&
            identical(selector, clue.subject) &&
            selector is BookColorSelector) {
          return targetCount == 2 && initialCount == 2;
        }
        if (clue is BetweenClue &&
            (identical(selector, clue.subject) ||
                identical(selector, clue.boundary)) &&
            selector is BookColorSelector) {
          return targetCount == 2 && initialCount == 2;
        }
        return false;
      case PuzzleTemplateId.t05TierOrder:
        if (selector is BookIdSelector) {
          return targetCount == 1 && initialCount == 1;
        }
        if (clue is BothEdgesClue &&
            identical(selector, clue.subject) &&
            selector is BookColorSelector) {
          return targetCount == 2 && initialCount == 2;
        }
        if (clue is AdjacentClue &&
            identical(selector, clue.subject) &&
            selector is BookIdSelector) {
          return targetCount == 1 && initialCount == 1;
        }
        if (clue is AdjacentClue &&
            identical(selector, clue.reference) &&
            selector is BookColorSelector) {
          return targetCount == 2 && initialCount == 2;
        }
        if (clue is TierAssignmentClue &&
            identical(selector, clue.subject) &&
            selector is BookColorSelector) {
          return targetCount == 2 && initialCount == 2;
        }
        if (clue is RelativeOrderClue &&
            identical(selector, clue.subject) &&
            selector is BookColorSelector) {
          return targetCount == 2 && initialCount == 2;
        }
        if (clue is RelativeOrderClue &&
            identical(selector, clue.reference) &&
            selector is BookIdSelector) {
          return targetCount == 1 && initialCount == 1;
        }
        return false;
      case PuzzleTemplateId.t06VerticalPair:
        if (selector is BookIdSelector) {
          return targetCount == 1 && initialCount == 1;
        }
        if (selector is BookVisualSelector) {
          return targetCount >= 1 && initialCount >= 1;
        }
        return false;
    }
  }

  bool _hasSameTemplateOrder(GeneratedStage stage) {
    return switch (stage.templateId) {
      PuzzleTemplateId.t01AnchorChain => permutationAnalyzer.hasSameBookOrder(
        first: stage.targetPlacements,
        second: stage.initialPlacements,
      ),
      PuzzleTemplateId.t02EdgeSandwich =>
        permutationAnalyzer.hasSameVisualOrder(
          first: stage.targetPlacements,
          second: stage.initialPlacements,
        ),
      PuzzleTemplateId.t03AdjacentBlocks =>
        permutationAnalyzer.hasSameVisualOrder(
          first: stage.targetPlacements,
          second: stage.initialPlacements,
        ),
      PuzzleTemplateId.t04TierGrouping =>
        permutationAnalyzer.hasSameVisualOrder(
          first: stage.targetPlacements,
          second: stage.initialPlacements,
        ),
      PuzzleTemplateId.t05TierOrder => permutationAnalyzer.hasSameVisualOrder(
        first: stage.targetPlacements,
        second: stage.initialPlacements,
      ),
      PuzzleTemplateId.t06VerticalPair =>
        permutationAnalyzer.hasSameVisualOrder(
          first: stage.targetPlacements,
          second: stage.initialPlacements,
        ),
    };
  }

  StageValidationIssueCode _minimumDistanceIssueCode(
    PuzzleTemplateId templateId,
  ) {
    return switch (templateId) {
      PuzzleTemplateId.t01AnchorChain =>
        StageValidationIssueCode.minimumSwapDistanceMismatch,
      PuzzleTemplateId.t02EdgeSandwich =>
        StageValidationIssueCode.minimumVisualSwapDistanceMismatch,
      PuzzleTemplateId.t03AdjacentBlocks =>
        StageValidationIssueCode.minimumVisualSwapDistanceMismatch,
      PuzzleTemplateId.t04TierGrouping =>
        StageValidationIssueCode.minimumVisualSwapDistanceMismatch,
      PuzzleTemplateId.t05TierOrder =>
        StageValidationIssueCode.minimumVisualSwapDistanceMismatch,
      PuzzleTemplateId.t06VerticalPair =>
        StageValidationIssueCode.minimumVisualSwapDistanceMismatch,
    };
  }

  int _expectedScrambleSeed(int stageSeed, PuzzleTemplateId templateId) {
    final salt = switch (templateId) {
      PuzzleTemplateId.t01AnchorChain => GeneratorConfig.t01ScrambleSalt,
      PuzzleTemplateId.t02EdgeSandwich => GeneratorConfig.t02ScrambleSalt,
      PuzzleTemplateId.t03AdjacentBlocks => GeneratorConfig.t03ScrambleSalt,
      PuzzleTemplateId.t04TierGrouping => GeneratorConfig.t04ScrambleSalt,
      PuzzleTemplateId.t05TierOrder => GeneratorConfig.t05ScrambleSalt,
      PuzzleTemplateId.t06VerticalPair => GeneratorConfig.t06ScrambleSalt,
    };
    final value = (stageSeed ^ salt) & GeneratorConfig.uint32Mask;
    if (value == 0) {
      return GeneratorConfig.zeroSeedFallback;
    }
    return value;
  }

  void _add(
    List<StageValidationIssue> issues,
    StageValidationIssueCode code,
    String message, [
    String? relatedId,
  ]) {
    issues.add(
      StageValidationIssue(code: code, message: message, relatedId: relatedId),
    );
  }
}

class _T02TargetShape {
  const _T02TargetShape({
    required this.edgeLeft,
    required this.fillerA,
    required this.fillerB,
    required this.duplicateCopy01,
    required this.duplicateCopy02,
    required this.edgeRight,
  });

  final Book edgeLeft;
  final Book fillerA;
  final Book fillerB;
  final Book duplicateCopy01;
  final Book duplicateCopy02;
  final Book edgeRight;

  BookColor get edgeColor => edgeLeft.color;

  BookColor get duplicateColor => duplicateCopy01.color;
}

class _T03TargetShape {
  const _T03TargetShape({
    required this.blockAFirst,
    required this.blockAMiddle,
    required this.blockALast,
    required this.duplicateCopy01,
    required this.duplicateCopy02,
    required this.blockBEnd,
  });

  final Book blockAFirst;
  final Book blockAMiddle;
  final Book blockALast;
  final Book duplicateCopy01;
  final Book duplicateCopy02;
  final Book blockBEnd;

  BookColor get duplicateColor => duplicateCopy01.color;
}
