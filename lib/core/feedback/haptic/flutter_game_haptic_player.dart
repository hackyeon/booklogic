import 'package:flutter/services.dart';

import '../domain/game_haptic_cue.dart';
import 'game_haptic_player.dart';

class FlutterGameHapticPlayer implements GameHapticPlayer {
  const FlutterGameHapticPlayer();

  @override
  Future<void> play(GameHapticCue cue) {
    return switch (cue) {
      GameHapticCue.bookSelect => HapticFeedback.selectionClick(),
      GameHapticCue.bookSwap => HapticFeedback.lightImpact(),
      GameHapticCue.clueSatisfied => HapticFeedback.selectionClick(),
      GameHapticCue.stageClear => HapticFeedback.mediumImpact(),
    };
  }
}
