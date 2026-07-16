import 'dart:async';

import '../../../features/game/application/game_controller.dart';
import '../domain/game_feedback_event.dart';
import '../domain/game_haptic_cue.dart';
import '../domain/game_sound_cue.dart';
import '../haptic/game_haptic_player.dart';
import '../sound/game_sound_player.dart';
import 'app_feedback_settings_controller.dart';

class GameFeedbackCoordinator {
  GameFeedbackCoordinator({
    required AppFeedbackSettingsController settingsController,
    required GameSoundPlayer soundPlayer,
    required GameHapticPlayer hapticPlayer,
  }) : _settingsController = settingsController,
       _soundPlayer = soundPlayer,
       _hapticPlayer = hapticPlayer;

  final AppFeedbackSettingsController _settingsController;
  final GameSoundPlayer _soundPlayer;
  final GameHapticPlayer _hapticPlayer;
  StreamSubscription<GameFeedbackEvent>? _subscription;
  GameController? _attachedController;
  bool _isDisposed = false;
  int _attachRevision = 0;

  void attach(GameController controller) {
    if (_isDisposed) {
      return;
    }
    if (identical(_attachedController, controller)) {
      return;
    }
    _subscription?.cancel();
    _attachRevision += 1;
    final revision = _attachRevision;
    _attachedController = controller;
    _subscription = controller.feedbackEvents.listen((event) {
      if (_isDisposed ||
          revision != _attachRevision ||
          !identical(_attachedController, controller)) {
        return;
      }
      _handleEvent(event);
    });
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _attachedController = null;
    _attachRevision += 1;
    await _runSafely(_soundPlayer.stopAll);
  }

  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    await stop();
  }

  void _handleEvent(GameFeedbackEvent event) {
    final soundCue = _soundCueFor(event);
    final hapticCue = _hapticCueFor(event);

    if (_settingsController.soundEnabled) {
      unawaited(_runSafely(() => _soundPlayer.play(soundCue)));
    }
    if (_settingsController.hapticEnabled) {
      unawaited(_runSafely(() => _hapticPlayer.play(hapticCue)));
    }
  }

  GameSoundCue _soundCueFor(GameFeedbackEvent event) {
    return switch (event.type) {
      GameFeedbackEventType.bookSelected => GameSoundCue.bookSelect,
      GameFeedbackEventType.booksSwapped => GameSoundCue.bookSwap,
      GameFeedbackEventType.cluesNewlySatisfied => GameSoundCue.clueSatisfied,
      GameFeedbackEventType.stageCleared => GameSoundCue.stageClear,
    };
  }

  GameHapticCue _hapticCueFor(GameFeedbackEvent event) {
    return switch (event.type) {
      GameFeedbackEventType.bookSelected => GameHapticCue.bookSelect,
      GameFeedbackEventType.booksSwapped => GameHapticCue.bookSwap,
      GameFeedbackEventType.cluesNewlySatisfied => GameHapticCue.clueSatisfied,
      GameFeedbackEventType.stageCleared => GameHapticCue.stageClear,
    };
  }

  Future<void> _runSafely(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Feedback is best-effort; gameplay must never wait for or fail because
      // of a platform sound/haptic error.
    }
  }
}
