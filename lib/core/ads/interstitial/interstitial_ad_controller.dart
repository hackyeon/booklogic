import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/ad_unit_id_provider.dart';
import '../consent/ad_consent_controller.dart';
import '../domain/interstitial_ad_state.dart';
import '../domain/interstitial_show_outcome.dart';
import '../sdk/mobile_ads_initializer.dart';
import 'interstitial_ad_gateway.dart';
import 'interstitial_ad_handle.dart';
import 'interstitial_ad_policy.dart';

class InterstitialAdController extends ChangeNotifier {
  InterstitialAdController({
    required AdConsentController consentController,
    required MobileAdsInitializer mobileAdsInitializer,
    required InterstitialAdGateway gateway,
    required AdUnitIdProvider adUnitIdProvider,
    required InterstitialAdPolicy policy,
  }) : _consentController = consentController,
       _mobileAdsInitializer = mobileAdsInitializer,
       _gateway = gateway,
       _adUnitIdProvider = adUnitIdProvider,
       _policy = policy;

  final AdConsentController _consentController;
  final MobileAdsInitializer _mobileAdsInitializer;
  final InterstitialAdGateway _gateway;
  final AdUnitIdProvider _adUnitIdProvider;
  final InterstitialAdPolicy _policy;

  InterstitialAdState _state = InterstitialAdState.waitingForConsent;
  InterstitialAdHandle? _readyAd;
  Future<void>? _loadFuture;
  Future<void>? _sdkInitializationFuture;
  int _loadRevision = 0;
  bool _sdkInitialized = false;
  bool _sdkInitializationFailed = false;
  bool _isDisposed = false;
  Object? _lastLoadError;

  InterstitialAdState get state => _state;

  bool get isReady => _state == InterstitialAdState.ready;

  bool get isShowing => _state == InterstitialAdState.showing;

  bool get hasReadyAd => _readyAd != null;

  Object? get lastLoadError => _lastLoadError;

  Future<void> initializeIfAllowed() {
    if (_isDisposed) {
      return Future<void>.value();
    }
    if (!_consentController.canRequestAds) {
      _setState(InterstitialAdState.waitingForConsent);
      return Future<void>.value();
    }
    if (_sdkInitialized) {
      return Future<void>.value();
    }
    if (_sdkInitializationFailed) {
      _setState(InterstitialAdState.disabled);
      return Future<void>.value();
    }
    final existing = _sdkInitializationFuture;
    if (existing != null) {
      return existing;
    }

    final future = _mobileAdsInitializer.initialize().then(
      (_) {
        _sdkInitialized = true;
        if (!_isDisposed && _state == InterstitialAdState.waitingForConsent) {
          _setState(InterstitialAdState.idle);
        }
      },
      onError: (Object error) {
        _sdkInitializationFailed = true;
        _lastLoadError = error;
        _setState(InterstitialAdState.disabled);
      },
    );
    _sdkInitializationFuture = future.whenComplete(() {
      _sdkInitializationFuture = null;
    });
    return _sdkInitializationFuture!;
  }

  Future<void> ensureLoaded({required int currentLevel}) {
    if (_isDisposed ||
        _state == InterstitialAdState.ready ||
        _state == InterstitialAdState.showing ||
        _state == InterstitialAdState.loading) {
      return _loadFuture ?? Future<void>.value();
    }
    if (!_policy.shouldPreloadForLevel(currentLevel)) {
      _setState(InterstitialAdState.idle);
      return Future<void>.value();
    }
    if (!_consentController.canRequestAds) {
      disposeReadyAd();
      _setState(InterstitialAdState.waitingForConsent);
      return Future<void>.value();
    }
    final adUnitId = _adUnitIdProvider.interstitialAdUnitId;
    if (adUnitId == null) {
      disposeReadyAd();
      _setState(InterstitialAdState.disabled);
      return Future<void>.value();
    }

    final future = _ensureLoaded(
      currentLevel: currentLevel,
      adUnitId: adUnitId,
    );
    _loadFuture = future.whenComplete(() {
      _loadFuture = null;
    });
    return _loadFuture!;
  }

  Future<InterstitialShowOutcome> showIfReady() async {
    if (_isDisposed) {
      return InterstitialShowOutcome.controllerDisposed;
    }
    if (!_consentController.canRequestAds) {
      disposeReadyAd();
      _setState(InterstitialAdState.waitingForConsent);
      return InterstitialShowOutcome.consentUnavailable;
    }
    if (!_sdkInitialized) {
      return InterstitialShowOutcome.sdkUnavailable;
    }
    final ad = _readyAd;
    if (ad == null || _state != InterstitialAdState.ready) {
      return InterstitialShowOutcome.notReady;
    }

    _readyAd = null;
    _setState(InterstitialAdState.showing);
    try {
      final outcome = await ad.show();
      ad.dispose();
      if (!_isDisposed) {
        _setState(InterstitialAdState.idle);
      }
      return outcome;
    } catch (_) {
      ad.dispose();
      if (!_isDisposed) {
        _setState(InterstitialAdState.idle);
      }
      return InterstitialShowOutcome.failedToShow;
    }
  }

  void disposeReadyAd() {
    final ad = _readyAd;
    _readyAd = null;
    ad?.dispose();
    if (!_isDisposed && _state == InterstitialAdState.ready) {
      _setState(InterstitialAdState.idle);
    }
  }

  void onConsentChanged({required int currentLevel}) {
    if (_isDisposed) {
      return;
    }
    if (!_consentController.canRequestAds) {
      _loadRevision += 1;
      disposeReadyAd();
      if (_state != InterstitialAdState.showing) {
        _setState(InterstitialAdState.waitingForConsent);
      }
      return;
    }
    unawaited(ensureLoaded(currentLevel: currentLevel));
  }

  void stop() {
    _loadRevision += 1;
    if (_state == InterstitialAdState.loading) {
      _setState(InterstitialAdState.idle);
    }
  }

  @override
  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _loadRevision += 1;
    _readyAd?.dispose();
    _readyAd = null;
    _state = InterstitialAdState.disposed;
    super.dispose();
  }

  Future<void> _ensureLoaded({
    required int currentLevel,
    required String adUnitId,
  }) async {
    await initializeIfAllowed();
    if (_isDisposed ||
        !_sdkInitialized ||
        !_consentController.canRequestAds ||
        !_policy.shouldPreloadForLevel(currentLevel)) {
      return;
    }

    final revision = ++_loadRevision;
    _setState(InterstitialAdState.loading);
    _lastLoadError = null;
    try {
      final ad = await _gateway.load(adUnitId: adUnitId);
      if (_isDisposed ||
          revision != _loadRevision ||
          !_consentController.canRequestAds ||
          !_policy.shouldPreloadForLevel(currentLevel)) {
        ad.dispose();
        return;
      }
      _readyAd?.dispose();
      _readyAd = ad;
      _setState(InterstitialAdState.ready);
    } catch (error) {
      if (_isDisposed || revision != _loadRevision) {
        return;
      }
      _lastLoadError = error;
      _readyAd = null;
      _setState(InterstitialAdState.failed);
    }
  }

  void _setState(InterstitialAdState state) {
    if (_isDisposed || _state == state) {
      return;
    }
    _state = state;
    notifyListeners();
  }
}
