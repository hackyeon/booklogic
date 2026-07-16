import '../../../../core/persistence/application/persistence_health_controller.dart';
import '../../../../core/persistence/application/persistence_lifecycle_coordinator.dart';
import '../domain/learning_progress.dart';

abstract interface class LearningProgressStore
    implements FlushablePersistenceStore, PersistenceReportProvider {
  Future<LearningProgress> load();

  Future<void> save(LearningProgress progress);
}
