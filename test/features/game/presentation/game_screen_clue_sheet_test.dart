import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:booklogic/core/constants/app_durations.dart';
import 'package:booklogic/core/progress/game_progress.dart';
import 'package:booklogic/core/progress/game_progress_controller.dart';
import 'package:booklogic/core/theme/app_theme.dart';
import 'package:booklogic/features/game/domain/book_placement.dart';
import 'package:booklogic/features/game/domain/book_position.dart';
import 'package:booklogic/features/game/domain/clue_evaluator.dart';
import 'package:booklogic/features/game/generator/generated_stage.dart';
import 'package:booklogic/features/game/generator/generator_version_policy.dart';
import 'package:booklogic/features/game/generator/stage_generator.dart';
import 'package:booklogic/features/game/presentation/game_screen.dart';
import 'package:booklogic/features/game/presentation/widgets/book_widget.dart';
import 'package:booklogic/features/game/presentation/widgets/clue_card_widget.dart';
import 'package:booklogic/features/game/tutorial/application/clue_book_reference_resolver.dart';
import 'package:booklogic/features/game/tutorial/application/learning_progress_controller.dart';
import 'package:booklogic/features/game/tutorial/application/tutorial_plan_factory.dart';
import 'package:booklogic/features/game/tutorial/domain/learning_progress.dart';
import 'package:booklogic/features/game/tutorial/domain/tutorial_step_type.dart';

import '../../../helpers/fake_game_progress_store.dart';
import '../../../helpers/fake_learning_progress_store.dart';

void main() {
  testWidgets('main game screen is fixed and opens clues in a bottom sheet', (
    tester,
  ) async {
    await _pumpGame(tester, level: 51);

    expect(find.byKey(const Key('game_status_bar')), findsOneWidget);
    expect(find.byKey(const Key('clue_summary_button')), findsOneWidget);
    expect(find.byKey(const Key('clue_bottom_sheet')), findsNothing);
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.byType(ListView), findsNothing);
    expect(find.byType(CustomScrollView), findsNothing);
    expect(find.byType(NestedScrollView), findsNothing);

    final orderBeforeSheet = _visibleBookGridOrder(tester, _stageBookIds(51));
    await _openClueSheet(tester);

    expect(find.byKey(const Key('clue_bottom_sheet')), findsOneWidget);
    expect(find.byKey(const Key('clue_bottom_sheet_list')), findsOneWidget);
    expect(find.byType(ClueCardWidget), findsNWidgets(_stage(51).clueCount));
    expect(find.byType(ListView), findsOneWidget);
    expect(_visibleBookGridOrder(tester, _stageBookIds(51)), orderBeforeSheet);
    expect(find.text('교환 0회'), findsOneWidget);

    await _closeClueSheet(tester);
    expect(find.byKey(const Key('clue_bottom_sheet')), findsNothing);
    expect(_visibleBookGridOrder(tester, _stageBookIds(51)), orderBeforeSheet);
    expect(find.text('교환 0회'), findsOneWidget);
  });

  testWidgets('game chrome uses a HUD header and keeps restart in status bar', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpGame(tester, level: 1);

    final header = find.byKey(const Key('game_header'));
    final statusBar = find.byKey(const Key('game_status_bar'));
    final restart = find.byKey(const Key('game_restart_button'));

    expect(find.byType(AppBar), findsNothing);
    expect(find.byKey(const Key('game_back_button')), findsOneWidget);
    expect(find.byKey(const Key('game_level_label')), findsOneWidget);
    expect(find.byKey(const Key('game_settings_button')), findsOneWidget);
    expect(find.descendant(of: header, matching: restart), findsNothing);
    expect(find.descendant(of: statusBar, matching: restart), findsOneWidget);
    expect(find.bySemanticsLabel('뒤로 가기'), findsOneWidget);
    expect(find.bySemanticsLabel('레벨 1'), findsOneWidget);
    expect(find.bySemanticsLabel('설정'), findsOneWidget);
    expect(find.bySemanticsLabel('현재 레벨 다시 시작'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets(
    'clue tap closes the sheet before starting 800ms book highlight',
    (tester) async {
      final stage = _stage(1);
      final clue = stage.clues.first;
      final highlightedBookIds = const ClueBookReferenceResolver()
          .resolveBookIds(clue: clue, placements: stage.initialPlacements);

      await _pumpGame(tester, level: 1);
      await _openClueSheet(tester);

      await tester.tap(find.byKey(Key('clue_${clue.id}')));
      await tester.pump();
      for (final bookId in highlightedBookIds) {
        expect(_bookWidget(tester, bookId).isClueHighlighted, isFalse);
      }

      await tester.pump(const Duration(milliseconds: 260));
      await tester.pump();
      expect(find.byKey(const Key('clue_bottom_sheet')), findsNothing);
      for (final bookId in highlightedBookIds) {
        expect(_bookWidget(tester, bookId).isClueHighlighted, isTrue);
      }

      await tester.pump(const Duration(milliseconds: 770));
      for (final bookId in highlightedBookIds) {
        expect(_bookWidget(tester, bookId).isClueHighlighted, isTrue);
      }

      await tester.pump(const Duration(milliseconds: 40));
      await tester.pump();
      for (final bookId in highlightedBookIds) {
        expect(_bookWidget(tester, bookId).isClueHighlighted, isFalse);
      }
    },
  );

  testWidgets('clue summary count follows current clue satisfaction', (
    tester,
  ) async {
    final stage = _stage(1);
    await _pumpGame(tester, level: 1);

    _expectSummaryForStage(tester, stage, stage.initialPlacements);

    var placements = List<BookPlacement>.of(stage.initialPlacements);
    final reverseSteps = stage.swapHistory.reversed.toList();
    for (var index = 0; index < reverseSteps.length; index += 1) {
      final step = reverseSteps[index];
      final firstBookId = _bookIdAtPosition(placements, step.firstPosition);
      final secondBookId = _bookIdAtPosition(placements, step.secondPosition);

      await tester.tap(find.byKey(Key('book_$firstBookId')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('book_$secondBookId')));
      await tester.pump();
      await tester.pump(AppDurations.bookSwap);
      await tester.pump();

      placements = _swapPlacementBooks(
        placements,
        step.firstPosition,
        step.secondPosition,
      );
      _expectSummaryForStage(tester, stage, placements);
      if (index == reverseSteps.length - 1) {
        expect(find.byKey(const Key('clear_result_overlay')), findsNothing);
      }
    }
  });

  testWidgets('small screens keep every representative bookshelf fixed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final level in [1, 21, 51, 101, 201, 281, 400]) {
      await _pumpGame(tester, level: level);

      expect(find.byKey(const Key('game_status_bar')), findsOneWidget);
      expect(find.byKey(const Key('clue_summary_button')), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(find.byType(ListView), findsNothing);
      for (
        var tierIndex = 0;
        tierIndex < _stage(level).tierCount;
        tierIndex++
      ) {
        expect(find.byKey(Key('bookshelf_tier_$tierIndex')), findsOneWidget);
        expect(find.byKey(Key('bookshelf_plank_$tierIndex')), findsOneWidget);
      }
      _expectBooksRestOnShelves(tester, _stage(level));
      _expectBooksStayAboveStatusBar(tester, _stageBookIds(level));
      expect(tester.takeException(), isNull, reason: 'Level $level');
    }
  });

  testWidgets('representative shelves fit common phone sizes', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final size in [const Size(390, 844), const Size(430, 932)]) {
      tester.view.physicalSize = size;
      for (final level in [1, 51, 201, 281, 400]) {
        await _pumpGame(tester, level: level);
        _expectBooksRestOnShelves(tester, _stage(level));
        _expectBooksStayAboveStatusBar(tester, _stageBookIds(level));
        expect(tester.takeException(), isNull, reason: '$size Level $level');
      }
    }
  });

  testWidgets('game HUD and shelves support large text without scrolling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final textScale in [1.0, 1.3, 2.0]) {
      await _pumpGame(tester, level: 400, textScale: textScale);
      expect(find.byType(SingleChildScrollView), findsNothing);
      _expectBooksRestOnShelves(tester, _stage(400));
      _expectBooksStayAboveStatusBar(tester, _stageBookIds(400));
      expect(tester.takeException(), isNull, reason: 'scale $textScale');
    }
  });

  testWidgets('large text keeps main fixed and bottom sheet scrollable', (
    tester,
  ) async {
    await _pumpGame(tester, level: 400, textScale: 2);

    expect(find.byKey(const Key('game_status_bar')), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.byType(ListView), findsNothing);

    await _openClueSheet(tester);

    expect(find.byKey(const Key('clue_bottom_sheet')), findsOneWidget);
    expect(find.byKey(const Key('clue_bottom_sheet_list')), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clue summary exposes accessibility semantics', (tester) async {
    final semantics = tester.ensureSemantics();

    await _pumpGame(tester, level: 1);

    final summarySemantics = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .map((widget) => widget.properties)
        .where((properties) => properties.label == '단서')
        .single;
    expect(summarySemantics.value, '3개 중 0개 만족');
    expect(summarySemantics.hint, '두 번 탭하여 단서 목록을 엽니다.');
    semantics.dispose();
  });

  testWidgets('Level 3 tutorial opens the sheet before clue-card highlight', (
    tester,
  ) async {
    final stage = _stage(3);
    final clueStep = const TutorialPlanFactory()
        .create(stage: stage)!
        .steps
        .singleWhere((step) => step.type == TutorialStepType.tapClueCard);
    final targetClueId = clueStep.expectedClueId!;
    final wrongClueId = stage.clues
        .map((clue) => clue.id)
        .firstWhere((id) => id != targetClueId);

    await _pumpGame(tester, level: 3, enableTutorial: true);

    expect(find.text('단서를 눌러 단서 목록을 확인해 보세요.'), findsOneWidget);
    await _openClueSheet(tester);

    expect(find.byKey(const Key('clue_bottom_sheet')), findsOneWidget);
    expect(find.text('단서 카드를 눌러 관련 책을 확인해 보세요.'), findsOneWidget);
    expect(find.byKey(const Key('game_tutorial_route_overlay')), findsNothing);
    expect(find.byKey(const Key('tutorial_overlay_bounds')), findsOneWidget);
    expect(find.byKey(const Key('tutorial_target_cutout')), findsOneWidget);

    await tester.tap(find.byKey(Key('clue_$wrongClueId')), warnIfMissed: false);
    await tester.pump();
    expect(find.byKey(const Key('clue_bottom_sheet')), findsOneWidget);
    expect(find.text('교환 0회'), findsOneWidget);

    await _closeClueSheet(tester);
    expect(find.text('단서를 눌러 단서 목록을 확인해 보세요.'), findsOneWidget);
    await _openClueSheet(tester);
    expect(find.text('단서 카드를 눌러 관련 책을 확인해 보세요.'), findsOneWidget);
    final targetFinder = find.byKey(Key('clue_$targetClueId'));
    await tester.ensureVisible(targetFinder);
    await tester.pumpAndSettle();
    await tester.tap(targetFinder);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(
      find.byKey(const Key('clue_bottom_sheet')).hitTestable(),
      findsNothing,
    );
    expect(find.text('교환 0회'), findsOneWidget);

    await tester.pump(AppDurations.clueBookHighlight);
    await tester.pump();
    expect(
      find.text('단서가 가리키는 책이 잠시 강조됩니다. 만족한 단서는 체크 표시로 바뀝니다.'),
      findsOneWidget,
    );
  });

  testWidgets('Level 4 tutorial reopens the sheet for the second clue', (
    tester,
  ) async {
    final stage = _stage(4);
    final clueSteps = const TutorialPlanFactory()
        .create(stage: stage)!
        .steps
        .where((step) => step.type == TutorialStepType.tapClueCard)
        .toList(growable: false);
    expect(
      clueSteps.first.expectedClueId,
      isNot(clueSteps.last.expectedClueId),
    );

    await _pumpGame(tester, level: 4, enableTutorial: true);

    expect(find.text('단서를 눌러 첫 번째 단서를 확인해 보세요.'), findsOneWidget);
    await _openClueSheet(tester);
    await tester.tap(find.byKey(Key('clue_${clueSteps.first.expectedClueId}')));
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pump(AppDurations.clueBookHighlight);
    await tester.pump();

    expect(find.text('단서를 다시 열어 두 번째 단서를 확인해 보세요.'), findsOneWidget);
    await _openClueSheet(tester);
    expect(find.byKey(const Key('clue_bottom_sheet')), findsOneWidget);
    expect(find.text('이제 두 번째 단서도 확인해 보세요.'), findsOneWidget);
  });

  testWidgets('tutorial clue sheet dismiss returns safely to summary step', (
    tester,
  ) async {
    await _pumpGame(tester, level: 3, enableTutorial: true);
    await _openClueSheet(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('clue_bottom_sheet')), findsNothing);
    expect(find.text('단서를 눌러 단서 목록을 확인해 보세요.'), findsOneWidget);

    await _openClueSheet(tester);
    expect(find.byKey(const Key('clue_bottom_sheet')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpGame(
  WidgetTester tester, {
  required int level,
  bool enableTutorial = false,
  double textScale = 1,
}) async {
  final generatorVersion = const GeneratorVersionPolicy().versionForLevel(
    level,
  );
  final progressController = _progressController(
    level: level,
    generatorVersion: generatorVersion,
  );
  final learningController = LearningProgressController(
    store: FakeLearningProgressStore(progress: LearningProgress()),
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: GameScreen(
          level: level,
          generatorVersion: generatorVersion,
          progressController: progressController,
          learningProgressController: learningController,
          enableTutorial: enableTutorial,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectBooksRestOnShelves(WidgetTester tester, GeneratedStage stage) {
  for (final placement in stage.initialPlacements) {
    final bookRect = tester.getRect(
      find.byKey(Key('book_${placement.book.id}')),
    );
    final plankRect = tester.getRect(
      find.byKey(Key('bookshelf_plank_${placement.position.tierIndex}')),
    );
    expect(
      (bookRect.bottom - plankRect.top).abs(),
      lessThanOrEqualTo(1),
      reason: placement.book.id,
    );
  }
}

GameProgressController _progressController({
  required int level,
  required int generatorVersion,
}) {
  final controller = GameProgressController(
    store: FakeGameProgressStore(
      progress: GameProgress(
        schemaVersion: GameProgress.currentSchemaVersion,
        currentLevel: level,
        highestUnlockedLevel: level,
        generatorVersion: generatorVersion,
      ),
    ),
  );
  controller.load();
  return controller;
}

Future<void> _openClueSheet(WidgetTester tester) async {
  final summaryButton = find.byKey(const Key('clue_summary_button'));
  final summaryText = find.descendant(
    of: summaryButton,
    matching: find.textContaining('단서 '),
  );
  if (summaryText.evaluate().isNotEmpty) {
    await tester.tap(summaryText.first, warnIfMissed: false);
  } else {
    await tester.tap(summaryButton, warnIfMissed: false);
  }
  await tester.pumpAndSettle();
}

Future<void> _closeClueSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('clue_bottom_sheet_close_button')));
  await tester.pumpAndSettle();
}

GeneratedStage _stage(int level) {
  final generatorVersion = const GeneratorVersionPolicy().versionForLevel(
    level,
  );
  return const StageGenerator().generate(
    level: level,
    generatorVersion: generatorVersion,
  );
}

List<String> _stageBookIds(int level) {
  return _bookIdsBySlot(_stage(level).initialPlacements);
}

List<String> _bookIdsBySlot(List<BookPlacement> placements) {
  final sorted = List<BookPlacement>.of(placements)
    ..sort((left, right) {
      final tierComparison = left.position.tierIndex.compareTo(
        right.position.tierIndex,
      );
      if (tierComparison != 0) {
        return tierComparison;
      }
      return left.position.slotIndex.compareTo(right.position.slotIndex);
    });
  return [for (final placement in sorted) placement.book.id];
}

List<String> _visibleBookGridOrder(WidgetTester tester, List<String> bookIds) {
  final rects =
      [
        for (final bookId in bookIds)
          MapEntry(bookId, tester.getRect(find.byKey(Key('book_$bookId')))),
      ]..sort((left, right) {
        final topComparison = left.value.top.compareTo(right.value.top);
        if (topComparison != 0) {
          return topComparison;
        }
        return left.value.left.compareTo(right.value.left);
      });
  return [for (final entry in rects) entry.key];
}

void _expectBooksStayAboveStatusBar(WidgetTester tester, List<String> bookIds) {
  final statusBarTop = tester
      .getRect(find.byKey(const Key('game_status_bar')))
      .top;
  for (final bookId in bookIds) {
    expect(
      tester.getRect(find.byKey(Key('book_$bookId'))).bottom,
      lessThan(statusBarTop),
      reason: bookId,
    );
  }
}

BookWidget _bookWidget(WidgetTester tester, String bookId) {
  return tester.widget<BookWidget>(find.byKey(ValueKey(bookId)));
}

void _expectSummaryForStage(
  WidgetTester tester,
  GeneratedStage stage,
  List<BookPlacement> placements,
) {
  final satisfiedIds = const ClueEvaluator().evaluateAll(
    clues: stage.clues,
    placements: placements,
  );
  expect(
    find.text('단서 ${satisfiedIds.length}/${stage.clueCount}'),
    findsOneWidget,
  );
}

String _bookIdAtPosition(
  List<BookPlacement> placements,
  BookPosition position,
) {
  return placements
      .singleWhere((placement) => placement.position == position)
      .book
      .id;
}

List<BookPlacement> _swapPlacementBooks(
  List<BookPlacement> placements,
  BookPosition first,
  BookPosition second,
) {
  final firstBook = placements
      .singleWhere((placement) => placement.position == first)
      .book;
  final secondBook = placements
      .singleWhere((placement) => placement.position == second)
      .book;
  return [
    for (final placement in placements)
      if (placement.position == first)
        placement.copyWith(book: secondBook)
      else if (placement.position == second)
        placement.copyWith(book: firstBook)
      else
        placement,
  ];
}
