import '../domain/clue.dart';
import 'generated_stage.dart';
import 'generated_stage_validator.dart';
import 'stage_generation_key.dart';
import 'template_scramble_result.dart';

class GeneratedStageFactory {
  const GeneratedStageFactory({
    this.validator = const GeneratedStageValidator(),
  });

  final GeneratedStageValidator validator;

  GeneratedStage create({
    required TemplateScrambleResult scrambleResult,
    required List<Clue> clues,
    StageGenerationKey? generationAttemptKey,
    int? generationAttemptSeed,
    bool isFallback = false,
  }) {
    final stage = GeneratedStage(
      scrambleResult: scrambleResult,
      clues: clues,
      generationAttemptKey: generationAttemptKey,
      generationAttemptSeed: generationAttemptSeed,
      isFallback: isFallback,
    );
    final result = validator.validate(stage);
    if (result.isInvalid) {
      throw StateError('GeneratedStage validation failed:\n${result.summary}');
    }
    return stage;
  }
}
