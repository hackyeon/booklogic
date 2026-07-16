import 'dart:async';

import 'package:booklogic/core/feedback/data/app_feedback_settings_store.dart';
import 'package:booklogic/core/feedback/domain/app_feedback_settings.dart';
import 'package:booklogic/core/persistence/domain/persistence_load_report.dart';

class FakeAppFeedbackSettingsStore implements AppFeedbackSettingsStore {
  FakeAppFeedbackSettingsStore({
    this.settings = AppFeedbackSettings.defaults,
    this.loadError,
    List<Object?> soundSaveErrors = const [],
    List<Object?> hapticSaveErrors = const [],
    this.soundSaveBlocker,
    this.hapticSaveBlocker,
  }) : _soundSaveErrors = List<Object?>.of(soundSaveErrors),
       _hapticSaveErrors = List<Object?>.of(hapticSaveErrors);

  AppFeedbackSettings settings;
  Object? loadError;
  Completer<void>? soundSaveBlocker;
  Completer<void>? hapticSaveBlocker;
  int loadCount = 0;
  final soundWrites = <bool>[];
  final hapticWrites = <bool>[];
  final saves = <AppFeedbackSettings>[];
  PersistenceLoadReport? _lastLoadReport;
  final List<Object?> _soundSaveErrors;
  final List<Object?> _hapticSaveErrors;

  @override
  PersistenceLoadReport? get lastLoadReport => _lastLoadReport;

  @override
  bool get canWrite => true;

  @override
  Future<AppFeedbackSettings> load() async {
    loadCount += 1;
    final error = loadError;
    if (error != null) {
      throw StateError(error.toString());
    }
    return settings;
  }

  @override
  Future<void> saveSoundEnabled(bool enabled) async {
    final blocker = soundSaveBlocker;
    if (blocker != null) {
      await blocker.future;
    }
    soundWrites.add(enabled);
    settings = settings.copyWith(soundEnabled: enabled);
    if (_soundSaveErrors.isNotEmpty) {
      final error = _soundSaveErrors.removeAt(0);
      if (error != null) {
        throw StateError(error.toString());
      }
    }
  }

  @override
  Future<void> saveHapticEnabled(bool enabled) async {
    final blocker = hapticSaveBlocker;
    if (blocker != null) {
      await blocker.future;
    }
    hapticWrites.add(enabled);
    settings = settings.copyWith(hapticEnabled: enabled);
    if (_hapticSaveErrors.isNotEmpty) {
      final error = _hapticSaveErrors.removeAt(0);
      if (error != null) {
        throw StateError(error.toString());
      }
    }
  }

  @override
  Future<void> save(AppFeedbackSettings settings) async {
    final blocker = soundSaveBlocker ?? hapticSaveBlocker;
    if (blocker != null) {
      await blocker.future;
    }
    saves.add(settings);
    soundWrites.add(settings.soundEnabled);
    hapticWrites.add(settings.hapticEnabled);
    this.settings = settings;
    if (_soundSaveErrors.isNotEmpty) {
      final error = _soundSaveErrors.removeAt(0);
      if (error != null) {
        throw StateError(error.toString());
      }
    }
    if (_hapticSaveErrors.isNotEmpty) {
      final error = _hapticSaveErrors.removeAt(0);
      if (error != null) {
        throw StateError(error.toString());
      }
    }
  }

  @override
  Future<void> flush() async {}
}
