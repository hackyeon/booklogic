import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:booklogic/core/progress/game_progress.dart';
import 'package:booklogic/core/progress/game_progress_controller.dart';
import 'package:booklogic/core/theme/app_colors.dart';
import 'package:booklogic/core/theme/app_theme.dart';
import 'package:booklogic/features/game/generator/generator_config.dart';
import 'package:booklogic/features/game/generator/stage_generator.dart';
import 'package:booklogic/features/game/presentation/game_screen.dart';
import 'package:booklogic/features/game/presentation/widgets/book_widget.dart';
import 'package:booklogic/features/game/tutorial/application/learning_progress_controller.dart';
import 'package:booklogic/features/game/tutorial/application/tutorial_solve_path_resolver.dart';
import 'package:booklogic/features/game/tutorial/domain/learning_progress.dart';
import 'package:booklogic/features/game/tutorial/presentation/tutorial_message_card.dart';

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
      expect(
        find.byKey(const Key('game_tutorial_route_overlay')),
        findsNothing,
      );
      expect(learningController.tutorialCompleted, isFalse);

      progressController.dispose();
      learningController.dispose();
    },
  );

  testWidgets('tutorial actions fit inside the card on a compact screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(580, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const generator = StageGenerator();
    const resolver = TutorialSolvePathResolver();
    final stage = generator.generate(level: 1, generatorVersion: 1);
    final target = resolver.resolveFirstSwap(stage)!;
    final progressController = _progressController();
    final learningController = LearningProgressController(
      store: FakeLearningProgressStore(progress: LearningProgress()),
    );
    addTearDown(progressController.dispose);
    addTearDown(learningController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
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

    await tester.tap(find.byKey(ValueKey(target.firstBookId)));
    await tester.pumpAndSettle();

    final cardRect = tester.getRect(find.byType(TutorialMessageCard));
    final skipRect = tester.getRect(
      find.byKey(const Key('tutorial_skip_button')),
    );
    final acknowledgeRect = tester.getRect(
      find.byKey(const Key('tutorial_acknowledge_button')),
    );

    expect(skipRect.bottom, lessThanOrEqualTo(cardRect.bottom));
    expect(acknowledgeRect.bottom, lessThanOrEqualTo(cardRect.bottom));
    expect(cardRect.bottom, lessThanOrEqualTo(800));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'tutorial route overlay dims system insets, header, and status bar',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpTutorialGame(
        tester,
        mediaQueryData: const MediaQueryData(
          size: Size(390, 844),
          padding: EdgeInsets.only(top: 24, bottom: 34),
          viewPadding: EdgeInsets.only(top: 24, bottom: 34),
        ),
      );

      final routeStackFinder = find.byKey(const Key('game_screen_route_stack'));
      final overlayFinder = find.byKey(const Key('tutorial_overlay_bounds'));
      final headerFinder = find.byKey(const Key('game_header'));
      final statusBarFinder = find.byKey(const Key('game_status_bar'));
      final cutoutFinder = find.byKey(const Key('tutorial_target_cutout'));

      expect(find.byKey(const Key('game_tutorial_route_overlay')), findsOne);
      expect(overlayFinder, findsOne);
      expect(cutoutFinder, findsOne);
      expect(find.byType(TutorialMessageCard), findsOne);
      expect(
        tester
            .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
              find.byKey(const Key('game_system_ui_style')),
            )
            .value,
        AppTheme.tutorialSystemUiOverlayStyle,
      );

      final routeRect = tester.getRect(routeStackFinder);
      final overlayRect = tester.getRect(overlayFinder);
      final headerRect = tester.getRect(headerFinder);
      final statusBarRect = tester.getRect(statusBarFinder);
      final cutoutRect = tester.getRect(cutoutFinder);
      final messageRect = tester.getRect(find.byType(TutorialMessageCard));
      final scrimRects = tester
          .widgetList<ColoredBox>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is ColoredBox &&
                  widget.color == AppColors.tutorialScrim,
            ),
          )
          .map((widget) => tester.getRect(find.byWidget(widget)))
          .toList(growable: false);

      expect(overlayRect, routeRect);
      expect(
        scrimRects.any((rect) => rect.contains(const Offset(12, 12))),
        isTrue,
      );
      expect(
        scrimRects.any((rect) => rect.contains(headerRect.center)),
        isTrue,
      );
      expect(
        scrimRects.any((rect) => rect.contains(statusBarRect.center)),
        isTrue,
      );
      expect(
        scrimRects.any((rect) => rect.contains(cutoutRect.center)),
        isFalse,
      );
      expect(messageRect.top, greaterThanOrEqualTo(routeRect.top + 24));
      expect(messageRect.bottom, lessThanOrEqualTo(routeRect.bottom - 34));

      final routeStack = tester.widget<Stack>(routeStackFinder);
      expect(routeStack.children.first, isA<Scaffold>());
      expect(
        routeStack.children.last.key,
        const Key('game_tutorial_route_overlay'),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('tutorial skip and lifecycle resume leave no duplicate overlay', (
    tester,
  ) async {
    await _pumpTutorialGame(tester);

    expect(find.byKey(const Key('game_tutorial_route_overlay')), findsOne);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(find.byKey(const Key('game_tutorial_route_overlay')), findsOne);
    expect(find.byType(TutorialMessageCard), findsOne);
    expect(find.byKey(const Key('tutorial_target_cutout')), findsOne);

    await tester.tap(find.byKey(const Key('tutorial_skip_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('건너뛰기'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('game_tutorial_route_overlay')), findsNothing);
    expect(find.byType(TutorialMessageCard), findsNothing);
    expect(find.byKey(const Key('tutorial_target_cutout')), findsNothing);
    expect(
      tester
          .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.byKey(const Key('game_system_ui_style')),
          )
          .value,
      AppTheme.systemUiOverlayStyle,
    );
  });

  testWidgets('disposing GameScreen leaves no tutorial overlay', (
    tester,
  ) async {
    await _pumpTutorialGame(tester);
    expect(find.byKey(const Key('game_tutorial_route_overlay')), findsOne);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();

    expect(find.byKey(const Key('game_tutorial_route_overlay')), findsNothing);
    expect(find.byKey(const Key('tutorial_overlay_bounds')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpTutorialGame(
  WidgetTester tester, {
  MediaQueryData? mediaQueryData,
}) async {
  final progressController = _progressController();
  final learningController = LearningProgressController(
    store: FakeLearningProgressStore(progress: LearningProgress()),
  );
  addTearDown(progressController.dispose);
  addTearDown(learningController.dispose);

  final game = GameScreen(
    level: 1,
    generatorVersion: GeneratorConfig.currentVersion,
    progressController: progressController,
    stageGenerator: const StageGenerator(),
    learningProgressController: learningController,
    enableTutorial: true,
  );

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: mediaQueryData == null
          ? game
          : MediaQuery(data: mediaQueryData, child: game),
    ),
  );
  await tester.pumpAndSettle();
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
