import 'dart:convert';

import '../../progress/game_progress.dart';
import '../../../features/game/generator/generator_version_policy.dart';
import '../data/local_key_value_store.dart';
import '../domain/persistence_document_source.dart';
import '../domain/persistence_issue.dart';
import '../domain/persistence_issue_code.dart';
import '../keys/legacy_persistence_keys.dart';
import 'legacy_persistence_reader.dart';

class LegacyGameProgressMigrator
    implements LegacyPersistenceReader<GameProgress> {
  const LegacyGameProgressMigrator({
    required LocalKeyValueStore keyValueStore,
    GeneratorVersionPolicy generatorVersionPolicy =
        const GeneratorVersionPolicy(),
  }) : _keyValueStore = keyValueStore,
       _generatorVersionPolicy = generatorVersionPolicy;

  final LocalKeyValueStore _keyValueStore;
  final GeneratorVersionPolicy _generatorVersionPolicy;

  @override
  LegacyPersistenceReadResult<GameProgress>? read() {
    final issues = <PersistenceIssue>[];
    final rawJson = _keyValueStore.getString(
      LegacyPersistenceKeys.gameProgressJson,
    );
    if (rawJson != null) {
      final progress = _readJsonProgress(rawJson, issues);
      if (progress != null) {
        return LegacyPersistenceReadResult(value: progress, issues: issues);
      }
    }

    final hasFlatProgress =
        _keyValueStore.containsKey(LegacyPersistenceKeys.currentLevel) ||
        _keyValueStore.containsKey(
          LegacyPersistenceKeys.highestUnlockedLevel,
        ) ||
        _keyValueStore.containsKey(LegacyPersistenceKeys.generatorVersion);
    if (!hasFlatProgress) {
      return null;
    }

    return LegacyPersistenceReadResult(
      value: _normalize(
        currentLevel: _keyValueStore.getInt(LegacyPersistenceKeys.currentLevel),
        highestUnlockedLevel: _keyValueStore.getInt(
          LegacyPersistenceKeys.highestUnlockedLevel,
        ),
        legacyGeneratorVersion: _keyValueStore.getInt(
          LegacyPersistenceKeys.generatorVersion,
        ),
        issues: issues,
      ),
      issues: issues,
    );
  }

  GameProgress? _readJsonProgress(String raw, List<PersistenceIssue> issues) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException('Legacy progress root must be object.');
      }
      return _normalize(
        currentLevel: decoded['currentLevel'] is int
            ? decoded['currentLevel'] as int
            : null,
        highestUnlockedLevel: decoded['highestUnlockedLevel'] is int
            ? decoded['highestUnlockedLevel'] as int
            : null,
        legacyGeneratorVersion: decoded['generatorVersion'] is int
            ? decoded['generatorVersion'] as int
            : null,
        issues: issues,
      );
    } catch (_) {
      issues.add(
        const PersistenceIssue(
          code: PersistenceIssueCode.legacyValueInvalid,
          source: PersistenceDocumentSource.legacy,
        ),
      );
      return null;
    }
  }

  GameProgress _normalize({
    required int? currentLevel,
    required int? highestUnlockedLevel,
    required int? legacyGeneratorVersion,
    required List<PersistenceIssue> issues,
  }) {
    var normalizedCurrentLevel = currentLevel ?? 1;
    if (normalizedCurrentLevel < 1 || normalizedCurrentLevel > 400) {
      normalizedCurrentLevel = 1;
      issues.add(
        const PersistenceIssue(
          code: PersistenceIssueCode.legacyValueInvalid,
          source: PersistenceDocumentSource.legacy,
        ),
      );
    }

    var normalizedHighestUnlocked =
        highestUnlockedLevel ?? normalizedCurrentLevel;
    if (normalizedHighestUnlocked < normalizedCurrentLevel) {
      normalizedHighestUnlocked = normalizedCurrentLevel;
      issues.add(
        const PersistenceIssue(
          code: PersistenceIssueCode.legacyValueInvalid,
          source: PersistenceDocumentSource.legacy,
        ),
      );
    }
    if (normalizedHighestUnlocked > 400) {
      normalizedHighestUnlocked = 400;
      issues.add(
        const PersistenceIssue(
          code: PersistenceIssueCode.legacyValueInvalid,
          source: PersistenceDocumentSource.legacy,
        ),
      );
    }

    final officialGeneratorVersion = _generatorVersionPolicy.versionForLevel(
      normalizedCurrentLevel,
    );
    if (legacyGeneratorVersion != null &&
        legacyGeneratorVersion != officialGeneratorVersion) {
      issues.add(
        PersistenceIssue(
          code: PersistenceIssueCode.legacyValueInvalid,
          source: PersistenceDocumentSource.legacy,
          revision: legacyGeneratorVersion,
        ),
      );
    }

    return GameProgress(
      schemaVersion: GameProgress.currentSchemaVersion,
      currentLevel: normalizedCurrentLevel,
      highestUnlockedLevel: normalizedHighestUnlocked,
      generatorVersion: officialGeneratorVersion,
    );
  }
}
