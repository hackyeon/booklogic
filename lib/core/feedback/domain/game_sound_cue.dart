enum GameSoundCue { bookSelect, bookSwap, clueSatisfied, stageClear }

extension GameSoundCueCode on GameSoundCue {
  String get code {
    return switch (this) {
      GameSoundCue.bookSelect => 'book_select',
      GameSoundCue.bookSwap => 'book_swap',
      GameSoundCue.clueSatisfied => 'clue_satisfied',
      GameSoundCue.stageClear => 'stage_clear',
    };
  }

  String get assetPath {
    return switch (this) {
      GameSoundCue.bookSelect => 'audio/sfx/book_select.wav',
      GameSoundCue.bookSwap => 'audio/sfx/book_swap.wav',
      GameSoundCue.clueSatisfied => 'audio/sfx/clue_satisfied.wav',
      GameSoundCue.stageClear => 'audio/sfx/stage_clear.wav',
    };
  }

  int get priority {
    return switch (this) {
      GameSoundCue.bookSelect => 1,
      GameSoundCue.bookSwap => 2,
      GameSoundCue.clueSatisfied => 3,
      GameSoundCue.stageClear => 4,
    };
  }
}
