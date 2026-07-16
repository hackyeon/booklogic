import '../domain/game_haptic_cue.dart';

abstract interface class GameHapticPlayer {
  Future<void> play(GameHapticCue cue);
}
