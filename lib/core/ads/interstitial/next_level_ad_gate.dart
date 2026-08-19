import 'dart:async';

import '../domain/interstitial_show_outcome.dart';
import 'interstitial_ad_controller.dart';
import 'interstitial_ad_policy.dart';

abstract interface class NextLevelAdGate {
  Future<InterstitialShowOutcome> showBeforeTransition({
    required int completedLevel,
    required int nextLevel,
  });
}

class DefaultNextLevelAdGate implements NextLevelAdGate {
  const DefaultNextLevelAdGate({
    required InterstitialAdPolicy policy,
    required InterstitialAdController interstitialController,
    Duration loadWaitTimeout = const Duration(seconds: 5),
  }) : _policy = policy,
       _interstitialController = interstitialController,
       _loadWaitTimeout = loadWaitTimeout;

  final InterstitialAdPolicy _policy;
  final InterstitialAdController _interstitialController;
  final Duration _loadWaitTimeout;

  @override
  Future<InterstitialShowOutcome> showBeforeTransition({
    required int completedLevel,
    required int nextLevel,
  }) async {
    if (!_policy.shouldAttemptBeforeNextLevel(
      completedLevel: completedLevel,
      nextLevel: nextLevel,
    )) {
      return InterstitialShowOutcome.skippedByPolicy;
    }

    try {
      await _interstitialController
          .ensureLoaded(currentLevel: completedLevel)
          .timeout(_loadWaitTimeout);
    } on TimeoutException {
      return InterstitialShowOutcome.notReady;
    }

    return _interstitialController.showIfReady();
  }
}
