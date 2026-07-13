import 'package:flutter_test/flutter_test.dart';

import 'package:booklogic/features/game/generator/deterministic_random.dart';
import 'package:booklogic/features/game/generator/generator_config.dart';
import 'package:booklogic/features/game/generator/stage_generation_key.dart';
import 'package:booklogic/features/game/generator/stage_seed_factory.dart';

void main() {
  group('StageGenerationKey', () {
    test('stores values and defaults attempt to zero', () {
      const key = StageGenerationKey(generatorVersion: 1, level: 10);

      expect(key.generatorVersion, 1);
      expect(key.level, 10);
      expect(key.attempt, 0);
    });

    test('compares by generatorVersion, level, and attempt', () {
      const base = StageGenerationKey(
        generatorVersion: 1,
        level: 100,
        attempt: 7,
      );

      expect(
        base,
        const StageGenerationKey(generatorVersion: 1, level: 100, attempt: 7),
      );
      expect(
        base,
        isNot(
          const StageGenerationKey(generatorVersion: 1, level: 101, attempt: 7),
        ),
      );
      expect(
        base,
        isNot(
          const StageGenerationKey(generatorVersion: 2, level: 100, attempt: 7),
        ),
      );
      expect(
        base,
        isNot(
          const StageGenerationKey(generatorVersion: 1, level: 100, attempt: 8),
        ),
      );
      expect(base.hashCode, base.hashCode);
    });

    test('toString contains debugging values', () {
      const key = StageGenerationKey(
        generatorVersion: 2,
        level: 100,
        attempt: 7,
      );

      expect(key.toString(), contains('generatorVersion: 2'));
      expect(key.toString(), contains('level: 100'));
      expect(key.toString(), contains('attempt: 7'));
    });
  });

  group('StageSeedFactory', () {
    const factory = StageSeedFactory();

    test('builds canonical input without platform data', () {
      expect(
        factory.canonicalInput(
          const StageGenerationKey(generatorVersion: 1, level: 1),
        ),
        'bookshelf_puzzle|generator=1|level=1|attempt=0',
      );
      expect(
        factory.canonicalInput(
          const StageGenerationKey(generatorVersion: 1, level: 100),
        ),
        'bookshelf_puzzle|generator=1|level=100|attempt=0',
      );
      expect(
        factory.buildCanonicalInput(
          generatorVersion: 2,
          level: 100,
          attempt: 7,
        ),
        'bookshelf_puzzle|generator=2|level=100|attempt=7',
      );
    });

    test('generator v1 seed golden values remain stable', () {
      // If this fails, existing generated levels may change. Do not update
      // expectations unless a new generatorVersion is intentionally introduced.
      expect(
        factory.create(const StageGenerationKey(generatorVersion: 1, level: 1)),
        3270846678,
      );
      expect(
        factory.create(const StageGenerationKey(generatorVersion: 1, level: 2)),
        786678099,
      );
      expect(
        factory.create(
          const StageGenerationKey(generatorVersion: 1, level: 100),
        ),
        2956496806,
      );
      expect(
        factory.create(
          const StageGenerationKey(generatorVersion: 1, level: 100, attempt: 1),
        ),
        2973274425,
      );
      expect(
        factory.create(
          const StageGenerationKey(generatorVersion: 2, level: 100),
        ),
        2794251331,
      );
    });

    test('returns stable unsigned nonzero seeds for the same input', () {
      const key = StageGenerationKey(generatorVersion: 1, level: 100);
      final seed = factory.create(key);

      for (var index = 0; index < 100; index += 1) {
        expect(factory.create(key), seed);
      }
      expect(seed, inInclusiveRange(0, GeneratorConfig.uint32Mask));
      expect(seed, isNot(0));
    });

    test('level, attempt, and generatorVersion change the seed', () {
      final levelOneSeed = factory.create(
        const StageGenerationKey(generatorVersion: 1, level: 1),
      );
      final levelTwoSeed = factory.create(
        const StageGenerationKey(generatorVersion: 1, level: 2),
      );
      final attemptZeroSeed = factory.create(
        const StageGenerationKey(generatorVersion: 1, level: 100),
      );
      final attemptOneSeed = factory.create(
        const StageGenerationKey(generatorVersion: 1, level: 100, attempt: 1),
      );
      final versionTwoSeed = factory.create(
        const StageGenerationKey(generatorVersion: 2, level: 100),
      );

      expect(levelOneSeed, isNot(levelTwoSeed));
      expect(attemptZeroSeed, isNot(attemptOneSeed));
      expect(attemptZeroSeed, isNot(versionTwoSeed));
    });

    test('validates public raw input in release-safe paths', () {
      expect(
        () => factory.createFromValues(generatorVersion: 0, level: 1),
        throwsArgumentError,
      );
      expect(
        () => factory.createFromValues(generatorVersion: -1, level: 1),
        throwsArgumentError,
      );
      expect(
        () => factory.createFromValues(generatorVersion: 1, level: 0),
        throwsArgumentError,
      );
      expect(
        () => factory.createFromValues(generatorVersion: 1, level: -1),
        throwsArgumentError,
      );
      expect(
        () => factory.createFromValues(
          generatorVersion: 1,
          level: 1,
          attempt: -1,
        ),
        throwsArgumentError,
      );
    });
  });

  group('DeterministicRandom', () {
    test('same seed produces the same nextUint32 sequence', () {
      final first = DeterministicRandom(_goldenSeed);
      final second = DeterministicRandom(_goldenSeed);

      for (var index = 0; index < 100; index += 1) {
        expect(first.nextUint32(), second.nextUint32());
      }
    });

    test('different seeds produce different sequences', () {
      final first = DeterministicRandom(_goldenSeed);
      final second = DeterministicRandom(_goldenSeed + 1);

      expect(
        [for (var index = 0; index < 5; index += 1) first.nextUint32()],
        isNot([for (var index = 0; index < 5; index += 1) second.nextUint32()]),
      );
    });

    test('generator v1 xorshift sequence remains stable', () {
      // If this fails, existing generated levels may change. Prefer a new
      // generatorVersion over editing v1 expectations.
      final random = DeterministicRandom(_goldenSeed);

      expect(
        [for (var index = 0; index < 5; index += 1) random.nextUint32()],
        [2555377472, 2992588403, 145779803, 2723862022, 3956745003],
      );
    });

    test('nextUint32 values stay in unsigned 32-bit range', () {
      final random = DeterministicRandom(_goldenSeed);

      for (var index = 0; index < 100; index += 1) {
        expect(
          random.nextUint32(),
          inInclusiveRange(0, GeneratorConfig.uint32Mask),
        );
      }
    });

    test('normalizes zero and negative seeds', () {
      expect(
        DeterministicRandom(0).initialSeed,
        GeneratorConfig.zeroSeedFallback,
      );
      expect(DeterministicRandom(-1).initialSeed, GeneratorConfig.uint32Mask);
    });

    test('currentState and initialSeed getters do not consume randomness', () {
      final first = DeterministicRandom(_goldenSeed);
      final second = DeterministicRandom(_goldenSeed);

      expect(first.initialSeed, _goldenSeed);
      expect(first.currentState, first.initialSeed);
      expect(first.currentState, first.initialSeed);
      expect(first.initialSeed, _goldenSeed);

      final next = first.nextUint32();

      expect(next, second.nextUint32());
      expect(first.currentState, next);
    });

    test('nextInt follows generator v1 modulo sequence', () {
      final random = DeterministicRandom(_goldenSeed);

      expect(random.nextInt(2), 0);
      expect(random.nextInt(3), 2);
      expect(random.nextInt(4), 3);
      expect(random.nextInt(5), 2);
      expect(random.nextInt(6), 3);
      expect(random.nextInt(10), 0);
      expect(random.nextInt(100), 8);
    });

    test('nextInt validates and stays inside range', () {
      final random = DeterministicRandom(_goldenSeed);

      for (final maxExclusive in [1, 2, 3, 10, 100, 1000]) {
        for (var index = 0; index < 20; index += 1) {
          final value = random.nextInt(maxExclusive);
          expect(value, inExclusiveRange(-1, maxExclusive));
          expect(value, greaterThanOrEqualTo(0));
        }
      }
      expect(DeterministicRandom(_goldenSeed).nextInt(1), 0);
      expect(() => random.nextInt(0), throwsArgumentError);
      expect(() => random.nextInt(-1), throwsArgumentError);
    });

    test('nextBool is deterministic and advances state', () {
      final first = DeterministicRandom(_goldenSeed);
      final second = DeterministicRandom(_goldenSeed);

      final firstState = first.currentState;
      final firstValues = [
        for (var index = 0; index < 5; index += 1) first.nextBool(),
      ];
      final secondValues = [
        for (var index = 0; index < 5; index += 1) second.nextBool(),
      ];

      expect(firstValues, secondValues);
      expect(firstValues, everyElement(isA<bool>()));
      expect(first.currentState, isNot(firstState));
    });

    test('nextDouble is deterministic and inside range', () {
      final first = DeterministicRandom(_goldenSeed);
      final second = DeterministicRandom(_goldenSeed);

      expect(first.nextDouble(), closeTo(0.5949701815843582, 1e-15));
      expect(first.currentState, isNot(first.initialSeed));

      final firstValues = [
        for (var index = 0; index < 20; index += 1) first.nextDouble(),
      ];
      final secondValues = [
        second.nextDouble(),
        for (var index = 0; index < 20; index += 1) second.nextDouble(),
      ].skip(1).toList();

      expect(firstValues, secondValues);
      for (final value in firstValues) {
        expect(value, greaterThanOrEqualTo(0));
        expect(value, lessThan(1));
      }
    });

    test('choose is deterministic, stateful, generic, and non-mutating', () {
      final values = ['A', 'B', 'C'];
      final first = DeterministicRandom(_goldenSeed);
      final second = DeterministicRandom(_goldenSeed);
      final stateful = DeterministicRandom(_goldenSeed);

      expect(first.choose(values), second.choose(values));
      final stateBeforeChoose = stateful.currentState;
      stateful.choose(values);
      final stateAfterFirstChoose = stateful.currentState;
      stateful.choose(values);
      expect(stateAfterFirstChoose, isNot(stateBeforeChoose));
      expect(stateful.currentState, isNot(stateAfterFirstChoose));
      expect(values, ['A', 'B', 'C']);
      expect(DeterministicRandom(_goldenSeed).choose(['only']), 'only');
      expect(DeterministicRandom(_goldenSeed).choose([10, 20, 30]), 30);
      expect(
        DeterministicRandom(
          _goldenSeed,
        ).choose(const [_TestToken('a'), _TestToken('b')]),
        const _TestToken('a'),
      );
      expect(() => first.choose(<String>[]), throwsStateError);
    });

    test('generator v1 shuffle order remains stable', () {
      // If this fails, generated stage layouts may change. Do not refresh this
      // golden value to match implementation drift.
      final original = ['A', 'B', 'C', 'D', 'E'];
      final shuffled = DeterministicRandom(_goldenSeed).shuffled(original);

      expect(shuffled, ['B', 'A', 'E', 'D', 'C']);
      expect(original, ['A', 'B', 'C', 'D', 'E']);
      expect(shuffled, isNot(same(original)));
    });

    test('shuffled is deterministic and preserves elements', () {
      final first = DeterministicRandom(_goldenSeed).shuffled(['A', 'B', 'C']);
      final second = DeterministicRandom(_goldenSeed).shuffled(['A', 'B', 'C']);
      final different = DeterministicRandom(
        _goldenSeed + 1,
      ).shuffled(['A', 'B', 'C']);
      final duplicates = DeterministicRandom(
        _goldenSeed,
      ).shuffled(['A', 'A', 'B', 'B']);

      expect(first, second);
      expect(first, isNot(different));
      expect(DeterministicRandom(_goldenSeed).shuffled(<String>[]), isEmpty);
      expect(DeterministicRandom(_goldenSeed).shuffled(['only']), ['only']);
      expect(first.toSet(), {'A', 'B', 'C'});
      expect(first, hasLength(3));
      expect(duplicates.where((value) => value == 'A'), hasLength(2));
      expect(duplicates.where((value) => value == 'B'), hasLength(2));
    });
  });
}

const _goldenSeed = 2956496806;

class _TestToken {
  const _TestToken(this.id);

  final String id;

  @override
  bool operator ==(Object other) {
    return identical(this, other) || other is _TestToken && other.id == id;
  }

  @override
  int get hashCode => id.length;
}
