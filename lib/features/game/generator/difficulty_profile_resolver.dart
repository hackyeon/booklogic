import 'difficulty_profile.dart';
import 'inclusive_int_range.dart';
import 'stage_layout.dart';

class DifficultyProfileResolver {
  const DifficultyProfileResolver();

  static final List<DifficultyProfile> _profiles =
      List<DifficultyProfile>.unmodifiable([
        DifficultyProfile(
          id: DifficultyProfileId.intro,
          minLevel: 1,
          maxLevel: 5,
          allowedLayouts: const [StageLayout(tierCount: 1, booksPerTier: 4)],
          clueCountRange: const InclusiveIntRange(min: 2, max: 3),
          targetSwapCountRange: const InclusiveIntRange(min: 1, max: 2),
          duplicateGroupCountRange: const InclusiveIntRange(min: 0, max: 0),
          maxDuplicateCopies: 1,
        ),
        DifficultyProfile(
          id: DifficultyProfileId.singleTierFive,
          minLevel: 6,
          maxLevel: 20,
          allowedLayouts: const [StageLayout(tierCount: 1, booksPerTier: 5)],
          clueCountRange: const InclusiveIntRange(min: 3, max: 4),
          targetSwapCountRange: const InclusiveIntRange(min: 2, max: 3),
          duplicateGroupCountRange: const InclusiveIntRange(min: 0, max: 0),
          maxDuplicateCopies: 1,
        ),
        DifficultyProfile(
          id: DifficultyProfileId.singleTierSix,
          minLevel: 21,
          maxLevel: 50,
          allowedLayouts: const [StageLayout(tierCount: 1, booksPerTier: 6)],
          clueCountRange: const InclusiveIntRange(min: 4, max: 5),
          targetSwapCountRange: const InclusiveIntRange(min: 3, max: 4),
          duplicateGroupCountRange: const InclusiveIntRange(min: 1, max: 1),
          maxDuplicateCopies: 2,
        ),
        DifficultyProfile(
          id: DifficultyProfileId.twoTierFour,
          minLevel: 51,
          maxLevel: 100,
          allowedLayouts: const [StageLayout(tierCount: 2, booksPerTier: 4)],
          clueCountRange: const InclusiveIntRange(min: 4, max: 6),
          targetSwapCountRange: const InclusiveIntRange(min: 3, max: 5),
          duplicateGroupCountRange: const InclusiveIntRange(min: 0, max: 1),
          maxDuplicateCopies: 2,
        ),
        DifficultyProfile(
          id: DifficultyProfileId.twoTierFive,
          minLevel: 101,
          maxLevel: 200,
          allowedLayouts: const [StageLayout(tierCount: 2, booksPerTier: 5)],
          clueCountRange: const InclusiveIntRange(min: 5, max: 7),
          targetSwapCountRange: const InclusiveIntRange(min: 4, max: 6),
          duplicateGroupCountRange: const InclusiveIntRange(min: 1, max: 2),
          maxDuplicateCopies: 2,
        ),
        DifficultyProfile(
          id: DifficultyProfileId.twelveBookMixed,
          minLevel: 201,
          maxLevel: 400,
          allowedLayouts: const [
            StageLayout(tierCount: 2, booksPerTier: 6),
            StageLayout(tierCount: 3, booksPerTier: 4),
          ],
          clueCountRange: const InclusiveIntRange(min: 6, max: 8),
          targetSwapCountRange: const InclusiveIntRange(min: 5, max: 7),
          duplicateGroupCountRange: const InclusiveIntRange(min: 1, max: 3),
          maxDuplicateCopies: 3,
        ),
        DifficultyProfile(
          id: DifficultyProfileId.advancedEndless,
          minLevel: 401,
          maxLevel: null,
          allowedLayouts: const [
            StageLayout(tierCount: 3, booksPerTier: 5),
            StageLayout(tierCount: 3, booksPerTier: 6),
          ],
          clueCountRange: const InclusiveIntRange(min: 6, max: 9),
          targetSwapCountRange: const InclusiveIntRange(min: 7, max: 10),
          duplicateGroupCountRange: const InclusiveIntRange(min: 1, max: 4),
          maxDuplicateCopies: 3,
        ),
      ]);

  List<DifficultyProfile> get profiles => _profiles;

  DifficultyProfile resolve(int level) {
    if (level < 1) {
      throw ArgumentError.value(level, 'level', '1 이상이어야 합니다.');
    }

    for (final profile in _profiles) {
      if (profile.containsLevel(level)) {
        return profile;
      }
    }

    throw StateError('레벨 $level에 해당하는 난이도 프로필이 없습니다.');
  }
}
