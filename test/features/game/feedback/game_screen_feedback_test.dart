import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:booklogic/core/feedback/application/app_feedback_settings_controller.dart';
import 'package:booklogic/core/feedback/domain/app_feedback_settings.dart';
import 'package:booklogic/core/feedback/domain/game_haptic_cue.dart';
import 'package:booklogic/core/feedback/domain/game_sound_cue.dart';
import 'package:booklogic/core/progress/game_progress.dart';
import 'package:booklogic/core/progress/game_progress_controller.dart';
import 'package:booklogic/features/game/generator/generator_config.dart';
import 'package:booklogic/features/game/generator/stage_generator.dart';
import 'package:booklogic/features/game/presentation/game_screen.dart';

import '../../../helpers/fake_app_feedback_settings_store.dart';
import '../../../helpers/fake_game_haptic_player.dart';
import '../../../helpers/fake_game_progress_store.dart';
import '../../../helpers/fake_game_sound_player.dart';

void main() {
  testWidgets('GameScreen uses the current feedback settings for new events', (
    tester,
  ) async {
    const generator = StageGenerator();
    final stage = generator.generate(level: 1, generatorVersion: 1);
    final firstBookId = stage.initialPlacements.first.book.id;
    final secondBookId = stage.initialPlacements[1].book.id;
    final progressController = GameProgressController(
      store: FakeGameProgressStore(
        progress: GameProgress(
          schemaVersion: GameProgress.currentSchemaVersion,
          currentLevel: 1,
          highestUnlockedLevel: 1,
          generatorVersion: GeneratorConfig.currentVersion,
        ),
      ),
    );
    await progressController.load();
    final feedbackController = AppFeedbackSettingsController(
      store: FakeAppFeedbackSettingsStore(
        settings: const AppFeedbackSettings(
          soundEnabled: false,
          hapticEnabled: false,
        ),
      ),
    );
    await feedbackController.initialize();
    final soundPlayer = FakeGameSoundPlayer();
    final hapticPlayer = FakeGameHapticPlayer();

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          progressController: progressController,
          stageGenerator: generator,
          feedbackSettingsController: feedbackController,
          soundPlayer: soundPlayer,
          hapticPlayer: hapticPlayer,
        ),
      ),
    );

    await tester.tap(find.byKey(ValueKey(firstBookId)));
    await tester.pump();
    expect(soundPlayer.playedCues, isEmpty);
    expect(hapticPlayer.playedCues, isEmpty);

    feedbackController
      ..setSoundEnabled(true)
      ..setHapticEnabled(true);
    await tester.pump();
    await tester.tap(find.byKey(ValueKey(firstBookId)));
    await tester.pump();
    await tester.tap(find.byKey(ValueKey(secondBookId)));
    await tester.pump();

    expect(soundPlayer.playedCues, [GameSoundCue.bookSelect]);
    expect(hapticPlayer.playedCues, [GameHapticCue.bookSelect]);

    progressController.dispose();
    feedbackController.dispose();
  });
}
