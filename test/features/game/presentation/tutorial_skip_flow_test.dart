import 'package:booklogic/core/constants/app_durations.dart';
import 'package:booklogic/core/progress/game_progress.dart';
import 'package:booklogic/core/progress/game_progress_controller.dart';
import 'package:booklogic/core/theme/app_theme.dart';
import 'package:booklogic/features/game/generator/generator_version_policy.dart';
import 'package:booklogic/features/game/generator/stage_generator.dart';
import 'package:booklogic/features/game/presentation/game_screen.dart';
import 'package:booklogic/features/game/tutorial/application/learning_progress_controller.dart';
import 'package:booklogic/features/game/tutorial/application/tutorial_plan_factory.dart';
import 'package:booklogic/features/game/tutorial/domain/learning_progress.dart';
import 'package:booklogic/features/game/tutorial/domain/tutorial_step_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_game_progress_store.dart';
import '../../../helpers/fake_learning_progress_store.dart';

void main() {
  for (final level in [1, 2, 5]) {
    testWidgets('Level $level main tutorial skip completes learning', (
      tester,
    ) async {
      final fixture = await _pumpTutorialGame(tester, level: level);

      await _confirmTutorialSkip(tester);

      _expectTutorialClosed(tester);
      expect(fixture.learningController.tutorialCompleted, isTrue);
      expect(fixture.learningStore.saveCount, 1);
      expect(fixture.learningStore.saves.single.tutorialCompleted, isTrue);
    });
  }

  testWidgets('Level 5 start action remains interactive', (tester) async {
    final fixture = await _pumpTutorialGame(tester, level: 5);

    await tester.tap(find.byKey(const Key('tutorial_acknowledge_button')));
    await tester.pumpAndSettle();

    _expectTutorialClosed(tester);
    expect(fixture.learningStore.saveCount, 0);
  });

  testWidgets('Level 3 summary skip is hit-testable and completes learning', (
    tester,
  ) async {
    final fixture = await _pumpTutorialGame(tester, level: 3);

    expect(find.text('단서를 눌러 단서 목록을 확인해 보세요.'), findsOneWidget);
    expect(_skipButton.hitTestable(), findsOneWidget);
    await _confirmTutorialSkip(tester);

    _expectTutorialClosed(tester);
    expect(fixture.learningController.tutorialCompleted, isTrue);
    expect(fixture.learningStore.saveCount, 1);
  });

  testWidgets('continue learning keeps the same Level 3 tutorial step', (
    tester,
  ) async {
    final fixture = await _pumpTutorialGame(tester, level: 3);

    await tester.tap(_skipButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('계속 배우기'));
    await tester.pumpAndSettle();

    expect(find.text('튜토리얼 1/3'), findsOneWidget);
    expect(find.text('단서를 눌러 단서 목록을 확인해 보세요.'), findsOneWidget);
    expect(fixture.learningController.tutorialCompleted, isFalse);
    expect(fixture.learningStore.saveCount, 0);
  });

  testWidgets('rapid skip taps open one confirmation and save once', (
    tester,
  ) async {
    final fixture = await _pumpTutorialGame(tester, level: 3);

    await tester.tap(_skipButton);
    await tester.tap(_skipButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('건너뛰기'));
    await tester.pumpAndSettle();

    expect(fixture.learningController.tutorialCompleted, isTrue);
    expect(fixture.learningStore.saveCount, 1);
  });

  testWidgets(
    'Level 3 clue sheet blocks other controls and skip closes the sheet',
    (tester) async {
      final fixture = await _pumpTutorialGame(tester, level: 3);
      final stage = const StageGenerator().generate(
        level: 3,
        generatorVersion: fixture.generatorVersion,
      );
      final targetClueId = const TutorialPlanFactory()
          .create(stage: stage)!
          .steps
          .singleWhere((step) => step.type == TutorialStepType.tapClueCard)
          .expectedClueId!;
      final wrongClueId = stage.clues
          .map((clue) => clue.id)
          .firstWhere((id) => id != targetClueId);

      await _openTutorialClueSheet(tester);

      expect(_skipButton.hitTestable(), findsOneWidget);
      expect(
        find.byKey(const Key('clue_bottom_sheet_close_button')).hitTestable(),
        findsNothing,
      );
      await tester.tap(
        find.byKey(Key('clue_$wrongClueId')),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(find.byKey(const Key('clue_bottom_sheet')), findsOneWidget);
      expect(find.text('단서 카드를 눌러 관련 책을 확인해 보세요.'), findsOneWidget);

      await _confirmTutorialSkip(tester);

      expect(find.byKey(const Key('clue_bottom_sheet')), findsNothing);
      _expectTutorialClosed(tester);
      expect(fixture.learningController.tutorialCompleted, isTrue);
      expect(fixture.learningStore.saveCount, 1);
      expect(
        find.byKey(const Key('game_back_button')).hitTestable(),
        findsOneWidget,
      );
    },
  );

  testWidgets('Level 4 summary step skip completes learning', (tester) async {
    final fixture = await _pumpTutorialGame(tester, level: 4);

    await _confirmTutorialSkip(tester);

    _expectTutorialCompleted(fixture, tester);
  });

  testWidgets('Level 4 first clue sheet skip closes the sheet', (tester) async {
    final fixture = await _pumpTutorialGame(tester, level: 4);
    await _openTutorialClueSheet(tester);

    await _confirmTutorialSkip(tester);

    expect(find.byKey(const Key('clue_bottom_sheet')), findsNothing);
    _expectTutorialCompleted(fixture, tester);
  });

  testWidgets('Level 4 second summary step skip completes learning', (
    tester,
  ) async {
    final fixture = await _pumpTutorialGame(tester, level: 4);
    await _advanceLevelFourFirstClue(tester);

    expect(find.text('단서를 다시 열어 두 번째 단서를 확인해 보세요.'), findsOneWidget);
    await _confirmTutorialSkip(tester);

    _expectTutorialCompleted(fixture, tester);
  });

  testWidgets('Level 4 second clue sheet skip closes the sheet', (
    tester,
  ) async {
    final fixture = await _pumpTutorialGame(tester, level: 4);
    await _advanceLevelFourFirstClue(tester);
    await _openTutorialClueSheet(tester);

    await _confirmTutorialSkip(tester);

    expect(find.byKey(const Key('clue_bottom_sheet')), findsNothing);
    _expectTutorialCompleted(fixture, tester);
  });

  testWidgets('Level 4 combination message skip completes learning', (
    tester,
  ) async {
    final fixture = await _pumpTutorialGame(tester, level: 4);
    await _advanceLevelFourFirstClue(tester);
    await _advanceLevelFourSecondClue(tester);

    expect(find.text('두 단서를 함께 사용하면 책의 위치를 더 정확하게 찾을 수 있어요.'), findsOneWidget);
    await _confirmTutorialSkip(tester);

    _expectTutorialCompleted(fixture, tester);
  });

  testWidgets('skip stays completed while later rule introductions remain', (
    tester,
  ) async {
    final fixture = await _pumpTutorialGame(tester, level: 3);
    await _confirmTutorialSkip(tester);

    await _pumpTutorialGame(
      tester,
      level: 4,
      learningController: fixture.learningController,
      learningStore: fixture.learningStore,
    );
    expect(find.byKey(const Key('tutorial_overlay_bounds')), findsNothing);

    await _pumpTutorialGame(
      tester,
      level: 6,
      learningController: fixture.learningController,
      learningStore: fixture.learningStore,
    );
    expect(find.byKey(const Key('tutorial_overlay_bounds')), findsNothing);
    expect(find.text('새로운 단서'), findsOneWidget);
    expect(fixture.learningStore.saveCount, 1);
  });
}

Finder get _skipButton => find.byKey(const Key('tutorial_skip_button'));

Future<_TutorialGameFixture> _pumpTutorialGame(
  WidgetTester tester, {
  required int level,
  LearningProgressController? learningController,
  FakeLearningProgressStore? learningStore,
}) async {
  final generatorVersion = const GeneratorVersionPolicy().versionForLevel(
    level,
  );
  final progressController = GameProgressController(
    store: FakeGameProgressStore(
      progress: GameProgress(
        schemaVersion: GameProgress.currentSchemaVersion,
        currentLevel: level,
        highestUnlockedLevel: level,
        generatorVersion: generatorVersion,
      ),
    ),
  );
  await progressController.load();
  addTearDown(progressController.dispose);

  final store =
      learningStore ?? FakeLearningProgressStore(progress: LearningProgress());
  final ownsLearningController = learningController == null;
  final activeLearningController =
      learningController ?? LearningProgressController(store: store);
  if (ownsLearningController) {
    addTearDown(activeLearningController.dispose);
  }

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: GameScreen(
        level: level,
        generatorVersion: generatorVersion,
        progressController: progressController,
        learningProgressController: activeLearningController,
        enableTutorial: true,
      ),
    ),
  );
  await tester.pumpAndSettle();

  return _TutorialGameFixture(
    generatorVersion: generatorVersion,
    learningController: activeLearningController,
    learningStore: store,
  );
}

Future<void> _confirmTutorialSkip(WidgetTester tester) async {
  await tester.tap(_skipButton);
  await tester.pumpAndSettle();
  expect(find.text('튜토리얼을 건너뛸까요?'), findsOneWidget);
  await tester.tap(find.text('건너뛰기'));
  await tester.pumpAndSettle();
}

Future<void> _openTutorialClueSheet(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const Key('tutorial_target_cutout')),
    warnIfMissed: false,
  );
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('clue_bottom_sheet')), findsOneWidget);
}

Future<void> _advanceLevelFourFirstClue(WidgetTester tester) async {
  await _openTutorialClueSheet(tester);
  await _tapTutorialClueTarget(tester);
  expect(find.text('단서를 다시 열어 두 번째 단서를 확인해 보세요.'), findsOneWidget);
}

Future<void> _advanceLevelFourSecondClue(WidgetTester tester) async {
  await _openTutorialClueSheet(tester);
  await _tapTutorialClueTarget(tester);
}

Future<void> _tapTutorialClueTarget(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const Key('tutorial_target_cutout')),
    warnIfMissed: false,
  );
  await tester.pump(const Duration(milliseconds: 260));
  await tester.pump(AppDurations.clueBookHighlight);
  await tester.pump();
}

void _expectTutorialClosed(WidgetTester tester) {
  expect(find.byKey(const Key('tutorial_overlay_bounds')), findsNothing);
  expect(find.byKey(const Key('game_tutorial_route_overlay')), findsNothing);
}

void _expectTutorialCompleted(
  _TutorialGameFixture fixture,
  WidgetTester tester,
) {
  _expectTutorialClosed(tester);
  expect(fixture.learningController.tutorialCompleted, isTrue);
  expect(fixture.learningStore.saveCount, 1);
}

class _TutorialGameFixture {
  const _TutorialGameFixture({
    required this.generatorVersion,
    required this.learningController,
    required this.learningStore,
  });

  final int generatorVersion;
  final LearningProgressController learningController;
  final FakeLearningProgressStore learningStore;
}
