import 'game_progress.dart';

abstract interface class GameProgressStore {
  Future<GameProgress?> read();

  Future<void> write(GameProgress progress);
}
