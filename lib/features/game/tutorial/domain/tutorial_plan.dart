import 'tutorial_step.dart';

class TutorialPlan {
  TutorialPlan({required this.level, required List<TutorialStep> steps})
    : steps = List<TutorialStep>.unmodifiable(_validateSteps(level, steps));

  final int level;
  final List<TutorialStep> steps;

  TutorialStep get firstStep => steps.first;
}

List<TutorialStep> _validateSteps(int level, List<TutorialStep> steps) {
  if (level < 1 || level > 5) {
    throw ArgumentError.value(level, 'level', '튜토리얼은 Level 1~5만 지원합니다.');
  }
  if (steps.isEmpty) {
    throw ArgumentError.value(steps, 'steps', '튜토리얼 단계가 비어 있습니다.');
  }
  final ids = <String>{};
  for (final step in steps) {
    if (!ids.add(step.id)) {
      throw ArgumentError.value(step.id, 'steps', '튜토리얼 단계 ID가 중복되었습니다.');
    }
  }
  return steps;
}
