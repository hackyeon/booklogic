enum ReleaseCheckStatus {
  passed,
  failed,
  skipped,
  manualRequired,
  unavailable;

  String get code {
    return switch (this) {
      ReleaseCheckStatus.passed => 'passed',
      ReleaseCheckStatus.failed => 'failed',
      ReleaseCheckStatus.skipped => 'skipped',
      ReleaseCheckStatus.manualRequired => 'manual_required',
      ReleaseCheckStatus.unavailable => 'unavailable',
    };
  }

  static ReleaseCheckStatus fromCode(String code) {
    return switch (code) {
      'passed' => ReleaseCheckStatus.passed,
      'failed' => ReleaseCheckStatus.failed,
      'skipped' => ReleaseCheckStatus.skipped,
      'manual_required' => ReleaseCheckStatus.manualRequired,
      'unavailable' => ReleaseCheckStatus.unavailable,
      _ => throw ArgumentError.value(code, 'code', 'Unknown status code.'),
    };
  }
}
