import '../domain/game_sound_cue.dart';

abstract interface class GameSoundPlayer {
  Future<void> initialize();

  Future<void> play(GameSoundCue cue);

  Future<void> stopAll();

  Future<void> dispose();
}
