import 'interstitial_ad_handle.dart';

abstract interface class InterstitialAdGateway {
  Future<InterstitialAdHandle> load({required String adUnitId});
}
