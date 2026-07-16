import 'dart:async';

import '../consent/ad_consent_controller.dart';
import '../interstitial/interstitial_ad_controller.dart';
import '../interstitial/interstitial_ad_policy.dart';

class AdSessionCoordinator {
  AdSessionCoordinator({
    required AdConsentController consentController,
    required InterstitialAdController interstitialController,
    required InterstitialAdPolicy policy,
  }) : _consentController = consentController,
       _interstitialController = interstitialController,
       _policy = policy {
    _consentController.addListener(_handleConsentChanged);
  }

  final AdConsentController _consentController;
  final InterstitialAdController _interstitialController;
  final InterstitialAdPolicy _policy;
  int? _currentLevel;
  bool _isGameScreenActive = false;
  bool _isDisposed = false;

  void updateCurrentLevel(int level) {
    if (_isDisposed) {
      return;
    }
    _currentLevel = level;
    _preloadIfNeeded();
  }

  void onGameScreenEntered(int level) {
    if (_isDisposed) {
      return;
    }
    _isGameScreenActive = true;
    updateCurrentLevel(level);
  }

  void onGameScreenLeft() {
    _isGameScreenActive = false;
  }

  void onConsentChanged() {
    _handleConsentChanged();
  }

  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _consentController.removeListener(_handleConsentChanged);
  }

  void _handleConsentChanged() {
    if (_isDisposed) {
      return;
    }
    final level = _currentLevel;
    if (level == null) {
      return;
    }
    _interstitialController.onConsentChanged(currentLevel: level);
    _preloadIfNeeded();
  }

  void _preloadIfNeeded() {
    final level = _currentLevel;
    if (_isDisposed || !_isGameScreenActive || level == null) {
      return;
    }
    if (_policy.shouldPreloadForLevel(level)) {
      unawaited(_interstitialController.ensureLoaded(currentLevel: level));
    }
  }
}
