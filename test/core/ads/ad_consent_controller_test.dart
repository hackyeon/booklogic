import 'dart:async';

import 'package:booklogic/core/ads/consent/ad_consent_controller.dart';
import 'package:booklogic/core/ads/domain/ad_consent_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_ad_services.dart';

void main() {
  group('AdConsentController', () {
    test('requests consent info and exposes ad request eligibility', () async {
      final service = FakeAdConsentService(
        canRequestAdsValue: true,
        privacyOptionsRequiredValue: true,
      );
      final controller = AdConsentController(service: service);

      await controller.initialize();

      expect(service.requestConsentInfoUpdateCount, 1);
      expect(service.loadAndShowConsentFormIfRequiredCount, 1);
      expect(controller.canRequestAds, isTrue);
      expect(controller.privacyOptionsRequired, isTrue);
      expect(controller.snapshot.state, AdConsentState.ready);
      expect(controller.snapshot.consentInfoUpdateCompleted, isTrue);
      expect(controller.snapshot.formPresentationCompleted, isTrue);

      controller.dispose();
    });

    test('coalesces concurrent initialization requests', () async {
      final blocker = Completer<void>();
      final service = FakeAdConsentService(
        canRequestAdsValue: true,
        requestConsentInfoUpdateCompleter: blocker,
      );
      final controller = AdConsentController(service: service);

      final first = controller.initialize();
      final second = controller.initialize();

      blocker.complete();
      await Future.wait([first, second]);

      expect(service.requestConsentInfoUpdateCount, 1);
      expect(controller.canRequestAds, isTrue);

      controller.dispose();
    });

    test('keeps ads unavailable when consent cannot request ads', () async {
      final service = FakeAdConsentService(
        canRequestAdsValue: false,
        privacyOptionsRequiredValue: false,
      );
      final controller = AdConsentController(service: service);

      await controller.initialize();

      expect(controller.canRequestAds, isFalse);
      expect(controller.snapshot.state, AdConsentState.unavailable);

      controller.dispose();
    });

    test(
      'privacy options refreshes status and rethrows presentation failures',
      () async {
        final service = FakeAdConsentService(
          canRequestAdsValue: true,
          privacyOptionsRequiredValue: true,
        );
        final controller = AdConsentController(service: service);
        await controller.initialize();

        service.privacyOptionsRequiredValue = false;
        await controller.showPrivacyOptions();

        expect(service.showPrivacyOptionsFormCount, 1);
        expect(controller.privacyOptionsRequired, isFalse);
        expect(controller.snapshot.state, AdConsentState.ready);

        service.showPrivacyOptionsFormError = StateError('form failed');

        await expectLater(
          controller.showPrivacyOptions(),
          throwsA(isA<StateError>()),
        );
        expect(controller.snapshot.state, AdConsentState.error);

        controller.dispose();
      },
    );
  });
}
