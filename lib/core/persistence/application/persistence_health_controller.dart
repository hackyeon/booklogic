import 'package:flutter/foundation.dart';

import '../domain/persistence_load_report.dart';
import '../domain/persistence_load_status.dart';

abstract interface class PersistenceReportProvider {
  PersistenceLoadReport? get lastLoadReport;

  bool get canWrite;
}

class PersistenceHealthController extends ChangeNotifier {
  PersistenceHealthController({
    required Iterable<PersistenceReportProvider> providers,
  }) : _providers = List<PersistenceReportProvider>.unmodifiable(providers);

  final List<PersistenceReportProvider> _providers;
  List<PersistenceLoadReport> _reports = const [];
  bool _isInitialized = false;
  bool _noticeConsumed = false;
  bool _isDisposed = false;

  bool get isInitialized => _isInitialized;

  List<PersistenceLoadReport> get reports =>
      List<PersistenceLoadReport>.unmodifiable(_reports);

  bool get noticeConsumed => _noticeConsumed;

  bool get hasRecoveryNotice {
    return _reports.any((report) => report.wasRecovered);
  }

  bool get hasResetNotice {
    return _reports.any(
      (report) => report.status == PersistenceLoadStatus.resetAfterCorruption,
    );
  }

  bool get hasFutureSchemaNotice {
    return _reports.any(
      (report) => report.status == PersistenceLoadStatus.futureSchemaReadOnly,
    );
  }

  String? get noticeMessage {
    if (_noticeConsumed) {
      return null;
    }
    if (hasFutureSchemaNotice) {
      return '저장 데이터가 더 새로운 앱 버전에서 생성되어 현재 버전에서는 변경 사항을 저장할 수 없습니다.';
    }
    if (hasResetNotice) {
      return '일부 저장 데이터를 불러오지 못해 기본값을 사용합니다.';
    }
    if (hasRecoveryNotice) {
      return '저장 데이터를 복구했습니다.';
    }
    return null;
  }

  void initialize() {
    if (_isDisposed) {
      return;
    }
    _reports = [
      for (final provider in _providers)
        if (provider.lastLoadReport != null) provider.lastLoadReport!,
    ];
    _isInitialized = true;
    notifyListeners();
  }

  void consumeNotice() {
    if (_noticeConsumed) {
      return;
    }
    _noticeConsumed = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
