import '../../../../core/persistence/codec/persistence_document_codec.dart';
import '../domain/learning_progress.dart';

class LearningProgressPersistenceCodec
    implements PersistenceDocumentCodec<LearningProgress> {
  const LearningProgressPersistenceCodec();

  @override
  int get currentSchemaVersion => 1;

  @override
  LearningProgress get defaultValue => LearningProgress();

  @override
  Map<String, Object?> encode(LearningProgress value) {
    final ruleCodes = value.acknowledgedRuleCodes.toList()..sort();
    return {
      'tutorialCompleted': value.tutorialCompleted,
      'acknowledgedRuleCodes': ruleCodes,
    };
  }

  @override
  LearningProgress decode({
    required int schemaVersion,
    required Map<String, Object?> payload,
  }) {
    if (schemaVersion != currentSchemaVersion) {
      throw UnsupportedError('Unsupported LearningProgress payload schema.');
    }
    final tutorialCompleted = payload['tutorialCompleted'];
    final acknowledgedRuleCodes = payload['acknowledgedRuleCodes'];
    if (tutorialCompleted is! bool) {
      throw const FormatException('tutorialCompleted must be bool.');
    }
    if (acknowledgedRuleCodes is! List) {
      throw const FormatException('acknowledgedRuleCodes must be list.');
    }
    final codes = <String>[];
    for (final code in acknowledgedRuleCodes) {
      if (code is! String || code.trim().isEmpty) {
        throw const FormatException('rule code must be a non-empty string.');
      }
      codes.add(code.trim());
    }
    return LearningProgress(
      tutorialCompleted: tutorialCompleted,
      acknowledgedRuleCodes: codes,
    );
  }
}
