import 'package:flutter_test/flutter_test.dart';

import 'package:booklogic/features/game/tutorial/application/learning_progress_controller.dart';
import 'package:booklogic/features/game/tutorial/domain/learning_progress.dart';

import '../../../helpers/fake_learning_progress_store.dart';

void main() {
  group('LearningProgressController', () {
    test('loads the default state', () async {
      final store = FakeLearningProgressStore();
      final controller = LearningProgressController(store: store);

      await controller.initialize(currentLevel: 1);

      expect(controller.tutorialCompleted, isFalse);
      expect(controller.acknowledgedRuleCodes, isEmpty);
      controller.dispose();
    });

    test('completeTutorial saves once even when called twice', () async {
      final store = FakeLearningProgressStore();
      final controller = LearningProgressController(store: store);

      await controller.initialize(currentLevel: 1);
      await controller.completeTutorial();
      await controller.completeTutorial();

      expect(controller.tutorialCompleted, isTrue);
      expect(store.saveCount, 1);
      expect(store.saves.single.tutorialCompleted, isTrue);
      controller.dispose();
    });

    test('acknowledgeRules deduplicates and stores codes', () async {
      final store = FakeLearningProgressStore();
      final controller = LearningProgressController(store: store);

      await controller.initialize(currentLevel: 1);
      await controller.acknowledgeRules([
        'c05_adjacent',
        '',
        'c05_adjacent',
        'c06_between',
      ]);

      expect(controller.acknowledgedRuleCodes, {'c05_adjacent', 'c06_between'});
      expect(store.saveCount, 1);
      controller.dispose();
    });

    test('reconciles Level 6 and later users to completed tutorial', () async {
      final store = FakeLearningProgressStore(progress: LearningProgress());
      final controller = LearningProgressController(store: store);

      await controller.initialize(currentLevel: 6);

      expect(controller.tutorialCompleted, isTrue);
      expect(store.saveCount, 1);
      controller.dispose();
    });

    test('save failure keeps the session state usable', () async {
      final store = FakeLearningProgressStore(saveErrors: ['failed']);
      final controller = LearningProgressController(store: store);

      await controller.initialize(currentLevel: 1);
      await controller.completeTutorial();

      expect(controller.tutorialCompleted, isTrue);
      expect(controller.lastError, isA<StateError>());
      controller.dispose();
    });
  });
}
