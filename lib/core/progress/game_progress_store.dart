import '../persistence/application/persistence_health_controller.dart';
import '../persistence/application/persistence_lifecycle_coordinator.dart';
import 'game_progress.dart';

abstract interface class GameProgressStore
    implements FlushablePersistenceStore, PersistenceReportProvider {
  Future<GameProgress?> read();

  Future<void> write(GameProgress progress);
}
