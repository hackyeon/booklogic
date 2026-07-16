import 'tutorial_step_type.dart';
import 'tutorial_target.dart';

class TutorialStep {
  const TutorialStep({
    required this.id,
    required this.type,
    required this.message,
    required this.target,
    this.expectedBookId,
    this.expectedClueId,
    this.secondaryMessage,
    this.actionLabel,
    this.allowSkip = true,
    this.blocksGameInput = true,
  }) : assert(id.length > 0),
       assert(message.length > 0);

  final String id;
  final TutorialStepType type;
  final String message;
  final TutorialTarget target;
  final String? expectedBookId;
  final String? expectedClueId;
  final String? secondaryMessage;
  final String? actionLabel;
  final bool allowSkip;
  final bool blocksGameInput;

  bool get requiresAcknowledgement {
    return type == TutorialStepType.acknowledgeMessage ||
        type == TutorialStepType.freePlayIntroduction;
  }
}
