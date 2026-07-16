import 'package:flutter_test/flutter_test.dart';

import 'package:booklogic/features/game/domain/book_position.dart';
import 'package:booklogic/features/game/generator/generated_stage.dart';
import 'package:booklogic/features/game/generator/stage_generator.dart';
import 'package:booklogic/features/game/tutorial/application/tutorial_plan_factory.dart';
import 'package:booklogic/features/game/tutorial/application/tutorial_solve_path_resolver.dart';
import 'package:booklogic/features/game/tutorial/domain/tutorial_policy.dart';
import 'package:booklogic/features/game/tutorial/domain/tutorial_step_type.dart';

void main() {
  group('TutorialPolicy', () {
    const policy = TutorialPolicy();

    test('shows tutorials only on Level 1 through 5 when incomplete', () {
      expect(
        policy.shouldShowTutorial(level: 1, tutorialCompleted: false),
        isTrue,
      );
      expect(
        policy.shouldShowTutorial(level: 5, tutorialCompleted: false),
        isTrue,
      );
      expect(
        policy.shouldShowTutorial(level: 6, tutorialCompleted: false),
        isFalse,
      );
      expect(
        policy.shouldShowTutorial(level: 3, tutorialCompleted: true),
        isFalse,
      );
      expect(
        policy.shouldShowTutorial(level: 0, tutorialCompleted: false),
        isFalse,
      );
    });

    test('suppresses interstitial ads for Level 1 through 5 regardless', () {
      expect(policy.suppressInterstitialAd(1), isTrue);
      expect(policy.suppressInterstitialAd(5), isTrue);
      expect(policy.suppressInterstitialAd(6), isFalse);
      expect(policy.suppressInterstitialAd(0), isFalse);
    });
  });

  group('TutorialSolvePathResolver', () {
    const generator = StageGenerator();
    const resolver = TutorialSolvePathResolver();

    for (var level = 1; level <= 5; level += 1) {
      test('uses swapHistory.last for Level $level', () {
        final stage = generator.generate(level: level, generatorVersion: 1);
        final target = resolver.resolveFirstSwap(stage);
        final lastStep = stage.swapHistory.last;

        expect(target, isNotNull);
        expect(target!.firstPosition, lastStep.firstPosition);
        expect(target.secondPosition, lastStep.secondPosition);
        expect(target.firstBookId, _bookIdAt(stage, lastStep.firstPosition));
        expect(target.secondBookId, _bookIdAt(stage, lastStep.secondPosition));
        expect(target.firstBookId, isNot(target.secondBookId));
      });
    }
  });

  group('TutorialPlanFactory', () {
    const generator = StageGenerator();
    const factory = TutorialPlanFactory();

    test('creates deterministic Level 1 through 5 plans', () {
      final expectedTypes = <int, List<TutorialStepType>>{
        1: [TutorialStepType.tapBook, TutorialStepType.acknowledgeMessage],
        2: [
          TutorialStepType.tapBook,
          TutorialStepType.tapSecondBook,
          TutorialStepType.acknowledgeMessage,
        ],
        3: [TutorialStepType.tapClueCard, TutorialStepType.acknowledgeMessage],
        4: [
          TutorialStepType.tapClueCard,
          TutorialStepType.tapClueCard,
          TutorialStepType.acknowledgeMessage,
        ],
        5: [TutorialStepType.freePlayIntroduction],
      };

      for (final entry in expectedTypes.entries) {
        final stage = generator.generate(level: entry.key, generatorVersion: 1);
        final firstPlan = factory.create(stage: stage);
        final secondPlan = factory.create(stage: stage);

        expect(firstPlan, isNotNull);
        expect(firstPlan!.steps.map((step) => step.type), entry.value);
        expect(
          firstPlan.steps.map((step) => step.id).toSet().length,
          firstPlan.steps.length,
        );
        expect(
          secondPlan!.steps.map((step) => step.id),
          firstPlan.steps.map((step) => step.id),
        );
      }
    });
  });
}

String _bookIdAt(GeneratedStage stage, BookPosition position) {
  return stage.initialPlacements
      .singleWhere((placement) => placement.position == position)
      .book
      .id;
}
