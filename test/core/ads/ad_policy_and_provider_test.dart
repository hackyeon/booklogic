import 'package:booklogic/core/ads/config/ad_runtime_config.dart';
import 'package:booklogic/core/ads/config/ad_unit_id_provider.dart';
import 'package:booklogic/core/ads/config/admob_production_ids.dart';
import 'package:booklogic/core/ads/config/admob_test_ids.dart';
import 'package:booklogic/core/ads/consent/ad_consent_controller.dart';
import 'package:booklogic/core/ads/domain/interstitial_show_outcome.dart';
import 'package:booklogic/core/ads/interstitial/interstitial_ad_controller.dart';
import 'package:booklogic/core/ads/interstitial/interstitial_ad_policy.dart';
import 'package:booklogic/core/ads/interstitial/next_level_ad_gate.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_ad_services.dart';

void main() {
  group('InterstitialAdPolicy', () {
    test('preloads only from level 6 while a next generated level exists', () {
      const policy = InterstitialAdPolicy();

      for (var level = 1; level <= 5; level += 1) {
        expect(policy.shouldPreloadForLevel(level), isFalse);
      }
      expect(policy.shouldPreloadForLevel(6), isTrue);
      expect(policy.shouldPreloadForLevel(200), isTrue);
      expect(policy.shouldPreloadForLevel(400), isFalse);
    });

    test('attempts interstitials only for supported level 6+ transitions', () {
      const policy = InterstitialAdPolicy();

      expect(
        policy.shouldAttemptBeforeNextLevel(completedLevel: 5, nextLevel: 6),
        isFalse,
      );
      expect(
        policy.shouldAttemptBeforeNextLevel(completedLevel: 6, nextLevel: 7),
        isTrue,
      );
      expect(
        policy.shouldAttemptBeforeNextLevel(
          completedLevel: 200,
          nextLevel: 201,
        ),
        isTrue,
      );
      expect(
        policy.shouldAttemptBeforeNextLevel(
          completedLevel: 400,
          nextLevel: 401,
        ),
        isFalse,
      );
      expect(
        policy.shouldAttemptBeforeNextLevel(completedLevel: 8, nextLevel: 10),
        isFalse,
      );
    });
  });

  group('PlatformAdUnitIdProvider', () {
    test('returns official test ids even when production defaults exist', () {
      const config = AdRuntimeConfig(
        isTestMode: true,
        adsEnabled: true,
        androidInterstitialAdUnitId: AdMobProductionIds.androidInterstitial,
        iosInterstitialAdUnitId: AdMobProductionIds.iosInterstitial,
      );

      expect(
        PlatformAdUnitIdProvider(
          config: config,
          targetPlatform: TargetPlatform.android,
        ).interstitialAdUnitId,
        AdMobTestIds.androidInterstitial,
      );
      expect(
        PlatformAdUnitIdProvider(
          config: config,
          targetPlatform: TargetPlatform.iOS,
        ).interstitialAdUnitId,
        AdMobTestIds.iosInterstitial,
      );
      expect(
        PlatformAdUnitIdProvider(
          config: config,
          targetPlatform: TargetPlatform.android,
        ).interstitialAdUnitId,
        isNot(AdMobProductionIds.androidInterstitial),
      );
      expect(
        PlatformAdUnitIdProvider(
          config: config,
          targetPlatform: TargetPlatform.iOS,
        ).interstitialAdUnitId,
        isNot(AdMobProductionIds.iosInterstitial),
      );
    });

    test('disables unsupported platforms and disabled ad sessions', () {
      expect(
        const PlatformAdUnitIdProvider(
          config: AdRuntimeConfig(isTestMode: true, adsEnabled: false),
          targetPlatform: TargetPlatform.android,
        ).interstitialAdUnitId,
        isNull,
      );
      expect(
        const PlatformAdUnitIdProvider(
          config: AdRuntimeConfig(isTestMode: true, adsEnabled: true),
          targetPlatform: TargetPlatform.macOS,
        ).interstitialAdUnitId,
        isNull,
      );
    });

    test('uses exact production ids in release mode', () {
      expect(
        const PlatformAdUnitIdProvider(
          config: AdRuntimeConfig(
            isTestMode: false,
            adsEnabled: true,
            androidInterstitialAdUnitId: AdMobProductionIds.androidInterstitial,
          ),
          targetPlatform: TargetPlatform.android,
        ).interstitialAdUnitId,
        AdMobProductionIds.androidInterstitial,
      );
      expect(
        const PlatformAdUnitIdProvider(
          config: AdRuntimeConfig(
            isTestMode: false,
            adsEnabled: true,
            iosInterstitialAdUnitId: AdMobProductionIds.iosInterstitial,
          ),
          targetPlatform: TargetPlatform.iOS,
        ).interstitialAdUnitId,
        AdMobProductionIds.iosInterstitial,
      );
      expect(
        AdMobProductionIds.androidInterstitial,
        isNot(AdMobTestIds.androidInterstitial),
      );
      expect(
        AdMobProductionIds.iosInterstitial,
        isNot(AdMobTestIds.iosInterstitial),
      );
    });

    test('rejects official sample ids in release mode', () {
      expect(
        const PlatformAdUnitIdProvider(
          config: AdRuntimeConfig(
            isTestMode: false,
            adsEnabled: true,
            androidInterstitialAdUnitId: AdMobTestIds.androidInterstitial,
          ),
          targetPlatform: TargetPlatform.android,
        ).interstitialAdUnitId,
        isNull,
      );
      expect(
        const PlatformAdUnitIdProvider(
          config: AdRuntimeConfig(
            isTestMode: false,
            adsEnabled: true,
            iosInterstitialAdUnitId: AdMobTestIds.iosInterstitial,
          ),
          targetPlatform: TargetPlatform.iOS,
        ).interstitialAdUnitId,
        isNull,
      );
    });

    test('environment config has production defaults behind test mode', () {
      final config = AdRuntimeConfig.fromEnvironment();

      expect(config.isTestMode, isTrue);
      expect(
        config.androidInterstitialAdUnitId,
        AdMobProductionIds.androidInterstitial,
      );
      expect(
        config.iosInterstitialAdUnitId,
        AdMobProductionIds.iosInterstitial,
      );
      expect(
        PlatformAdUnitIdProvider(
          config: config,
          targetPlatform: TargetPlatform.android,
        ).interstitialAdUnitId,
        AdMobTestIds.androidInterstitial,
      );
      expect(
        PlatformAdUnitIdProvider(
          config: config,
          targetPlatform: TargetPlatform.iOS,
        ).interstitialAdUnitId,
        AdMobTestIds.iosInterstitial,
      );
    });
  });

  group('DefaultNextLevelAdGate', () {
    test(
      'skips excluded transitions without touching the ad controller',
      () async {
        final service = FakeAdConsentService(canRequestAdsValue: true);
        final consentController = AdConsentController(service: service);
        await consentController.initialize();
        final initializer = FakeMobileAdsInitializer();
        final gateway = FakeInterstitialAdGateway();
        final adProvider = FakeAdUnitIdProvider(id: 'unit-id');
        const policy = InterstitialAdPolicy();
        final interstitialController = InterstitialAdController(
          consentController: consentController,
          mobileAdsInitializer: initializer,
          gateway: gateway,
          adUnitIdProvider: adProvider,
          policy: policy,
        );
        final gate = DefaultNextLevelAdGate(
          policy: policy,
          interstitialController: interstitialController,
        );

        final outcome = await gate.showBeforeTransition(
          completedLevel: 5,
          nextLevel: 6,
        );

        expect(outcome, InterstitialShowOutcome.skippedByPolicy);
        expect(initializer.initializeCount, 0);
        expect(gateway.loadCount, 0);

        interstitialController.dispose();
        consentController.dispose();
      },
    );
  });
}
