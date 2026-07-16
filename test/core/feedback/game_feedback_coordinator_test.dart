import 'package:flutter_test/flutter_test.dart';

import 'package:booklogic/core/feedback/application/app_feedback_settings_controller.dart';
import 'package:booklogic/core/feedback/application/game_feedback_coordinator.dart';
import 'package:booklogic/core/feedback/domain/app_feedback_settings.dart';
import 'package:booklogic/core/feedback/domain/game_haptic_cue.dart';
import 'package:booklogic/core/feedback/domain/game_sound_cue.dart';
import 'package:booklogic/features/game/application/game_controller.dart';
import 'package:booklogic/features/game/domain/book.dart';
import 'package:booklogic/features/game/domain/book_placement.dart';
import 'package:booklogic/features/game/domain/book_position.dart';
import 'package:booklogic/features/game/domain/clue.dart';
import 'package:booklogic/features/game/domain/book_selector.dart';

import '../../helpers/fake_app_feedback_settings_store.dart';
import '../../helpers/fake_game_haptic_player.dart';
import '../../helpers/fake_game_sound_player.dart';

void main() {
  test('maps events to sound and haptic cues using current settings', () async {
    final settingsStore = FakeAppFeedbackSettingsStore();
    final settingsController = AppFeedbackSettingsController(
      store: settingsStore,
    );
    await settingsController.initialize();
    final soundPlayer = FakeGameSoundPlayer();
    final hapticPlayer = FakeGameHapticPlayer();
    final controller = _selectionController();
    final coordinator = GameFeedbackCoordinator(
      settingsController: settingsController,
      soundPlayer: soundPlayer,
      hapticPlayer: hapticPlayer,
    )..attach(controller);

    controller.handleBookTap('blue_moon');
    await Future<void>.delayed(Duration.zero);

    expect(soundPlayer.playedCues, [GameSoundCue.bookSelect]);
    expect(hapticPlayer.playedCues, [GameHapticCue.bookSelect]);

    settingsController.setSoundEnabled(false);
    await Future<void>.delayed(Duration.zero);
    controller.handleBookTap('red_star');
    await Future<void>.delayed(Duration.zero);

    expect(soundPlayer.playedCues, [GameSoundCue.bookSelect]);
    expect(hapticPlayer.playedCues.last, GameHapticCue.bookSwap);

    await coordinator.dispose();
    controller.dispose();
    settingsController.dispose();
  });

  test('isolates sound and haptic errors from each other', () async {
    final settingsController = AppFeedbackSettingsController(
      store: FakeAppFeedbackSettingsStore(
        settings: AppFeedbackSettings.defaults,
      ),
    );
    await settingsController.initialize();
    final soundPlayer = FakeGameSoundPlayer(playError: 'sound failed');
    final hapticPlayer = FakeGameHapticPlayer(playError: 'haptic failed');
    final controller = _selectionController();
    final coordinator = GameFeedbackCoordinator(
      settingsController: settingsController,
      soundPlayer: soundPlayer,
      hapticPlayer: hapticPlayer,
    )..attach(controller);

    controller.handleBookTap('blue_moon');
    await Future<void>.delayed(Duration.zero);

    expect(controller.selectedBookId, 'blue_moon');
    expect(soundPlayer.playedCues, [GameSoundCue.bookSelect]);
    expect(hapticPlayer.playedCues, [GameHapticCue.bookSelect]);

    await coordinator.dispose();
    controller.dispose();
    settingsController.dispose();
  });
}

GameController _selectionController() {
  return GameController(
    initialPlacements: const [
      BookPlacement(
        book: Book(
          id: 'blue_moon',
          color: BookColor.blue,
          symbol: BookSymbol.moon,
        ),
        position: BookPosition(tierIndex: 0, slotIndex: 0),
      ),
      BookPlacement(
        book: Book(
          id: 'red_star',
          color: BookColor.red,
          symbol: BookSymbol.star,
        ),
        position: BookPosition(tierIndex: 0, slotIndex: 1),
      ),
    ],
    clues: const [
      EdgePositionClue(
        id: 'never_clear',
        subject: BookIdSelector(bookId: 'red_star'),
        tierIndex: 0,
        edge: ShelfEdge.left,
      ),
    ],
    swapDuration: Duration(milliseconds: 1),
  );
}
