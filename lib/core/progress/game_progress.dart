import 'dart:convert';

import '../../features/game/generator/generator_version_policy.dart';

class GameProgress {
  const GameProgress._({
    required this.schemaVersion,
    required this.currentLevel,
    required this.highestUnlockedLevel,
    required this.generatorVersion,
  });

  factory GameProgress({
    required int schemaVersion,
    required int currentLevel,
    required int highestUnlockedLevel,
    required int generatorVersion,
  }) {
    _validate(
      schemaVersion: schemaVersion,
      currentLevel: currentLevel,
      highestUnlockedLevel: highestUnlockedLevel,
      generatorVersion: generatorVersion,
    );
    return GameProgress._(
      schemaVersion: schemaVersion,
      currentLevel: currentLevel,
      highestUnlockedLevel: highestUnlockedLevel,
      generatorVersion: generatorVersion,
    );
  }

  factory GameProgress.initial({required int generatorVersion}) {
    return GameProgress(
      schemaVersion: currentSchemaVersion,
      currentLevel: 1,
      highestUnlockedLevel: 1,
      generatorVersion: generatorVersion,
    );
  }

  factory GameProgress.fromJson(Map<String, dynamic> json) {
    try {
      return GameProgress(
        schemaVersion: _readRequiredInt(json, 'schemaVersion'),
        currentLevel: _readRequiredInt(json, 'currentLevel'),
        highestUnlockedLevel: _readRequiredInt(json, 'highestUnlockedLevel'),
        generatorVersion: _readRequiredInt(json, 'generatorVersion'),
      );
    } on FormatException {
      rethrow;
    } on ArgumentError catch (error) {
      throw FormatException(error.message?.toString() ?? error.toString());
    }
  }

  static const currentSchemaVersion = 1;

  final int schemaVersion;
  final int currentLevel;
  final int highestUnlockedLevel;
  final int generatorVersion;

  GameProgress advanceTo({required int level, required int generatorVersion}) {
    if (level != currentLevel + 1) {
      throw ArgumentError.value(level, 'level', 'currentLevel + 1 값이어야 합니다.');
    }
    final expectedVersion = const GeneratorVersionPolicy().versionForLevel(
      level,
    );
    if (generatorVersion != expectedVersion) {
      throw ArgumentError.value(
        generatorVersion,
        'generatorVersion',
        '다음 레벨의 공식 generatorVersion과 같아야 합니다.',
      );
    }

    return GameProgress(
      schemaVersion: schemaVersion,
      currentLevel: level,
      highestUnlockedLevel: highestUnlockedLevel < level
          ? level
          : highestUnlockedLevel,
      generatorVersion: generatorVersion,
    );
  }

  Map<String, Object> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'currentLevel': currentLevel,
      'highestUnlockedLevel': highestUnlockedLevel,
      'generatorVersion': generatorVersion,
    };
  }

  String encode() {
    return jsonEncode(toJson());
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is GameProgress &&
            runtimeType == other.runtimeType &&
            schemaVersion == other.schemaVersion &&
            currentLevel == other.currentLevel &&
            highestUnlockedLevel == other.highestUnlockedLevel &&
            generatorVersion == other.generatorVersion;
  }

  @override
  int get hashCode {
    return Object.hash(
      schemaVersion,
      currentLevel,
      highestUnlockedLevel,
      generatorVersion,
    );
  }

  @override
  String toString() {
    return 'GameProgress('
        'currentLevel: $currentLevel, '
        'highestUnlockedLevel: $highestUnlockedLevel, '
        'generatorVersion: $generatorVersion'
        ')';
  }
}

int _readRequiredInt(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key)) {
    throw FormatException('Missing game progress field: $key');
  }
  final value = json[key];
  if (value is! int) {
    throw FormatException('Game progress field must be an int: $key');
  }
  return value;
}

void _validate({
  required int schemaVersion,
  required int currentLevel,
  required int highestUnlockedLevel,
  required int generatorVersion,
}) {
  if (schemaVersion != GameProgress.currentSchemaVersion) {
    throw ArgumentError.value(
      schemaVersion,
      'schemaVersion',
      '지원하는 schemaVersion은 1입니다.',
    );
  }
  if (currentLevel < 1) {
    throw ArgumentError.value(currentLevel, 'currentLevel', '1 이상이어야 합니다.');
  }
  if (highestUnlockedLevel < 1) {
    throw ArgumentError.value(
      highestUnlockedLevel,
      'highestUnlockedLevel',
      '1 이상이어야 합니다.',
    );
  }
  if (highestUnlockedLevel < currentLevel) {
    throw ArgumentError.value(
      highestUnlockedLevel,
      'highestUnlockedLevel',
      'currentLevel 이상이어야 합니다.',
    );
  }
  if (generatorVersion < 1) {
    throw ArgumentError.value(
      generatorVersion,
      'generatorVersion',
      '1 이상이어야 합니다.',
    );
  }
  const GeneratorVersionPolicy().validate(
    level: currentLevel,
    generatorVersion: generatorVersion,
  );
}
