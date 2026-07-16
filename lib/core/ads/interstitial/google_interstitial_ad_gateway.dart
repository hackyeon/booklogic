import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../domain/interstitial_show_outcome.dart';
import 'interstitial_ad_gateway.dart';
import 'interstitial_ad_handle.dart';

class GoogleInterstitialAdGateway implements InterstitialAdGateway {
  const GoogleInterstitialAdGateway();

  @override
  Future<InterstitialAdHandle> load({required String adUnitId}) {
    final completer = Completer<InterstitialAdHandle>();
    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          if (!completer.isCompleted) {
            completer.complete(_GoogleInterstitialAdHandle(ad));
          } else {
            ad.dispose();
          }
        },
        onAdFailedToLoad: (error) {
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
      ),
    ).catchError((Object error) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    });
    return completer.future;
  }
}

class _GoogleInterstitialAdHandle implements InterstitialAdHandle {
  _GoogleInterstitialAdHandle(this._ad);

  final InterstitialAd _ad;
  bool _hasShown = false;
  bool _isDisposed = false;
  Completer<InterstitialShowOutcome>? _showCompleter;

  @override
  Future<InterstitialShowOutcome> show() {
    if (_isDisposed || _hasShown) {
      return Future.value(InterstitialShowOutcome.failedToShow);
    }
    _hasShown = true;
    final completer = Completer<InterstitialShowOutcome>();
    _showCompleter = completer;

    void completeOnce(InterstitialShowOutcome outcome) {
      if (!completer.isCompleted) {
        completer.complete(outcome);
      }
    }

    _ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdDismissedFullScreenContent: (ad) {
        completeOnce(InterstitialShowOutcome.shownAndDismissed);
        dispose();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        completeOnce(InterstitialShowOutcome.failedToShow);
        dispose();
      },
    );

    _ad.show().catchError((Object error) {
      completeOnce(InterstitialShowOutcome.failedToShow);
      dispose();
    });
    return completer.future;
  }

  @override
  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _ad.dispose();
    final completer = _showCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(InterstitialShowOutcome.failedToShow);
    }
  }
}
