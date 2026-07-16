import 'package:booklogic/core/feedback/domain/game_sound_cue.dart';
import 'package:booklogic/core/feedback/sound/game_sound_player.dart';

class FakeGameSoundPlayer implements GameSoundPlayer {
  FakeGameSoundPlayer({this.playError});

  Object? playError;
  int initializeCount = 0;
  int stopAllCount = 0;
  int disposeCount = 0;
  final playedCues = <GameSoundCue>[];

  @override
  Future<void> initialize() async {
    initializeCount += 1;
  }

  @override
  Future<void> play(GameSoundCue cue) async {
    playedCues.add(cue);
    final error = playError;
    if (error != null) {
      throw StateError(error.toString());
    }
  }

  @override
  Future<void> stopAll() async {
    stopAllCount += 1;
  }

  @override
  Future<void> dispose() async {
    disposeCount += 1;
  }
}
