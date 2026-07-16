import 'dart:convert';

import 'package:booklogic/core/release/release_check_result.dart';
import 'package:booklogic/core/release/release_check_severity.dart';
import 'package:booklogic/core/release/release_check_status.dart';
import 'package:booklogic/core/release/release_readiness_report.dart';
import 'package:booklogic/core/release/release_readiness_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReleaseCheckResult', () {
    test('validates codes and stores immutable evidence', () {
      final result = ReleaseCheckResult(
        code: 'valid_code_1',
        title: 'Valid',
        severity: ReleaseCheckSeverity.info,
        status: ReleaseCheckStatus.passed,
        message: 'ok',
        evidence: ['relative/path.log'],
      );

      expect(result.evidence, ['relative/path.log']);
      expect(() => result.evidence.add('mutate'), throwsUnsupportedError);
      expect(
        () => ReleaseCheckResult(
          code: 'Invalid-Code',
          title: 'Invalid',
          severity: ReleaseCheckSeverity.info,
          status: ReleaseCheckStatus.passed,
          message: 'ok',
        ),
        throwsArgumentError,
      );
    });

    test('rejects full AdMob identifiers in report fields', () {
      expect(
        () => ReleaseCheckResult(
          code: 'admob_secret',
          title: 'AdMob',
          severity: ReleaseCheckSeverity.info,
          status: ReleaseCheckStatus.passed,
          message: 'ca-app-pub-1234567890123456/1234567890',
        ),
        throwsArgumentError,
      );
    });
  });

  group('ReleaseReadinessReport', () {
    test('sorts checks and derives blocked status deterministically', () {
      final report = ReleaseReadinessReport.fromChecks(
        appVersion: '1.0.0+1',
        androidApplicationId: 'com.hack.booklogic.booklogic',
        iosBundleIdentifier: 'com.hack.booklogic.booklogic',
        generatorV1Checksum: 1,
        generatorV2Checksum: 2,
        checks: [
          ReleaseCheckResult(
            code: 'z_check',
            title: 'Z',
            severity: ReleaseCheckSeverity.info,
            status: ReleaseCheckStatus.passed,
            message: 'ok',
          ),
          ReleaseCheckResult(
            code: 'a_check',
            title: 'A',
            severity: ReleaseCheckSeverity.blocker,
            status: ReleaseCheckStatus.failed,
            message: 'failed',
          ),
        ],
      );

      expect(report.status, ReleaseReadinessStatus.blocked);
      expect(report.blockerCount, 1);
      expect(report.passedCount, 1);
      expect(report.checks.map((check) => check.code), ['a_check', 'z_check']);

      final decoded = jsonDecode(report.toPrettyJson()) as Map<String, Object?>;
      expect(decoded.keys.toList().take(7), [
        'status',
        'appVersion',
        'androidApplicationId',
        'iosBundleIdentifier',
        'generatorV1Checksum',
        'generatorV2Checksum',
        'summary',
      ]);
    });

    test('manual items keep report out of ready state', () {
      final report = ReleaseReadinessReport.fromChecks(
        appVersion: '1.0.0+1',
        androidApplicationId: 'com.hack.booklogic.booklogic',
        iosBundleIdentifier: 'com.hack.booklogic.booklogic',
        generatorV1Checksum: 1,
        generatorV2Checksum: 2,
        checks: [
          ReleaseCheckResult(
            code: 'manual_device_qa',
            title: 'Device QA',
            severity: ReleaseCheckSeverity.warning,
            status: ReleaseCheckStatus.manualRequired,
            message: 'not run',
          ),
        ],
      );

      expect(report.status, ReleaseReadinessStatus.automatedReadyManualPending);
      expect(report.manualRequiredCount, 1);
    });
  });
}
