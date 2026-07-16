import 'package:booklogic/features/game/tutorial/application/learning_progress_store.dart';
import 'package:booklogic/features/game/tutorial/domain/learning_progress.dart';
import 'package:booklogic/core/persistence/domain/persistence_load_report.dart';

class FakeLearningProgressStore implements LearningProgressStore {
  FakeLearningProgressStore({
    LearningProgress? progress,
    List<Object?> saveErrors = const [],
  }) : progress = progress ?? LearningProgress(),
       _saveErrors = List<Object?>.of(saveErrors);

  LearningProgress progress;
  final List<Object?> _saveErrors;
  final saves = <LearningProgress>[];
  PersistenceLoadReport? _lastLoadReport;

  int get saveCount => saves.length;

  @override
  PersistenceLoadReport? get lastLoadReport => _lastLoadReport;

  @override
  bool get canWrite => true;

  @override
  Future<LearningProgress> load() async {
    return progress;
  }

  @override
  Future<void> save(LearningProgress progress) async {
    saves.add(progress);
    this.progress = progress;
    if (_saveErrors.isNotEmpty) {
      final error = _saveErrors.removeAt(0);
      if (error != null) {
        throw StateError(error.toString());
      }
    }
  }

  @override
  Future<void> flush() async {}
}
