import 'dart:async';

import 'package:booklogic/core/ads/consent/ad_consent_controller.dart';
import 'package:booklogic/core/ads/domain/interstitial_ad_state.dart';
import 'package:booklogic/core/ads/domain/interstitial_show_outcome.dart';
import 'package:booklogic/core/ads/interstitial/interstitial_ad_controller.dart';
import 'package:booklogic/core/ads/interstitial/interstitial_ad_handle.dart';
import 'package:booklogic/core/ads/interstitial/interstitial_ad_policy.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_ad_services.dart';

void main() {
  group('InterstitialAdController', () {
    test('does not initialize or load before level 6', () async {
      final fixture = await _buildControllerFixture();

      await fixture.controller.ensureLoaded(currentLevel: 5);

      expect(fixture.initializer.initializeCount, 0);
      expect(fixture.gateway.loadCount, 0);
      expect(fixture.controller.state, InterstitialAdState.idle);

      fixture.dispose();
    });

    test('loads from level 6 and shows a ready ad once', () async {
      final handle = FakeInterstitialAdHandle();
      final fixture = await _buildControllerFixture(ads: [handle]);

      await fixture.controller.ensureLoaded(currentLevel: 6);

      expect(fixture.initializer.initializeCount, 1);
      expect(fixture.gateway.loadAdUnitIds, ['test-interstitial']);
      expect(fixture.controller.state, InterstitialAdState.ready);
      expect(fixture.controller.hasReadyAd, isTrue);

      final outcome = await fixture.controller.showIfReady();

      expect(outcome, InterstitialShowOutcome.shownAndDismissed);
      expect(handle.showCount, 1);
      expect(handle.disposeCount, 1);
      expect(fixture.controller.hasReadyAd, isFalse);
      expect(fixture.controller.state, InterstitialAdState.idle);

      expect(
        await fixture.controller.showIfReady(),
        InterstitialShowOutcome.notReady,
      );
      expect(handle.showCount, 1);

      fixture.dispose();
    });

    test('disposes stale loaded ads when loading is stopped', () async {
      final staleHandle = FakeInterstitialAdHandle();
      final completer = Completer<InterstitialAdHandle>();
      final fixture = await _buildControllerFixture();
      fixture.gateway.nextLoadCompleter = completer;

      final load = fixture.controller.ensureLoaded(currentLevel: 6);
      await Future<void>.delayed(Duration.zero);
      expect(fixture.controller.state, InterstitialAdState.loading);

      fixture.controller.stop();
      completer.complete(staleHandle);
      await load;

      expect(staleHandle.disposeCount, 1);
      expect(fixture.controller.hasReadyAd, isFalse);
      expect(fixture.controller.state, InterstitialAdState.idle);

      fixture.dispose();
    });

    test('consent withdrawal disposes a ready ad and blocks showing', () async {
      final handle = FakeInterstitialAdHandle();
      final fixture = await _buildControllerFixture(ads: [handle]);
      await fixture.controller.ensureLoaded(currentLevel: 6);
      expect(fixture.controller.state, InterstitialAdState.ready);

      fixture.service.canRequestAdsValue = false;
      await fixture.consentController.refreshAfterPrivacyOptions();
      fixture.controller.onConsentChanged(currentLevel: 6);

      expect(handle.disposeCount, 1);
      expect(fixture.controller.hasReadyAd, isFalse);
      expect(fixture.controller.state, InterstitialAdState.waitingForConsent);
      expect(
        await fixture.controller.showIfReady(),
        InterstitialShowOutcome.consentUnavailable,
      );

      fixture.dispose();
    });

    test('failed loads leave gameplay free to continue later', () async {
      final fixture = await _buildControllerFixture();
      fixture.gateway.loadError = StateError('load failed');

      await fixture.controller.ensureLoaded(currentLevel: 6);

      expect(fixture.controller.state, InterstitialAdState.failed);
      expect(fixture.controller.lastLoadError, isA<StateError>());
      expect(
        await fixture.controller.showIfReady(),
        InterstitialShowOutcome.notReady,
      );

      fixture.gateway.loadError = null;
      await fixture.controller.ensureLoaded(currentLevel: 6);

      expect(fixture.controller.state, InterstitialAdState.ready);
      expect(fixture.gateway.loadCount, 2);

      fixture.dispose();
    });
  });
}

Future<_ControllerFixture> _buildControllerFixture({
  List<InterstitialAdHandle> ads = const [],
}) async {
  final service = FakeAdConsentService(canRequestAdsValue: true);
  final consentController = AdConsentController(service: service);
  await consentController.initialize();
  final initializer = FakeMobileAdsInitializer();
  final gateway = FakeInterstitialAdGateway(ads: ads);
  final controller = InterstitialAdController(
    consentController: consentController,
    mobileAdsInitializer: initializer,
    gateway: gateway,
    adUnitIdProvider: FakeAdUnitIdProvider(id: 'test-interstitial'),
    policy: const InterstitialAdPolicy(),
  );
  return _ControllerFixture(
    service: service,
    consentController: consentController,
    initializer: initializer,
    gateway: gateway,
    controller: controller,
  );
}

class _ControllerFixture {
  const _ControllerFixture({
    required this.service,
    required this.consentController,
    required this.initializer,
    required this.gateway,
    required this.controller,
  });

  final FakeAdConsentService service;
  final AdConsentController consentController;
  final FakeMobileAdsInitializer initializer;
  final FakeInterstitialAdGateway gateway;
  final InterstitialAdController controller;

  void dispose() {
    controller.dispose();
    consentController.dispose();
  }
}
