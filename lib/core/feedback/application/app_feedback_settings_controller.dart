import 'package:flutter/foundation.dart';

import '../data/app_feedback_settings_store.dart';
import '../domain/app_feedback_settings.dart';

class AppFeedbackSettingsController extends ChangeNotifier {
  AppFeedbackSettingsController({required AppFeedbackSettingsStore store})
    : _store = store;

  final AppFeedbackSettingsStore _store;
  AppFeedbackSettings _settings = AppFeedbackSettings.defaults;
  bool _isInitialized = false;
  bool _isSavingSound = false;
  bool _isSavingHaptic = false;
  bool _isDisposed = false;
  Object? _lastError;
  Future<void>? _initializeFuture;
  Future<void> _saveQueue = Future<void>.value();
  int _saveRevision = 0;

  AppFeedbackSettings get settings => _settings;

  bool get isInitialized => _isInitialized;

  bool get isSavingSound => _isSavingSound;

  bool get isSavingHaptic => _isSavingHaptic;

  Object? get lastError => _lastError;

  bool get soundEnabled => _settings.soundEnabled;

  bool get hapticEnabled => _settings.hapticEnabled;

  Future<void> initialize() {
    if (_isDisposed) {
      return Future<void>.value();
    }
    final existing = _initializeFuture;
    if (existing != null) {
      return existing;
    }
    if (_isInitialized) {
      return Future<void>.value();
    }
    final future = _initialize();
    _initializeFuture = future.whenComplete(() {
      _initializeFuture = null;
    });
    return future;
  }

  void setSoundEnabled(bool enabled) {
    if (_isDisposed || _settings.soundEnabled == enabled) {
      return;
    }
    _settings = _settings.copyWith(soundEnabled: enabled);
    _isSavingSound = true;
    _lastError = null;
    _notifySafely();
    _scheduleSave(_settings);
  }

  void setHapticEnabled(bool enabled) {
    if (_isDisposed || _settings.hapticEnabled == enabled) {
      return;
    }
    _settings = _settings.copyWith(hapticEnabled: enabled);
    _isSavingHaptic = true;
    _lastError = null;
    _notifySafely();
    _scheduleSave(_settings);
  }

  void clearError() {
    if (_lastError == null) {
      return;
    }
    _lastError = null;
    _notifySafely();
  }

  Future<void> _initialize() async {
    try {
      _settings = await _store.load();
      _lastError = null;
    } catch (error) {
      _settings = AppFeedbackSettings.defaults;
      _lastError = error;
    }
    _isInitialized = true;
    _notifySafely();
  }

  void _scheduleSave(AppFeedbackSettings settings) {
    final revision = ++_saveRevision;
    _saveQueue = _saveQueue
        .catchError((_) {})
        .then((_) => _store.save(settings))
        .then(
          (_) => _finishSave(revision),
          onError: (Object error) => _failSave(revision, error),
        );
  }

  void _finishSave(int revision) {
    if (_isDisposed || revision != _saveRevision) {
      return;
    }
    _isSavingSound = false;
    _isSavingHaptic = false;
    _lastError = null;
    _notifySafely();
  }

  void _failSave(int revision, Object error) {
    if (_isDisposed) {
      return;
    }
    _lastError = error;
    if (revision == _saveRevision) {
      _isSavingSound = false;
      _isSavingHaptic = false;
    }
    _notifySafely();
  }

  void _notifySafely() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
