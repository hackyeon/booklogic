class StageGenerationKey {
  const StageGenerationKey({
    required this.generatorVersion,
    required this.level,
    this.attempt = 0,
  }) : assert(generatorVersion >= 1),
       assert(level >= 1),
       assert(attempt >= 0);

  final int generatorVersion;
  final int level;
  final int attempt;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is StageGenerationKey &&
            other.generatorVersion == generatorVersion &&
            other.level == level &&
            other.attempt == attempt;
  }

  @override
  int get hashCode {
    var result = generatorVersion & 0x1FFFFFFF;
    result = ((result * 31) + level) & 0x1FFFFFFF;
    result = ((result * 31) + attempt) & 0x1FFFFFFF;
    return result;
  }

  @override
  String toString() {
    return 'StageGenerationKey('
        'generatorVersion: $generatorVersion, '
        'level: $level, '
        'attempt: $attempt'
        ')';
  }
}
