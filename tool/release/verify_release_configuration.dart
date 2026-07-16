import 'dart:io';

import 'release_common.dart';

void main() {
  final checks = verifyReleaseConfigurationChecks();
  final report = buildReport(checks);
  stdout.writeln(report.toMarkdown());
  exitCode = exitCodeForChecks(checks);
}
