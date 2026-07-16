enum ReleaseCheckSeverity {
  blocker,
  warning,
  info;

  String get code {
    return switch (this) {
      ReleaseCheckSeverity.blocker => 'blocker',
      ReleaseCheckSeverity.warning => 'warning',
      ReleaseCheckSeverity.info => 'info',
    };
  }

  static ReleaseCheckSeverity fromCode(String code) {
    return switch (code) {
      'blocker' => ReleaseCheckSeverity.blocker,
      'warning' => ReleaseCheckSeverity.warning,
      'info' => ReleaseCheckSeverity.info,
      _ => throw ArgumentError.value(code, 'code', 'Unknown severity code.'),
    };
  }
}
