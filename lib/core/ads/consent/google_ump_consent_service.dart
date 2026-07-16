import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ad_runtime_config.dart';
import 'ad_consent_service.dart';

class GoogleUmpConsentService implements AdConsentService {
  const GoogleUmpConsentService({
    required AdRuntimeConfig config,
    ConsentInformation? consentInformation,
  }) : _config = config,
       _consentInformation = consentInformation;

  final AdRuntimeConfig _config;
  final ConsentInformation? _consentInformation;

  ConsentInformation get _info {
    return _consentInformation ?? ConsentInformation.instance;
  }

  @override
  Future<void> requestConsentInfoUpdate() {
    final completer = Completer<void>();
    void completeOnce([Object? error]) {
      if (completer.isCompleted) {
        return;
      }
      if (error == null) {
        completer.complete();
      } else {
        completer.completeError(error);
      }
    }

    try {
      _info.requestConsentInfoUpdate(
        _requestParameters(),
        () => completeOnce(),
        (error) => completeOnce(error),
      );
    } catch (error) {
      completeOnce(error);
    }
    return completer.future;
  }

  @override
  Future<void> loadAndShowConsentFormIfRequired() {
    final completer = Completer<void>();
    void completeOnce([Object? error]) {
      if (completer.isCompleted) {
        return;
      }
      if (error == null) {
        completer.complete();
      } else {
        completer.completeError(error);
      }
    }

    try {
      ConsentForm.loadAndShowConsentFormIfRequired((formError) {
        completeOnce(formError);
      });
    } catch (error) {
      completeOnce(error);
    }
    return completer.future;
  }

  @override
  Future<bool> canRequestAds() {
    return _info.canRequestAds();
  }

  @override
  Future<bool> isPrivacyOptionsRequired() async {
    final status = await _info.getPrivacyOptionsRequirementStatus();
    return status == PrivacyOptionsRequirementStatus.required;
  }

  @override
  Future<void> showPrivacyOptionsForm() {
    final completer = Completer<void>();
    void completeOnce([Object? error]) {
      if (completer.isCompleted) {
        return;
      }
      if (error == null) {
        completer.complete();
      } else {
        completer.completeError(error);
      }
    }

    try {
      ConsentForm.showPrivacyOptionsForm((formError) {
        completeOnce(formError);
      });
    } catch (error) {
      completeOnce(error);
    }
    return completer.future;
  }

  ConsentRequestParameters _requestParameters() {
    final testDeviceIds = _config.umpTestDeviceIds;
    final debugGeography = _config.debugGeography;
    return ConsentRequestParameters(
      consentDebugSettings: testDeviceIds.isEmpty && debugGeography == null
          ? null
          : ConsentDebugSettings(
              debugGeography: debugGeography,
              testIdentifiers: testDeviceIds,
            ),
    );
  }
}
