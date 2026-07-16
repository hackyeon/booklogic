import 'release_check_result.dart';
import 'release_check_severity.dart';
import 'release_check_status.dart';

enum ReleaseReadinessStatus {
  blocked,
  automatedReadyManualPending,
  ready;

  String get code {
    return switch (this) {
      ReleaseReadinessStatus.blocked => 'blocked',
      ReleaseReadinessStatus.automatedReadyManualPending =>
        'automated_ready_manual_pending',
      ReleaseReadinessStatus.ready => 'ready',
    };
  }

  static ReleaseReadinessStatus fromCode(String code) {
    return switch (code) {
      'blocked' => ReleaseReadinessStatus.blocked,
      'automated_ready_manual_pending' =>
        ReleaseReadinessStatus.automatedReadyManualPending,
      'ready' => ReleaseReadinessStatus.ready,
      _ => throw ArgumentError.value(
        code,
        'code',
        'Unknown readiness status code.',
      ),
    };
  }

  static ReleaseReadinessStatus fromChecks(
    Iterable<ReleaseCheckResult> checks,
  ) {
    var hasManualOrUnavailable = false;
    for (final check in checks) {
      if (check.severity == ReleaseCheckSeverity.blocker &&
          check.status != ReleaseCheckStatus.passed &&
          check.status != ReleaseCheckStatus.skipped) {
        return ReleaseReadinessStatus.blocked;
      }
      if (check.status == ReleaseCheckStatus.manualRequired ||
          check.status == ReleaseCheckStatus.unavailable) {
        hasManualOrUnavailable = true;
      }
    }
    return hasManualOrUnavailable
        ? ReleaseReadinessStatus.automatedReadyManualPending
        : ReleaseReadinessStatus.ready;
  }
}
