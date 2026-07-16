import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:booklogic/core/persistence/keys/persistence_keys.dart';
import 'package:booklogic/features/game/tutorial/data/shared_preferences_learning_progress_store.dart';
import 'package:booklogic/features/game/tutorial/domain/learning_progress.dart';

void main() {
  group('SharedPreferencesLearningProgressStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('missing keys load as the default progress', () async {
      final store = SharedPreferencesLearningProgressStore();

      final progress = await store.load();

      expect(progress.tutorialCompleted, isFalse);
      expect(progress.acknowledgedRuleCodes, isEmpty);
    });

    test(
      'saves a resilient document and round-trips sorted rule codes',
      () async {
        final store = SharedPreferencesLearningProgressStore();
        final progress = LearningProgress(
          tutorialCompleted: true,
          acknowledgedRuleCodes: ['c06_between', '', 'c05_adjacent'],
        );

        await store.save(progress);

        final preferences = await SharedPreferences.getInstance();
        expect(
          preferences.getInt(PersistenceKeys.learningProgress.commitRevision),
          1,
        );
        expect(
          preferences.getString(PersistenceKeys.learningProgress.primary),
          contains('"acknowledgedRuleCodes":["c05_adjacent","c06_between"]'),
        );
        expect(await store.load(), progress);
      },
    );
  });
}
