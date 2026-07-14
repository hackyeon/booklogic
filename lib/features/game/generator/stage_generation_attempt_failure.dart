import 'generator_config.dart';

class StageGenerationAttemptFailure {
  const StageGenerationAttemptFailure({
    required this.attempt,
    required this.seed,
    required this.message,
  }) : assert(attempt >= 0),
       assert(seed >= 0),
       assert(seed <= GeneratorConfig.uint32Mask),
       assert(message != '');

  final int attempt;
  final int seed;
  final String message;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is StageGenerationAttemptFailure &&
            runtimeType == other.runtimeType &&
            attempt == other.attempt &&
            seed == other.seed &&
            message == other.message;
  }

  @override
  int get hashCode {
    var result = attempt & 0x1FFFFFFF;
    result = _combineHash(result, seed);
    result = _combineHash(result, message.hashCode);
    return result;
  }

  @override
  String toString() {
    return 'StageGenerationAttemptFailure('
        'attempt: $attempt, seed: $seed, message: $message'
        ')';
  }
}

int _combineHash(int current, int value) {
  return ((current * 31) + value) & 0x1FFFFFFF;
}
