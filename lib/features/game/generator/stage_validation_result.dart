import 'stage_validation_issue.dart';

class StageValidationResult {
  StageValidationResult({required List<StageValidationIssue> issues})
    : issues = List<StageValidationIssue>.unmodifiable(
        List<StageValidationIssue>.of(issues),
      );

  final List<StageValidationIssue> issues;

  bool get isValid => issues.isEmpty;

  bool get isInvalid => issues.isNotEmpty;

  int get issueCount => issues.length;

  bool containsCode(StageValidationIssueCode code) {
    return issues.any((issue) => issue.code == code);
  }

  String get summary {
    if (issues.isEmpty) {
      return 'valid';
    }
    return issues.map((issue) => '${issue.code}: ${issue.message}').join('\n');
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is StageValidationResult &&
            runtimeType == other.runtimeType &&
            _listEquals(other.issues, issues);
  }

  @override
  int get hashCode {
    var result = 17;
    for (final issue in issues) {
      result = _combineHash(result, issue.hashCode);
    }
    return result;
  }

  @override
  String toString() {
    return 'StageValidationResult(isValid: $isValid, issueCount: $issueCount)';
  }
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

int _combineHash(int current, int value) {
  return ((current * 31) + value) & 0x1FFFFFFF;
}
