import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/persistence/application/resilient_json_document_store.dart';
import '../../../../core/persistence/data/local_key_value_store.dart';
import '../../../../core/persistence/data/shared_preferences_key_value_store.dart';
import '../../../../core/persistence/domain/persistence_load_report.dart';
import '../../../../core/persistence/keys/legacy_persistence_keys.dart';
import '../../../../core/persistence/keys/persistence_keys.dart';
import '../../../../core/persistence/migration/legacy_learning_progress_migrator.dart';
import '../application/learning_progress_store.dart';
import '../domain/learning_progress.dart';
import 'learning_progress_persistence_codec.dart';

class SharedPreferencesLearningProgressStore implements LearningProgressStore {
  SharedPreferencesLearningProgressStore({
    LocalKeyValueStore? keyValueStore,
    int Function()? currentLevelProvider,
  }) : _keyValueStore = keyValueStore,
       _currentLevelProvider = currentLevelProvider;

  static const tutorialCompletedKey = LegacyPersistenceKeys.tutorialCompleted;
  static const acknowledgedRuleCodesKey =
      LegacyPersistenceKeys.acknowledgedRuleCodes;

  final LocalKeyValueStore? _keyValueStore;
  final int Function()? _currentLevelProvider;
  ResilientJsonDocumentStore<LearningProgress>? _documentStore;

  @override
  PersistenceLoadReport? get lastLoadReport => _documentStore?.lastLoadReport;

  @override
  bool get canWrite => _documentStore?.canWrite ?? true;

  @override
  Future<LearningProgress> load() async {
    final store = await _getDocumentStore();
    final result = await store.load();
    return result.value;
  }

  @override
  Future<void> save(LearningProgress progress) async {
    final store = await _getDocumentStore();
    await store.save(progress);
  }

  @override
  Future<void> flush() async {
    await _documentStore?.flush();
  }

  Future<ResilientJsonDocumentStore<LearningProgress>>
  _getDocumentStore() async {
    final existing = _documentStore;
    if (existing != null) {
      return existing;
    }
    final keyValueStore =
        _keyValueStore ??
        SharedPreferencesKeyValueStore(await SharedPreferences.getInstance());
    final store = ResilientJsonDocumentStore<LearningProgress>(
      keyValueStore: keyValueStore,
      keys: PersistenceKeys.learningProgress,
      codec: const LearningProgressPersistenceCodec(),
      legacyReader: LegacyLearningProgressMigrator(
        keyValueStore: keyValueStore,
        currentLevelProvider: _currentLevelProvider,
      ),
    );
    _documentStore = store;
    return store;
  }
}
