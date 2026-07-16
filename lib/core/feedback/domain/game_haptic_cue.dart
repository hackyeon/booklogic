enum GameHapticCue { bookSelect, bookSwap, clueSatisfied, stageClear }

extension GameHapticCueCode on GameHapticCue {
  String get code {
    return switch (this) {
      GameHapticCue.bookSelect => 'book_select',
      GameHapticCue.bookSwap => 'book_swap',
      GameHapticCue.clueSatisfied => 'clue_satisfied',
      GameHapticCue.stageClear => 'stage_clear',
    };
  }
}
