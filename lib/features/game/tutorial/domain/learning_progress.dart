class LearningProgress {
  LearningProgress({
    this.tutorialCompleted = false,
    Iterable<String> acknowledgedRuleCodes = const [],
  }) : acknowledgedRuleCodes = Set.unmodifiable(
         acknowledgedRuleCodes.where((code) => code.trim().isNotEmpty),
       );

  final bool tutorialCompleted;
  final Set<String> acknowledgedRuleCodes;

  LearningProgress copyWith({
    bool? tutorialCompleted,
    Iterable<String>? acknowledgedRuleCodes,
  }) {
    return LearningProgress(
      tutorialCompleted: tutorialCompleted ?? this.tutorialCompleted,
      acknowledgedRuleCodes:
          acknowledgedRuleCodes ?? this.acknowledgedRuleCodes,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is LearningProgress &&
        tutorialCompleted == other.tutorialCompleted &&
        _setEquals(acknowledgedRuleCodes, other.acknowledgedRuleCodes);
  }

  @override
  int get hashCode {
    final sortedCodes = acknowledgedRuleCodes.toList()..sort();
    return Object.hash(tutorialCompleted, Object.hashAll(sortedCodes));
  }

  @override
  String toString() {
    return 'LearningProgress('
        'tutorialCompleted: $tutorialCompleted, '
        'acknowledgedRuleCodes: $acknowledgedRuleCodes'
        ')';
  }
}

bool _setEquals(Set<String> left, Set<String> right) {
  if (left.length != right.length) {
    return false;
  }
  for (final value in left) {
    if (!right.contains(value)) {
      return false;
    }
  }
  return true;
}
