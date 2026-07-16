import 'package:shared_preferences/shared_preferences.dart';

import '../persistence/application/resilient_json_document_store.dart';
import '../persistence/data/local_key_value_store.dart';
import '../persistence/data/shared_preferences_key_value_store.dart';
import '../persistence/domain/persistence_load_report.dart';
import '../persistence/keys/legacy_persistence_keys.dart';
import '../persistence/keys/persistence_keys.dart';
import '../persistence/migration/legacy_game_progress_migrator.dart';
import 'data/game_progress_persistence_codec.dart';
import 'game_progress.dart';
import 'game_progress_store.dart';

class SharedPreferencesGameProgressStore implements GameProgressStore {
  SharedPreferencesGameProgressStore({LocalKeyValueStore? keyValueStore})
    : _keyValueStore = keyValueStore;

  static const String storageKey = LegacyPersistenceKeys.gameProgressJson;

  final LocalKeyValueStore? _keyValueStore;
  ResilientJsonDocumentStore<GameProgress>? _documentStore;

  @override
  PersistenceLoadReport? get lastLoadReport => _documentStore?.lastLoadReport;

  @override
  bool get canWrite => _documentStore?.canWrite ?? true;

  @override
  Future<GameProgress?> read() async {
    final store = await _getDocumentStore();
    final result = await store.load();
    return result.hadNoStoredValue ? null : result.value;
  }

  @override
  Future<void> write(GameProgress progress) async {
    final store = await _getDocumentStore();
    await store.save(progress);
  }

  @override
  Future<void> flush() async {
    await _documentStore?.flush();
  }

  Future<ResilientJsonDocumentStore<GameProgress>> _getDocumentStore() async {
    final existing = _documentStore;
    if (existing != null) {
      return existing;
    }
    final keyValueStore =
        _keyValueStore ??
        SharedPreferencesKeyValueStore(await SharedPreferences.getInstance());
    final store = ResilientJsonDocumentStore<GameProgress>(
      keyValueStore: keyValueStore,
      keys: PersistenceKeys.gameProgress,
      codec: const GameProgressPersistenceCodec(),
      legacyReader: LegacyGameProgressMigrator(keyValueStore: keyValueStore),
    );
    _documentStore = store;
    return store;
  }
}
