import 'package:flutter/foundation.dart';

import 'ad_runtime_config.dart';
import 'admob_test_ids.dart';

abstract interface class AdUnitIdProvider {
  String? get interstitialAdUnitId;
}

class PlatformAdUnitIdProvider implements AdUnitIdProvider {
  const PlatformAdUnitIdProvider({
    required AdRuntimeConfig config,
    TargetPlatform? targetPlatform,
  }) : _config = config,
       _targetPlatform = targetPlatform;

  final AdRuntimeConfig _config;
  final TargetPlatform? _targetPlatform;

  @override
  String? get interstitialAdUnitId {
    if (!_config.adsEnabled || kIsWeb) {
      return null;
    }

    final platform = _targetPlatform ?? defaultTargetPlatform;
    if (_config.isTestMode) {
      return switch (platform) {
        TargetPlatform.android => AdMobTestIds.androidInterstitial,
        TargetPlatform.iOS => AdMobTestIds.iosInterstitial,
        _ => null,
      };
    }

    final id = switch (platform) {
      TargetPlatform.android => _config.androidInterstitialAdUnitId,
      TargetPlatform.iOS => _config.iosInterstitialAdUnitId,
      _ => null,
    };
    final normalized = id?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    if (AdMobTestIds.isTestInterstitialId(normalized)) {
      return null;
    }
    return normalized;
  }
}
