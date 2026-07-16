import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'mobile_ads_initializer.dart';

class GoogleMobileAdsInitializer implements MobileAdsInitializer {
  const GoogleMobileAdsInitializer();

  @override
  Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }
}
