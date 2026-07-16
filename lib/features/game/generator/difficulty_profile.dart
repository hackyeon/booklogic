import 'inclusive_int_range.dart';
import 'stage_layout.dart';

enum DifficultyProfileId {
  intro,
  singleTierFive,
  singleTierSix,
  twoTierFour,
  twoTierFive,
  twelveBookMixed,
  advancedEndless,
  verticalIntro2x6,
  verticalNegative2x6,
  verticalThreeTier3x4,
  fullAdvanced3x4,
}

class DifficultyProfile {
  DifficultyProfile({
    required this.id,
    required this.minLevel,
    required this.maxLevel,
    required List<StageLayout> allowedLayouts,
    required this.clueCountRange,
    required this.targetSwapCountRange,
    required this.duplicateGroupCountRange,
    required this.maxDuplicateCopies,
  }) : assert(minLevel >= 1),
       assert(maxLevel == null || maxLevel >= minLevel),
       assert(allowedLayouts.isNotEmpty),
       assert(clueCountRange.min >= 1),
       assert(targetSwapCountRange.min >= 1),
       assert(duplicateGroupCountRange.min >= 0),
       assert(maxDuplicateCopies >= 1),
       assert(maxDuplicateCopies <= 3),
       assert(duplicateGroupCountRange.max == 0 || maxDuplicateCopies >= 2),
       allowedLayouts = List<StageLayout>.unmodifiable(allowedLayouts);

  final DifficultyProfileId id;
  final int minLevel;
  final int? maxLevel;
  final List<StageLayout> allowedLayouts;
  final InclusiveIntRange clueCountRange;
  final InclusiveIntRange targetSwapCountRange;
  final InclusiveIntRange duplicateGroupCountRange;
  final int maxDuplicateCopies;

  bool containsLevel(int level) {
    return level >= minLevel && (maxLevel == null || level <= maxLevel!);
  }

  bool get allowsDuplicates => duplicateGroupCountRange.max > 0;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DifficultyProfile &&
            other.id == id &&
            other.minLevel == minLevel &&
            other.maxLevel == maxLevel &&
            _listEquals(other.allowedLayouts, allowedLayouts) &&
            other.clueCountRange == clueCountRange &&
            other.targetSwapCountRange == targetSwapCountRange &&
            other.duplicateGroupCountRange == duplicateGroupCountRange &&
            other.maxDuplicateCopies == maxDuplicateCopies;
  }

  @override
  int get hashCode {
    var result = id.index & 0x1FFFFFFF;
    result = _combineHash(result, minLevel);
    result = _combineHash(result, maxLevel ?? 0);
    for (final layout in allowedLayouts) {
      result = _combineHash(result, layout.hashCode);
    }
    result = _combineHash(result, clueCountRange.hashCode);
    result = _combineHash(result, targetSwapCountRange.hashCode);
    result = _combineHash(result, duplicateGroupCountRange.hashCode);
    result = _combineHash(result, maxDuplicateCopies);
    return result;
  }

  @override
  String toString() {
    return 'DifficultyProfile('
        'id: $id, '
        'minLevel: $minLevel, '
        'maxLevel: $maxLevel, '
        'allowedLayouts: $allowedLayouts, '
        'clueCountRange: $clueCountRange, '
        'targetSwapCountRange: $targetSwapCountRange, '
        'duplicateGroupCountRange: $duplicateGroupCountRange, '
        'maxDuplicateCopies: $maxDuplicateCopies'
        ')';
  }
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

int _combineHash(int current, int value) {
  return ((current * 31) + value) & 0x1FFFFFFF;
}
