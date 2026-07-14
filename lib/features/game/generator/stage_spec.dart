import 'difficulty_profile.dart';
import 'generator_config.dart';
import 'stage_generation_key.dart';
import 'stage_layout.dart';

class StageSpec {
  StageSpec({
    required this.generationKey,
    required this.seed,
    required this.profileId,
    required this.layout,
    required this.clueCount,
    required this.targetSwapCount,
    required this.duplicateGroupCount,
    required this.maxDuplicateCopies,
  }) : assert(generationKey.attempt == 0),
       assert(seed >= 0),
       assert(seed <= GeneratorConfig.uint32Mask),
       assert(clueCount >= 1),
       assert(targetSwapCount >= 1),
       assert(duplicateGroupCount >= 0),
       assert(maxDuplicateCopies >= 1),
       assert(maxDuplicateCopies <= 3),
       assert(duplicateGroupCount == 0 || maxDuplicateCopies >= 2),
       assert(layout.totalBookCount <= 18);

  final StageGenerationKey generationKey;
  final int seed;
  final DifficultyProfileId profileId;
  final StageLayout layout;
  final int clueCount;
  final int targetSwapCount;
  final int duplicateGroupCount;
  final int maxDuplicateCopies;

  int get level => generationKey.level;

  int get generatorVersion => generationKey.generatorVersion;

  int get tierCount => layout.tierCount;

  int get booksPerTier => layout.booksPerTier;

  int get totalBookCount => layout.totalBookCount;

  bool get hasDuplicates => duplicateGroupCount > 0;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is StageSpec &&
            other.generationKey == generationKey &&
            other.seed == seed &&
            other.profileId == profileId &&
            other.layout == layout &&
            other.clueCount == clueCount &&
            other.targetSwapCount == targetSwapCount &&
            other.duplicateGroupCount == duplicateGroupCount &&
            other.maxDuplicateCopies == maxDuplicateCopies;
  }

  @override
  int get hashCode {
    var result = generationKey.hashCode & 0x1FFFFFFF;
    result = _combineHash(result, seed);
    result = _combineHash(result, profileId.index);
    result = _combineHash(result, layout.hashCode);
    result = _combineHash(result, clueCount);
    result = _combineHash(result, targetSwapCount);
    result = _combineHash(result, duplicateGroupCount);
    result = _combineHash(result, maxDuplicateCopies);
    return result;
  }

  @override
  String toString() {
    return 'StageSpec('
        'generationKey: $generationKey, '
        'seed: $seed, '
        'profileId: $profileId, '
        'layout: $layout, '
        'clueCount: $clueCount, '
        'targetSwapCount: $targetSwapCount, '
        'duplicateGroupCount: $duplicateGroupCount, '
        'maxDuplicateCopies: $maxDuplicateCopies'
        ')';
  }
}

int _combineHash(int current, int value) {
  return ((current * 31) + value) & 0x1FFFFFFF;
}
