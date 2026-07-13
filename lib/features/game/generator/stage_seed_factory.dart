import 'dart:convert';

import 'generator_config.dart';
import 'stage_generation_key.dart';

class StageSeedFactory {
  const StageSeedFactory();

  int create(StageGenerationKey key) {
    return createFromValues(
      generatorVersion: key.generatorVersion,
      level: key.level,
      attempt: key.attempt,
    );
  }

  int createFromValues({
    required int generatorVersion,
    required int level,
    int attempt = 0,
  }) {
    final input = buildCanonicalInput(
      generatorVersion: generatorVersion,
      level: level,
      attempt: attempt,
    );
    final hash = _fnv1a32(utf8.encode(input));
    if (hash == 0) {
      return GeneratorConfig.zeroSeedFallback;
    }
    return hash;
  }

  String canonicalInput(StageGenerationKey key) {
    return buildCanonicalInput(
      generatorVersion: key.generatorVersion,
      level: key.level,
      attempt: key.attempt,
    );
  }

  String buildCanonicalInput({
    required int generatorVersion,
    required int level,
    int attempt = 0,
  }) {
    _validate(
      generatorVersion: generatorVersion,
      level: level,
      attempt: attempt,
    );
    return '${GeneratorConfig.namespace}|'
        'generator=$generatorVersion|'
        'level=$level|'
        'attempt=$attempt';
  }

  int _fnv1a32(List<int> bytes) {
    var hash = GeneratorConfig.fnvOffsetBasis;

    for (final byte in bytes) {
      hash ^= byte;
      hash = (hash * GeneratorConfig.fnvPrime) & GeneratorConfig.uint32Mask;
    }

    return hash;
  }

  void _validate({
    required int generatorVersion,
    required int level,
    required int attempt,
  }) {
    if (generatorVersion < 1) {
      throw ArgumentError.value(
        generatorVersion,
        'generatorVersion',
        '1 이상이어야 합니다.',
      );
    }
    if (level < 1) {
      throw ArgumentError.value(level, 'level', '1 이상이어야 합니다.');
    }
    if (attempt < 0) {
      throw ArgumentError.value(attempt, 'attempt', '0 이상이어야 합니다.');
    }
  }
}
