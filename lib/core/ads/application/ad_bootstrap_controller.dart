import 'dart:async';

import '../consent/ad_consent_controller.dart';
import '../interstitial/interstitial_ad_controller.dart';
import 'ad_session_coordinator.dart';

class AdBootstrapController {
  AdBootstrapController({
    required AdConsentController consentController,
    required InterstitialAdController interstitialController,
    required AdSessionCoordinator adSessionCoordinator,
  }) : _consentController = consentController,
       _interstitialController = interstitialController,
       _adSessionCoordinator = adSessionCoordinator;

  final AdConsentController _consentController;
  final InterstitialAdController _interstitialController;
  final AdSessionCoordinator _adSessionCoordinator;
  Future<void>? _initializeFuture;
  bool _isDisposed = false;

  Future<void> initialize({required int currentLevel}) {
    if (_isDisposed) {
      return Future<void>.value();
    }
    final existing = _initializeFuture;
    if (existing != null) {
      return existing;
    }
    final future = _initialize(currentLevel);
    _initializeFuture = future.whenComplete(() {
      _initializeFuture = null;
    });
    return _initializeFuture!;
  }

  void dispose() {
    _isDisposed = true;
  }

  Future<void> _initialize(int currentLevel) async {
    await _consentController.initialize();
    if (_isDisposed) {
      return;
    }
    if (_consentController.canRequestAds) {
      await _interstitialController.initializeIfAllowed();
    }
    if (_isDisposed) {
      return;
    }
    _adSessionCoordinator.updateCurrentLevel(currentLevel);
  }
}
