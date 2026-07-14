import 'package:flutter_test/flutter_test.dart';

import 'package:booklogic/features/game/domain/book.dart';
import 'package:booklogic/features/game/domain/book_placement.dart';
import 'package:booklogic/features/game/domain/book_position.dart';
import 'package:booklogic/features/game/domain/book_selector.dart';
import 'package:booklogic/features/game/domain/clue.dart';
import 'package:booklogic/features/game/generator/book_catalog.dart';
import 'package:booklogic/features/game/generator/book_swap_step.dart';
import 'package:booklogic/features/game/generator/generated_stage.dart';
import 'package:booklogic/features/game/generator/generated_stage_factory.dart';
import 'package:booklogic/features/game/generator/generated_stage_validator.dart';
import 'package:booklogic/features/game/generator/puzzle_template_id.dart';
import 'package:booklogic/features/game/generator/stage_permutation_analyzer.dart';
import 'package:booklogic/features/game/generator/stage_spec_factory.dart';
import 'package:booklogic/features/game/generator/stage_validation_issue.dart';
import 'package:booklogic/features/game/generator/stage_validation_result.dart';
import 'package:booklogic/features/game/generator/t01_anchor_chain_clue_factory.dart';
import 'package:booklogic/features/game/generator/t01_anchor_chain_scrambler.dart';
import 'package:booklogic/features/game/generator/t01_anchor_chain_solution_factory.dart';
import 'package:booklogic/features/game/generator/template_scramble_result.dart';

void main() {
  group('GeneratedStage', () {
    test('exposes generated data through getters and protects clues', () {
      final fixture = _stageFixture(1);
      final sourceClues = List<Clue>.of(fixture.clues);
      final stage = GeneratedStage(
        scrambleResult: fixture.scrambleResult,
        clues: sourceClues,
      );

      sourceClues.removeLast();

      expect(stage.scrambleResult, fixture.scrambleResult);
      expect(stage.clues, fixture.clues);
      expect(stage.solution, fixture.solution);
      expect(stage.stageSpec, fixture.spec);
      expect(stage.templateId, PuzzleTemplateId.t01AnchorChain);
      expect(stage.targetPlacements, fixture.solution.targetPlacements);
      expect(stage.initialPlacements, fixture.scrambleResult.initialPlacements);
      expect(stage.swapHistory, fixture.scrambleResult.swapHistory);
      expect(stage.scrambleSeed, 1556238703);
      expect(stage.level, 1);
      expect(stage.generatorVersion, 1);
      expect(stage.tierCount, 1);
      expect(stage.booksPerTier, 4);
      expect(stage.totalBookCount, 4);
      expect(stage.clueCount, 3);
      expect(stage.targetSwapCount, 2);
      expect(() => stage.clues.add(stage.clues.first), throwsUnsupportedError);
      expect(
        () => stage.clues.remove(stage.clues.first),
        throwsUnsupportedError,
      );
      expect(() => stage.clues.clear(), throwsUnsupportedError);
      expect(
        () => stage.clues.sort((left, right) => left.id.compareTo(right.id)),
        throwsUnsupportedError,
      );
      expect(() => stage.clues.shuffle(), throwsUnsupportedError);
      expect(
        stage,
        GeneratedStage(
          scrambleResult: fixture.scrambleResult,
          clues: fixture.clues,
        ),
      );
      expect(
        stage,
        isNot(
          GeneratedStage(
            scrambleResult: fixture.scrambleResult,
            clues: fixture.clues.reversed.toList(),
          ),
        ),
      );
      expect(stage.toString(), contains('level: 1'));
      expect(stage.toString(), contains('generatorVersion: 1'));
      expect(stage.toString(), contains('scrambleSeed: 1556238703'));
    });
  });

  group('StageValidationResult', () {
    test('stores immutable issues and reports status', () {
      final issues = [
        const StageValidationIssue(
          code: StageValidationIssueCode.invalidClueCount,
          message: 'bad count',
          relatedId: 'clues',
        ),
      ];
      final invalid = StageValidationResult(issues: issues);
      issues.clear();
      final valid = StageValidationResult(issues: const []);

      expect(valid.isValid, isTrue);
      expect(valid.isInvalid, isFalse);
      expect(valid.issueCount, 0);
      expect(invalid.isValid, isFalse);
      expect(invalid.isInvalid, isTrue);
      expect(invalid.issueCount, 1);
      expect(
        invalid.containsCode(StageValidationIssueCode.invalidClueCount),
        isTrue,
      );
      expect(
        invalid.containsCode(StageValidationIssueCode.invalidSwapStep),
        isFalse,
      );
      expect(invalid.summary, contains('invalidClueCount'));
      expect(invalid.summary, contains('bad count'));
      expect(
        () => invalid.issues.add(invalid.issues.first),
        throwsUnsupportedError,
      );
      expect(() => invalid.issues.clear(), throwsUnsupportedError);
      expect(
        () => invalid.issues.sort(
          (left, right) => left.message.compareTo(right.message),
        ),
        throwsUnsupportedError,
      );
      expect(() => invalid.issues.shuffle(), throwsUnsupportedError);
    });
  });

  group('StagePermutationAnalyzer', () {
    const analyzer = StagePermutationAnalyzer();

    test('calculates minimum swap distance for common permutations', () {
      expect(
        analyzer.minimumSwapDistance(
          target: _placementsForIds([
            'red_key',
            'blue_moon',
            'blue_leaf',
            'yellow_leaf',
          ]),
          current: _placementsForIds([
            'red_key',
            'blue_moon',
            'blue_leaf',
            'yellow_leaf',
          ]),
        ),
        0,
      );
      expect(
        analyzer.minimumSwapDistance(
          target: _placementsForIds([
            'red_key',
            'blue_moon',
            'blue_leaf',
            'yellow_leaf',
          ]),
          current: _placementsForIds([
            'blue_moon',
            'red_key',
            'blue_leaf',
            'yellow_leaf',
          ]),
        ),
        1,
      );
      expect(
        analyzer.minimumSwapDistance(
          target: _placementsForIds([
            'red_key',
            'blue_moon',
            'blue_leaf',
            'yellow_leaf',
          ]),
          current: _placementsForIds([
            'red_key',
            'blue_leaf',
            'yellow_leaf',
            'blue_moon',
          ]),
        ),
        2,
      );
      expect(
        analyzer.minimumSwapDistance(
          target: _placementsForIds([
            'red_key',
            'blue_moon',
            'blue_leaf',
            'yellow_leaf',
          ]),
          current: _placementsForIds([
            'blue_moon',
            'blue_leaf',
            'yellow_leaf',
            'red_key',
          ]),
        ),
        3,
      );
      expect(
        analyzer.minimumSwapDistance(
          target: _placementsForIds([
            'red_key',
            'blue_moon',
            'blue_leaf',
            'yellow_leaf',
            'green_key',
          ]),
          current: _placementsForIds([
            'blue_moon',
            'red_key',
            'yellow_leaf',
            'blue_leaf',
            'green_key',
          ]),
        ),
        2,
      );
    });

    test(
      'replays swaps, ignores source list storage order, and preserves inputs',
      () {
        final fixture = _stageFixture(1);
        final targetBefore = _placementSignature(
          fixture.stage.targetPlacements,
        );
        final initialBefore = _placementSignature(
          fixture.stage.initialPlacements,
        );
        final shuffledTargetList = fixture.stage.targetPlacements.reversed
            .toList();

        final forward = analyzer.replayForward(
          start: shuffledTargetList,
          swapHistory: fixture.stage.swapHistory.reversed.toList(),
        );
        final reverse = analyzer.replayReverse(
          start: fixture.stage.initialPlacements,
          swapHistory: fixture.stage.swapHistory,
        );

        expect(
          analyzer.hasSameBookOrder(
            first: forward,
            second: fixture.stage.initialPlacements,
          ),
          isTrue,
        );
        expect(
          analyzer.hasSameBookOrder(
            first: reverse,
            second: fixture.stage.targetPlacements,
          ),
          isTrue,
        );
        expect(
          _placementSignature(fixture.stage.targetPlacements),
          targetBefore,
        );
        expect(
          _placementSignature(fixture.stage.initialPlacements),
          initialBefore,
        );
        expect(
          () => analyzer.minimumSwapDistance(
            target: fixture.stage.targetPlacements,
            current: _placementsForIds([
              'green_key',
              'blue_moon',
              'blue_leaf',
              'yellow_leaf',
            ]),
          ),
          throwsStateError,
        );
      },
    );
  });

  group('GeneratedStageFactory and validator golden stages', () {
    const validator = GeneratedStageValidator();
    const analyzer = StagePermutationAnalyzer();

    test('level 1 generated stage remains stable', () {
      final fixture = _stageFixture(1);

      expect(fixture.stage.level, 1);
      expect(fixture.stage.generatorVersion, 1);
      expect(fixture.stage.templateId, PuzzleTemplateId.t01AnchorChain);
      expect(fixture.stage.stageSpec.seed, 3270846678);
      expect(fixture.stage.scrambleSeed, 1556238703);
      expect(fixture.stage.totalBookCount, 4);
      expect(fixture.stage.clueCount, 3);
      expect(fixture.stage.targetSwapCount, 2);
      expect(_placementIds(fixture.stage.targetPlacements), [
        'red_key',
        'blue_moon',
        'blue_leaf',
        'yellow_leaf',
      ]);
      expect(_placementIds(fixture.stage.initialPlacements), [
        'red_key',
        'blue_leaf',
        'yellow_leaf',
        'blue_moon',
      ]);
      expect(_clueIds(fixture.stage.clues), [
        't01_c02_00_red_key_left_edge',
        't01_c05_01_blue_moon_immediately_right_of_red_key',
        't01_c04_02_blue_leaf_left_of_yellow_leaf',
      ]);
      expect(fixture.stage.swapHistory, hasLength(2));
      expect(
        analyzer.minimumSwapDistance(
          target: fixture.stage.targetPlacements,
          current: fixture.stage.initialPlacements,
        ),
        2,
      );
      expect(validator.validate(fixture.stage).isValid, isTrue);
      expect(validator.validate(fixture.stage).issues, isEmpty);
    });

    test('level 6, 15, and 20 generated stages remain valid and stable', () {
      _expectGeneratedStageGolden(
        level: 6,
        stageSeed: 651865735,
        scrambleSeed: 3102594878,
        targetSwapCount: 2,
        targetIds: [
          'orange_moon',
          'yellow_drop',
          'blue_leaf',
          'yellow_moon',
          'yellow_star',
        ],
        initialIds: [
          'yellow_drop',
          'yellow_moon',
          'blue_leaf',
          'orange_moon',
          'yellow_star',
        ],
      );
      _expectGeneratedStageGolden(
        level: 15,
        stageSeed: 765167081,
        scrambleSeed: 3014458448,
        targetSwapCount: 2,
        targetIds: [
          'red_sun',
          'orange_moon',
          'yellow_diamond',
          'blue_moon',
          'blue_key',
        ],
        initialIds: [
          'blue_key',
          'orange_moon',
          'yellow_diamond',
          'red_sun',
          'blue_moon',
        ],
      );
      _expectGeneratedStageGolden(
        level: 20,
        stageSeed: 279833785,
        scrambleSeed: 2392495360,
        targetSwapCount: 3,
        targetIds: [
          'red_drop',
          'yellow_sun',
          'yellow_moon',
          'blue_star',
          'green_key',
        ],
        initialIds: [
          'yellow_moon',
          'red_drop',
          'green_key',
          'blue_star',
          'yellow_sun',
        ],
      );
    });

    test('levels 1 through 20 pass integrated validation', () {
      for (var level = 1; level <= 20; level += 1) {
        final fixture = _stageFixture(level);
        final validation = validator.validate(fixture.stage);

        expect(validation.isValid, isTrue, reason: 'level $level');
        expect(validation.issues, isEmpty, reason: 'level $level');
        expect(fixture.stage.level, level);
        expect(
          fixture.stage.targetPlacements,
          hasLength(fixture.stage.totalBookCount),
        );
        expect(
          fixture.stage.initialPlacements,
          hasLength(fixture.stage.totalBookCount),
        );
        expect(
          fixture.stage.clues,
          hasLength(fixture.stage.stageSpec.clueCount),
        );
        expect(
          fixture.stage.swapHistory,
          hasLength(fixture.stage.targetSwapCount),
        );
        expect(
          analyzer.minimumSwapDistance(
            target: fixture.stage.targetPlacements,
            current: fixture.stage.initialPlacements,
          ),
          fixture.stage.targetSwapCount,
        );
      }
    });

    test('manual pipeline is deterministic', () {
      final expected = _stageFixture(1).stage;

      for (var index = 0; index < 100; index += 1) {
        expect(_stageFixture(1).stage, expected);
      }
      expect(_stageFixture(1, const GeneratedStageFactory()).stage, expected);
      expect(
        const GeneratedStageValidator().validate(expected),
        validator.validate(expected),
      );
      expect(
        GeneratedStage(
          scrambleResult: expected.scrambleResult,
          clues: List<Clue>.of(expected.clues),
        ),
        expected,
      );
    });
  });

  group('GeneratedStageValidator invalid stages', () {
    const validator = GeneratedStageValidator();
    const factory = GeneratedStageFactory();

    test('detects target clues that are not satisfied', () {
      final fixture = _stageFixture(1);
      final badStage = _replaceClues(fixture.stage, [
        EdgePositionClue(
          id: 'c_bad_right_edge',
          subject: BookIdSelector(
            bookId: fixture.stage.targetPlacements.first.book.id,
          ),
          tierIndex: 0,
          edge: ShelfEdge.right,
        ),
        ...fixture.stage.clues.skip(1),
      ]);
      final result = validator.validate(badStage);

      expect(
        result.containsCode(
          StageValidationIssueCode.targetDoesNotSatisfyAllClues,
        ),
        isTrue,
      );
      expect(
        () => factory.create(
          scrambleResult: badStage.scrambleResult,
          clues: badStage.clues,
        ),
        throwsStateError,
      );
    });

    test('detects completed initial placements', () {
      final fixture = _stageFixture(1);
      final badStage = _replaceScrambleResult(
        fixture.stage,
        initialPlacements: fixture.stage.targetPlacements,
      );
      final result = validator.validate(badStage);

      expect(
        result.containsCode(
          StageValidationIssueCode.initialAlreadySatisfiesAllClues,
        ),
        isTrue,
      );
      expect(
        result.containsCode(
          StageValidationIssueCode.minimumSwapDistanceMismatch,
        ),
        isTrue,
      );
    });

    test(
      'detects clue count, duplicate ids, invalid ids, and bad selectors',
      () {
        final fixture = _stageFixture(1);
        expect(
          validator
              .validate(
                _replaceClues(
                  fixture.stage,
                  fixture.stage.clues.take(2).toList(),
                ),
              )
              .containsCode(StageValidationIssueCode.invalidClueCount),
          isTrue,
        );

        final duplicateIdStage = _replaceClues(fixture.stage, [
          fixture.stage.clues.first,
          AdjacentClue(
            id: fixture.stage.clues.first.id,
            subject: const BookIdSelector(bookId: 'blue_moon'),
            reference: const BookIdSelector(bookId: 'red_key'),
            tierIndex: 0,
            direction: AdjacentDirection.immediatelyRightOf,
          ),
          fixture.stage.clues.last,
        ]);
        final invalidIdStage = _replaceClues(fixture.stage, [
          EdgePositionClue(
            id: 'Bad-ID',
            subject: const BookIdSelector(bookId: 'red_key'),
            tierIndex: 0,
            edge: ShelfEdge.left,
          ),
          ...fixture.stage.clues.skip(1),
        ]);
        final missingSelectorStage = _replaceClues(fixture.stage, [
          EdgePositionClue(
            id: 'missing_book_left_edge',
            subject: const BookIdSelector(bookId: 'missing_book'),
            tierIndex: 0,
            edge: ShelfEdge.left,
          ),
          ...fixture.stage.clues.skip(1),
        ]);

        expect(
          validator
              .validate(duplicateIdStage)
              .containsCode(StageValidationIssueCode.duplicateClueId),
          isTrue,
        );
        expect(
          validator
              .validate(invalidIdStage)
              .containsCode(StageValidationIssueCode.invalidClueId),
          isTrue,
        );
        expect(
          validator
              .validate(missingSelectorStage)
              .containsCode(StageValidationIssueCode.unresolvedClueSelector),
          isTrue,
        );
      },
    );

    test('detects mismatched book set and swap history problems', () {
      final fixture = _stageFixture(1);
      final foreignBookStage = _replaceScrambleResult(
        fixture.stage,
        initialPlacements: [
          _placement(_catalogBook('green_key'), 0),
          ...fixture.stage.initialPlacements.skip(1),
        ],
      );
      expect(
        validator
            .validate(foreignBookStage)
            .containsCode(StageValidationIssueCode.mismatchedBookSet),
        isTrue,
      );

      final shortHistoryStage = _replaceScrambleResult(
        fixture.stage,
        swapHistory: fixture.stage.swapHistory.take(1).toList(),
      );
      expect(
        validator
            .validate(shortHistoryStage)
            .containsCode(StageValidationIssueCode.invalidSwapHistoryCount),
        isTrue,
      );

      final wrongBookRecordStage = _replaceScrambleResult(
        fixture.stage,
        swapHistory: [
          BookSwapStep(
            stepIndex: fixture.stage.swapHistory.first.stepIndex,
            firstPosition: fixture.stage.swapHistory.first.firstPosition,
            secondPosition: fixture.stage.swapHistory.first.secondPosition,
            firstBookIdBeforeSwap: 'wrong_book',
            secondBookIdBeforeSwap:
                fixture.stage.swapHistory.first.secondBookIdBeforeSwap,
          ),
          ...fixture.stage.swapHistory.skip(1),
        ],
      );
      expect(
        validator
            .validate(wrongBookRecordStage)
            .containsCode(StageValidationIssueCode.swapHistoryBookMismatch),
        isTrue,
      );
    });

    test(
      'detects invalid swap positions, replay mismatches, and seed errors',
      () {
        final fixture = _stageFixture(1);
        final samePositionStage = _replaceScrambleResult(
          fixture.stage,
          swapHistory: [
            const BookSwapStep(
              stepIndex: 0,
              firstPosition: BookPosition(tierIndex: 0, slotIndex: 1),
              secondPosition: BookPosition(tierIndex: 0, slotIndex: 1),
              firstBookIdBeforeSwap: 'blue_moon',
              secondBookIdBeforeSwap: 'blue_moon',
            ),
            fixture.stage.swapHistory.last,
          ],
        );
        final outOfRangeStage = _replaceScrambleResult(
          fixture.stage,
          swapHistory: [
            BookSwapStep(
              stepIndex: 0,
              firstPosition: const BookPosition(tierIndex: 0, slotIndex: 99),
              secondPosition: fixture.stage.swapHistory.first.secondPosition,
              firstBookIdBeforeSwap:
                  fixture.stage.swapHistory.first.firstBookIdBeforeSwap,
              secondBookIdBeforeSwap:
                  fixture.stage.swapHistory.first.secondBookIdBeforeSwap,
            ),
            fixture.stage.swapHistory.last,
          ],
        );
        final duplicateStepIndexStage = _replaceScrambleResult(
          fixture.stage,
          swapHistory: [
            fixture.stage.swapHistory.first,
            BookSwapStep(
              stepIndex: 0,
              firstPosition: fixture.stage.swapHistory.last.firstPosition,
              secondPosition: fixture.stage.swapHistory.last.secondPosition,
              firstBookIdBeforeSwap:
                  fixture.stage.swapHistory.last.firstBookIdBeforeSwap,
              secondBookIdBeforeSwap:
                  fixture.stage.swapHistory.last.secondBookIdBeforeSwap,
            ),
          ],
        );
        final changedPositionStage = _replaceScrambleResult(
          fixture.stage,
          swapHistory: [
            BookSwapStep(
              stepIndex: 0,
              firstPosition: const BookPosition(tierIndex: 0, slotIndex: 0),
              secondPosition: fixture.stage.swapHistory.first.secondPosition,
              firstBookIdBeforeSwap: 'red_key',
              secondBookIdBeforeSwap:
                  fixture.stage.swapHistory.first.secondBookIdBeforeSwap,
            ),
            fixture.stage.swapHistory.last,
          ],
        );
        final badSeedStage = _replaceScrambleResult(
          fixture.stage,
          scrambleSeed: 0,
        );

        expect(
          validator
              .validate(samePositionStage)
              .containsCode(StageValidationIssueCode.invalidSwapStep),
          isTrue,
        );
        expect(
          validator
              .validate(outOfRangeStage)
              .containsCode(StageValidationIssueCode.invalidSwapStep),
          isTrue,
        );
        expect(
          validator
              .validate(duplicateStepIndexStage)
              .containsCode(StageValidationIssueCode.invalidSwapStep),
          isTrue,
        );
        final changedPositionResult = validator.validate(changedPositionStage);
        expect(
          changedPositionResult.containsCode(
            StageValidationIssueCode.forwardReplayMismatch,
          ),
          isTrue,
        );
        expect(
          changedPositionResult.containsCode(
            StageValidationIssueCode.reverseReplayMismatch,
          ),
          isTrue,
        );
        expect(
          validator
              .validate(badSeedStage)
              .containsCode(StageValidationIssueCode.invalidScrambleSeed),
          isTrue,
        );
      },
    );
  });
}

class _StageFixture {
  const _StageFixture({
    required this.spec,
    required this.solution,
    required this.clues,
    required this.scrambleResult,
    required this.stage,
  });

  final dynamic spec;
  final dynamic solution;
  final List<Clue> clues;
  final TemplateScrambleResult scrambleResult;
  final GeneratedStage stage;
}

_StageFixture _stageFixture([
  int level = 1,
  GeneratedStageFactory factory = const GeneratedStageFactory(),
]) {
  const specFactory = StageSpecFactory();
  const solutionFactory = T01AnchorChainSolutionFactory();
  const clueFactory = T01AnchorChainClueFactory();
  const scrambler = T01AnchorChainScrambler();
  final spec = specFactory.create(level: level);
  final solution = solutionFactory.create(spec);
  final clues = clueFactory.create(solution);
  final scrambleResult = scrambler.create(solution: solution, clues: clues);
  final stage = factory.create(scrambleResult: scrambleResult, clues: clues);
  return _StageFixture(
    spec: spec,
    solution: solution,
    clues: clues,
    scrambleResult: scrambleResult,
    stage: stage,
  );
}

void _expectGeneratedStageGolden({
  required int level,
  required int stageSeed,
  required int scrambleSeed,
  required int targetSwapCount,
  required List<String> targetIds,
  required List<String> initialIds,
}) {
  const validator = GeneratedStageValidator();
  const analyzer = StagePermutationAnalyzer();
  final fixture = _stageFixture(level);

  expect(fixture.stage.stageSpec.seed, stageSeed);
  expect(fixture.stage.scrambleSeed, scrambleSeed);
  expect(fixture.stage.targetSwapCount, targetSwapCount);
  expect(_placementIds(fixture.stage.targetPlacements), targetIds);
  expect(_placementIds(fixture.stage.initialPlacements), initialIds);
  expect(validator.validate(fixture.stage).isValid, isTrue);
  expect(
    analyzer.minimumSwapDistance(
      target: fixture.stage.targetPlacements,
      current: fixture.stage.initialPlacements,
    ),
    targetSwapCount,
  );
  expect(
    analyzer.hasSameBookOrder(
      first: analyzer.replayForward(
        start: fixture.stage.targetPlacements,
        swapHistory: fixture.stage.swapHistory,
      ),
      second: fixture.stage.initialPlacements,
    ),
    isTrue,
  );
  expect(
    analyzer.hasSameBookOrder(
      first: analyzer.replayReverse(
        start: fixture.stage.initialPlacements,
        swapHistory: fixture.stage.swapHistory,
      ),
      second: fixture.stage.targetPlacements,
    ),
    isTrue,
  );
}

GeneratedStage _replaceClues(GeneratedStage stage, List<Clue> clues) {
  return GeneratedStage(scrambleResult: stage.scrambleResult, clues: clues);
}

GeneratedStage _replaceScrambleResult(
  GeneratedStage stage, {
  int? scrambleSeed,
  List<BookPlacement>? initialPlacements,
  List<BookSwapStep>? swapHistory,
}) {
  return GeneratedStage(
    scrambleResult: TemplateScrambleResult(
      solution: stage.solution,
      scrambleSeed: scrambleSeed ?? stage.scrambleSeed,
      initialPlacements: initialPlacements ?? stage.initialPlacements,
      swapHistory: swapHistory ?? stage.swapHistory,
    ),
    clues: stage.clues,
  );
}

List<BookPlacement> _placementsForIds(List<String> ids) {
  return [
    for (var index = 0; index < ids.length; index += 1)
      _placement(_catalogBook(ids[index]), index),
  ];
}

BookPlacement _placement(Book book, int slotIndex) {
  return BookPlacement(
    book: book,
    position: BookPosition(tierIndex: 0, slotIndex: slotIndex),
  );
}

Book _catalogBook(String id) {
  return const BookCatalog().books.firstWhere((book) => book.id == id);
}

List<String> _placementIds(List<BookPlacement> placements) {
  final sorted = List<BookPlacement>.of(placements);
  sorted.sort((left, right) {
    final tierComparison = left.position.tierIndex.compareTo(
      right.position.tierIndex,
    );
    if (tierComparison != 0) {
      return tierComparison;
    }
    return left.position.slotIndex.compareTo(right.position.slotIndex);
  });
  return [for (final placement in sorted) placement.book.id];
}

List<String> _clueIds(List<Clue> clues) {
  return [for (final clue in clues) clue.id];
}

String _placementSignature(List<BookPlacement> placements) {
  return [
    for (final placement in placements)
      [
        placement.book.id,
        placement.position.tierIndex,
        placement.position.slotIndex,
      ].join(':'),
  ].join('|');
}
