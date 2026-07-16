import 'package:shared_preferences/shared_preferences.dart';

import '../../persistence/application/resilient_json_document_store.dart';
import '../../persistence/data/local_key_value_store.dart';
import '../../persistence/data/shared_preferences_key_value_store.dart';
import '../../persistence/domain/persistence_load_report.dart';
import '../../persistence/keys/legacy_persistence_keys.dart';
import '../../persistence/keys/persistence_keys.dart';
import '../../persistence/migration/legacy_feedback_settings_migrator.dart';
import '../domain/app_feedback_settings.dart';
import 'app_feedback_settings_persistence_codec.dart';
import 'app_feedback_settings_store.dart';

class SharedPreferencesAppFeedbackSettingsStore
    implements AppFeedbackSettingsStore {
  SharedPreferencesAppFeedbackSettingsStore({LocalKeyValueStore? keyValueStore})
    : _keyValueStore = keyValueStore;

  static const soundEnabledKey = LegacyPersistenceKeys.soundEnabled;
  static const hapticEnabledKey = LegacyPersistenceKeys.hapticEnabled;

  final LocalKeyValueStore? _keyValueStore;
  ResilientJsonDocumentStore<AppFeedbackSettings>? _documentStore;

  @override
  PersistenceLoadReport? get lastLoadReport => _documentStore?.lastLoadReport;

  @override
  bool get canWrite => _documentStore?.canWrite ?? true;

  @override
  Future<AppFeedbackSettings> load() async {
    final store = await _getDocumentStore();
    final result = await store.load();
    return result.value;
  }

  @override
  Future<void> save(AppFeedbackSettings settings) async {
    final store = await _getDocumentStore();
    await store.save(settings);
  }

  @override
  Future<void> saveSoundEnabled(bool enabled) async {
    final current = await load();
    await save(current.copyWith(soundEnabled: enabled));
  }

  @override
  Future<void> saveHapticEnabled(bool enabled) async {
    final current = await load();
    await save(current.copyWith(hapticEnabled: enabled));
  }

  @override
  Future<void> flush() async {
    await _documentStore?.flush();
  }

  Future<ResilientJsonDocumentStore<AppFeedbackSettings>>
  _getDocumentStore() async {
    final existing = _documentStore;
    if (existing != null) {
      return existing;
    }
    final keyValueStore =
        _keyValueStore ??
        SharedPreferencesKeyValueStore(await SharedPreferences.getInstance());
    final store = ResilientJsonDocumentStore<AppFeedbackSettings>(
      keyValueStore: keyValueStore,
      keys: PersistenceKeys.feedbackSettings,
      codec: const AppFeedbackSettingsPersistenceCodec(),
      legacyReader: LegacyFeedbackSettingsMigrator(
        keyValueStore: keyValueStore,
      ),
    );
    _documentStore = store;
    return store;
  }
}
