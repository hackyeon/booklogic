import 'package:flutter/foundation.dart';

import '../../features/game/generator/generator_config.dart';
import 'game_progress.dart';
import 'game_progress_store.dart';

enum GameProgressStatus { initial, loading, ready, saving }

class GameProgressController extends ChangeNotifier {
  GameProgressController({
    required GameProgressStore store,
    int defaultGeneratorVersion = GeneratorConfig.currentVersion,
  }) : _store = store,
       _defaultProgress = GameProgress.initial(
         generatorVersion: defaultGeneratorVersion,
       ),
       _progress = GameProgress.initial(
         generatorVersion: defaultGeneratorVersion,
       );

  final GameProgressStore _store;
  final GameProgress _defaultProgress;
  GameProgress _progress;
  GameProgressStatus _status = GameProgressStatus.initial;
  Object? _lastError;
  bool _isDisposed = false;
  Future<void>? _loadFuture;

  GameProgress get progress => _progress;

  GameProgressStatus get status => _status;

  Object? get lastError => _lastError;

  bool get isReady => _status == GameProgressStatus.ready;

  bool get isLoading => _status == GameProgressStatus.loading;

  bool get isSaving => _status == GameProgressStatus.saving;

  int get currentLevel => _progress.currentLevel;

  int get highestUnlockedLevel => _progress.highestUnlockedLevel;

  int get generatorVersion => _progress.generatorVersion;

  Future<void> load() {
    if (_isDisposed) {
      return Future<void>.value();
    }
    final existingLoad = _loadFuture;
    if (existingLoad != null) {
      return existingLoad;
    }

    final future = _load();
    _loadFuture = future.whenComplete(() {
      _loadFuture = null;
    });
    return _loadFuture!;
  }

  Future<void> advanceToLevel({
    required int level,
    required int generatorVersion,
  }) async {
    if (_isDisposed) {
      throw StateError('GameProgressController is disposed.');
    }
    if (_status == GameProgressStatus.saving) {
      throw StateError('Game progress is already saving.');
    }
    if (_status != GameProgressStatus.ready) {
      throw StateError('Game progress is not ready.');
    }

    final nextProgress = _progress.advanceTo(
      level: level,
      generatorVersion: generatorVersion,
    );

    _status = GameProgressStatus.saving;
    _lastError = null;
    _notifySafely();

    try {
      await _store.write(nextProgress);
      if (_isDisposed) {
        return;
      }
      _progress = nextProgress;
      _status = GameProgressStatus.ready;
      _lastError = null;
      _notifySafely();
    } catch (error) {
      if (!_isDisposed) {
        _status = GameProgressStatus.ready;
        _lastError = error;
        _notifySafely();
      }
      rethrow;
    }
  }

  Future<void> _load() async {
    if (_isDisposed) {
      return;
    }

    _status = GameProgressStatus.loading;
    _lastError = null;
    _notifySafely();

    try {
      final storedProgress = await _store.read();
      if (_isDisposed) {
        return;
      }
      _progress = storedProgress ?? _defaultProgress;
      if (storedProgress == null) {
        await _writeDefaultProgressAfterLoad();
      }
    } on FormatException catch (error) {
      await _recoverFromLoadError(error);
    } on ArgumentError catch (error) {
      await _recoverFromLoadError(error);
    } on StateError catch (error) {
      await _recoverFromLoadError(error);
    }

    if (_isDisposed) {
      return;
    }
    _status = GameProgressStatus.ready;
    _notifySafely();
  }

  Future<void> _recoverFromLoadError(Object error) async {
    if (_isDisposed) {
      return;
    }
    _progress = _defaultProgress;
    _lastError = error;
    try {
      await _store.write(_defaultProgress);
    } catch (_) {
      // Keep the original read/parse error so UI can show a generic warning.
    }
  }

  Future<void> _writeDefaultProgressAfterLoad() async {
    try {
      await _store.write(_defaultProgress);
    } catch (error) {
      if (!_isDisposed) {
        _lastError = error;
      }
    }
  }

  void _notifySafely() {
    if (_isDisposed) {
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
