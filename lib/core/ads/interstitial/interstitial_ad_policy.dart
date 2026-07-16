import '../../../features/game/generator/generator_version_policy.dart';

class InterstitialAdPolicy {
  const InterstitialAdPolicy({
    GeneratorVersionPolicy generatorVersionPolicy =
        const GeneratorVersionPolicy(),
  }) : _generatorVersionPolicy = generatorVersionPolicy;

  final GeneratorVersionPolicy _generatorVersionPolicy;

  bool shouldPreloadForLevel(int currentLevel) {
    if (currentLevel < 6) {
      return false;
    }
    try {
      _generatorVersionPolicy.versionForLevel(currentLevel + 1);
      return true;
    } on UnsupportedError {
      return false;
    } on ArgumentError {
      return false;
    }
  }

  bool shouldAttemptBeforeNextLevel({
    required int completedLevel,
    required int nextLevel,
  }) {
    if (completedLevel < 6 || nextLevel != completedLevel + 1) {
      return false;
    }
    try {
      _generatorVersionPolicy.versionForLevel(nextLevel);
      return true;
    } on UnsupportedError {
      return false;
    } on ArgumentError {
      return false;
    }
  }
}
