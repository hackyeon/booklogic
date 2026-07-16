import 'package:flutter/foundation.dart';

import '../domain/ad_consent_snapshot.dart';
import '../domain/ad_consent_state.dart';
import 'ad_consent_service.dart';

class AdConsentController extends ChangeNotifier {
  AdConsentController({required AdConsentService service}) : _service = service;

  final AdConsentService _service;
  AdConsentSnapshot _snapshot = AdConsentSnapshot.initial;
  Future<void>? _initializationFuture;
  bool _isDisposed = false;

  AdConsentSnapshot get snapshot => _snapshot;

  bool get canRequestAds => _snapshot.canRequestAds;

  bool get privacyOptionsRequired => _snapshot.privacyOptionsRequired;

  bool get isInitialized {
    return _snapshot.state == AdConsentState.ready ||
        _snapshot.state == AdConsentState.unavailable ||
        _snapshot.state == AdConsentState.error;
  }

  bool get isBusy {
    return _snapshot.state == AdConsentState.updating ||
        _snapshot.state == AdConsentState.presentingForm;
  }

  Future<void> initialize() {
    if (_isDisposed) {
      return Future<void>.value();
    }
    final existing = _initializationFuture;
    if (existing != null) {
      return existing;
    }
    if (isInitialized) {
      return Future<void>.value();
    }

    final future = _initialize();
    _initializationFuture = future.whenComplete(() {
      _initializationFuture = null;
    });
    return _initializationFuture!;
  }

  Future<void> refreshAfterPrivacyOptions() async {
    if (_isDisposed) {
      return;
    }
    try {
      final canRequestAds = await _service.canRequestAds();
      final privacyOptionsRequired = await _service.isPrivacyOptionsRequired();
      _setSnapshot(
        _snapshot.copyWith(
          state: canRequestAds
              ? AdConsentState.ready
              : AdConsentState.unavailable,
          canRequestAds: canRequestAds,
          privacyOptionsRequired: privacyOptionsRequired,
          clearLastError: true,
        ),
      );
    } catch (error) {
      _setSnapshot(
        _snapshot.copyWith(state: AdConsentState.error, lastError: error),
      );
    }
  }

  Future<void> showPrivacyOptions() async {
    if (_isDisposed) {
      return;
    }
    _setSnapshot(_snapshot.copyWith(state: AdConsentState.presentingForm));
    try {
      await _service.showPrivacyOptionsForm();
      _setSnapshot(
        _snapshot.copyWith(
          formPresentationCompleted: true,
          clearLastError: true,
        ),
      );
      await refreshAfterPrivacyOptions();
    } catch (error) {
      _setSnapshot(
        _snapshot.copyWith(state: AdConsentState.error, lastError: error),
      );
      rethrow;
    }
  }

  Future<void> _initialize() async {
    Object? lastError;
    _setSnapshot(
      _snapshot.copyWith(state: AdConsentState.updating, clearLastError: true),
    );

    try {
      await _service.requestConsentInfoUpdate();
      _setSnapshot(_snapshot.copyWith(consentInfoUpdateCompleted: true));
    } catch (error) {
      lastError = error;
    }

    var canRequestAds = false;
    try {
      canRequestAds = await _service.canRequestAds();
    } catch (error) {
      lastError ??= error;
    }

    _setSnapshot(
      _snapshot.copyWith(
        state: AdConsentState.presentingForm,
        canRequestAds: canRequestAds,
        lastError: lastError,
      ),
    );

    try {
      await _service.loadAndShowConsentFormIfRequired();
      _setSnapshot(_snapshot.copyWith(formPresentationCompleted: true));
    } catch (error) {
      lastError ??= error;
    }

    try {
      canRequestAds = await _service.canRequestAds();
    } catch (error) {
      lastError ??= error;
    }

    var privacyOptionsRequired = false;
    try {
      privacyOptionsRequired = await _service.isPrivacyOptionsRequired();
    } catch (error) {
      lastError ??= error;
    }

    _setSnapshot(
      AdConsentSnapshot(
        state: canRequestAds
            ? AdConsentState.ready
            : lastError == null
            ? AdConsentState.unavailable
            : AdConsentState.error,
        canRequestAds: canRequestAds,
        privacyOptionsRequired: privacyOptionsRequired,
        lastError: lastError,
        consentInfoUpdateCompleted: _snapshot.consentInfoUpdateCompleted,
        formPresentationCompleted: _snapshot.formPresentationCompleted,
      ),
    );
  }

  void _setSnapshot(AdConsentSnapshot snapshot) {
    if (_isDisposed) {
      return;
    }
    _snapshot = snapshot;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _snapshot = _snapshot.copyWith(state: AdConsentState.disposed);
    super.dispose();
  }
}
