import 'package:booklogic/app/app.dart';
import 'package:booklogic/core/ads/config/ad_runtime_config.dart';
import 'package:booklogic/core/constants/app_durations.dart';
import 'package:booklogic/features/game/domain/book_placement.dart';
import 'package:booklogic/features/game/domain/book_position.dart';
import 'package:booklogic/features/game/generator/generated_stage.dart';
import 'package:booklogic/features/game/generator/stage_generator.dart';
import 'package:booklogic/features/game/tutorial/domain/learning_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/helpers/fake_ad_services.dart';
import '../test/helpers/fake_app_feedback_settings_store.dart';
import '../test/helpers/fake_game_haptic_player.dart';
import '../test/helpers/fake_game_progress_store.dart';
import '../test/helpers/fake_game_sound_player.dart';
import '../test/helpers/fake_learning_progress_store.dart';

void main() {
  testWidgets(
    'release smoke flow uses fake services and restores saved level',
    (tester) async {
      final progressStore = FakeGameProgressStore();
      final learningStore = FakeLearningProgressStore(
        progress: LearningProgress(),
      );

      await tester.pumpWidget(
        BookLogicApp(
          progressStore: progressStore,
          learningProgressStore: learningStore,
          feedbackSettingsStore: FakeAppFeedbackSettingsStore(),
          adRuntimeConfig: const AdRuntimeConfig(
            isTestMode: true,
            adsEnabled: false,
          ),
          adConsentService: FakeAdConsentService(),
          mobileAdsInitializer: FakeMobileAdsInitializer(),
          interstitialAdGateway: FakeInterstitialAdGateway(),
          soundPlayer: FakeGameSoundPlayer(),
          hapticPlayer: FakeGameHapticPlayer(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home_continue_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('home_continue_button')));
      await tester.pumpAndSettle();

      expect(find.text('Level 1'), findsOneWidget);
      expect(find.byKey(const Key('tutorial_skip_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('tutorial_skip_button')));
      await tester.pumpAndSettle();

      await _clearGeneratedStageByReverseSwaps(
        tester,
        stage: const StageGenerator().generate(level: 1, generatorVersion: 1),
      );

      expect(find.byKey(const Key('clear_result_overlay')), findsOneWidget);

      await tester.tap(find.byKey(const Key('clear_retry_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('clear_result_overlay')), findsNothing);
      expect(find.text('Level 1'), findsOneWidget);

      await _clearGeneratedStageByReverseSwaps(
        tester,
        stage: const StageGenerator().generate(level: 1, generatorVersion: 1),
      );
      await tester.tap(find.byKey(const Key('clear_next_level_button')));
      await tester.pumpAndSettle();

      expect(find.text('Level 2'), findsOneWidget);
      expect(progressStore.lastWrite?.currentLevel, 2);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('계속하기 · Level 2'), findsOneWidget);

      await tester.tap(find.byKey(const Key('home_continue_button')));
      await tester.pumpAndSettle();
      expect(find.text('Level 2'), findsOneWidget);
    },
  );
}

Future<void> _clearGeneratedStageByReverseSwaps(
  WidgetTester tester, {
  required GeneratedStage stage,
}) async {
  var placements = List<BookPlacement>.of(stage.initialPlacements);
  final reverseSteps = stage.swapHistory.reversed.toList();

  for (var index = 0; index < reverseSteps.length; index += 1) {
    final step = reverseSteps[index];
    final firstBookId = _bookIdAtPosition(placements, step.firstPosition);
    final secondBookId = _bookIdAtPosition(placements, step.secondPosition);

    await tester.tap(find.byKey(Key('book_$firstBookId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('book_$secondBookId')));
    await _finishSwap(tester);

    placements = _swapPlacementBooks(
      placements,
      step.firstPosition,
      step.secondPosition,
    );
    if (index == reverseSteps.length - 1) {
      await _finishClear(tester, stage.totalBookCount);
    } else {
      await tester.pump(AppDurations.clueStateChange);
      await tester.pump();
    }
  }
}

Future<void> _finishSwap(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(AppDurations.bookSwap);
  await tester.pump();
}

Future<void> _finishClear(WidgetTester tester, int bookCount) async {
  await tester.pump(AppDurations.clueCompletionDelay);
  for (var index = 0; index < bookCount; index += 1) {
    await tester.pump(AppDurations.clearBookStep);
  }
  await tester.pump(AppDurations.clearFinalGlow);
  await tester.pump(AppDurations.resultOverlay);
  await tester.pump();
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
