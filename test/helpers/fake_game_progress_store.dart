import 'dart:async';

import 'package:booklogic/core/progress/game_progress.dart';
import 'package:booklogic/core/progress/game_progress_store.dart';
import 'package:booklogic/core/persistence/domain/persistence_load_report.dart';

class FakeGameProgressStore implements GameProgressStore {
  FakeGameProgressStore({
    this.progress,
    this.readError,
    List<Object?> writeErrors = const [],
    this.readBlocker,
    this.writeBlocker,
  }) : _writeErrors = List<Object?>.of(writeErrors);

  GameProgress? progress;
  Object? readError;
  Completer<void>? readBlocker;
  Completer<void>? writeBlocker;

  final List<Object?> _writeErrors;
  final writes = <GameProgress>[];
  int readCount = 0;
  PersistenceLoadReport? _lastLoadReport;

  int get writeCount => writes.length;

  GameProgress? get lastWrite => writes.isEmpty ? null : writes.last;

  @override
  PersistenceLoadReport? get lastLoadReport => _lastLoadReport;

  @override
  bool get canWrite => true;

  @override
  Future<GameProgress?> read() async {
    readCount += 1;
    final blocker = readBlocker;
    if (blocker != null) {
      await blocker.future;
    }
    final error = readError;
    if (error != null) {
      _throwFakeError(error);
    }
    return progress;
  }

  @override
  Future<void> write(GameProgress progress) async {
    final blocker = writeBlocker;
    if (blocker != null) {
      await blocker.future;
    }
    writes.add(progress);
    if (_writeErrors.isNotEmpty) {
      final error = _writeErrors.removeAt(0);
      if (error != null) {
        _throwFakeError(error);
      }
    }
    this.progress = progress;
  }

  @override
  Future<void> flush() async {}
}

Never _throwFakeError(Object error) {
  if (error is FormatException) {
    throw error;
  }
  if (error is ArgumentError) {
    throw error;
  }
  if (error is StateError) {
    throw error;
  }
  throw StateError(error.toString());
}
