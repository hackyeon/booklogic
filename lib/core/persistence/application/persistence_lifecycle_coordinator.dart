import 'dart:async';

import 'package:flutter/widgets.dart';

abstract interface class FlushablePersistenceStore {
  Future<void> flush();
}

class PersistenceLifecycleCoordinator {
  PersistenceLifecycleCoordinator({
    required Iterable<FlushablePersistenceStore> stores,
  }) : _stores = List<FlushablePersistenceStore>.unmodifiable(stores);

  final List<FlushablePersistenceStore> _stores;
  bool _isAttached = false;
  bool _isDisposed = false;

  void attach() {
    if (_isDisposed) {
      return;
    }
    _isAttached = true;
  }

  Future<void> flushAll() async {
    await Future.wait([for (final store in _stores) store.flush()]);
  }

  void handleLifecycleState(AppLifecycleState state) {
    if (!_isAttached || _isDisposed) {
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(flushAll());
    }
  }

  void dispose() {
    _isDisposed = true;
    _isAttached = false;
  }
}
