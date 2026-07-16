import '../domain/interstitial_show_outcome.dart';

abstract interface class InterstitialAdHandle {
  Future<InterstitialShowOutcome> show();

  void dispose();
}
