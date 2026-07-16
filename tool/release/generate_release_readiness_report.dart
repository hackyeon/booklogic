import 'dart:io';

import 'release_common.dart';

void main(List<String> arguments) {
  final outputDirectory = _readOutputDirectory(arguments);
  final checks = [
    ...verifyReleaseConfigurationChecks(),
    ...verifyReleaseBaselineChecks(),
  ];
  final report = buildReport(checks);
  writeReport(report, Directory(outputDirectory));
  stdout.writeln('Release readiness report written to $outputDirectory');
  stdout.writeln('status: ${report.status.code}');
  exitCode = exitCodeForChecks(checks);
}

String _readOutputDirectory(List<String> arguments) {
  const flag = '--output-directory';
  final index = arguments.indexOf(flag);
  if (index == -1) {
    return releaseOutputDirectory;
  }
  if (index == arguments.length - 1) {
    stderr.writeln('$flag requires a value.');
    exitCode = 2;
    return releaseOutputDirectory;
  }
  return arguments[index + 1];
}
