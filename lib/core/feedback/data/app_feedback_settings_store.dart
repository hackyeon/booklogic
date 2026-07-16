import '../../persistence/application/persistence_health_controller.dart';
import '../../persistence/application/persistence_lifecycle_coordinator.dart';
import '../domain/app_feedback_settings.dart';

abstract interface class AppFeedbackSettingsStore
    implements FlushablePersistenceStore, PersistenceReportProvider {
  Future<AppFeedbackSettings> load();

  Future<void> save(AppFeedbackSettings settings);

  Future<void> saveSoundEnabled(bool enabled);

  Future<void> saveHapticEnabled(bool enabled);
}
