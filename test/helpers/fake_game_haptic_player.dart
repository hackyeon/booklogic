import 'package:booklogic/core/feedback/domain/game_haptic_cue.dart';
import 'package:booklogic/core/feedback/haptic/game_haptic_player.dart';

class FakeGameHapticPlayer implements GameHapticPlayer {
  FakeGameHapticPlayer({this.playError});

  Object? playError;
  final playedCues = <GameHapticCue>[];

  @override
  Future<void> play(GameHapticCue cue) async {
    playedCues.add(cue);
    final error = playError;
    if (error != null) {
      throw StateError(error.toString());
    }
  }
}
