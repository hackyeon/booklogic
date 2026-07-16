import '../../domain/clue.dart';
import '../../domain/clue_evaluator.dart';
import '../../generator/generated_stage.dart';
import '../domain/tutorial_plan.dart';
import '../domain/tutorial_step.dart';
import '../domain/tutorial_step_type.dart';
import '../domain/tutorial_target.dart';
import 'tutorial_solve_path_resolver.dart';

class TutorialPlanFactory {
  const TutorialPlanFactory({
    this.solvePathResolver = const TutorialSolvePathResolver(),
    this.clueEvaluator = const ClueEvaluator(),
  });

  final TutorialSolvePathResolver solvePathResolver;
  final ClueEvaluator clueEvaluator;

  TutorialPlan? create({required GeneratedStage stage}) {
    if (stage.level < 1 || stage.level > 5) {
      return null;
    }
    final swapTarget = solvePathResolver.resolveFirstSwap(stage);
    if (swapTarget == null && (stage.level == 1 || stage.level == 2)) {
      return null;
    }

    return switch (stage.level) {
      1 => _levelOne(stage, swapTarget!),
      2 => _levelTwo(stage, swapTarget!),
      3 => _levelThree(stage),
      4 => _levelFour(stage),
      5 => _levelFive(stage),
      _ => null,
    };
  }

  TutorialPlan _levelOne(GeneratedStage stage, TutorialSwapTarget target) {
    return TutorialPlan(
      level: stage.level,
      steps: [
        TutorialStep(
          id: 'level_1_tap_first_book',
          type: TutorialStepType.tapBook,
          message: '책을 한 권 선택해 보세요.',
          target: TutorialTarget.book(target.firstBookId),
          expectedBookId: target.firstBookId,
        ),
        const TutorialStep(
          id: 'level_1_selection_message',
          type: TutorialStepType.acknowledgeMessage,
          message: '선택한 책은 앞으로 표시됩니다. 같은 책을 다시 누르면 선택을 취소할 수 있어요.',
          target: TutorialTarget.none(),
          actionLabel: '확인',
        ),
      ],
    );
  }

  TutorialPlan _levelTwo(GeneratedStage stage, TutorialSwapTarget target) {
    return TutorialPlan(
      level: stage.level,
      steps: [
        TutorialStep(
          id: 'level_2_tap_first_book',
          type: TutorialStepType.tapBook,
          message: '먼저 옮길 책을 선택해 보세요.',
          target: TutorialTarget.book(target.firstBookId),
          expectedBookId: target.firstBookId,
        ),
        TutorialStep(
          id: 'level_2_tap_second_book',
          type: TutorialStepType.tapSecondBook,
          message: '자리를 바꿀 책을 선택해 보세요.',
          target: TutorialTarget.book(target.secondBookId),
          expectedBookId: target.secondBookId,
        ),
        const TutorialStep(
          id: 'level_2_swap_message',
          type: TutorialStepType.acknowledgeMessage,
          message: '두 책의 자리가 바뀌었습니다. 단서에 맞게 나머지 책도 옮겨보세요.',
          target: TutorialTarget.none(),
          actionLabel: '계속하기',
        ),
      ],
    );
  }

  TutorialPlan _levelThree(GeneratedStage stage) {
    final unsatisfiedClues = _firstUnSatisfiedClues(stage, 1).toList();
    final clue = unsatisfiedClues.isNotEmpty
        ? unsatisfiedClues.first
        : stage.clues[0];
    return TutorialPlan(
      level: stage.level,
      steps: [
        TutorialStep(
          id: 'level_3_tap_clue',
          type: TutorialStepType.tapClueCard,
          message: '단서를 눌러 관련 책을 확인해 보세요.',
          target: TutorialTarget.clueCard(clue.id),
          expectedClueId: clue.id,
        ),
        const TutorialStep(
          id: 'level_3_clue_message',
          type: TutorialStepType.acknowledgeMessage,
          message: '단서가 가리키는 책이 잠시 강조됩니다. 만족한 단서는 체크 표시로 바뀝니다.',
          target: TutorialTarget.none(),
          actionLabel: '확인',
        ),
      ],
    );
  }

  TutorialPlan _levelFour(GeneratedStage stage) {
    final clues = _firstUnSatisfiedClues(stage, 2).toList();
    for (final clue in stage.clues) {
      if (clues.length >= 2) {
        break;
      }
      if (!clues.any((existing) => existing.id == clue.id)) {
        clues.add(clue);
      }
    }
    if (clues.isEmpty) {
      clues.add(stage.clues[0]);
    }
    if (clues.length == 1 && stage.clues.length > 1) {
      clues.add(stage.clues.firstWhere((clue) => clue.id != clues.first.id));
    }

    return TutorialPlan(
      level: stage.level,
      steps: [
        TutorialStep(
          id: 'level_4_tap_first_clue',
          type: TutorialStepType.tapClueCard,
          message: '첫 번째 단서를 확인해 보세요.',
          target: TutorialTarget.clueCard(clues.first.id),
          expectedClueId: clues.first.id,
        ),
        TutorialStep(
          id: 'level_4_tap_second_clue',
          type: TutorialStepType.tapClueCard,
          message: '이제 두 번째 단서도 확인해 보세요.',
          target: TutorialTarget.clueCard(clues.last.id),
          expectedClueId: clues.last.id,
        ),
        const TutorialStep(
          id: 'level_4_combination_message',
          type: TutorialStepType.acknowledgeMessage,
          message: '두 단서를 함께 사용하면 책의 위치를 더 정확하게 찾을 수 있어요.',
          target: TutorialTarget.none(),
          actionLabel: '직접 풀기',
        ),
      ],
    );
  }

  TutorialPlan _levelFive(GeneratedStage stage) {
    return TutorialPlan(
      level: stage.level,
      steps: const [
        TutorialStep(
          id: 'level_5_free_play',
          type: TutorialStepType.freePlayIntroduction,
          message: '이제 단서를 확인하며 직접 책장을 완성해 보세요.',
          secondaryMessage: '모든 단서를 만족하면 책장 정리가 완료됩니다.',
          target: TutorialTarget.none(),
          actionLabel: '시작',
        ),
      ],
    );
  }

  Iterable<Clue> _firstUnSatisfiedClues(GeneratedStage stage, int count) {
    final satisfiedIds = clueEvaluator.evaluateAll(
      clues: stage.clues,
      placements: stage.initialPlacements,
    );
    return stage.clues
        .where((clue) => !satisfiedIds.contains(clue.id))
        .take(count);
  }
}
