import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import '../domain/game_sound_cue.dart';
import 'game_sound_player.dart';

class AssetGameSoundPlayer implements GameSoundPlayer {
  AssetGameSoundPlayer({AudioPlayer Function()? playerFactory})
    : _playerFactory = playerFactory ?? AudioPlayer.new;

  final AudioPlayer Function() _playerFactory;
  final Map<GameSoundCue, AudioPlayer> _players = <GameSoundCue, AudioPlayer>{};
  final List<StreamSubscription<void>> _completionSubscriptions =
      <StreamSubscription<void>>[];
  Future<void>? _initializeFuture;
  bool _isInitialized = false;
  bool _isDisposed = false;
  GameSoundCue? _activeCue;

  @override
  Future<void> initialize() {
    if (_isDisposed) {
      return Future<void>.value();
    }
    final existing = _initializeFuture;
    if (existing != null) {
      return existing;
    }
    if (_isInitialized) {
      return Future<void>.value();
    }

    final future = _initialize();
    _initializeFuture = future.whenComplete(() {
      _initializeFuture = null;
    });
    return future;
  }

  @override
  Future<void> play(GameSoundCue cue) async {
    if (_isDisposed) {
      return;
    }
    if (!_isInitialized) {
      return;
    }

    final activeCue = _activeCue;
    if (cue == GameSoundCue.stageClear &&
        activeCue == GameSoundCue.stageClear) {
      return;
    }
    if (cue == GameSoundCue.stageClear && activeCue != null) {
      await stopAll();
    } else if (activeCue != null && activeCue.priority > cue.priority) {
      return;
    }

    final player = _players[cue];
    if (player == null) {
      return;
    }

    await player.stop();
    _activeCue = cue;
    await player.play(AssetSource(cue.assetPath));
  }

  @override
  Future<void> stopAll() async {
    if (_isDisposed) {
      return;
    }
    _activeCue = null;
    for (final player in _players.values) {
      await player.stop();
    }
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    for (final player in _players.values) {
      await player.dispose();
    }
    for (final subscription in _completionSubscriptions) {
      await subscription.cancel();
    }
    _players.clear();
    _completionSubscriptions.clear();
  }

  Future<void> _initialize() async {
    for (final cue in GameSoundCue.values) {
      final player = _playerFactory();
      await player.setReleaseMode(ReleaseMode.stop);
      _completionSubscriptions.add(
        player.onPlayerComplete.listen((_) {
          if (_activeCue == cue) {
            _activeCue = null;
          }
        }),
      );
      _players[cue] = player;
    }
    _isInitialized = true;
  }
}
