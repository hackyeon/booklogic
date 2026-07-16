import 'package:flutter_test/flutter_test.dart';

import 'package:booklogic/core/progress/data/game_progress_persistence_codec.dart';
import 'package:booklogic/core/progress/game_progress.dart';

void main() {
  group('GameProgressPersistenceCodec', () {
    const codec = GameProgressPersistenceCodec();

    test('round-trips supported level and generator version boundaries', () {
      for (final progress in [
        GameProgress(
          schemaVersion: 1,
          currentLevel: 1,
          highestUnlockedLevel: 1,
          generatorVersion: 1,
        ),
        GameProgress(
          schemaVersion: 1,
          currentLevel: 200,
          highestUnlockedLevel: 200,
          generatorVersion: 1,
        ),
        GameProgress(
          schemaVersion: 1,
          currentLevel: 201,
          highestUnlockedLevel: 201,
          generatorVersion: 2,
        ),
        GameProgress(
          schemaVersion: 1,
          currentLevel: 400,
          highestUnlockedLevel: 400,
          generatorVersion: 2,
        ),
      ]) {
        expect(
          codec.decode(schemaVersion: 1, payload: codec.encode(progress)),
          progress,
        );
      }
    });

    test('rejects invalid payloads strictly', () {
      expect(
        () => codec.decode(
          schemaVersion: 1,
          payload: {
            'schemaVersion': 1,
            'currentLevel': 0,
            'highestUnlockedLevel': 1,
            'generatorVersion': 1,
          },
        ),
        throwsA(anything),
      );
      expect(
        () => codec.decode(
          schemaVersion: 1,
          payload: {
            'schemaVersion': 1,
            'currentLevel': 201,
            'highestUnlockedLevel': 201,
            'generatorVersion': 1,
          },
        ),
        throwsA(anything),
      );
      expect(
        () => codec.decode(
          schemaVersion: 1,
          payload: {
            'schemaVersion': 1,
            'currentLevel': '201',
            'highestUnlockedLevel': 201,
            'generatorVersion': 2,
          },
        ),
        throwsFormatException,
      );
      expect(
        () => codec.decode(
          schemaVersion: 2,
          payload: codec.encode(GameProgress.initial(generatorVersion: 1)),
        ),
        throwsUnsupportedError,
      );
    });
  });
}
