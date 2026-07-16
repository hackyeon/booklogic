import '../../../features/game/tutorial/domain/learning_progress.dart';
import '../data/local_key_value_store.dart';
import '../domain/persistence_document_source.dart';
import '../domain/persistence_issue.dart';
import '../domain/persistence_issue_code.dart';
import '../keys/legacy_persistence_keys.dart';
import 'legacy_persistence_reader.dart';

class LegacyLearningProgressMigrator
    implements LegacyPersistenceReader<LearningProgress> {
  const LegacyLearningProgressMigrator({
    required LocalKeyValueStore keyValueStore,
    int Function()? currentLevelProvider,
  }) : _keyValueStore = keyValueStore,
       _currentLevelProvider = currentLevelProvider;

  final LocalKeyValueStore _keyValueStore;
  final int Function()? _currentLevelProvider;

  @override
  LegacyPersistenceReadResult<LearningProgress>? read() {
    final hasLegacy =
        _keyValueStore.containsKey(LegacyPersistenceKeys.tutorialCompleted) ||
        _keyValueStore.containsKey(LegacyPersistenceKeys.acknowledgedRuleCodes);
    if (!hasLegacy) {
      return null;
    }

    final issues = <PersistenceIssue>[];
    var tutorialCompleted =
        _keyValueStore.getBool(LegacyPersistenceKeys.tutorialCompleted) ??
        false;
    final currentLevel = _currentLevelProvider?.call();
    if ((currentLevel ?? 1) >= 6 && !tutorialCompleted) {
      tutorialCompleted = true;
    }

    final rawCodes =
        _keyValueStore.getStringList(
          LegacyPersistenceKeys.acknowledgedRuleCodes,
        ) ??
        const <String>[];
    final cleanedCodes = <String>{};
    for (final code in rawCodes) {
      final normalized = code.trim();
      if (normalized.isEmpty) {
        issues.add(
          const PersistenceIssue(
            code: PersistenceIssueCode.legacyValueInvalid,
            source: PersistenceDocumentSource.legacy,
          ),
        );
      } else {
        cleanedCodes.add(normalized);
      }
    }

    return LegacyPersistenceReadResult(
      value: LearningProgress(
        tutorialCompleted: tutorialCompleted,
        acknowledgedRuleCodes: cleanedCodes,
      ),
      issues: issues,
    );
  }
}
