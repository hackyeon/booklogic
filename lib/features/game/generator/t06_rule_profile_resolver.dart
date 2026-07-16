import 'difficulty_profile.dart';
import 'inclusive_int_range.dart';
import 'stage_layout.dart';
import 't06_rule_profile.dart';

class T06RuleProfileResolver {
  const T06RuleProfileResolver();

  static const verticalIntro2x6 = T06RuleProfile(
    id: DifficultyProfileId.verticalIntro2x6,
    minimumLevel: 201,
    maximumLevel: 240,
    layout: StageLayout(tierCount: 2, booksPerTier: 6),
    clueCountRange: InclusiveIntRange(min: 6, max: 6),
    targetSwapCountRange: InclusiveIntRange(min: 6, max: 6),
    duplicateGroupCountRange: InclusiveIntRange(min: 1, max: 1),
    usesVerticalRelation: true,
    usesNotAtEdge: false,
    usesDistance: false,
    minimumCrossTierSwapCount: 2,
    minimumUnsatisfiedClueCount: 3,
  );

  static const verticalNegative2x6 = T06RuleProfile(
    id: DifficultyProfileId.verticalNegative2x6,
    minimumLevel: 241,
    maximumLevel: 280,
    layout: StageLayout(tierCount: 2, booksPerTier: 6),
    clueCountRange: InclusiveIntRange(min: 6, max: 7),
    targetSwapCountRange: InclusiveIntRange(min: 6, max: 7),
    duplicateGroupCountRange: InclusiveIntRange(min: 1, max: 2),
    usesVerticalRelation: true,
    usesNotAtEdge: true,
    usesDistance: false,
    minimumCrossTierSwapCount: 2,
    minimumUnsatisfiedClueCount: 3,
  );

  static const verticalThreeTier3x4 = T06RuleProfile(
    id: DifficultyProfileId.verticalThreeTier3x4,
    minimumLevel: 281,
    maximumLevel: 320,
    layout: StageLayout(tierCount: 3, booksPerTier: 4),
    clueCountRange: InclusiveIntRange(min: 7, max: 7),
    targetSwapCountRange: InclusiveIntRange(min: 7, max: 7),
    duplicateGroupCountRange: InclusiveIntRange(min: 2, max: 2),
    usesVerticalRelation: true,
    usesNotAtEdge: true,
    usesDistance: false,
    minimumCrossTierSwapCount: 3,
    minimumUnsatisfiedClueCount: 4,
  );

  static const fullAdvanced3x4 = T06RuleProfile(
    id: DifficultyProfileId.fullAdvanced3x4,
    minimumLevel: 321,
    maximumLevel: 400,
    layout: StageLayout(tierCount: 3, booksPerTier: 4),
    clueCountRange: InclusiveIntRange(min: 7, max: 8),
    targetSwapCountRange: InclusiveIntRange(min: 7, max: 8),
    duplicateGroupCountRange: InclusiveIntRange(min: 2, max: 3),
    usesVerticalRelation: true,
    usesNotAtEdge: true,
    usesDistance: true,
    minimumCrossTierSwapCount: 3,
    minimumUnsatisfiedClueCount: 4,
  );

  static const profiles = [
    verticalIntro2x6,
    verticalNegative2x6,
    verticalThreeTier3x4,
    fullAdvanced3x4,
  ];

  T06RuleProfile resolve(int level) {
    for (final profile in profiles) {
      if (profile.containsLevel(level)) {
        return profile;
      }
    }
    if (level < 201) {
      throw ArgumentError.value(level, 'level', '201 이상이어야 합니다.');
    }
    throw UnsupportedError('T06 does not support level $level.');
  }
}
