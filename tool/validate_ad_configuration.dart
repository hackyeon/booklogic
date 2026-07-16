import 'dart:io';

void main() {
  final checks = <_AdConfigCheck>[
    _AdConfigCheck(
      name: 'google_mobile_ads dependency',
      path: 'pubspec.yaml',
      pattern: RegExp(r'google_mobile_ads:\s*\^9\.0\.0'),
    ),
    _AdConfigCheck(
      name: 'Android AdMob App ID manifest placeholder',
      path: 'android/app/src/main/AndroidManifest.xml',
      pattern: RegExp(r'com\.google\.android\.gms\.ads\.APPLICATION_ID'),
    ),
    _AdConfigCheck(
      name: 'Android ADMOB_APP_ID placeholder value',
      path: 'android/app/src/main/AndroidManifest.xml',
      pattern: RegExp(r'\$\{ADMOB_APP_ID\}'),
    ),
    _AdConfigCheck(
      name: 'Android debug sample App ID',
      path: 'android/app/build.gradle.kts',
      pattern: RegExp(r'ca-app-pub-3940256099942544~3347511713'),
    ),
    _AdConfigCheck(
      name: 'Android profile build type',
      path: 'android/app/build.gradle.kts',
      pattern: RegExp(r'maybeCreate\("profile"\)'),
    ),
    _AdConfigCheck(
      name: 'Android release property name',
      path: 'android/app/build.gradle.kts',
      pattern: RegExp(r'ADMOB_ANDROID_APP_ID'),
    ),
    _AdConfigCheck(
      name: 'iOS GADApplicationIdentifier',
      path: 'ios/Runner/Info.plist',
      pattern: RegExp(r'GADApplicationIdentifier'),
    ),
    _AdConfigCheck(
      name: 'iOS ADMOB_APP_ID build setting',
      path: 'ios/Runner/Info.plist',
      pattern: RegExp(r'\$\(ADMOB_APP_ID\)'),
    ),
    _AdConfigCheck(
      name: 'iOS debug sample App ID',
      path: 'ios/Flutter/Debug.xcconfig',
      pattern: RegExp(r'ca-app-pub-3940256099942544~1458002511'),
    ),
    _AdConfigCheck(
      name: 'iOS profile sample App ID',
      path: 'ios/Flutter/Profile.xcconfig',
      pattern: RegExp(r'ca-app-pub-3940256099942544~1458002511'),
    ),
    _AdConfigCheck(
      name: 'iOS release injected App ID',
      path: 'ios/Flutter/Release.xcconfig',
      pattern: RegExp(r'ADMOB_APP_ID=\$\(ADMOB_IOS_APP_ID\)'),
    ),
    _AdConfigCheck(
      name: 'Android interstitial test ID',
      path: 'lib/core/ads/config/admob_test_ids.dart',
      pattern: RegExp(r'ca-app-pub-3940256099942544/1033173712'),
    ),
    _AdConfigCheck(
      name: 'iOS interstitial test ID',
      path: 'lib/core/ads/config/admob_test_ids.dart',
      pattern: RegExp(r'ca-app-pub-3940256099942544/4411468910'),
    ),
  ];

  final failures = <String>[];
  for (final check in checks) {
    final file = File(check.path);
    if (!file.existsSync()) {
      failures.add('${check.name}: missing ${check.path}');
      continue;
    }
    final content = file.readAsStringSync();
    if (!check.pattern.hasMatch(content)) {
      failures.add('${check.name}: pattern not found');
    }
  }

  final provider = File(
    'lib/core/ads/config/ad_unit_id_provider.dart',
  ).readAsStringSync();
  if (!provider.contains('AdMobTestIds.isTestInterstitialId')) {
    failures.add('Release ad unit test ID guard is missing.');
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Ad configuration validation failed:');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exitCode = 1;
    return;
  }

  stdout.writeln('Ad configuration validated.');
}

class _AdConfigCheck {
  const _AdConfigCheck({
    required this.name,
    required this.path,
    required this.pattern,
  });

  final String name;
  final String path;
  final RegExp pattern;
}
