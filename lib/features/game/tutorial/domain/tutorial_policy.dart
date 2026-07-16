class TutorialPolicy {
  const TutorialPolicy();

  bool isTutorialLevel(int level) {
    return level >= 1 && level <= 5;
  }

  bool shouldShowTutorial({
    required int level,
    required bool tutorialCompleted,
  }) {
    return isTutorialLevel(level) && !tutorialCompleted;
  }

  bool suppressInterstitialAd(int level) {
    return isTutorialLevel(level);
  }
}
