import 'package:flutter_test/flutter_test.dart';

import 'package:booklogic/core/feedback/data/app_feedback_settings_persistence_codec.dart';
import 'package:booklogic/core/feedback/domain/app_feedback_settings.dart';
import 'package:booklogic/core/persistence/application/resilient_json_document_store.dart';
import 'package:booklogic/core/persistence/codec/persistence_envelope_codec.dart';
import 'package:booklogic/core/persistence/domain/persistence_exceptions.dart';
import 'package:booklogic/core/persistence/domain/persistence_issue_code.dart';
import 'package:booklogic/core/persistence/domain/persistence_load_status.dart';
import 'package:booklogic/core/persistence/keys/persistence_keys.dart';

import '../../helpers/fake_local_key_value_store.dart';

void main() {
  group('ResilientJsonDocumentStore', () {
    test(
      'commits primary with marker and keeps backup on second save',
      () async {
        final keyValueStore = FakeLocalKeyValueStore();
        final store = _feedbackStore(keyValueStore);

        await store.save(
          const AppFeedbackSettings(soundEnabled: false, hapticEnabled: true),
        );

        expect(
          keyValueStore.values[PersistenceKeys.feedbackSettings.commitRevision],
          1,
        );
        expect(
          keyValueStore.values[PersistenceKeys.feedbackSettings.primary],
          isA<String>(),
        );
        expect(
          keyValueStore.values[PersistenceKeys.feedbackSettings.pending],
          isNull,
        );
        expect(
          keyValueStore.values[PersistenceKeys.feedbackSettings.backup],
          isNull,
        );

        await store.save(
          const AppFeedbackSettings(soundEnabled: false, hapticEnabled: false),
        );

        expect(
          keyValueStore.values[PersistenceKeys.feedbackSettings.commitRevision],
          2,
        );
        expect(
          keyValueStore.values[PersistenceKeys.feedbackSettings.backup],
          isA<String>(),
        );

        final reloaded = _feedbackStore(keyValueStore);
        final result = await reloaded.load();
        expect(result.value.soundEnabled, isFalse);
        expect(result.value.hapticEnabled, isFalse);
        expect(result.report.status, PersistenceLoadStatus.loadedPrimary);
      },
    );

    test('does not write when saving the committed value again', () async {
      final keyValueStore = FakeLocalKeyValueStore();
      final store = _feedbackStore(keyValueStore);
      final settings = const AppFeedbackSettings(
        soundEnabled: false,
        hapticEnabled: true,
      );

      await store.save(settings);
      final stringWrites = keyValueStore.setStringCalls.length;
      final intWrites = keyValueStore.setIntCalls.length;
      await store.save(settings);

      expect(keyValueStore.setStringCalls.length, stringWrites);
      expect(keyValueStore.setIntCalls.length, intWrites);
    });

    test('recovers committed pending when primary is damaged', () async {
      final pendingRaw = _rawFeedback(
        revision: 6,
        settings: const AppFeedbackSettings(
          soundEnabled: false,
          hapticEnabled: true,
        ),
      );
      final keyValueStore = FakeLocalKeyValueStore(
        initialValues: {
          PersistenceKeys.feedbackSettings.commitRevision: 6,
          PersistenceKeys.feedbackSettings.primary: '{ broken',
          PersistenceKeys.feedbackSettings.pending: pendingRaw,
          PersistenceKeys.feedbackSettings.backup: _rawFeedback(
            revision: 5,
            settings: AppFeedbackSettings.defaults,
          ),
        },
      );

      final result = await _feedbackStore(keyValueStore).load();

      expect(result.value.soundEnabled, isFalse);
      expect(result.report.status, PersistenceLoadStatus.recoveredPending);
      expect(
        keyValueStore.values[PersistenceKeys.feedbackSettings.primary],
        pendingRaw,
      );
      expect(
        keyValueStore.values[PersistenceKeys.feedbackSettings.pending],
        isNull,
      );
    });

    test('recovers backup and lowers commit revision', () async {
      final backupRaw = _rawFeedback(
        revision: 5,
        settings: const AppFeedbackSettings(
          soundEnabled: true,
          hapticEnabled: false,
        ),
      );
      final keyValueStore = FakeLocalKeyValueStore(
        initialValues: {
          PersistenceKeys.feedbackSettings.commitRevision: 6,
          PersistenceKeys.feedbackSettings.primary: '{ broken',
          PersistenceKeys.feedbackSettings.pending: '{ also broken',
          PersistenceKeys.feedbackSettings.backup: backupRaw,
        },
      );

      final result = await _feedbackStore(keyValueStore).load();

      expect(result.value.hapticEnabled, isFalse);
      expect(result.report.status, PersistenceLoadStatus.recoveredBackup);
      expect(
        keyValueStore.values[PersistenceKeys.feedbackSettings.commitRevision],
        5,
      );
      expect(
        keyValueStore.values[PersistenceKeys.feedbackSettings.primary],
        backupRaw,
      );
    });

    test('ignores uncommitted primary written before commit marker', () async {
      final backupRaw = _rawFeedback(
        revision: 10,
        settings: AppFeedbackSettings.defaults,
      );
      final keyValueStore = FakeLocalKeyValueStore(
        initialValues: {
          PersistenceKeys.feedbackSettings.commitRevision: 10,
          PersistenceKeys.feedbackSettings.primary: _rawFeedback(
            revision: 11,
            settings: const AppFeedbackSettings(
              soundEnabled: false,
              hapticEnabled: false,
            ),
          ),
          PersistenceKeys.feedbackSettings.backup: backupRaw,
        },
      );

      final result = await _feedbackStore(keyValueStore).load();

      expect(result.value, AppFeedbackSettings.defaults);
      expect(result.report.status, PersistenceLoadStatus.recoveredBackup);
      expect(
        result.report.issues.map((issue) => issue.code),
        contains(PersistenceIssueCode.uncommittedPrimaryIgnored),
      );
    });

    test('detects checksum mismatch', () async {
      final raw = _rawFeedback(
        revision: 1,
        settings: AppFeedbackSettings.defaults,
      ).replaceFirst('"soundEnabled":true', '"soundEnabled":false');
      final keyValueStore = FakeLocalKeyValueStore(
        initialValues: {
          PersistenceKeys.feedbackSettings.commitRevision: 1,
          PersistenceKeys.feedbackSettings.primary: raw,
        },
      );

      final result = await _feedbackStore(keyValueStore).load();

      expect(result.report.status, PersistenceLoadStatus.resetAfterCorruption);
      expect(
        result.report.issues.map((issue) => issue.code),
        contains(PersistenceIssueCode.checksumMismatch),
      );
    });

    test('keeps future schema data read-only', () async {
      final keyValueStore = FakeLocalKeyValueStore(
        initialValues: {
          PersistenceKeys.feedbackSettings.commitRevision: 1,
          PersistenceKeys.feedbackSettings.primary:
              const PersistenceEnvelopeCodec().encode(
                payloadSchemaVersion: 2,
                revision: 1,
                payload: const AppFeedbackSettingsPersistenceCodec().encode(
                  AppFeedbackSettings.defaults,
                ),
              ),
        },
      );
      final store = _feedbackStore(keyValueStore);

      final result = await store.load();

      expect(result.report.status, PersistenceLoadStatus.futureSchemaReadOnly);
      expect(store.canWrite, isFalse);
      await expectLater(
        store.save(
          const AppFeedbackSettings(soundEnabled: false, hapticEnabled: true),
        ),
        throwsA(isA<PersistenceReadOnlyException>()),
      );
    });

    test('queue continues after a failed commit', () async {
      final keyValueStore = FakeLocalKeyValueStore()
        ..failNextSetString(PersistenceKeys.feedbackSettings.primary, false);
      final store = _feedbackStore(keyValueStore);

      await expectLater(
        store.save(
          const AppFeedbackSettings(soundEnabled: false, hapticEnabled: true),
        ),
        throwsA(isA<PersistenceWriteException>()),
      );
      await store.save(
        const AppFeedbackSettings(soundEnabled: true, hapticEnabled: false),
      );

      expect(
        keyValueStore.values[PersistenceKeys.feedbackSettings.commitRevision],
        1,
      );
      final result = await _feedbackStore(keyValueStore).load();
      expect(result.value.hapticEnabled, isFalse);
    });

    test('commit marker failure keeps previous committed value', () async {
      final keyValueStore = FakeLocalKeyValueStore();
      final store = _feedbackStore(keyValueStore);
      await store.save(
        const AppFeedbackSettings(soundEnabled: false, hapticEnabled: true),
      );

      keyValueStore.failNextSetInt(
        PersistenceKeys.feedbackSettings.commitRevision,
        false,
      );
      await expectLater(
        store.save(
          const AppFeedbackSettings(soundEnabled: true, hapticEnabled: false),
        ),
        throwsA(isA<PersistenceWriteException>()),
      );

      final result = await _feedbackStore(keyValueStore).load();
      expect(result.value.soundEnabled, isFalse);
      expect(result.value.hapticEnabled, isTrue);
      expect(
        keyValueStore.values[PersistenceKeys.feedbackSettings.commitRevision],
        1,
      );
    });

    test('cleanup failure does not roll back a completed commit', () async {
      final keyValueStore = FakeLocalKeyValueStore()
        ..failNextRemove(PersistenceKeys.feedbackSettings.pending, false);
      final store = _feedbackStore(keyValueStore);

      await store.save(
        const AppFeedbackSettings(soundEnabled: false, hapticEnabled: true),
      );

      expect(
        keyValueStore.values[PersistenceKeys.feedbackSettings.commitRevision],
        1,
      );
      expect(
        keyValueStore.values[PersistenceKeys.feedbackSettings.pending],
        isA<String>(),
      );

      final result = await _feedbackStore(keyValueStore).load();
      expect(result.report.status, PersistenceLoadStatus.loadedPrimary);
      expect(result.value.soundEnabled, isFalse);
    });
  });
}

ResilientJsonDocumentStore<AppFeedbackSettings> _feedbackStore(
  FakeLocalKeyValueStore keyValueStore,
) {
  return ResilientJsonDocumentStore<AppFeedbackSettings>(
    keyValueStore: keyValueStore,
    keys: PersistenceKeys.feedbackSettings,
    codec: const AppFeedbackSettingsPersistenceCodec(),
  );
}

String _rawFeedback({
  required int revision,
  required AppFeedbackSettings settings,
}) {
  return const PersistenceEnvelopeCodec().encode(
    payloadSchemaVersion:
        const AppFeedbackSettingsPersistenceCodec().currentSchemaVersion,
    revision: revision,
    payload: const AppFeedbackSettingsPersistenceCodec().encode(settings),
  );
}
