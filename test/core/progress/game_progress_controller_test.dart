import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:booklogic/core/progress/game_progress.dart';
import 'package:booklogic/core/progress/game_progress_controller.dart';

import '../../helpers/fake_game_progress_store.dart';

void main() {
  group('GameProgressController', () {
    test('loads default progress and stores it when no data exists', () async {
      final store = FakeGameProgressStore();
      final controller = GameProgressController(store: store);
      final statuses = <GameProgressStatus>[];
      controller.addListener(() => statuses.add(controller.status));

      await controller.load();

      expect(statuses, contains(GameProgressStatus.loading));
      expect(controller.status, GameProgressStatus.ready);
      expect(controller.currentLevel, 1);
      expect(controller.highestUnlockedLevel, 1);
      expect(controller.generatorVersion, 1);
      expect(store.readCount, 1);
      expect(store.writeCount, 1);
      expect(store.lastWrite, GameProgress.initial(generatorVersion: 1));

      controller.dispose();
    });

    test('loads stored progress values', () async {
      final stored = GameProgress(
        schemaVersion: 1,
        currentLevel: 5,
        highestUnlockedLevel: 8,
        generatorVersion: 1,
      );
      final store = FakeGameProgressStore(progress: stored);
      final controller = GameProgressController(store: store);

      await controller.load();

      expect(controller.progress, stored);
      expect(store.writeCount, 0);

      controller.dispose();
    });

    test('recovers corrupted progress and remains usable', () async {
      final store = FakeGameProgressStore(
        readError: const FormatException('broken'),
      );
      final controller = GameProgressController(store: store);

      await controller.load();

      expect(controller.status, GameProgressStatus.ready);
      expect(controller.currentLevel, 1);
      expect(controller.lastError, isA<FormatException>());
      expect(store.writeCount, 1);
      expect(store.lastWrite, GameProgress.initial(generatorVersion: 1));

      controller.dispose();
    });

    test('does not run duplicate reads while loading', () async {
      final blocker = Completer<void>();
      final store = FakeGameProgressStore(readBlocker: blocker);
      final controller = GameProgressController(store: store);

      final first = controller.load();
      final second = controller.load();

      expect(store.readCount, 1);
      blocker.complete();
      await Future.wait([first, second]);
      expect(controller.status, GameProgressStatus.ready);
      expect(store.readCount, 1);

      controller.dispose();
    });

    test('saving advances only after store write succeeds', () async {
      final store = FakeGameProgressStore(
        progress: GameProgress.initial(generatorVersion: 1),
      );
      final controller = GameProgressController(store: store);
      await controller.load();

      await controller.advanceToLevel(level: 2, generatorVersion: 1);

      expect(store.writeCount, 1);
      expect(store.lastWrite?.currentLevel, 2);
      expect(controller.currentLevel, 2);
      expect(controller.highestUnlockedLevel, 2);
      expect(controller.status, GameProgressStatus.ready);
      expect(controller.lastError, isNull);

      await controller.advanceToLevel(level: 3, generatorVersion: 1);

      expect(store.writeCount, 2);
      expect(controller.currentLevel, 3);
      expect(controller.highestUnlockedLevel, 3);

      controller.dispose();
    });

    test('saving failure rolls back and can be retried', () async {
      final store = FakeGameProgressStore(
        progress: GameProgress.initial(generatorVersion: 1),
        writeErrors: [StateError('disk full')],
      );
      final controller = GameProgressController(store: store);
      await controller.load();

      await expectLater(
        controller.advanceToLevel(level: 2, generatorVersion: 1),
        throwsStateError,
      );

      expect(controller.status, GameProgressStatus.ready);
      expect(controller.currentLevel, 1);
      expect(controller.highestUnlockedLevel, 1);
      expect(controller.lastError, isA<StateError>());

      await controller.advanceToLevel(level: 2, generatorVersion: 1);

      expect(controller.currentLevel, 2);
      expect(controller.highestUnlockedLevel, 2);

      controller.dispose();
    });

    test('rejects invalid advance requests and duplicate saves', () async {
      final blocker = Completer<void>();
      final store = FakeGameProgressStore(
        progress: GameProgress.initial(generatorVersion: 1),
        writeBlocker: blocker,
      );
      final controller = GameProgressController(store: store);
      await controller.load();

      expect(
        () => controller.advanceToLevel(level: 3, generatorVersion: 1),
        throwsArgumentError,
      );
      expect(
        () => controller.advanceToLevel(level: 2, generatorVersion: 2),
        throwsArgumentError,
      );

      final firstSave = controller.advanceToLevel(
        level: 2,
        generatorVersion: 1,
      );
      expect(controller.status, GameProgressStatus.saving);
      await expectLater(
        controller.advanceToLevel(level: 2, generatorVersion: 1),
        throwsStateError,
      );

      blocker.complete();
      await firstSave;

      expect(store.writeCount, 1);
      expect(controller.currentLevel, 2);

      controller.dispose();
    });

    test('dispose during load completion is safe', () async {
      final blocker = Completer<void>();
      final store = FakeGameProgressStore(readBlocker: blocker);
      final controller = GameProgressController(store: store);

      final load = controller.load();
      controller.dispose();
      blocker.complete();

      await load;
    });
  });
}
