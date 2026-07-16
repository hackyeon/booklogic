class AdMobTestIds {
  const AdMobTestIds._();

  static const androidAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const iosAppId = 'ca-app-pub-3940256099942544~1458002511';
  static const androidInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const iosInterstitial = 'ca-app-pub-3940256099942544/4411468910';

  static bool isTestInterstitialId(String id) {
    return id == androidInterstitial || id == iosInterstitial;
  }
}
