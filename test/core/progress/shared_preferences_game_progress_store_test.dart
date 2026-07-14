import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:booklogic/core/progress/game_progress.dart';
import 'package:booklogic/core/progress/shared_preferences_game_progress_store.dart';

void main() {
  group('SharedPreferencesGameProgressStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('returns null when no progress is saved', () async {
      const store = SharedPreferencesGameProgressStore();

      expect(await store.read(), isNull);
    });

    test('writes and reads a single JSON string with the stable key', () async {
      const store = SharedPreferencesGameProgressStore();
      final progress = GameProgress(
        schemaVersion: 1,
        currentLevel: 2,
        highestUnlockedLevel: 2,
        generatorVersion: 1,
      );

      await store.write(progress);

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getKeys(), {
        SharedPreferencesGameProgressStore.storageKey,
      });
      expect(
        preferences.getString(SharedPreferencesGameProgressStore.storageKey),
        '{"schemaVersion":1,"currentLevel":2,"highestUnlockedLevel":2,"generatorVersion":1}',
      );
      expect(await store.read(), progress);
    });

    test('rejects malformed stored data', () async {
      const store = SharedPreferencesGameProgressStore();
      final preferences = await SharedPreferences.getInstance();

      await preferences.setString(
        SharedPreferencesGameProgressStore.storageKey,
        '{ invalid json',
      );
      await expectLater(store.read(), throwsFormatException);

      await preferences.setString(
        SharedPreferencesGameProgressStore.storageKey,
        '[1, 2, 3]',
      );
      await expectLater(store.read(), throwsFormatException);

      await preferences.setString(
        SharedPreferencesGameProgressStore.storageKey,
        '{"schemaVersion":1,"currentLevel":"2","highestUnlockedLevel":2,"generatorVersion":1}',
      );
      await expectLater(store.read(), throwsFormatException);
    });
  });
}
