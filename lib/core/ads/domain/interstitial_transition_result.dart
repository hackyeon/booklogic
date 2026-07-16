import 'interstitial_show_outcome.dart';

class InterstitialTransitionResult {
  const InterstitialTransitionResult({
    required this.outcome,
    required this.completedLevel,
    required this.nextLevel,
  });

  final InterstitialShowOutcome outcome;
  final int completedLevel;
  final int nextLevel;
}
