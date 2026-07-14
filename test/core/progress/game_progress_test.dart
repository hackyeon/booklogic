import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:booklogic/core/progress/game_progress.dart';

void main() {
  group('GameProgress', () {
    test('initial creates level 1 progress', () {
      final progress = GameProgress.initial(generatorVersion: 1);

      expect(progress.schemaVersion, 1);
      expect(progress.currentLevel, 1);
      expect(progress.highestUnlockedLevel, 1);
      expect(progress.generatorVersion, 1);
    });

    test('validates constructor values', () {
      expect(
        GameProgress(
          schemaVersion: 1,
          currentLevel: 5,
          highestUnlockedLevel: 7,
          generatorVersion: 1,
        ),
        GameProgress(
          schemaVersion: 1,
          currentLevel: 5,
          highestUnlockedLevel: 7,
          generatorVersion: 1,
        ),
      );

      expect(
        () => GameProgress(
          schemaVersion: 0,
          currentLevel: 1,
          highestUnlockedLevel: 1,
          generatorVersion: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => GameProgress(
          schemaVersion: 2,
          currentLevel: 1,
          highestUnlockedLevel: 1,
          generatorVersion: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => GameProgress(
          schemaVersion: 1,
          currentLevel: 0,
          highestUnlockedLevel: 1,
          generatorVersion: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => GameProgress(
          schemaVersion: 1,
          currentLevel: -1,
          highestUnlockedLevel: 1,
          generatorVersion: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => GameProgress(
          schemaVersion: 1,
          currentLevel: 5,
          highestUnlockedLevel: 4,
          generatorVersion: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => GameProgress(
          schemaVersion: 1,
          currentLevel: 1,
          highestUnlockedLevel: 1,
          generatorVersion: 0,
        ),
        throwsArgumentError,
      );
    });

    test(
      'advanceTo accepts only the next level and same generator version',
      () {
        final progress = GameProgress.initial(generatorVersion: 1);
        final advanced = progress.advanceTo(level: 2, generatorVersion: 1);

        expect(advanced.currentLevel, 2);
        expect(advanced.highestUnlockedLevel, 2);
        expect(advanced.generatorVersion, 1);

        expect(
          () => progress.advanceTo(level: 3, generatorVersion: 1),
          throwsArgumentError,
        );
        expect(
          () => progress.advanceTo(level: 1, generatorVersion: 1),
          throwsArgumentError,
        );
        expect(
          () => progress.advanceTo(level: 2, generatorVersion: 2),
          throwsArgumentError,
        );
      },
    );

    test('serializes to exact JSON fields and round trips', () {
      final progress = GameProgress(
        schemaVersion: 1,
        currentLevel: 2,
        highestUnlockedLevel: 3,
        generatorVersion: 1,
      );

      expect(progress.toJson(), {
        'schemaVersion': 1,
        'currentLevel': 2,
        'highestUnlockedLevel': 3,
        'generatorVersion': 1,
      });

      final decoded = jsonDecode(jsonEncode(progress.toJson()));
      expect(GameProgress.fromJson(decoded as Map<String, dynamic>), progress);
    });

    test('rejects malformed JSON values', () {
      expect(
        () => GameProgress.fromJson({
          'currentLevel': 1,
          'highestUnlockedLevel': 1,
          'generatorVersion': 1,
        }),
        throwsFormatException,
      );
      expect(
        () => GameProgress.fromJson({
          'schemaVersion': 1,
          'currentLevel': '1',
          'highestUnlockedLevel': 1,
          'generatorVersion': 1,
        }),
        throwsFormatException,
      );
      expect(
        () => GameProgress.fromJson({
          'schemaVersion': 1,
          'currentLevel': 1.0,
          'highestUnlockedLevel': 1,
          'generatorVersion': 1,
        }),
        throwsFormatException,
      );
      expect(
        () => GameProgress.fromJson({
          'schemaVersion': 1,
          'currentLevel': 0,
          'highestUnlockedLevel': 0,
          'generatorVersion': 1,
        }),
        throwsFormatException,
      );
      expect(
        () => GameProgress.fromJson({
          'schemaVersion': 1,
          'currentLevel': 3,
          'highestUnlockedLevel': 2,
          'generatorVersion': 1,
        }),
        throwsFormatException,
      );
      expect(
        GameProgress.fromJson({
          'schemaVersion': 1,
          'currentLevel': 2,
          'highestUnlockedLevel': 2,
          'generatorVersion': 1,
          'extra': 'ignored',
        }).currentLevel,
        2,
      );
    });

    test('compares by value and prints useful debug fields', () {
      final progress = GameProgress(
        schemaVersion: 1,
        currentLevel: 4,
        highestUnlockedLevel: 5,
        generatorVersion: 1,
      );
      final same = GameProgress(
        schemaVersion: 1,
        currentLevel: 4,
        highestUnlockedLevel: 5,
        generatorVersion: 1,
      );

      expect(progress, same);
      expect(progress.hashCode, same.hashCode);
      expect(progress.toString(), contains('currentLevel: 4'));
      expect(progress.toString(), contains('highestUnlockedLevel: 5'));
      expect(progress.toString(), contains('generatorVersion: 1'));
    });
  });
}
