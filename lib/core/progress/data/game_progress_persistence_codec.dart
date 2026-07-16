import '../../persistence/codec/persistence_document_codec.dart';
import '../../../features/game/generator/generator_version_policy.dart';
import '../game_progress.dart';

class GameProgressPersistenceCodec
    implements PersistenceDocumentCodec<GameProgress> {
  const GameProgressPersistenceCodec({
    GeneratorVersionPolicy generatorVersionPolicy =
        const GeneratorVersionPolicy(),
  }) : _generatorVersionPolicy = generatorVersionPolicy;

  final GeneratorVersionPolicy _generatorVersionPolicy;

  @override
  int get currentSchemaVersion => 1;

  @override
  GameProgress get defaultValue {
    return GameProgress.initial(
      generatorVersion: _generatorVersionPolicy.versionForLevel(1),
    );
  }

  @override
  Map<String, Object?> encode(GameProgress value) {
    return {
      'schemaVersion': value.schemaVersion,
      'currentLevel': value.currentLevel,
      'highestUnlockedLevel': value.highestUnlockedLevel,
      'generatorVersion': value.generatorVersion,
    };
  }

  @override
  GameProgress decode({
    required int schemaVersion,
    required Map<String, Object?> payload,
  }) {
    if (schemaVersion != currentSchemaVersion) {
      throw UnsupportedError('Unsupported GameProgress payload schema.');
    }
    final progressSchemaVersion = _readRequiredInt(payload, 'schemaVersion');
    final currentLevel = _readRequiredInt(payload, 'currentLevel');
    final highestUnlockedLevel = _readRequiredInt(
      payload,
      'highestUnlockedLevel',
    );
    final generatorVersion = _readRequiredInt(payload, 'generatorVersion');

    if (currentLevel > 400 || highestUnlockedLevel > 400) {
      throw FormatException('GameProgress level is outside supported range.');
    }
    _generatorVersionPolicy.validate(
      level: currentLevel,
      generatorVersion: generatorVersion,
    );

    return GameProgress(
      schemaVersion: progressSchemaVersion,
      currentLevel: currentLevel,
      highestUnlockedLevel: highestUnlockedLevel,
      generatorVersion: generatorVersion,
    );
  }

  int _readRequiredInt(Map<String, Object?> payload, String key) {
    if (!payload.containsKey(key)) {
      throw FormatException('Missing GameProgress field: $key');
    }
    final value = payload[key];
    if (value is! int) {
      throw FormatException('GameProgress field must be int: $key');
    }
    return value;
  }
}
