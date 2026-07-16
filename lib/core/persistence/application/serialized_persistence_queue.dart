import 'dart:async';

class SerializedPersistenceQueue {
  Future<void> _tail = Future<void>.value();
  bool _isDisposed = false;

  Future<T> add<T>(Future<T> Function() task) {
    if (_isDisposed) {
      return Future<T>.error(StateError('Persistence queue is disposed.'));
    }

    final completer = Completer<T>();
    _tail = _tail.catchError((_) {}).then((_) async {
      try {
        completer.complete(await task());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<void> flush() {
    return _tail.catchError((_) {});
  }

  void dispose() {
    _isDisposed = true;
  }
}
