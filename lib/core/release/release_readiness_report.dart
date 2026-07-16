import 'dart:collection';
import 'dart:convert';

import 'release_check_result.dart';
import 'release_check_severity.dart';
import 'release_check_status.dart';
import 'release_readiness_status.dart';

class ReleaseReadinessReport {
  ReleaseReadinessReport({
    required this.status,
    required this.appVersion,
    required this.androidApplicationId,
    required this.iosBundleIdentifier,
    required this.generatorV1Checksum,
    required this.generatorV2Checksum,
    required List<ReleaseCheckResult> checks,
  }) : checks = UnmodifiableListView<ReleaseCheckResult>(
         List<ReleaseCheckResult>.of(checks)
           ..sort((left, right) => left.code.compareTo(right.code)),
       );

  factory ReleaseReadinessReport.fromChecks({
    required String appVersion,
    required String androidApplicationId,
    required String iosBundleIdentifier,
    required int generatorV1Checksum,
    required int generatorV2Checksum,
    required List<ReleaseCheckResult> checks,
  }) {
    final sortedChecks = List<ReleaseCheckResult>.of(checks)
      ..sort((left, right) => left.code.compareTo(right.code));
    return ReleaseReadinessReport(
      status: ReleaseReadinessStatus.fromChecks(sortedChecks),
      appVersion: appVersion,
      androidApplicationId: androidApplicationId,
      iosBundleIdentifier: iosBundleIdentifier,
      generatorV1Checksum: generatorV1Checksum,
      generatorV2Checksum: generatorV2Checksum,
      checks: sortedChecks,
    );
  }

  final ReleaseReadinessStatus status;
  final String appVersion;
  final String androidApplicationId;
  final String iosBundleIdentifier;
  final int generatorV1Checksum;
  final int generatorV2Checksum;
  final UnmodifiableListView<ReleaseCheckResult> checks;

  int get blockerCount {
    return checks.where((check) => check.isBlockingFailure).length;
  }

  int get warningCount {
    return checks
        .where(
          (check) =>
              check.severity == ReleaseCheckSeverity.warning &&
              check.status != ReleaseCheckStatus.passed,
        )
        .length;
  }

  int get manualRequiredCount {
    return checks
        .where((check) => check.status == ReleaseCheckStatus.manualRequired)
        .length;
  }

  int get passedCount {
    return checks
        .where((check) => check.status == ReleaseCheckStatus.passed)
        .length;
  }

  Map<String, Object?> toJson() {
    return {
      'status': status.code,
      'appVersion': appVersion,
      'androidApplicationId': androidApplicationId,
      'iosBundleIdentifier': iosBundleIdentifier,
      'generatorV1Checksum': generatorV1Checksum,
      'generatorV2Checksum': generatorV2Checksum,
      'summary': {
        'blockerCount': blockerCount,
        'warningCount': warningCount,
        'manualRequiredCount': manualRequiredCount,
        'passedCount': passedCount,
        'totalCount': checks.length,
      },
      'checks': [for (final check in checks) check.toJson()],
    };
  }

  factory ReleaseReadinessReport.fromJson(Map<String, Object?> json) {
    final checksJson = json['checks']! as List<Object?>;
    return ReleaseReadinessReport(
      status: ReleaseReadinessStatus.fromCode(json['status']! as String),
      appVersion: json['appVersion']! as String,
      androidApplicationId: json['androidApplicationId']! as String,
      iosBundleIdentifier: json['iosBundleIdentifier']! as String,
      generatorV1Checksum: json['generatorV1Checksum']! as int,
      generatorV2Checksum: json['generatorV2Checksum']! as int,
      checks: [
        for (final check in checksJson)
          ReleaseCheckResult.fromJson((check! as Map).cast<String, Object?>()),
      ],
    );
  }

  String toPrettyJson() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# Release Readiness Report')
      ..writeln()
      ..writeln('- Status: `${status.code}`')
      ..writeln('- App version: `$appVersion`')
      ..writeln('- Android applicationId: `$androidApplicationId`')
      ..writeln('- iOS bundle identifier: `$iosBundleIdentifier`')
      ..writeln('- Generator v1 checksum: `$generatorV1Checksum`')
      ..writeln('- Generator v2 checksum: `$generatorV2Checksum`')
      ..writeln('- Passed: `$passedCount`')
      ..writeln('- Blockers: `$blockerCount`')
      ..writeln('- Warnings: `$warningCount`')
      ..writeln('- Manual required: `$manualRequiredCount`')
      ..writeln()
      ..writeln('## Checks')
      ..writeln();

    for (final check in checks) {
      buffer
        ..writeln('### ${check.code}')
        ..writeln()
        ..writeln('- Title: ${check.title}')
        ..writeln('- Severity: `${check.severity.code}`')
        ..writeln('- Status: `${check.status.code}`')
        ..writeln('- Message: ${check.message}');
      if (check.remediation != null) {
        buffer.writeln('- Remediation: ${check.remediation}');
      }
      if (check.evidence.isNotEmpty) {
        buffer.writeln('- Evidence:');
        for (final evidence in check.evidence) {
          buffer.writeln('  - $evidence');
        }
      }
      buffer.writeln();
    }
    return buffer.toString();
  }
}
