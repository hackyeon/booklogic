import 'dart:io';

import 'release_common.dart';

void main() {
  final checks = verifyReleaseBaselineChecks();
  final report = buildReport(checks);
  stdout.writeln(report.toMarkdown());
  exitCode = exitCodeForChecks(checks);
}
