import 'stage_generation_attempt_failure.dart';

class StageGenerationException implements Exception {
  StageGenerationException({
    required this.level,
    required this.generatorVersion,
    required List<StageGenerationAttemptFailure> failures,
    required this.fallbackMessage,
  }) : assert(level >= 1),
       assert(generatorVersion >= 1),
       assert(fallbackMessage.isNotEmpty),
       failures = List<StageGenerationAttemptFailure>.unmodifiable(
         List<StageGenerationAttemptFailure>.of(failures),
       );

  final int level;
  final int generatorVersion;
  final List<StageGenerationAttemptFailure> failures;
  final String fallbackMessage;

  @override
  String toString() {
    return 'StageGenerationException('
        'level: $level, '
        'generatorVersion: $generatorVersion, '
        'failureCount: ${failures.length}, '
        'fallbackMessage: $fallbackMessage'
        ')';
  }
}
