import 'dart:async';

import 'package:booklogic/core/ads/config/ad_runtime_config.dart';
import 'package:booklogic/core/ads/config/ad_unit_id_provider.dart';
import 'package:booklogic/core/ads/config/admob_production_ids.dart';
import 'package:booklogic/core/ads/config/admob_test_ids.dart';
import 'package:booklogic/core/ads/consent/ad_consent_controller.dart';
import 'package:booklogic/core/ads/domain/interstitial_show_outcome.dart';
import 'package:booklogic/core/ads/interstitial/interstitial_ad_controller.dart';
import 'package:booklogic/core/ads/interstitial/interstitial_ad_handle.dart';
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

    test('waits for an in-flight load before showing the ad', () async {
      final fixture = await _buildAdGateFixture();
      final handle = FakeInterstitialAdHandle();
      final loadCompleter = Completer<InterstitialAdHandle>();
      fixture.gateway.nextLoadCompleter = loadCompleter;

      final preload = fixture.controller.ensureLoaded(currentLevel: 6);
      await Future<void>.delayed(Duration.zero);
      final show = fixture.gate.showBeforeTransition(
        completedLevel: 6,
        nextLevel: 7,
      );

      var showCompleted = false;
      show.then((_) => showCompleted = true);
      await Future<void>.delayed(Duration.zero);
      expect(showCompleted, isFalse);
      expect(handle.showCount, 0);

      loadCompleter.complete(handle);

      expect(await show, InterstitialShowOutcome.shownAndDismissed);
      await preload;
      expect(handle.showCount, 1);
      expect(fixture.gateway.loadCount, 1);

      fixture.dispose();
    });

    test('retries a failed preload before showing the ad', () async {
      final fixture = await _buildAdGateFixture();
      fixture.gateway.loadError = StateError('first load failed');
      await fixture.controller.ensureLoaded(currentLevel: 6);
      fixture.gateway.loadError = null;
      final handle = FakeInterstitialAdHandle();
      fixture.gateway.ads.add(handle);

      final outcome = await fixture.gate.showBeforeTransition(
        completedLevel: 6,
        nextLevel: 7,
      );

      expect(outcome, InterstitialShowOutcome.shownAndDismissed);
      expect(fixture.gateway.loadCount, 2);
      expect(handle.showCount, 1);

      fixture.dispose();
    });

    test(
      'continues the transition when loading exceeds the wait limit',
      () async {
        final fixture = await _buildAdGateFixture(
          loadWaitTimeout: const Duration(milliseconds: 1),
        );
        final loadCompleter = Completer<InterstitialAdHandle>();
        fixture.gateway.nextLoadCompleter = loadCompleter;

        final outcome = await fixture.gate.showBeforeTransition(
          completedLevel: 6,
          nextLevel: 7,
        );

        expect(outcome, InterstitialShowOutcome.notReady);

        final handle = FakeInterstitialAdHandle();
        loadCompleter.complete(handle);
        await Future<void>.delayed(Duration.zero);
        expect(fixture.controller.hasReadyAd, isTrue);
        expect(handle.showCount, 0);

        fixture.dispose();
      },
    );
  });
}

Future<_AdGateFixture> _buildAdGateFixture({
  Duration loadWaitTimeout = const Duration(seconds: 5),
}) async {
  final service = FakeAdConsentService(canRequestAdsValue: true);
  final consentController = AdConsentController(service: service);
  await consentController.initialize();
  final gateway = FakeInterstitialAdGateway();
  const policy = InterstitialAdPolicy();
  final controller = InterstitialAdController(
    consentController: consentController,
    mobileAdsInitializer: FakeMobileAdsInitializer(),
    gateway: gateway,
    adUnitIdProvider: FakeAdUnitIdProvider(id: 'unit-id'),
    policy: policy,
  );
  return _AdGateFixture(
    consentController: consentController,
    gateway: gateway,
    controller: controller,
    gate: DefaultNextLevelAdGate(
      policy: policy,
      interstitialController: controller,
      loadWaitTimeout: loadWaitTimeout,
    ),
  );
}

class _AdGateFixture {
  const _AdGateFixture({
    required this.consentController,
    required this.gateway,
    required this.controller,
    required this.gate,
  });

  final AdConsentController consentController;
  final FakeInterstitialAdGateway gateway;
  final InterstitialAdController controller;
  final DefaultNextLevelAdGate gate;

  void dispose() {
    controller.dispose();
    consentController.dispose();
  }
}
