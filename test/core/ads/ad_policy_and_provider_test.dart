import 'package:booklogic/core/ads/config/ad_runtime_config.dart';
import 'package:booklogic/core/ads/config/ad_unit_id_provider.dart';
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
    test('returns official test interstitial ids in test mode', () {
      const config = AdRuntimeConfig(isTestMode: true, adsEnabled: true);

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

    test('uses production ids in release mode and rejects sample test ids', () {
      expect(
        const PlatformAdUnitIdProvider(
          config: AdRuntimeConfig(
            isTestMode: false,
            adsEnabled: true,
            androidInterstitialAdUnitId: 'ca-app-pub-123/456',
          ),
          targetPlatform: TargetPlatform.android,
        ).interstitialAdUnitId,
        'ca-app-pub-123/456',
      );
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
