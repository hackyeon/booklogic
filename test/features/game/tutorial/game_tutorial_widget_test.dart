import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:booklogic/core/progress/game_progress.dart';
import 'package:booklogic/core/progress/game_progress_controller.dart';
import 'package:booklogic/features/game/generator/generator_config.dart';
import 'package:booklogic/features/game/generator/stage_generator.dart';
import 'package:booklogic/features/game/presentation/game_screen.dart';
import 'package:booklogic/features/game/presentation/widgets/book_widget.dart';
import 'package:booklogic/features/game/tutorial/application/learning_progress_controller.dart';
import 'package:booklogic/features/game/tutorial/application/tutorial_solve_path_resolver.dart';
import 'package:booklogic/features/game/tutorial/domain/learning_progress.dart';

import '../../../helpers/fake_game_progress_store.dart';
import '../../../helpers/fake_learning_progress_store.dart';

void main() {
  testWidgets(
    'Level 1 tutorial blocks other books and accepts the target book',
    (tester) async {
      const generator = StageGenerator();
      const resolver = TutorialSolvePathResolver();
      final stage = generator.generate(level: 1, generatorVersion: 1);
      final target = resolver.resolveFirstSwap(stage)!;
      final otherBookId = stage.initialPlacements
          .map((placement) => placement.book.id)
          .firstWhere((bookId) => bookId != target.firstBookId);
      final progressController = _progressController();
      final learningController = LearningProgressController(
        store: FakeLearningProgressStore(progress: LearningProgress()),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: GameScreen(
            level: 1,
            generatorVersion: GeneratorConfig.currentVersion,
            progressController: progressController,
            stageGenerator: generator,
            learningProgressController: learningController,
            enableTutorial: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('책을 한 권 선택해 보세요.'), findsOneWidget);

      await tester.tap(find.byKey(ValueKey(otherBookId)), warnIfMissed: false);
      await tester.pump();
      expect(
        tester.widget<BookWidget>(find.byKey(ValueKey(otherBookId))).isSelected,
        isFalse,
      );

      await tester.tap(find.byKey(ValueKey(target.firstBookId)));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<BookWidget>(find.byKey(ValueKey(target.firstBookId)))
            .isSelected,
        isTrue,
      );
      expect(
        find.text('선택한 책은 앞으로 표시됩니다. 같은 책을 다시 누르면 선택을 취소할 수 있어요.'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('tutorial_acknowledge_button')));
      await tester.pumpAndSettle();

      expect(find.text('책을 한 권 선택해 보세요.'), findsNothing);
      expect(learningController.tutorialCompleted, isFalse);

      progressController.dispose();
      learningController.dispose();
    },
  );
}

GameProgressController _progressController() {
  final controller = GameProgressController(
    store: FakeGameProgressStore(
      progress: GameProgress(
        schemaVersion: GameProgress.currentSchemaVersion,
        currentLevel: 1,
        highestUnlockedLevel: 1,
        generatorVersion: GeneratorConfig.currentVersion,
      ),
    ),
  );
  controller.load();
  return controller;
}
