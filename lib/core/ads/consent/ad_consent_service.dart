abstract interface class AdConsentService {
  Future<void> requestConsentInfoUpdate();

  Future<void> loadAndShowConsentFormIfRequired();

  Future<bool> canRequestAds();

  Future<bool> isPrivacyOptionsRequired();

  Future<void> showPrivacyOptionsForm();
}
