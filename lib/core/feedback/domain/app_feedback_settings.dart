class AppFeedbackSettings {
  const AppFeedbackSettings({
    required this.soundEnabled,
    required this.hapticEnabled,
  });

  static const defaults = AppFeedbackSettings(
    soundEnabled: true,
    hapticEnabled: true,
  );

  final bool soundEnabled;
  final bool hapticEnabled;

  AppFeedbackSettings copyWith({bool? soundEnabled, bool? hapticEnabled}) {
    return AppFeedbackSettings(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticEnabled: hapticEnabled ?? this.hapticEnabled,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AppFeedbackSettings &&
            runtimeType == other.runtimeType &&
            soundEnabled == other.soundEnabled &&
            hapticEnabled == other.hapticEnabled;
  }

  @override
  int get hashCode => Object.hash(soundEnabled, hapticEnabled);

  @override
  String toString() {
    return 'AppFeedbackSettings('
        'soundEnabled: $soundEnabled, '
        'hapticEnabled: $hapticEnabled'
        ')';
  }
}
