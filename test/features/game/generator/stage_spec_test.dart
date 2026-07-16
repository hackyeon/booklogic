import 'package:flutter_test/flutter_test.dart';

import 'package:booklogic/features/game/generator/difficulty_profile.dart';
import 'package:booklogic/features/game/generator/difficulty_profile_resolver.dart';
import 'package:booklogic/features/game/generator/generator_config.dart';
import 'package:booklogic/features/game/generator/inclusive_int_range.dart';
import 'package:booklogic/features/game/generator/stage_generation_key.dart';
import 'package:booklogic/features/game/generator/stage_layout.dart';
import 'package:booklogic/features/game/generator/stage_spec.dart';
import 'package:booklogic/features/game/generator/stage_spec_factory.dart';

void main() {
  group('InclusiveIntRange', () {
    test('stores values, calculates length, and checks containment', () {
      const range = InclusiveIntRange(min: 4, max: 6);

      expect(range.min, 4);
      expect(range.max, 6);
      expect(range.length, 3);
      expect(range.contains(4), isTrue);
      expect(range.contains(5), isTrue);
      expect(range.contains(6), isTrue);
      expect(range.contains(3), isFalse);
      expect(range.contains(7), isFalse);
      expect(const InclusiveIntRange(min: 0, max: 0).length, 1);
    });

    test('compares by min and max and asserts invalid ranges', () {
      expect(
        const InclusiveIntRange(min: 4, max: 6),
        const InclusiveIntRange(min: 4, max: 6),
      );
      expect(
        const InclusiveIntRange(min: 4, max: 6),
        isNot(const InclusiveIntRange(min: 5, max: 6)),
      );
      expect(() => InclusiveIntRange(min: 7, max: 6), throwsAssertionError);
    });
  });

  group('StageLayout', () {
    test('calculates totalBookCount', () {
      expect(
        const StageLayout(tierCount: 1, booksPerTier: 4).totalBookCount,
        4,
      );
      expect(
        const StageLayout(tierCount: 2, booksPerTier: 6).totalBookCount,
        12,
      );
      expect(
        const StageLayout(tierCount: 3, booksPerTier: 4).totalBookCount,
        12,
      );
      expect(
        const StageLayout(tierCount: 3, booksPerTier: 6).totalBookCount,
        18,
      );
    });

    test('compares values and asserts invalid dimensions', () {
      expect(
        const StageLayout(tierCount: 2, booksPerTier: 4),
        const StageLayout(tierCount: 2, booksPerTier: 4),
      );
      expect(
        const StageLayout(tierCount: 2, booksPerTier: 4),
        isNot(const StageLayout(tierCount: 3, booksPerTier: 4)),
      );
      expect(
        () => StageLayout(tierCount: 0, booksPerTier: 4),
        throwsAssertionError,
      );
      expect(
        () => StageLayout(tierCount: 4, booksPerTier: 4),
        throwsAssertionError,
      );
      expect(
        () => StageLayout(tierCount: 1, booksPerTier: 3),
        throwsAssertionError,
      );
      expect(
        () => StageLayout(tierCount: 1, booksPerTier: 7),
        throwsAssertionError,
      );
    });
  });

  group('DifficultyProfile', () {
    test('contains levels and exposes duplicate allowance', () {
      final resolver = const DifficultyProfileResolver();
      final intro = resolver.resolve(1);
      final singleTierFive = resolver.resolve(6);
      final singleTierSix = resolver.resolve(21);
      final twoTierFour = resolver.resolve(51);
      final advancedEndless = resolver.resolve(401);

      expect(intro.containsLevel(1), isTrue);
      expect(intro.containsLevel(5), isTrue);
      expect(intro.containsLevel(6), isFalse);
      expect(advancedEndless.containsLevel(401), isTrue);
      expect(advancedEndless.containsLevel(100000), isTrue);
      expect(advancedEndless.containsLevel(400), isFalse);
      expect(intro.allowsDuplicates, isFalse);
      expect(singleTierFive.allowsDuplicates, isFalse);
      expect(singleTierSix.allowsDuplicates, isTrue);
      expect(twoTierFour.allowsDuplicates, isTrue);
    });

    test('protects allowedLayouts from external mutation', () {
      final layouts = [const StageLayout(tierCount: 1, booksPerTier: 4)];
      final profile = DifficultyProfile(
        id: DifficultyProfileId.intro,
        minLevel: 1,
        maxLevel: 5,
        allowedLayouts: layouts,
        clueCountRange: const InclusiveIntRange(min: 2, max: 3),
        targetSwapCountRange: const InclusiveIntRange(min: 1, max: 2),
        duplicateGroupCountRange: const InclusiveIntRange(min: 0, max: 0),
        maxDuplicateCopies: 1,
      );

      layouts.add(const StageLayout(tierCount: 1, booksPerTier: 5));

      expect(profile.allowedLayouts, [
        const StageLayout(tierCount: 1, booksPerTier: 4),
      ]);
      expect(
        () => profile.allowedLayouts.add(
          const StageLayout(tierCount: 1, booksPerTier: 5),
        ),
        throwsUnsupportedError,
      );
    });

    test('compares all fields', () {
      final first = DifficultyProfile(
        id: DifficultyProfileId.intro,
        minLevel: 1,
        maxLevel: 5,
        allowedLayouts: const [StageLayout(tierCount: 1, booksPerTier: 4)],
        clueCountRange: const InclusiveIntRange(min: 2, max: 3),
        targetSwapCountRange: const InclusiveIntRange(min: 1, max: 2),
        duplicateGroupCountRange: const InclusiveIntRange(min: 0, max: 0),
        maxDuplicateCopies: 1,
      );
      final second = DifficultyProfile(
        id: DifficultyProfileId.intro,
        minLevel: 1,
        maxLevel: 5,
        allowedLayouts: const [StageLayout(tierCount: 1, booksPerTier: 4)],
        clueCountRange: const InclusiveIntRange(min: 2, max: 3),
        targetSwapCountRange: const InclusiveIntRange(min: 1, max: 2),
        duplicateGroupCountRange: const InclusiveIntRange(min: 0, max: 0),
        maxDuplicateCopies: 1,
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first.toString(), contains('DifficultyProfileId.intro'));
    });
  });

  group('DifficultyProfileResolver', () {
    test('resolves boundary levels by range only', () {
      const resolver = DifficultyProfileResolver();

      expect(resolver.resolve(1).id, DifficultyProfileId.intro);
      expect(resolver.resolve(5).id, DifficultyProfileId.intro);
      expect(resolver.resolve(6).id, DifficultyProfileId.singleTierFive);
      expect(resolver.resolve(20).id, DifficultyProfileId.singleTierFive);
      expect(resolver.resolve(21).id, DifficultyProfileId.singleTierSix);
      expect(resolver.resolve(50).id, DifficultyProfileId.singleTierSix);
      expect(resolver.resolve(51).id, DifficultyProfileId.twoTierFour);
      expect(resolver.resolve(100).id, DifficultyProfileId.twoTierFour);
      expect(resolver.resolve(101).id, DifficultyProfileId.twoTierFive);
      expect(resolver.resolve(200).id, DifficultyProfileId.twoTierFive);
      expect(resolver.resolve(201).id, DifficultyProfileId.twelveBookMixed);
      expect(resolver.resolve(400).id, DifficultyProfileId.twelveBookMixed);
      expect(resolver.resolve(401).id, DifficultyProfileId.advancedEndless);
      expect(resolver.resolve(1000).id, DifficultyProfileId.advancedEndless);
      expect(resolver.resolve(100000).id, DifficultyProfileId.advancedEndless);
    });

    test('validates levels and protects profiles list', () {
      const resolver = DifficultyProfileResolver();

      expect(() => resolver.resolve(0), throwsArgumentError);
      expect(() => resolver.resolve(-1), throwsArgumentError);
      expect(
        () => resolver.profiles.add(resolver.resolve(1)),
        throwsUnsupportedError,
      );
      expect(
        () => resolver.profiles.remove(resolver.resolve(1)),
        throwsUnsupportedError,
      );
      expect(() => resolver.profiles.clear(), throwsUnsupportedError);
    });

    test('has no overlap or gaps from level 1 to 10000', () {
      const resolver = DifficultyProfileResolver();

      for (var level = 1; level <= 10000; level += 1) {
        final matches = resolver.profiles
            .where((profile) => profile.containsLevel(level))
            .toList();

        expect(matches, hasLength(1), reason: 'level $level');
        expect(resolver.resolve(level), matches.single);
      }
    });
  });

  group('StageSpec', () {
    test('stores fields and calculates getters', () {
      final spec = StageSpec(
        generationKey: const StageGenerationKey(
          generatorVersion: 1,
          level: 100,
        ),
        seed: 2956496806,
        profileId: DifficultyProfileId.twoTierFour,
        layout: const StageLayout(tierCount: 2, booksPerTier: 4),
        clueCount: 6,
        targetSwapCount: 5,
        duplicateGroupCount: 0,
        maxDuplicateCopies: 2,
      );

      expect(spec.generationKey.level, 100);
      expect(spec.seed, 2956496806);
      expect(spec.profileId, DifficultyProfileId.twoTierFour);
      expect(spec.layout, const StageLayout(tierCount: 2, booksPerTier: 4));
      expect(spec.clueCount, 6);
      expect(spec.targetSwapCount, 5);
      expect(spec.duplicateGroupCount, 0);
      expect(spec.maxDuplicateCopies, 2);
      expect(spec.level, 100);
      expect(spec.generatorVersion, 1);
      expect(spec.tierCount, 2);
      expect(spec.booksPerTier, 4);
      expect(spec.totalBookCount, 8);
      expect(spec.hasDuplicates, isFalse);
    });

    test('detects duplicates and compares values', () {
      final first = StageSpec(
        generationKey: const StageGenerationKey(
          generatorVersion: 1,
          level: 101,
        ),
        seed: 710837801,
        profileId: DifficultyProfileId.twoTierFive,
        layout: const StageLayout(tierCount: 2, booksPerTier: 5),
        clueCount: 7,
        targetSwapCount: 6,
        duplicateGroupCount: 1,
        maxDuplicateCopies: 2,
      );
      final second = StageSpec(
        generationKey: const StageGenerationKey(
          generatorVersion: 1,
          level: 101,
        ),
        seed: 710837801,
        profileId: DifficultyProfileId.twoTierFive,
        layout: const StageLayout(tierCount: 2, booksPerTier: 5),
        clueCount: 7,
        targetSwapCount: 6,
        duplicateGroupCount: 1,
        maxDuplicateCopies: 2,
      );

      expect(first.hasDuplicates, isTrue);
      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(secondWithSeed(second, 710837802)));
      expect(first.toString(), contains('StageSpec'));
    });

    test('asserts nonzero attempts', () {
      expect(
        () => StageSpec(
          generationKey: const StageGenerationKey(
            generatorVersion: 1,
            level: 1,
            attempt: 1,
          ),
          seed: 1,
          profileId: DifficultyProfileId.intro,
          layout: const StageLayout(tierCount: 1, booksPerTier: 4),
          clueCount: 2,
          targetSwapCount: 1,
          duplicateGroupCount: 0,
          maxDuplicateCopies: 1,
        ),
        throwsAssertionError,
      );
    });
  });

  group('StageSpecFactory', () {
    const factory = StageSpecFactory();

    test('generator v1 StageSpec golden values remain stable', () {
      // If this fails, existing level difficulty specs may change. Do not
      // refresh expectations unless a new generatorVersion is introduced.
      _expectGoldenSpec(
        factory.create(level: 1),
        seed: 3270846678,
        profileId: DifficultyProfileId.intro,
        tierCount: 1,
        booksPerTier: 4,
        clueCount: 3,
        targetSwapCount: 2,
        duplicateGroupCount: 0,
        maxDuplicateCopies: 1,
      );
      _expectGoldenSpec(
        factory.create(level: 6),
        seed: 651865735,
        profileId: DifficultyProfileId.singleTierFive,
        tierCount: 1,
        booksPerTier: 5,
        clueCount: 3,
        targetSwapCount: 2,
        duplicateGroupCount: 0,
        maxDuplicateCopies: 1,
      );
      _expectGoldenSpec(
        factory.create(level: 21),
        seed: 2758664950,
        profileId: DifficultyProfileId.singleTierSix,
        tierCount: 1,
        booksPerTier: 6,
        clueCount: 4,
        targetSwapCount: 4,
        duplicateGroupCount: 1,
        maxDuplicateCopies: 2,
      );
      _expectGoldenSpec(
        factory.create(level: 51),
        seed: 3935744153,
        profileId: DifficultyProfileId.twoTierFour,
        tierCount: 2,
        booksPerTier: 4,
        clueCount: 4,
        targetSwapCount: 3,
        duplicateGroupCount: 0,
        maxDuplicateCopies: 2,
      );
      _expectGoldenSpec(
        factory.create(level: 100),
        seed: 2956496806,
        profileId: DifficultyProfileId.twoTierFour,
        tierCount: 2,
        booksPerTier: 4,
        clueCount: 6,
        targetSwapCount: 5,
        duplicateGroupCount: 0,
        maxDuplicateCopies: 2,
      );
      _expectGoldenSpec(
        factory.create(level: 101),
        seed: 710837801,
        profileId: DifficultyProfileId.twoTierFive,
        tierCount: 2,
        booksPerTier: 5,
        clueCount: 7,
        targetSwapCount: 6,
        duplicateGroupCount: 1,
        maxDuplicateCopies: 2,
      );
    });

    test('generator v2 StageSpec golden values remain stable', () {
      _expectGoldenSpec(
        factory.create(
          level: 201,
          generatorVersion: GeneratorConfig.generatorVersion2,
        ),
        seed: 4070155089,
        profileId: DifficultyProfileId.verticalIntro2x6,
        tierCount: 2,
        booksPerTier: 6,
        clueCount: 6,
        targetSwapCount: 6,
        duplicateGroupCount: 1,
        maxDuplicateCopies: 2,
      );
      _expectGoldenSpec(
        factory.create(
          level: 241,
          generatorVersion: GeneratorConfig.generatorVersion2,
        ),
        seed: 3410928389,
        profileId: DifficultyProfileId.verticalNegative2x6,
        tierCount: 2,
        booksPerTier: 6,
        clueCount: 6,
        targetSwapCount: 6,
        duplicateGroupCount: 2,
        maxDuplicateCopies: 2,
      );
      _expectGoldenSpec(
        factory.create(
          level: 281,
          generatorVersion: GeneratorConfig.generatorVersion2,
        ),
        seed: 2496737945,
        profileId: DifficultyProfileId.verticalThreeTier3x4,
        tierCount: 3,
        booksPerTier: 4,
        clueCount: 7,
        targetSwapCount: 7,
        duplicateGroupCount: 2,
        maxDuplicateCopies: 2,
      );
      _expectGoldenSpec(
        factory.create(
          level: 321,
          generatorVersion: GeneratorConfig.generatorVersion2,
        ),
        seed: 3122699240,
        profileId: DifficultyProfileId.fullAdvanced3x4,
        tierCount: 3,
        booksPerTier: 4,
        clueCount: 7,
        targetSwapCount: 7,
        duplicateGroupCount: 2,
        maxDuplicateCopies: 2,
      );
      _expectGoldenSpec(
        factory.create(
          level: 400,
          generatorVersion: GeneratorConfig.generatorVersion2,
        ),
        seed: 4245720908,
        profileId: DifficultyProfileId.fullAdvanced3x4,
        tierCount: 3,
        booksPerTier: 4,
        clueCount: 7,
        targetSwapCount: 7,
        duplicateGroupCount: 2,
        maxDuplicateCopies: 2,
      );
    });

    test('is deterministic across calls and factory instances', () {
      final first = factory.create(level: 100);
      final secondFactory = const StageSpecFactory();

      for (var index = 0; index < 100; index += 1) {
        expect(factory.create(level: 100), first);
      }
      expect(secondFactory.create(level: 100), first);
      expect(factory.create(level: 101).seed, isNot(first.seed));
      expect(
        () => factory.create(level: 100, generatorVersion: 2),
        throwsUnsupportedError,
      );
    });

    test('validates input', () {
      expect(() => factory.create(level: 0), throwsArgumentError);
      expect(() => factory.create(level: -1), throwsArgumentError);
      expect(
        () => factory.create(level: 1, generatorVersion: 0),
        throwsArgumentError,
      );
      expect(
        () => factory.create(level: 1, generatorVersion: -1),
        throwsArgumentError,
      );
    });

    test('creates valid specs for supported version ranges', () {
      const resolver = DifficultyProfileResolver();

      for (var level = 1; level <= 200; level += 1) {
        final spec = factory.create(level: level);
        final profile = resolver.resolve(level);

        _expectSpecInProfile(spec, profile);
      }
      for (var level = 201; level <= 400; level += 1) {
        final spec = factory.create(
          level: level,
          generatorVersion: GeneratorConfig.generatorVersion2,
        );

        expect(spec.generatorVersion, GeneratorConfig.generatorVersion2);
        expect(spec.totalBookCount, 12);
      }
      expect(() => factory.create(level: 201), throwsUnsupportedError);
      expect(
        () => factory.create(
          level: 401,
          generatorVersion: GeneratorConfig.generatorVersion2,
        ),
        throwsUnsupportedError,
      );
    });

    test('version 2 profile layout ranges are level-gated', () {
      final twoTierLayouts = <StageLayout>{};
      for (var level = 201; level <= 400; level += 1) {
        final spec = factory.create(
          level: level,
          generatorVersion: GeneratorConfig.generatorVersion2,
        );
        if (level <= 280) {
          twoTierLayouts.add(spec.layout);
        } else {
          expect(spec.layout, const StageLayout(tierCount: 3, booksPerTier: 4));
        }
      }

      expect(twoTierLayouts, {
        const StageLayout(tierCount: 2, booksPerTier: 6),
      });
    });

    test('representative profile values stay inside declared ranges', () {
      const resolver = DifficultyProfileResolver();
      const representativeLevels = [1, 5, 6, 20, 21, 50, 51, 100, 101, 200];

      for (final level in representativeLevels) {
        final spec = factory.create(level: level);
        final profile = resolver.resolve(level);

        _expectSpecInProfile(spec, profile);
      }
      for (final level in [201, 241, 281, 321, 400]) {
        final spec = factory.create(
          level: level,
          generatorVersion: GeneratorConfig.generatorVersion2,
        );

        expect(spec.clueCount, inInclusiveRange(6, 8));
        expect(spec.targetSwapCount, inInclusiveRange(6, 8));
        expect(spec.duplicateGroupCount, inInclusiveRange(1, 3));
        expect(spec.maxDuplicateCopies, 2);
      }
    });
  });
}

StageSpec secondWithSeed(StageSpec spec, int seed) {
  return StageSpec(
    generationKey: spec.generationKey,
    seed: seed,
    profileId: spec.profileId,
    layout: spec.layout,
    clueCount: spec.clueCount,
    targetSwapCount: spec.targetSwapCount,
    duplicateGroupCount: spec.duplicateGroupCount,
    maxDuplicateCopies: spec.maxDuplicateCopies,
  );
}

void _expectGoldenSpec(
  StageSpec spec, {
  required int seed,
  required DifficultyProfileId profileId,
  required int tierCount,
  required int booksPerTier,
  required int clueCount,
  required int targetSwapCount,
  required int duplicateGroupCount,
  required int maxDuplicateCopies,
}) {
  expect(spec.seed, seed);
  expect(spec.profileId, profileId);
  expect(spec.tierCount, tierCount);
  expect(spec.booksPerTier, booksPerTier);
  expect(spec.totalBookCount, tierCount * booksPerTier);
  expect(spec.clueCount, clueCount);
  expect(spec.targetSwapCount, targetSwapCount);
  expect(spec.duplicateGroupCount, duplicateGroupCount);
  expect(spec.maxDuplicateCopies, maxDuplicateCopies);
  expect(spec.generationKey.attempt, 0);
}

void _expectSpecInProfile(StageSpec spec, DifficultyProfile profile) {
  expect(profile.containsLevel(spec.level), isTrue);
  expect(spec.profileId, profile.id);
  expect(spec.generatorVersion, GeneratorConfig.currentVersion);
  expect(spec.generationKey.attempt, 0);
  expect(spec.seed, inInclusiveRange(0, GeneratorConfig.uint32Mask));
  expect(spec.tierCount, inInclusiveRange(1, 3));
  expect(spec.booksPerTier, inInclusiveRange(4, 6));
  expect(spec.totalBookCount, inInclusiveRange(4, 18));
  expect(profile.allowedLayouts, contains(spec.layout));
  expect(profile.clueCountRange.contains(spec.clueCount), isTrue);
  expect(profile.targetSwapCountRange.contains(spec.targetSwapCount), isTrue);
  expect(
    profile.duplicateGroupCountRange.contains(spec.duplicateGroupCount),
    isTrue,
  );
  expect(spec.maxDuplicateCopies, profile.maxDuplicateCopies);
}
