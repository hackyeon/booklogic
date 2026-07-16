import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:booklogic/core/persistence/application/persistence_health_controller.dart';
import 'package:booklogic/core/persistence/application/persistence_lifecycle_coordinator.dart';
import 'package:booklogic/core/persistence/domain/persistence_document_source.dart';
import 'package:booklogic/core/persistence/domain/persistence_load_report.dart';
import 'package:booklogic/core/persistence/domain/persistence_load_status.dart';

void main() {
  group('PersistenceHealthController', () {
    test('reports recovery notice once', () {
      final provider = _ReportProvider(
        PersistenceLoadReport(
          documentId: 'game_progress',
          status: PersistenceLoadStatus.recoveredBackup,
          source: PersistenceDocumentSource.backup,
          committedRevision: 5,
          canWrite: true,
        ),
      );
      final controller = PersistenceHealthController(providers: [provider]);

      controller.initialize();

      expect(controller.noticeMessage, '저장 데이터를 복구했습니다.');
      controller.consumeNotice();
      expect(controller.noticeMessage, isNull);
      controller.dispose();
    });
  });

  group('PersistenceLifecycleCoordinator', () {
    test('flushes stores on paused but not on resumed', () async {
      final store = _FlushableStore();
      final coordinator = PersistenceLifecycleCoordinator(stores: [store])
        ..attach();

      coordinator.handleLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(store.flushCount, 0);

      coordinator.handleLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(Duration.zero);
      expect(store.flushCount, 1);

      coordinator.dispose();
      coordinator.handleLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(Duration.zero);
      expect(store.flushCount, 1);
    });
  });
}

class _ReportProvider implements PersistenceReportProvider {
  const _ReportProvider(this.lastLoadReport);

  @override
  final PersistenceLoadReport? lastLoadReport;

  @override
  bool get canWrite => true;
}

class _FlushableStore implements FlushablePersistenceStore {
  int flushCount = 0;

  @override
  Future<void> flush() async {
    flushCount += 1;
  }
}
