import 'dart:collection';

import 'release_check_severity.dart';
import 'release_check_status.dart';

final _checkCodePattern = RegExp(r'^[a-z0-9_]+$');
final _fullAdMobIdPattern = RegExp(r'ca-app-pub-\d{16}[/~]\d{10}');
final _absoluteHomePathPattern = RegExp(r'/(Users|home)/[^/\s]+/');

class ReleaseCheckResult {
  ReleaseCheckResult({
    required this.code,
    required this.title,
    required this.severity,
    required this.status,
    required this.message,
    this.remediation,
    List<String> evidence = const [],
  }) : evidence = UnmodifiableListView<String>(List<String>.of(evidence)) {
    if (!_checkCodePattern.hasMatch(code)) {
      throw ArgumentError.value(code, 'code', 'Use lowercase snake_case.');
    }
    final allText = [title, message, ?remediation, ...evidence].join('\n');
    if (_fullAdMobIdPattern.hasMatch(allText)) {
      throw ArgumentError('Release checks must mask full AdMob identifiers.');
    }
    if (_absoluteHomePathPattern.hasMatch(allText)) {
      throw ArgumentError(
        'Release checks must not include absolute home paths.',
      );
    }
  }

  final String code;
  final String title;
  final ReleaseCheckSeverity severity;
  final ReleaseCheckStatus status;
  final String message;
  final String? remediation;
  final UnmodifiableListView<String> evidence;

  bool get isBlockingFailure {
    return severity == ReleaseCheckSeverity.blocker &&
        status != ReleaseCheckStatus.passed &&
        status != ReleaseCheckStatus.skipped;
  }

  Map<String, Object?> toJson() {
    return {
      'code': code,
      'title': title,
      'severity': severity.code,
      'status': status.code,
      'message': message,
      'remediation': remediation,
      'evidence': List<String>.of(evidence),
    };
  }

  factory ReleaseCheckResult.fromJson(Map<String, Object?> json) {
    final evidence = json['evidence'];
    return ReleaseCheckResult(
      code: json['code']! as String,
      title: json['title']! as String,
      severity: ReleaseCheckSeverity.fromCode(json['severity']! as String),
      status: ReleaseCheckStatus.fromCode(json['status']! as String),
      message: json['message']! as String,
      remediation: json['remediation'] as String?,
      evidence: evidence is List
          ? evidence.cast<String>().toList(growable: false)
          : const [],
    );
  }
}
