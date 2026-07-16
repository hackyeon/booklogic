import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:booklogic/core/release/release_check_result.dart';
import 'package:booklogic/core/release/release_check_severity.dart';
import 'package:booklogic/core/release/release_check_status.dart';
import 'package:booklogic/core/release/release_readiness_report.dart';
import 'package:booklogic/features/game/domain/book_placement.dart';
import 'package:booklogic/features/game/domain/book_position.dart';
import 'package:booklogic/features/game/domain/clue_evaluator.dart';
import 'package:booklogic/features/game/generator/generated_stage.dart';
import 'package:booklogic/features/game/generator/generated_stage_validator.dart';
import 'package:booklogic/features/game/generator/generator_config.dart';
import 'package:booklogic/features/game/generator/generator_version_policy.dart';
import 'package:booklogic/features/game/generator/quality/generator_v1_quality_manifest.dart';
import 'package:booklogic/features/game/generator/quality/generator_v2_quality_manifest.dart';
import 'package:booklogic/features/game/generator/stage_generator.dart';

const releaseBaselinePath = 'release/release_baseline.json';
const releaseOutputDirectory = 'build/release_qa';

const generatorV1Checksum = GeneratorV1QualityManifest.checksum;
const generatorV2Checksum = GeneratorV2QualityManifest.checksum;

final _fullAdMobIdPattern = RegExp(r'ca-app-pub-\d{16}[/~]\d{10}');
final _placeholderIdentifierPattern = RegExp(
  r'^(com\.example|org\.example|your\.company)',
);

class ProjectInfo {
  const ProjectInfo({
    required this.appVersion,
    required this.appVersionName,
    required this.buildNumber,
    required this.androidApplicationId,
    required this.androidNamespace,
    required this.androidMinSdk,
    required this.androidCompileSdk,
    required this.androidTargetSdk,
    required this.androidLabel,
    required this.iosBundleIdentifier,
    required this.iosDeploymentTarget,
    required this.iosDisplayName,
  });

  final String appVersion;
  final String appVersionName;
  final int buildNumber;
  final String androidApplicationId;
  final String androidNamespace;
  final String androidMinSdk;
  final String androidCompileSdk;
  final String androidTargetSdk;
  final String androidLabel;
  final String iosBundleIdentifier;
  final String iosDeploymentTarget;
  final String iosDisplayName;
}

class CommandOutcome {
  const CommandOutcome({
    required this.command,
    required this.arguments,
    required this.exitCode,
    required this.logPath,
    required this.timedOut,
  });

  final String command;
  final List<String> arguments;
  final int exitCode;
  final String logPath;
  final bool timedOut;
}

ProjectInfo readProjectInfo() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final buildGradle = File('android/app/build.gradle.kts').readAsStringSync();
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();
  final pbxproj = File(
    'ios/Runner.xcodeproj/project.pbxproj',
  ).readAsStringSync();
  final plist = File('ios/Runner/Info.plist').readAsStringSync();

  final appVersion = _firstMatch(
    pubspec,
    RegExp(r'^version:\s*([^\s]+)$', multiLine: true),
  );
  final versionMatch = RegExp(
    r'^(\d+)\.(\d+)\.(\d+)\+(\d+)$',
  ).firstMatch(appVersion);
  final buildNumber = int.parse(versionMatch?.group(4) ?? '0');

  return ProjectInfo(
    appVersion: appVersion,
    appVersionName: versionMatch == null
        ? appVersion
        : '${versionMatch.group(1)}.${versionMatch.group(2)}.${versionMatch.group(3)}',
    buildNumber: buildNumber,
    androidApplicationId: _firstMatch(
      buildGradle,
      RegExp(r'applicationId\s*=\s*"([^"]+)"'),
    ),
    androidNamespace: _firstMatch(
      buildGradle,
      RegExp(r'namespace\s*=\s*"([^"]+)"'),
    ),
    androidMinSdk: _firstMatch(
      buildGradle,
      RegExp(r'minSdk\s*=\s*([^\n]+)'),
    ).trim(),
    androidCompileSdk: _firstMatch(
      buildGradle,
      RegExp(r'compileSdk\s*=\s*([^\n]+)'),
    ).trim(),
    androidTargetSdk: _firstMatch(
      buildGradle,
      RegExp(r'targetSdk\s*=\s*([^\n]+)'),
    ).trim(),
    androidLabel: _firstMatch(manifest, RegExp(r'android:label="([^"]+)"')),
    iosBundleIdentifier: _firstNonTestBundleIdentifier(pbxproj),
    iosDeploymentTarget: _firstMatch(
      pbxproj,
      RegExp(r'IPHONEOS_DEPLOYMENT_TARGET\s*=\s*([^;]+);'),
    ),
    iosDisplayName: _plistString(plist, 'CFBundleDisplayName') ?? '',
  );
}

Map<String, Object?> currentBaselineJson() {
  final info = readProjectInfo();
  return {
    'baselineVersion': 1,
    'appVersion': info.appVersion,
    'androidApplicationId': info.androidApplicationId,
    'iosBundleIdentifier': info.iosBundleIdentifier,
    'minimumSupportedLevel': 1,
    'maximumSupportedLevel': 400,
    'generatorVersions': {
      '1': {
        'minimumLevel': GeneratorV1QualityManifest.minimumLevel,
        'maximumLevel': GeneratorV1QualityManifest.maximumLevel,
        'manifestChecksum': GeneratorV1QualityManifest.checksum,
      },
      '2': {
        'minimumLevel': GeneratorV2QualityManifest.minimumLevel,
        'maximumLevel': GeneratorV2QualityManifest.maximumLevel,
        'manifestChecksum': GeneratorV2QualityManifest.checksum,
      },
    },
  };
}

List<ReleaseCheckResult> verifyReleaseBaselineChecks() {
  final checks = <ReleaseCheckResult>[];
  final info = readProjectInfo();
  final baselineFile = File(releaseBaselinePath);
  if (!baselineFile.existsSync()) {
    return [
      _failed(
        'release_baseline_exists',
        'Release baseline exists',
        'release_baseline.json is missing.',
        remediation:
            'Create release/release_baseline.json from current safe project values.',
      ),
    ];
  }

  final baseline =
      jsonDecode(baselineFile.readAsStringSync()) as Map<String, Object?>;
  void compare(String code, String title, Object? actual, Object? expected) {
    if (actual == expected) {
      checks.add(_passed(code, title, '$actual'));
    } else {
      checks.add(
        _failed(
          code,
          title,
          'Baseline mismatch.',
          remediation:
              'Do not regenerate automatically. Investigate the source change.',
          evidence: ['baseline=$expected', 'actual=$actual'],
        ),
      );
    }
  }

  compare(
    'baseline_version',
    'Baseline schema version',
    baseline['baselineVersion'],
    1,
  );
  compare(
    'baseline_app_version',
    'App version baseline',
    info.appVersion,
    baseline['appVersion'],
  );
  compare(
    'baseline_android_application_id',
    'Android applicationId baseline',
    info.androidApplicationId,
    baseline['androidApplicationId'],
  );
  compare(
    'baseline_ios_bundle_identifier',
    'iOS bundle identifier baseline',
    info.iosBundleIdentifier,
    baseline['iosBundleIdentifier'],
  );
  compare(
    'baseline_minimum_level',
    'Minimum supported level',
    1,
    baseline['minimumSupportedLevel'],
  );
  compare(
    'baseline_maximum_level',
    'Maximum supported level',
    400,
    baseline['maximumSupportedLevel'],
  );

  final generatorVersions = (baseline['generatorVersions']! as Map)
      .cast<String, Object?>();
  final v1 = (generatorVersions['1']! as Map).cast<String, Object?>();
  final v2 = (generatorVersions['2']! as Map).cast<String, Object?>();
  compare(
    'baseline_v1_minimum_level',
    'Generator v1 minimum level',
    1,
    v1['minimumLevel'],
  );
  compare(
    'baseline_v1_maximum_level',
    'Generator v1 maximum level',
    200,
    v1['maximumLevel'],
  );
  compare(
    'baseline_v1_checksum',
    'Generator v1 manifest checksum',
    GeneratorV1QualityManifest.checksum,
    v1['manifestChecksum'],
  );
  compare(
    'baseline_v2_minimum_level',
    'Generator v2 minimum level',
    201,
    v2['minimumLevel'],
  );
  compare(
    'baseline_v2_maximum_level',
    'Generator v2 maximum level',
    400,
    v2['maximumLevel'],
  );
  compare(
    'baseline_v2_checksum',
    'Generator v2 manifest checksum',
    GeneratorV2QualityManifest.checksum,
    v2['manifestChecksum'],
  );

  checks.addAll(_verifyLevelPolicyAndGeneration());
  return checks;
}

List<ReleaseCheckResult> verifyReleaseConfigurationChecks() {
  final info = readProjectInfo();
  final checks = <ReleaseCheckResult>[
    _verifyAppVersion(info),
    _verifyIdentifier(
      code: 'android_application_id',
      title: 'Android applicationId',
      value: info.androidApplicationId,
    ),
    _verifyIdentifier(
      code: 'ios_bundle_identifier',
      title: 'iOS bundle identifier',
      value: info.iosBundleIdentifier,
    ),
    _verifyAndroidConfiguration(info),
    _verifyIosConfiguration(info),
    _verifyAdConfiguration(),
    _verifyPrivacyPolicyUrl(),
    _verifySecretScan(),
    _verifySourcePlaceholders(),
    _verifyDebugUiExposure(),
    _verifyAssets(),
    _verifyDependencies(),
    _manual(
      'store_policy_latest_manual',
      'Store policy freshness',
      'Google Play and App Store policies must be reviewed again at submission time.',
      evidence: ['release/store_submission_checklist.md'],
    ),
    _manual(
      'ios_privacy_manifest_manual',
      'iOS Privacy Manifest review',
      'Archive privacy report and SDK privacy manifests require manual release review.',
      evidence: ['release/store_submission_checklist.md'],
    ),
    _manual(
      'device_qa_manual',
      'Real device QA',
      'Physical device, haptic, audio, accessibility, ad no-fill, and store console tests were not executed by this tool.',
      evidence: ['release/manual_qa_matrix.md'],
    ),
  ];
  checks.addAll(_verifyReleaseDocuments());
  return checks;
}

Future<CommandOutcome> runLoggedCommand({
  required String code,
  required String command,
  required List<String> arguments,
  required Directory outputDirectory,
  Duration timeout = const Duration(minutes: 15),
}) async {
  final logsDirectory = Directory('${outputDirectory.path}/command_logs');
  logsDirectory.createSync(recursive: true);
  final logPath = '${logsDirectory.path}/$code.log';
  final log = File(logPath);
  final sink = log.openWrite();
  sink.writeln('command: $command ${arguments.join(' ')}');
  sink.writeln();

  late final Process process;
  try {
    process = await Process.start(command, arguments);
  } catch (error) {
    sink.writeln('start_error: $error');
    await sink.close();
    return CommandOutcome(
      command: command,
      arguments: arguments,
      exitCode: 127,
      logPath: _relativePath(logPath),
      timedOut: false,
    );
  }

  final stdoutDone = process.stdout.transform(utf8.decoder).listen(sink.write);
  final stderrDone = process.stderr.transform(utf8.decoder).listen(sink.write);
  var timedOut = false;
  final timer = Timer(timeout, () {
    timedOut = true;
    process.kill(ProcessSignal.sigterm);
  });
  final exitCode = await process.exitCode;
  timer.cancel();
  await stdoutDone.cancel();
  await stderrDone.cancel();
  sink.writeln();
  sink.writeln('exitCode: $exitCode');
  if (timedOut) {
    sink.writeln('timedOut: true');
  }
  await sink.close();

  return CommandOutcome(
    command: command,
    arguments: arguments,
    exitCode: exitCode,
    logPath: _relativePath(logPath),
    timedOut: timedOut,
  );
}

ReleaseCheckResult commandResultCheck({
  required String code,
  required String title,
  required ReleaseCheckSeverity severity,
  required CommandOutcome outcome,
}) {
  if (outcome.exitCode == 0 && !outcome.timedOut) {
    return ReleaseCheckResult(
      code: code,
      title: title,
      severity: severity,
      status: ReleaseCheckStatus.passed,
      message: 'Command completed successfully.',
      evidence: [outcome.logPath],
    );
  }
  return ReleaseCheckResult(
    code: code,
    title: title,
    severity: severity,
    status: outcome.timedOut
        ? ReleaseCheckStatus.unavailable
        : ReleaseCheckStatus.failed,
    message: outcome.timedOut
        ? 'Command timed out before completion.'
        : 'Command exited with code ${outcome.exitCode}.',
    remediation: 'Review the command log and fix the underlying failure.',
    evidence: [outcome.logPath],
  );
}

ReleaseReadinessReport buildReport(List<ReleaseCheckResult> checks) {
  final info = readProjectInfo();
  return ReleaseReadinessReport.fromChecks(
    appVersion: info.appVersion,
    androidApplicationId: info.androidApplicationId,
    iosBundleIdentifier: info.iosBundleIdentifier,
    generatorV1Checksum: GeneratorV1QualityManifest.checksum,
    generatorV2Checksum: GeneratorV2QualityManifest.checksum,
    checks: checks,
  );
}

void writeReport(ReleaseReadinessReport report, Directory outputDirectory) {
  outputDirectory.createSync(recursive: true);
  File(
    '${outputDirectory.path}/release_readiness_report.json',
  ).writeAsStringSync('${report.toPrettyJson()}\n');
  File(
    '${outputDirectory.path}/release_readiness_report.md',
  ).writeAsStringSync(report.toMarkdown());
}

int exitCodeForChecks(List<ReleaseCheckResult> checks) {
  return checks.any((check) => check.isBlockingFailure) ? 1 : 0;
}

List<ReleaseCheckResult> _verifyLevelPolicyAndGeneration() {
  final checks = <ReleaseCheckResult>[];
  const policy = GeneratorVersionPolicy();
  const generator = StageGenerator();
  const validator = GeneratedStageValidator();
  const evaluator = ClueEvaluator();
  final failures = <String>[];
  final representativeFailures = <String>[];
  const representativeLevels = [
    1,
    20,
    21,
    23,
    50,
    51,
    100,
    101,
    200,
    201,
    241,
    281,
    321,
    400,
  ];

  for (final entry in <int, int>{1: 1, 200: 1, 201: 2, 400: 2}.entries) {
    try {
      final actual = policy.versionForLevel(entry.key);
      if (actual != entry.value) {
        failures.add('level_${entry.key}_policy_$actual');
      }
    } catch (error) {
      failures.add('level_${entry.key}_policy_error');
    }
  }
  try {
    policy.versionForLevel(401);
    failures.add('level_401_supported');
  } on UnsupportedError {
    // Expected.
  }

  for (var level = 1; level <= 400; level += 1) {
    final version = policy.versionForLevel(level);
    try {
      final first = generator.generate(level: level, generatorVersion: version);
      final second = generator.generate(
        level: level,
        generatorVersion: version,
      );
      if (first != second) {
        failures.add('level_${level}_not_deterministic');
      }
      if (!validator.validate(first).isValid) {
        failures.add('level_${level}_invalid');
      }
      if (first.isFallback) {
        failures.add('level_${level}_fallback');
      }
      final preferredAttempt = version == GeneratorConfig.generatorVersion1
          ? GeneratorV1QualityManifest.preferredAttemptByLevel[level]
          : GeneratorV2QualityManifest.preferredAttemptByLevel[level];
      if (first.generationAttempt != preferredAttempt) {
        failures.add(
          'level_${level}_attempt_${first.generationAttempt}_expected_$preferredAttempt',
        );
      }
      final targetSatisfied = evaluator.evaluateAll(
        clues: first.clues,
        placements: first.targetPlacements,
      );
      if (targetSatisfied.length != first.clues.length) {
        failures.add('level_${level}_target_unsatisfied');
      }
      final initialSatisfied = evaluator.evaluateAll(
        clues: first.clues,
        placements: first.initialPlacements,
      );
      if (initialSatisfied.length == first.clues.length) {
        failures.add('level_${level}_initial_already_clear');
      }
      if (representativeLevels.contains(level) &&
          jsonEncode(_stageSnapshot(first)) !=
              jsonEncode(_stageSnapshot(second))) {
        representativeFailures.add('level_$level');
      }
    } catch (error) {
      failures.add('level_${level}_${error.runtimeType}');
    }
  }

  checks.add(
    failures.isEmpty
        ? _passed(
            'level_1_400_generation',
            'Level 1-400 generation',
            'All generated stages are deterministic, valid, non-fallback, and use manifest attempts.',
          )
        : _failed(
            'level_1_400_generation',
            'Level 1-400 generation',
            'Generation regression detected.',
            remediation:
                'Do not regenerate manifests automatically. Investigate generator changes.',
            evidence: failures.take(20).toList(growable: false),
          ),
  );
  checks.add(
    representativeFailures.isEmpty
        ? _passed(
            'representative_stage_snapshots',
            'Representative stage snapshots',
            'Representative levels regenerate to identical deterministic snapshots.',
          )
        : _failed(
            'representative_stage_snapshots',
            'Representative stage snapshots',
            'Representative stage snapshot mismatch.',
            remediation:
                'Investigate generator output drift without changing golden data.',
            evidence: representativeFailures,
          ),
  );
  checks.add(
    _passed(
      'level_400_401_policy',
      'Level 400 to 401 policy',
      'Level 400 is supported and Level 401 remains unsupported.',
    ),
  );
  return checks;
}

ReleaseCheckResult _verifyAppVersion(ProjectInfo info) {
  final valid =
      RegExp(r'^\d+\.\d+\.\d+\+\d+$').hasMatch(info.appVersion) &&
      info.buildNumber >= 1;
  return valid
      ? _passed(
          'app_version',
          'App version',
          info.appVersion,
          evidence: [
            'versionName=${info.appVersionName}',
            'buildNumber=${info.buildNumber}',
          ],
        )
      : _failed(
          'app_version',
          'App version',
          'pubspec.yaml version must be major.minor.patch+buildNumber.',
          remediation:
              'Set an explicit release version after product approval.',
        );
}

ReleaseCheckResult _verifyIdentifier({
  required String code,
  required String title,
  required String value,
}) {
  final invalid =
      value.isEmpty ||
      _placeholderIdentifierPattern.hasMatch(value) ||
      value.toLowerCase().contains('todo') ||
      value.toLowerCase().contains('placeholder');
  return invalid
      ? _failed(code, title, 'Identifier is a placeholder.', evidence: [value])
      : _passed(code, title, value);
}

ReleaseCheckResult _verifyAndroidConfiguration(ProjectInfo info) {
  final gradle = File('android/app/build.gradle.kts').readAsStringSync();
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();
  final failures = <String>[];
  final warnings = <String>[];
  if (info.androidApplicationId.isEmpty) {
    failures.add('missing applicationId');
  }
  if (info.androidNamespace.isEmpty) {
    failures.add('missing namespace');
  }
  if (!gradle.contains('versionCode = flutter.versionCode')) {
    failures.add('missing versionCode');
  }
  if (!gradle.contains('versionName = flutter.versionName')) {
    failures.add('missing versionName');
  }
  if (!gradle.contains('release {')) {
    failures.add('missing release buildType');
  }
  if (!gradle.contains('ADMOB_ANDROID_APP_ID')) {
    failures.add('missing release AdMob App ID injection');
  }
  if (!gradle.contains('Release builds must not use the sample AdMob App ID')) {
    failures.add('missing sample AdMob App ID release guard');
  }
  if (gradle.contains('signingConfig = signingConfigs.getByName("debug")')) {
    failures.add('release uses debug signing config');
  }
  if (manifest.contains('usesCleartextTraffic="true"')) {
    failures.add('cleartext traffic allowed');
  }
  if (!manifest.contains('android:exported="true"')) {
    warnings.add('launcher exported flag not found');
  }
  if (!manifest.contains('screenOrientation="portrait"')) {
    warnings.add('portrait orientation is not locked in AndroidManifest');
  }

  if (failures.isNotEmpty) {
    return _failed(
      'android_release_configuration',
      'Android release configuration',
      'Android release configuration has blockers.',
      remediation:
          'Configure production signing and verify release manifest before Store submission.',
      evidence: [...failures, ...warnings],
    );
  }
  return warnings.isEmpty
      ? _passed(
          'android_release_configuration',
          'Android release configuration',
          'Required Android release settings are present.',
        )
      : _warning(
          'android_release_configuration',
          'Android release configuration',
          'Android release configuration needs manual review.',
          evidence: warnings,
        );
}

ReleaseCheckResult _verifyIosConfiguration(ProjectInfo info) {
  final plist = File('ios/Runner/Info.plist').readAsStringSync();
  final debug = File('ios/Flutter/Debug.xcconfig').readAsStringSync();
  final profile = File('ios/Flutter/Profile.xcconfig').readAsStringSync();
  final release = File('ios/Flutter/Release.xcconfig').readAsStringSync();
  final failures = <String>[];
  final warnings = <String>[];
  if (info.iosBundleIdentifier.isEmpty) {
    failures.add('missing bundle identifier');
  }
  if (info.iosDeploymentTarget.isEmpty) {
    failures.add('missing deployment target');
  }
  if (!plist.contains('GADApplicationIdentifier')) {
    failures.add('missing GADApplicationIdentifier');
  }
  if (!_containsMaskedSampleAppId(debug)) {
    failures.add('missing debug sample App ID');
  }
  if (!_containsMaskedSampleAppId(profile)) {
    failures.add('missing profile sample App ID');
  }
  if (!release.contains(r'ADMOB_APP_ID=$(ADMOB_IOS_APP_ID)')) {
    failures.add('missing release App ID injection');
  }
  if (release.contains('ca-app-pub-3940256099942544')) {
    failures.add('release uses sample App ID');
  }
  if (plist.contains('UIInterfaceOrientationLandscape')) {
    warnings.add('iPhone/iPad landscape orientations are still enabled');
  }
  if (failures.isNotEmpty) {
    return _failed(
      'ios_release_configuration',
      'iOS release configuration',
      'iOS release configuration has blockers.',
      remediation:
          'Fix Info.plist and xcconfig release settings before Store submission.',
      evidence: [...failures, ...warnings],
    );
  }
  return warnings.isEmpty
      ? _passed(
          'ios_release_configuration',
          'iOS release configuration',
          'Required iOS release settings are present.',
        )
      : _warning(
          'ios_release_configuration',
          'iOS release configuration',
          'iOS release configuration needs manual review.',
          evidence: warnings,
        );
}

ReleaseCheckResult _verifyAdConfiguration() {
  final runtime = File(
    'lib/core/ads/config/ad_runtime_config.dart',
  ).readAsStringSync();
  final provider = File(
    'lib/core/ads/config/ad_unit_id_provider.dart',
  ).readAsStringSync();
  final policy = File(
    'lib/core/ads/interstitial/interstitial_ad_policy.dart',
  ).readAsStringSync();
  final failures = <String>[];
  if (!runtime.contains('isRelease ? const [] : _umpTestDeviceIds')) {
    failures.add('UMP test device IDs not disabled in release');
  }
  if (!runtime.contains('isRelease ? null : _debugGeography')) {
    failures.add('UMP debug geography not disabled in release');
  }
  if (!provider.contains('AdMobTestIds.isTestInterstitialId')) {
    failures.add('release test ad unit guard missing');
  }
  if (!policy.contains('currentLevel < 6')) {
    failures.add('level 1-5 ad exclusion policy missing');
  }
  return failures.isEmpty
      ? _passed(
          'ad_release_configuration',
          'Ad release configuration',
          'Debug/Profile test IDs are separated from Release runtime injection.',
        )
      : _failed(
          'ad_release_configuration',
          'Ad release configuration',
          'Ad release configuration has blockers.',
          evidence: failures,
        );
}

ReleaseCheckResult _verifyPrivacyPolicyUrl() {
  final strings = File(
    'lib/core/constants/app_strings.dart',
  ).readAsStringSync();
  final hasHttpsUrl = RegExp(
    r'https://[^\s'
    '"<>]+',
  ).hasMatch(strings);
  return hasHttpsUrl
      ? _manual(
          'privacy_policy_url',
          'Privacy policy URL',
          'An HTTPS URL is present; reachability and policy coverage require manual verification.',
        )
      : _failed(
          'privacy_policy_url',
          'Privacy policy URL',
          'No production HTTPS privacy policy URL is configured.',
          remediation:
              'Add a real privacy policy URL that covers ads and UMP before Store submission.',
        );
}

ReleaseCheckResult _verifySecretScan() {
  final findings = <String>[];
  for (final file in _scanFiles()) {
    final lines = file.readAsLinesSync();
    for (var index = 0; index < lines.length; index += 1) {
      final line = lines[index];
      final lower = line.toLowerCase();
      if (lower.contains('storepassword') ||
          lower.contains('keypassword') ||
          lower.contains('keystorepassword') ||
          lower.contains('api_secret') ||
          lower.contains('client_secret')) {
        findings.add('${_relativePath(file.path)}:${index + 1}');
      }
      if (_fullAdMobIdPattern.hasMatch(line) &&
          !line.contains('3940256099942544') &&
          !line.contains('0000000000000000')) {
        findings.add('${_relativePath(file.path)}:${index + 1}');
      }
    }
  }
  return findings.isEmpty
      ? _passed(
          'secret_scan',
          'Secret scan',
          'No obvious hard-coded signing secrets or production AdMob IDs were found.',
        )
      : _failed(
          'secret_scan',
          'Secret scan',
          'Potential secret material was found.',
          remediation:
              'Move secrets to local untracked files or CI secret storage.',
          evidence: findings,
        );
}

ReleaseCheckResult _verifySourcePlaceholders() {
  final findings = <String>[];
  final patterns = <String>[
    'com.example',
    'example.com/privacy',
    'TODO_PRIVACY_URL',
    'YOUR_ADMOB',
    'YOUR_APP_ID',
    'YOUR_AD_UNIT_ID',
    '127.0.0.1',
    'localhost',
  ];
  for (final file in _scanFiles()) {
    final lines = file.readAsLinesSync();
    for (var index = 0; index < lines.length; index += 1) {
      final line = lines[index];
      for (final pattern in patterns) {
        if (line.contains(pattern)) {
          findings.add('${_relativePath(file.path)}:${index + 1}:$pattern');
        }
      }
    }
  }
  return findings.isEmpty
      ? _passed(
          'placeholder_scan',
          'Placeholder scan',
          'No release-blocking placeholders were found in release source files.',
        )
      : _failed(
          'placeholder_scan',
          'Placeholder scan',
          'Release-blocking placeholder strings were found.',
          remediation:
              'Replace placeholders with production values or remove unreachable sample code.',
          evidence: findings,
        );
}

ReleaseCheckResult _verifyDebugUiExposure() {
  final findings = <String>[];
  final patterns = [
    'debug menu',
    'debug_menu',
    'seed 표시',
    'solver 실행',
    'auto clear',
  ];
  for (final file in Directory(
    'lib',
  ).listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart')) continue;
    final lines = file.readAsLinesSync();
    for (var index = 0; index < lines.length; index += 1) {
      final lower = lines[index].toLowerCase();
      for (final pattern in patterns) {
        if (lower.contains(pattern)) {
          findings.add('${_relativePath(file.path)}:${index + 1}');
        }
      }
    }
  }
  return findings.isEmpty
      ? _passed(
          'debug_ui_release_exposure',
          'Debug UI release exposure',
          'No obvious release-accessible debug, solver, seed, or auto-clear UI was found.',
        )
      : _failed(
          'debug_ui_release_exposure',
          'Debug UI release exposure',
          'Potential debug UI references were found.',
          remediation: 'Ensure debug tooling is unavailable in release builds.',
          evidence: findings,
        );
}

ReleaseCheckResult _verifyAssets() {
  final requiredAssets = [
    'assets/audio/sfx/book_select.wav',
    'assets/audio/sfx/book_swap.wav',
    'assets/audio/sfx/clue_satisfied.wav',
    'assets/audio/sfx/stage_clear.wav',
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
  ];
  final missing = <String>[];
  final empty = <String>[];
  for (final path in requiredAssets) {
    final file = File(path);
    if (!file.existsSync()) {
      missing.add(path);
    } else if (file.lengthSync() == 0) {
      empty.add(path);
    }
  }
  final failures = [
    ...missing.map((path) => 'missing $path'),
    ...empty.map((path) => 'empty $path'),
  ];
  return failures.isEmpty
      ? _manual(
          'asset_inventory',
          'Asset inventory',
          'Required assets exist. Visual icon and launch screen quality require manual review.',
          evidence: requiredAssets,
        )
      : _failed(
          'asset_inventory',
          'Asset inventory',
          'Required release assets are missing or empty.',
          evidence: failures,
        );
}

ReleaseCheckResult _verifyDependencies() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final findings = <String>[];
  if (pubspec.contains('dependency_overrides:')) {
    findings.add('dependency_overrides present');
  }
  if (RegExp(r'^\s*path:\s', multiLine: true).hasMatch(pubspec)) {
    findings.add('path dependency present');
  }
  if (RegExp(r'^\s*git:\s', multiLine: true).hasMatch(pubspec)) {
    findings.add('git dependency present');
  }
  final adPackageCount = RegExp(
    r'^\s*google_mobile_ads:',
    multiLine: true,
  ).allMatches(pubspec).length;
  if (adPackageCount != 1) {
    findings.add('expected exactly one google_mobile_ads dependency');
  }
  return findings.isEmpty
      ? _passed(
          'dependency_configuration',
          'Dependency configuration',
          'No dependency overrides, path dependencies, git dependencies, or duplicate ad packages were found.',
        )
      : _warning(
          'dependency_configuration',
          'Dependency configuration',
          'Dependency configuration needs manual review.',
          evidence: findings,
        );
}

List<ReleaseCheckResult> _verifyReleaseDocuments() {
  final required = [
    'release/manual_qa_matrix.md',
    'release/store_submission_checklist.md',
    'release/privacy_data_inventory.md',
    'release/permission_inventory.md',
    'release/release_scope.md',
    'release/known_issues.md',
    'release/release_notes_ko.md',
  ];
  return [
    for (final path in required)
      File(path).existsSync()
          ? _passed(
              'document_${_codeForPath(path)}',
              'Document $path',
              'Document exists.',
            )
          : _failed(
              'document_${_codeForPath(path)}',
              'Document $path',
              'Required release document is missing.',
              remediation:
                  'Create the release document before Store submission.',
            ),
  ];
}

Map<String, Object?> _stageSnapshot(GeneratedStage stage) {
  return {
    'level': stage.level,
    'generatorVersion': stage.generatorVersion,
    'stageSpec': stage.stageSpec.toString(),
    'templateId': stage.templateId.toString(),
    'generationAttempt': stage.generationAttempt,
    'generationAttemptSeed': stage.generationAttemptSeed,
    'scrambleSeed': stage.scrambleSeed,
    'isFallback': stage.isFallback,
    'target': _placementsSnapshot(stage.targetPlacements),
    'initial': _placementsSnapshot(stage.initialPlacements),
    'clues': [for (final clue in stage.clues) clue.toString()],
    'swapHistory': [
      for (final step in stage.swapHistory)
        {
          'stepIndex': step.stepIndex,
          'firstPosition': _positionSnapshot(step.firstPosition),
          'secondPosition': _positionSnapshot(step.secondPosition),
          'firstBookIdBeforeSwap': step.firstBookIdBeforeSwap,
          'secondBookIdBeforeSwap': step.secondBookIdBeforeSwap,
        },
    ],
  };
}

List<Map<String, Object?>> _placementsSnapshot(List<BookPlacement> placements) {
  return [
    for (final placement in placements)
      {
        'bookId': placement.book.id,
        'color': placement.book.color.name,
        'symbol': placement.book.symbol.name,
        'position': _positionSnapshot(placement.position),
      },
  ];
}

Map<String, int> _positionSnapshot(BookPosition position) {
  return {'tierIndex': position.tierIndex, 'slotIndex': position.slotIndex};
}

Iterable<File> _scanFiles() sync* {
  final roots = ['lib', 'android', 'ios'];
  for (final root in roots) {
    final directory = Directory(root);
    if (!directory.existsSync()) continue;
    for (final entity in directory.listSync(recursive: true)) {
      if (entity is! File) continue;
      final path = entity.path;
      if (path.contains('/Pods/') ||
          path.contains('/.symlinks/') ||
          path.contains('/DerivedData/') ||
          path.contains('/.gradle/') ||
          path.contains('/gradle/wrapper/') ||
          path.endsWith('.jar') ||
          path.endsWith('.class') ||
          path.endsWith('.png') ||
          path.endsWith('.wav')) {
        continue;
      }
      yield entity;
    }
  }
  yield File('pubspec.yaml');
}

ReleaseCheckResult _passed(
  String code,
  String title,
  String message, {
  List<String> evidence = const [],
}) {
  return ReleaseCheckResult(
    code: code,
    title: title,
    severity: ReleaseCheckSeverity.info,
    status: ReleaseCheckStatus.passed,
    message: message,
    evidence: evidence,
  );
}

ReleaseCheckResult _failed(
  String code,
  String title,
  String message, {
  String? remediation,
  List<String> evidence = const [],
}) {
  return ReleaseCheckResult(
    code: code,
    title: title,
    severity: ReleaseCheckSeverity.blocker,
    status: ReleaseCheckStatus.failed,
    message: message,
    remediation: remediation,
    evidence: evidence,
  );
}

ReleaseCheckResult _warning(
  String code,
  String title,
  String message, {
  List<String> evidence = const [],
}) {
  return ReleaseCheckResult(
    code: code,
    title: title,
    severity: ReleaseCheckSeverity.warning,
    status: ReleaseCheckStatus.manualRequired,
    message: message,
    evidence: evidence,
  );
}

ReleaseCheckResult _manual(
  String code,
  String title,
  String message, {
  List<String> evidence = const [],
}) {
  return ReleaseCheckResult(
    code: code,
    title: title,
    severity: ReleaseCheckSeverity.warning,
    status: ReleaseCheckStatus.manualRequired,
    message: message,
    evidence: evidence,
  );
}

bool _containsMaskedSampleAppId(String value) {
  return value.contains('ca-app-pub-3940256099942544') && value.contains('~');
}

String _firstMatch(String source, RegExp pattern) {
  return pattern.firstMatch(source)?.group(1) ?? '';
}

String _firstNonTestBundleIdentifier(String pbxproj) {
  for (final match in RegExp(
    r'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*([^;]+);',
  ).allMatches(pbxproj)) {
    final value = match.group(1)!.trim();
    if (!value.endsWith('.RunnerTests')) {
      return value;
    }
  }
  return '';
}

String? _plistString(String plist, String key) {
  final match = RegExp(
    '<key>${RegExp.escape(key)}</key>\\s*<string>([^<]+)</string>',
  ).firstMatch(plist);
  return match?.group(1);
}

String _relativePath(String path) {
  final normalized = path.replaceAll('\\', '/');
  final cwd = Directory.current.path.replaceAll('\\', '/');
  if (normalized.startsWith('$cwd/')) {
    return normalized.substring(cwd.length + 1);
  }
  return normalized;
}

String _codeForPath(String path) {
  return path
      .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
      .toLowerCase()
      .replaceAll(RegExp(r'^_|_$'), '');
}
