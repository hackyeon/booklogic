import 'difficulty_profile.dart';
import 'inclusive_int_range.dart';
import 'stage_layout.dart';

class T06RuleProfile {
  const T06RuleProfile({
    required this.id,
    required this.minimumLevel,
    required this.maximumLevel,
    required this.layout,
    required this.clueCountRange,
    required this.targetSwapCountRange,
    required this.duplicateGroupCountRange,
    required this.usesVerticalRelation,
    required this.usesNotAtEdge,
    required this.usesDistance,
    required this.minimumCrossTierSwapCount,
    required this.minimumUnsatisfiedClueCount,
  }) : assert(minimumLevel >= 201),
       assert(maximumLevel >= minimumLevel),
       assert(minimumCrossTierSwapCount >= 0),
       assert(minimumUnsatisfiedClueCount >= 1);

  final DifficultyProfileId id;
  final int minimumLevel;
  final int maximumLevel;
  final StageLayout layout;
  final InclusiveIntRange clueCountRange;
  final InclusiveIntRange targetSwapCountRange;
  final InclusiveIntRange duplicateGroupCountRange;
  final bool usesVerticalRelation;
  final bool usesNotAtEdge;
  final bool usesDistance;
  final int minimumCrossTierSwapCount;
  final int minimumUnsatisfiedClueCount;

  bool containsLevel(int level) {
    return level >= minimumLevel && level <= maximumLevel;
  }
}
