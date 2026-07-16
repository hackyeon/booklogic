import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:booklogic/core/persistence/keys/persistence_keys.dart';
import 'package:booklogic/core/progress/game_progress.dart';
import 'package:booklogic/core/progress/shared_preferences_game_progress_store.dart';

void main() {
  group('SharedPreferencesGameProgressStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('returns null when no progress is saved', () async {
      final store = SharedPreferencesGameProgressStore();

      expect(await store.read(), isNull);
    });

    test('writes and reads a resilient primary document', () async {
      final store = SharedPreferencesGameProgressStore();
      final progress = GameProgress(
        schemaVersion: 1,
        currentLevel: 2,
        highestUnlockedLevel: 2,
        generatorVersion: 1,
      );

      await store.write(progress);

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getKeys(), {
        PersistenceKeys.gameProgress.primary,
        PersistenceKeys.gameProgress.commitRevision,
      });
      expect(
        preferences.getInt(PersistenceKeys.gameProgress.commitRevision),
        1,
      );
      expect(
        preferences.getString(PersistenceKeys.gameProgress.primary),
        contains('"currentLevel":2'),
      );
      expect(await store.read(), progress);
    });

    test('ignores malformed legacy data and keeps the app usable', () async {
      final store = SharedPreferencesGameProgressStore();
      final preferences = await SharedPreferences.getInstance();

      await preferences.setString(
        SharedPreferencesGameProgressStore.storageKey,
        '{ invalid json',
      );
      expect(await store.read(), isNull);
      expect(await store.read(), GameProgress.initial(generatorVersion: 1));
    });

    test('migrates legacy JSON without deleting the legacy key', () async {
      final store = SharedPreferencesGameProgressStore();
      final preferences = await SharedPreferences.getInstance();
      final legacyProgress = GameProgress(
        schemaVersion: 1,
        currentLevel: 201,
        highestUnlockedLevel: 201,
        generatorVersion: 2,
      );

      await preferences.setString(
        SharedPreferencesGameProgressStore.storageKey,
        legacyProgress.encode(),
      );

      expect(await store.read(), legacyProgress);
      expect(
        preferences.getString(SharedPreferencesGameProgressStore.storageKey),
        legacyProgress.encode(),
      );
      expect(
        preferences.getInt(PersistenceKeys.gameProgress.commitRevision),
        1,
      );
      expect(
        preferences.getString(PersistenceKeys.gameProgress.primary),
        isNotNull,
      );
    });
  });
}
