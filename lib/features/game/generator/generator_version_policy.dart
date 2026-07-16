import 'generator_config.dart';

class GeneratorVersionPolicy {
  const GeneratorVersionPolicy();

  int versionForLevel(int level) {
    if (level < 1) {
      throw ArgumentError.value(level, 'level', '1 이상이어야 합니다.');
    }
    if (level <= 200) {
      return GeneratorConfig.generatorVersion1;
    }
    if (level <= 400) {
      return GeneratorConfig.generatorVersion2;
    }
    throw UnsupportedError('StageGenerator does not support level $level.');
  }

  bool supports({required int level, required int generatorVersion}) {
    try {
      validate(level: level, generatorVersion: generatorVersion);
      return true;
    } on ArgumentError {
      return false;
    } on UnsupportedError {
      return false;
    }
  }

  void validate({required int level, required int generatorVersion}) {
    if (generatorVersion < 1) {
      throw ArgumentError.value(
        generatorVersion,
        'generatorVersion',
        '1 이상이어야 합니다.',
      );
    }
    final expected = versionForLevel(level);
    if (generatorVersion != expected) {
      throw UnsupportedError(
        'Level $level requires generatorVersion $expected, '
        'but received $generatorVersion.',
      );
    }
  }
}
