import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release checklist documents do not mark manual QA as passed', () {
    final manualQa = File('release/manual_qa_matrix.md').readAsStringSync();
    expect(manualQa, contains('NOT_RUN'));
    expect(manualQa, isNot(contains('| PASS |')));
    expect(manualQa, contains('Codex has not executed real-device QA'));
  });

  test('release scope does not advertise excluded features', () {
    final scope = File('release/release_scope.md').readAsStringSync();
    expect(scope, contains('Level 1-400'));
    expect(scope, contains('Rewarded ad hints'));
    expect(scope, isNot(contains('cloud sync is included')));
    expect(scope, isNot(contains('infinite levels')));
  });
}
