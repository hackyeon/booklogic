import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdRuntimeConfig {
  const AdRuntimeConfig({
    required this.isTestMode,
    required this.adsEnabled,
    this.androidInterstitialAdUnitId,
    this.iosInterstitialAdUnitId,
    this.umpTestDeviceIds = const [],
    this.debugGeography,
  });

  factory AdRuntimeConfig.fromEnvironment() {
    const isRelease = kReleaseMode;
    return AdRuntimeConfig(
      isTestMode: !isRelease,
      adsEnabled: true,
      androidInterstitialAdUnitId: const String.fromEnvironment(
        'ADMOB_ANDROID_INTERSTITIAL_ID',
      ),
      iosInterstitialAdUnitId: const String.fromEnvironment(
        'ADMOB_IOS_INTERSTITIAL_ID',
      ),
      umpTestDeviceIds: isRelease ? const [] : _umpTestDeviceIds,
      debugGeography: isRelease ? null : _debugGeography,
    );
  }

  final bool isTestMode;
  final bool adsEnabled;
  final String? androidInterstitialAdUnitId;
  final String? iosInterstitialAdUnitId;
  final List<String> umpTestDeviceIds;
  final DebugGeography? debugGeography;

  static const _rawUmpTestDeviceIds = String.fromEnvironment(
    'UMP_TEST_DEVICE_IDS',
  );

  static final List<String> _umpTestDeviceIds = _rawUmpTestDeviceIds
      .split(',')
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toList(growable: false);

  static final DebugGeography? _debugGeography = _parseDebugGeography(
    const String.fromEnvironment('UMP_DEBUG_GEOGRAPHY'),
  );

  static DebugGeography? _parseDebugGeography(String value) {
    switch (value.trim().toUpperCase()) {
      case 'EEA':
        return DebugGeography.debugGeographyEea;
      case 'NOT_EEA':
        return DebugGeography.debugGeographyOther;
      case 'DISABLED':
      case '':
        return null;
      default:
        return null;
    }
  }
}
