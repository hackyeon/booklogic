import 'dart:io';

import 'package:booklogic/core/ads/config/admob_production_ids.dart';
import 'package:booklogic/core/ads/config/admob_test_ids.dart';

const _androidProductionAppId = 'ca-app-pub-6427159244427547~8152679496';
const _iosProductionAppId = 'ca-app-pub-6427159244427547~4956399469';

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
      name: 'Android debug/profile sample App ID',
      path: 'android/app/build.gradle.kts',
      pattern: _literal(AdMobTestIds.androidAppId),
    ),
    _AdConfigCheck(
      name: 'Android debug sample App ID assignment',
      path: 'android/app/build.gradle.kts',
      pattern: RegExp(
        r'getByName\("debug"\)\s*\{[^}]*manifestPlaceholders\["ADMOB_APP_ID"\]\s*=\s*sampleAndroidAdMobAppId',
        dotAll: true,
      ),
    ),
    _AdConfigCheck(
      name: 'Android profile sample App ID assignment',
      path: 'android/app/build.gradle.kts',
      pattern: RegExp(
        r'maybeCreate\("profile"\).*?manifestPlaceholders\["ADMOB_APP_ID"\]\s*=\s*sampleAndroidAdMobAppId',
        dotAll: true,
      ),
    ),
    _AdConfigCheck(
      name: 'Android release production App ID',
      path: 'android/app/build.gradle.kts',
      pattern: _literal(_androidProductionAppId),
    ),
    _AdConfigCheck(
      name: 'Android release App ID override',
      path: 'android/app/build.gradle.kts',
      pattern: RegExp(r'ADMOB_ANDROID_APP_ID'),
    ),
    _AdConfigCheck(
      name: 'Android release sample App ID guard',
      path: 'android/app/build.gradle.kts',
      pattern: RegExp(r'Release builds must not use the sample AdMob App ID'),
    ),
    _AdConfigCheck(
      name: 'iOS GADApplicationIdentifier build setting',
      path: 'ios/Runner/Info.plist',
      pattern: RegExp(r'<string>\$\(ADMOB_APP_ID\)</string>'),
    ),
    _AdConfigCheck(
      name: 'iOS debug sample App ID',
      path: 'ios/Flutter/Debug.xcconfig',
      pattern: _literal(AdMobTestIds.iosAppId),
    ),
    _AdConfigCheck(
      name: 'iOS profile sample App ID',
      path: 'ios/Flutter/Profile.xcconfig',
      pattern: _literal(AdMobTestIds.iosAppId),
    ),
    _AdConfigCheck(
      name: 'iOS release production App ID',
      path: 'ios/Flutter/Release.xcconfig',
      pattern: _literal(_iosProductionAppId),
    ),
    _AdConfigCheck(
      name: 'iOS release App ID override connection',
      path: 'ios/Flutter/Release.xcconfig',
      pattern: RegExp(r'ADMOB_APP_ID=\$\(ADMOB_IOS_APP_ID\)'),
    ),
    _AdConfigCheck(
      name: 'Android interstitial test ID',
      path: 'lib/core/ads/config/admob_test_ids.dart',
      pattern: _literal(AdMobTestIds.androidInterstitial),
    ),
    _AdConfigCheck(
      name: 'iOS interstitial test ID',
      path: 'lib/core/ads/config/admob_test_ids.dart',
      pattern: _literal(AdMobTestIds.iosInterstitial),
    ),
    _AdConfigCheck(
      name: 'Android production interstitial ID',
      path: 'lib/core/ads/config/admob_production_ids.dart',
      pattern: _literal(AdMobProductionIds.androidInterstitial),
    ),
    _AdConfigCheck(
      name: 'iOS production interstitial ID',
      path: 'lib/core/ads/config/admob_production_ids.dart',
      pattern: _literal(AdMobProductionIds.iosInterstitial),
    ),
    _AdConfigCheck(
      name: 'Android production interstitial default',
      path: 'lib/core/ads/config/ad_runtime_config.dart',
      pattern: RegExp(
        r'defaultValue:\s*AdMobProductionIds\.androidInterstitial',
      ),
    ),
    _AdConfigCheck(
      name: 'iOS production interstitial default',
      path: 'lib/core/ads/config/ad_runtime_config.dart',
      pattern: RegExp(r'defaultValue:\s*AdMobProductionIds\.iosInterstitial'),
    ),
  ];

  final failures = <String>[];
  for (final check in checks) {
    final file = File(check.path);
    if (!file.existsSync()) {
      failures.add('${check.name}: missing ${check.path}');
      continue;
    }
    if (!check.pattern.hasMatch(file.readAsStringSync())) {
      failures.add('${check.name}: pattern not found');
    }
  }

  final provider = File(
    'lib/core/ads/config/ad_unit_id_provider.dart',
  ).readAsStringSync();
  if (!provider.contains('if (_config.isTestMode)')) {
    failures.add('Debug/Profile test mode branch is missing.');
  }
  if (!provider.contains('AdMobTestIds.isTestInterstitialId')) {
    failures.add('Release ad unit test ID guard is missing.');
  }

  _validateIdKinds(failures);

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

void _validateIdKinds(List<String> failures) {
  final appIds = [
    AdMobTestIds.androidAppId,
    AdMobTestIds.iosAppId,
    _androidProductionAppId,
    _iosProductionAppId,
  ];
  if (appIds.any((id) => !id.contains('~') || id.contains('/'))) {
    failures.add('An AdMob App ID has an invalid separator.');
  }

  final testUnitIds = [
    AdMobTestIds.androidInterstitial,
    AdMobTestIds.iosInterstitial,
  ];
  final productionUnitIds = [
    AdMobProductionIds.androidInterstitial,
    AdMobProductionIds.iosInterstitial,
  ];
  if ([
    ...testUnitIds,
    ...productionUnitIds,
  ].any((id) => !id.contains('/') || id.contains('~'))) {
    failures.add('An AdMob ad unit ID has an invalid separator.');
  }
  if (productionUnitIds.toSet().intersection(testUnitIds.toSet()).isNotEmpty) {
    failures.add('Production and test interstitial IDs must be distinct.');
  }
}

RegExp _literal(String value) => RegExp(RegExp.escape(value));

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
