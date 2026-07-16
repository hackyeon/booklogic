import 'dart:async';

import 'package:booklogic/core/ads/config/ad_unit_id_provider.dart';
import 'package:booklogic/core/ads/consent/ad_consent_service.dart';
import 'package:booklogic/core/ads/domain/interstitial_show_outcome.dart';
import 'package:booklogic/core/ads/interstitial/interstitial_ad_gateway.dart';
import 'package:booklogic/core/ads/interstitial/interstitial_ad_handle.dart';
import 'package:booklogic/core/ads/interstitial/next_level_ad_gate.dart';
import 'package:booklogic/core/ads/sdk/mobile_ads_initializer.dart';

class FakeAdConsentService implements AdConsentService {
  FakeAdConsentService({
    this.canRequestAdsValue = false,
    this.privacyOptionsRequiredValue = false,
    this.requestConsentInfoUpdateError,
    this.loadAndShowConsentFormError,
    this.canRequestAdsError,
    this.privacyOptionsRequiredError,
    this.showPrivacyOptionsFormError,
    this.requestConsentInfoUpdateCompleter,
  });

  bool canRequestAdsValue;
  bool privacyOptionsRequiredValue;
  Object? requestConsentInfoUpdateError;
  Object? loadAndShowConsentFormError;
  Object? canRequestAdsError;
  Object? privacyOptionsRequiredError;
  Object? showPrivacyOptionsFormError;
  Completer<void>? requestConsentInfoUpdateCompleter;

  int requestConsentInfoUpdateCount = 0;
  int loadAndShowConsentFormIfRequiredCount = 0;
  int canRequestAdsCount = 0;
  int isPrivacyOptionsRequiredCount = 0;
  int showPrivacyOptionsFormCount = 0;

  @override
  Future<void> requestConsentInfoUpdate() {
    requestConsentInfoUpdateCount += 1;
    final error = requestConsentInfoUpdateError;
    if (error != null) {
      return Future<void>.error(error);
    }
    return requestConsentInfoUpdateCompleter?.future ?? Future<void>.value();
  }

  @override
  Future<void> loadAndShowConsentFormIfRequired() {
    loadAndShowConsentFormIfRequiredCount += 1;
    final error = loadAndShowConsentFormError;
    if (error != null) {
      return Future<void>.error(error);
    }
    return Future<void>.value();
  }

  @override
  Future<bool> canRequestAds() {
    canRequestAdsCount += 1;
    final error = canRequestAdsError;
    if (error != null) {
      return Future<bool>.error(error);
    }
    return Future<bool>.value(canRequestAdsValue);
  }

  @override
  Future<bool> isPrivacyOptionsRequired() {
    isPrivacyOptionsRequiredCount += 1;
    final error = privacyOptionsRequiredError;
    if (error != null) {
      return Future<bool>.error(error);
    }
    return Future<bool>.value(privacyOptionsRequiredValue);
  }

  @override
  Future<void> showPrivacyOptionsForm() {
    showPrivacyOptionsFormCount += 1;
    final error = showPrivacyOptionsFormError;
    if (error != null) {
      return Future<void>.error(error);
    }
    return Future<void>.value();
  }
}

class FakeMobileAdsInitializer implements MobileAdsInitializer {
  FakeMobileAdsInitializer({this.error, this.completer});

  Object? error;
  Completer<void>? completer;
  int initializeCount = 0;

  @override
  Future<void> initialize() {
    initializeCount += 1;
    final error = this.error;
    if (error != null) {
      return Future<void>.error(error);
    }
    return completer?.future ?? Future<void>.value();
  }
}

class FakeAdUnitIdProvider implements AdUnitIdProvider {
  FakeAdUnitIdProvider({this.id});

  String? id;

  @override
  String? get interstitialAdUnitId => id;
}

class FakeInterstitialAdGateway implements InterstitialAdGateway {
  FakeInterstitialAdGateway({this.loadError, List<InterstitialAdHandle>? ads})
    : ads = List<InterstitialAdHandle>.of(ads ?? const []);

  Object? loadError;
  final List<InterstitialAdHandle> ads;
  Completer<InterstitialAdHandle>? nextLoadCompleter;
  final loadAdUnitIds = <String>[];

  int get loadCount => loadAdUnitIds.length;

  @override
  Future<InterstitialAdHandle> load({required String adUnitId}) {
    loadAdUnitIds.add(adUnitId);
    final error = loadError;
    if (error != null) {
      return Future<InterstitialAdHandle>.error(error);
    }
    final completer = nextLoadCompleter;
    if (completer != null) {
      nextLoadCompleter = null;
      return completer.future;
    }
    if (ads.isNotEmpty) {
      return Future<InterstitialAdHandle>.value(ads.removeAt(0));
    }
    return Future<InterstitialAdHandle>.value(FakeInterstitialAdHandle());
  }
}

class FakeInterstitialAdHandle implements InterstitialAdHandle {
  FakeInterstitialAdHandle({
    this.outcome = InterstitialShowOutcome.shownAndDismissed,
    this.showError,
  });

  InterstitialShowOutcome outcome;
  Object? showError;
  int showCount = 0;
  int disposeCount = 0;

  bool get isDisposed => disposeCount > 0;

  @override
  Future<InterstitialShowOutcome> show() {
    showCount += 1;
    final error = showError;
    if (error != null) {
      return Future<InterstitialShowOutcome>.error(error);
    }
    return Future<InterstitialShowOutcome>.value(outcome);
  }

  @override
  void dispose() {
    disposeCount += 1;
  }
}

class FakeNextLevelAdGate implements NextLevelAdGate {
  FakeNextLevelAdGate({
    this.outcome = InterstitialShowOutcome.shownAndDismissed,
    this.error,
  });

  InterstitialShowOutcome outcome;
  Object? error;
  final calls = <FakeNextLevelAdGateCall>[];

  @override
  Future<InterstitialShowOutcome> showBeforeTransition({
    required int completedLevel,
    required int nextLevel,
  }) {
    calls.add(
      FakeNextLevelAdGateCall(
        completedLevel: completedLevel,
        nextLevel: nextLevel,
      ),
    );
    final error = this.error;
    if (error != null) {
      return Future<InterstitialShowOutcome>.error(error);
    }
    return Future<InterstitialShowOutcome>.value(outcome);
  }
}

class FakeNextLevelAdGateCall {
  const FakeNextLevelAdGateCall({
    required this.completedLevel,
    required this.nextLevel,
  });

  final int completedLevel;
  final int nextLevel;
}
