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
  }) : _policy = policy,
       _interstitialController = interstitialController;

  final InterstitialAdPolicy _policy;
  final InterstitialAdController _interstitialController;

  @override
  Future<InterstitialShowOutcome> showBeforeTransition({
    required int completedLevel,
    required int nextLevel,
  }) {
    if (!_policy.shouldAttemptBeforeNextLevel(
      completedLevel: completedLevel,
      nextLevel: nextLevel,
    )) {
      return Future.value(InterstitialShowOutcome.skippedByPolicy);
    }
    return _interstitialController.showIfReady();
  }
}
