import '../../persistence/codec/persistence_document_codec.dart';
import '../domain/app_feedback_settings.dart';

class AppFeedbackSettingsPersistenceCodec
    implements PersistenceDocumentCodec<AppFeedbackSettings> {
  const AppFeedbackSettingsPersistenceCodec();

  @override
  int get currentSchemaVersion => 1;

  @override
  AppFeedbackSettings get defaultValue => AppFeedbackSettings.defaults;

  @override
  Map<String, Object?> encode(AppFeedbackSettings value) {
    return {
      'soundEnabled': value.soundEnabled,
      'hapticEnabled': value.hapticEnabled,
    };
  }

  @override
  AppFeedbackSettings decode({
    required int schemaVersion,
    required Map<String, Object?> payload,
  }) {
    if (schemaVersion != currentSchemaVersion) {
      throw UnsupportedError('Unsupported AppFeedbackSettings payload schema.');
    }
    final soundEnabled = payload['soundEnabled'];
    final hapticEnabled = payload['hapticEnabled'];
    if (soundEnabled is! bool) {
      throw const FormatException('soundEnabled must be bool.');
    }
    if (hapticEnabled is! bool) {
      throw const FormatException('hapticEnabled must be bool.');
    }
    return AppFeedbackSettings(
      soundEnabled: soundEnabled,
      hapticEnabled: hapticEnabled,
    );
  }
}
