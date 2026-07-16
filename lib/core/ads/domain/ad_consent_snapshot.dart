import 'ad_consent_state.dart';

class AdConsentSnapshot {
  const AdConsentSnapshot({
    required this.state,
    required this.canRequestAds,
    required this.privacyOptionsRequired,
    this.lastError,
    this.consentInfoUpdateCompleted = false,
    this.formPresentationCompleted = false,
  });

  static const initial = AdConsentSnapshot(
    state: AdConsentState.initial,
    canRequestAds: false,
    privacyOptionsRequired: false,
  );

  final AdConsentState state;
  final bool canRequestAds;
  final bool privacyOptionsRequired;
  final Object? lastError;
  final bool consentInfoUpdateCompleted;
  final bool formPresentationCompleted;

  AdConsentSnapshot copyWith({
    AdConsentState? state,
    bool? canRequestAds,
    bool? privacyOptionsRequired,
    Object? lastError,
    bool clearLastError = false,
    bool? consentInfoUpdateCompleted,
    bool? formPresentationCompleted,
  }) {
    return AdConsentSnapshot(
      state: state ?? this.state,
      canRequestAds: canRequestAds ?? this.canRequestAds,
      privacyOptionsRequired:
          privacyOptionsRequired ?? this.privacyOptionsRequired,
      lastError: clearLastError ? null : lastError ?? this.lastError,
      consentInfoUpdateCompleted:
          consentInfoUpdateCompleted ?? this.consentInfoUpdateCompleted,
      formPresentationCompleted:
          formPresentationCompleted ?? this.formPresentationCompleted,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AdConsentSnapshot &&
            state == other.state &&
            canRequestAds == other.canRequestAds &&
            privacyOptionsRequired == other.privacyOptionsRequired &&
            lastError == other.lastError &&
            consentInfoUpdateCompleted == other.consentInfoUpdateCompleted &&
            formPresentationCompleted == other.formPresentationCompleted;
  }

  @override
  int get hashCode {
    return Object.hash(
      state,
      canRequestAds,
      privacyOptionsRequired,
      lastError,
      consentInfoUpdateCompleted,
      formPresentationCompleted,
    );
  }

  @override
  String toString() {
    return 'AdConsentSnapshot('
        'state: $state, '
        'canRequestAds: $canRequestAds, '
        'privacyOptionsRequired: $privacyOptionsRequired, '
        'hasError: ${lastError != null}, '
        'consentInfoUpdateCompleted: $consentInfoUpdateCompleted, '
        'formPresentationCompleted: $formPresentationCompleted'
        ')';
  }
}
