import 'dart:io';

import 'package:booklogic/core/release/release_check_result.dart';
import 'package:booklogic/core/release/release_check_severity.dart';
import 'package:booklogic/core/release/release_check_status.dart';

import 'release_common.dart';

Future<void> main(List<String> arguments) async {
  final options = _ReleaseQaOptions.parse(arguments);
  if (options.hasUsageError) {
    stderr.writeln(options.usageError);
    exitCode = 2;
    return;
  }

  final outputDirectory = Directory(options.outputDirectory);
  outputDirectory.createSync(recursive: true);
  final checks = <ReleaseCheckResult>[
    ...verifyReleaseConfigurationChecks(),
    ...verifyReleaseBaselineChecks(),
  ];

  if (!options.skipTests) {
    checks.addAll(
      await _runCommands(
        outputDirectory: outputDirectory,
        commands: options.smoke
            ? const [
                _QaCommand(
                  code: 'dart_format',
                  title: 'dart format',
                  command: 'dart',
                  arguments: ['format', '.'],
                  severity: ReleaseCheckSeverity.blocker,
                ),
                _QaCommand(
                  code: 'flutter_analyze',
                  title: 'flutter analyze',
                  command: 'flutter',
                  arguments: ['analyze', '--fatal-infos', '--fatal-warnings'],
                  severity: ReleaseCheckSeverity.blocker,
                ),
                _QaCommand(
                  code: 'flutter_test_release_core',
                  title: 'Release core tests',
                  command: 'flutter',
                  arguments: ['test', 'test/core/release', 'test/core/ads'],
                  severity: ReleaseCheckSeverity.blocker,
                ),
              ]
            : const [
                _QaCommand(
                  code: 'dart_format',
                  title: 'dart format',
                  command: 'dart',
                  arguments: ['format', '.'],
                  severity: ReleaseCheckSeverity.blocker,
                ),
                _QaCommand(
                  code: 'flutter_analyze',
                  title: 'flutter analyze',
                  command: 'flutter',
                  arguments: ['analyze', '--fatal-infos', '--fatal-warnings'],
                  severity: ReleaseCheckSeverity.blocker,
                ),
                _QaCommand(
                  code: 'flutter_test',
                  title: 'flutter test',
                  command: 'flutter',
                  arguments: ['test'],
                  severity: ReleaseCheckSeverity.blocker,
                ),
                _QaCommand(
                  code: 'verify_generator_v1_quality',
                  title: 'Generator v1 quality',
                  command: 'dart',
                  arguments: ['run', 'tool/verify_generator_v1_quality.dart'],
                  severity: ReleaseCheckSeverity.blocker,
                ),
                _QaCommand(
                  code: 'verify_generator_v2_quality',
                  title: 'Generator v2 quality',
                  command: 'dart',
                  arguments: ['run', 'tool/verify_generator_v2_quality.dart'],
                  severity: ReleaseCheckSeverity.blocker,
                ),
                _QaCommand(
                  code: 'validate_ad_configuration',
                  title: 'Ad configuration validation',
                  command: 'dart',
                  arguments: ['run', 'tool/validate_ad_configuration.dart'],
                  severity: ReleaseCheckSeverity.blocker,
                ),
              ],
      ),
    );
  }

  if (!options.skipBuilds && !options.skipAndroid) {
    checks.addAll(
      await _runCommands(
        outputDirectory: outputDirectory,
        commands: const [
          _QaCommand(
            code: 'android_debug_apk',
            title: 'Android debug APK build',
            command: 'flutter',
            arguments: ['build', 'apk', '--debug'],
            severity: ReleaseCheckSeverity.blocker,
            timeoutMinutes: 25,
          ),
        ],
      ),
    );
    checks.add(_androidReleaseAabReadiness());
  }

  if (!options.skipBuilds && !options.skipIos) {
    if (Platform.isMacOS) {
      checks.addAll(
        await _runCommands(
          outputDirectory: outputDirectory,
          commands: const [
            _QaCommand(
              code: 'ios_debug_no_codesign',
              title: 'iOS debug no-codesign build',
              command: 'flutter',
              arguments: ['build', 'ios', '--debug', '--no-codesign'],
              severity: ReleaseCheckSeverity.blocker,
              timeoutMinutes: 25,
            ),
          ],
        ),
      );
    } else {
      checks.add(
        ReleaseCheckResult(
          code: 'ios_debug_no_codesign',
          title: 'iOS debug no-codesign build',
          severity: ReleaseCheckSeverity.warning,
          status: ReleaseCheckStatus.unavailable,
          message: 'iOS build was not run because the host is not macOS.',
        ),
      );
    }
    checks.add(_iosReleaseReadiness());
  }

  final report = buildReport(checks);
  writeReport(report, outputDirectory);
  stdout.writeln('Release QA report written to ${options.outputDirectory}');
  stdout.writeln('status: ${report.status.code}');
  exitCode = exitCodeForChecks(checks);
}

Future<List<ReleaseCheckResult>> _runCommands({
  required Directory outputDirectory,
  required List<_QaCommand> commands,
}) async {
  final checks = <ReleaseCheckResult>[];
  for (final command in commands) {
    final outcome = await runLoggedCommand(
      code: command.code,
      command: command.command,
      arguments: command.arguments,
      outputDirectory: outputDirectory,
      timeout: Duration(minutes: command.timeoutMinutes),
    );
    checks.add(
      commandResultCheck(
        code: command.code,
        title: command.title,
        severity: command.severity,
        outcome: outcome,
      ),
    );
  }
  return checks;
}

ReleaseCheckResult _androidReleaseAabReadiness() {
  final hasAdMobAppId = _hasEnvOrDefine('ADMOB_ANDROID_APP_ID');
  final hasAdUnitId = _hasEnvOrDefine('ADMOB_ANDROID_INTERSTITIAL_ID');
  final signingReady = File('android/key.properties').existsSync();
  if (hasAdMobAppId && hasAdUnitId && signingReady) {
    return ReleaseCheckResult(
      code: 'android_release_aab_readiness',
      title: 'Android release AAB readiness',
      severity: ReleaseCheckSeverity.warning,
      status: ReleaseCheckStatus.manualRequired,
      message:
          'Release inputs appear present; run appbundle build in the release signing environment.',
    );
  }
  return ReleaseCheckResult(
    code: 'android_release_aab_readiness',
    title: 'Android release AAB readiness',
    severity: ReleaseCheckSeverity.blocker,
    status: ReleaseCheckStatus.unavailable,
    message:
        'Android release AAB was not built because production ad IDs or release signing inputs are missing.',
    remediation:
        'Provide real AdMob IDs and release signing through untracked local files or CI secrets.',
    evidence: [
      'ADMOB_ANDROID_APP_ID=${hasAdMobAppId ? 'present' : 'missing'}',
      'ADMOB_ANDROID_INTERSTITIAL_ID=${hasAdUnitId ? 'present' : 'missing'}',
      'android/key.properties=${signingReady ? 'present' : 'missing'}',
    ],
  );
}

ReleaseCheckResult _iosReleaseReadiness() {
  final hasAppId = _hasEnvOrDefine('ADMOB_IOS_APP_ID');
  final hasAdUnitId = _hasEnvOrDefine('ADMOB_IOS_INTERSTITIAL_ID');
  if (hasAppId && hasAdUnitId) {
    return ReleaseCheckResult(
      code: 'ios_release_no_codesign_readiness',
      title: 'iOS release no-codesign readiness',
      severity: ReleaseCheckSeverity.warning,
      status: ReleaseCheckStatus.manualRequired,
      message:
          'Release ad inputs appear present; run iOS release no-codesign build in the release environment.',
    );
  }
  return ReleaseCheckResult(
    code: 'ios_release_no_codesign_readiness',
    title: 'iOS release no-codesign readiness',
    severity: ReleaseCheckSeverity.blocker,
    status: ReleaseCheckStatus.unavailable,
    message:
        'iOS release no-codesign build was not run because production ad IDs are missing.',
    remediation:
        'Provide real iOS AdMob App ID and interstitial ad unit ID before release validation.',
    evidence: [
      'ADMOB_IOS_APP_ID=${hasAppId ? 'present' : 'missing'}',
      'ADMOB_IOS_INTERSTITIAL_ID=${hasAdUnitId ? 'present' : 'missing'}',
    ],
  );
}

bool _hasEnvOrDefine(String key) {
  final value = Platform.environment[key]?.trim();
  return value != null && value.isNotEmpty;
}

class _QaCommand {
  const _QaCommand({
    required this.code,
    required this.title,
    required this.command,
    required this.arguments,
    required this.severity,
    this.timeoutMinutes = 15,
  });

  final String code;
  final String title;
  final String command;
  final List<String> arguments;
  final ReleaseCheckSeverity severity;
  final int timeoutMinutes;
}

class _ReleaseQaOptions {
  const _ReleaseQaOptions({
    required this.skipTests,
    required this.skipBuilds,
    required this.skipIos,
    required this.skipAndroid,
    required this.smoke,
    required this.outputDirectory,
    this.usageError,
  });

  final bool skipTests;
  final bool skipBuilds;
  final bool skipIos;
  final bool skipAndroid;
  final bool smoke;
  final String outputDirectory;
  final String? usageError;

  bool get hasUsageError => usageError != null;

  factory _ReleaseQaOptions.parse(List<String> arguments) {
    var skipTests = false;
    var skipBuilds = false;
    var skipIos = false;
    var skipAndroid = false;
    var smoke = false;
    var outputDirectory = releaseOutputDirectory;

    for (var index = 0; index < arguments.length; index += 1) {
      final argument = arguments[index];
      switch (argument) {
        case '--skip-tests':
          skipTests = true;
        case '--skip-builds':
          skipBuilds = true;
        case '--skip-ios':
          skipIos = true;
        case '--skip-android':
          skipAndroid = true;
        case '--smoke':
          smoke = true;
        case '--output-directory':
          if (index == arguments.length - 1) {
            return const _ReleaseQaOptions(
              skipTests: false,
              skipBuilds: false,
              skipIos: false,
              skipAndroid: false,
              smoke: false,
              outputDirectory: releaseOutputDirectory,
              usageError: '--output-directory requires a value.',
            );
          }
          index += 1;
          outputDirectory = arguments[index];
        default:
          return _ReleaseQaOptions(
            skipTests: false,
            skipBuilds: false,
            skipIos: false,
            skipAndroid: false,
            smoke: false,
            outputDirectory: releaseOutputDirectory,
            usageError: 'Unknown argument: $argument',
          );
      }
    }
    return _ReleaseQaOptions(
      skipTests: skipTests,
      skipBuilds: skipBuilds,
      skipIos: skipIos,
      skipAndroid: skipAndroid,
      smoke: smoke,
      outputDirectory: outputDirectory,
    );
  }
}
