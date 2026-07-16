import '../../feedback/domain/app_feedback_settings.dart';
import '../data/local_key_value_store.dart';
import '../keys/legacy_persistence_keys.dart';
import 'legacy_persistence_reader.dart';

class LegacyFeedbackSettingsMigrator
    implements LegacyPersistenceReader<AppFeedbackSettings> {
  const LegacyFeedbackSettingsMigrator({
    required LocalKeyValueStore keyValueStore,
  }) : _keyValueStore = keyValueStore;

  final LocalKeyValueStore _keyValueStore;

  @override
  LegacyPersistenceReadResult<AppFeedbackSettings>? read() {
    final hasLegacy =
        _keyValueStore.containsKey(LegacyPersistenceKeys.soundEnabled) ||
        _keyValueStore.containsKey(LegacyPersistenceKeys.hapticEnabled);
    if (!hasLegacy) {
      return null;
    }
    return LegacyPersistenceReadResult(
      value: AppFeedbackSettings(
        soundEnabled:
            _keyValueStore.getBool(LegacyPersistenceKeys.soundEnabled) ?? true,
        hapticEnabled:
            _keyValueStore.getBool(LegacyPersistenceKeys.hapticEnabled) ?? true,
      ),
    );
  }
}
