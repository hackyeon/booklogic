import '../codec/persistence_document_codec.dart';
import '../codec/persistence_envelope_codec.dart';
import '../data/local_key_value_store.dart';
import '../domain/persistence_commit_result.dart';
import '../domain/persistence_document_source.dart';
import '../domain/persistence_exceptions.dart';
import '../domain/persistence_issue.dart';
import '../domain/persistence_issue_code.dart';
import '../domain/persistence_load_report.dart';
import '../domain/persistence_load_status.dart';
import '../keys/persistence_keys.dart';
import '../migration/legacy_persistence_reader.dart';
import 'serialized_persistence_queue.dart';

class ResilientJsonDocumentLoadResult<T> {
  const ResilientJsonDocumentLoadResult({
    required this.value,
    required this.report,
    required this.hadNoStoredValue,
  });

  final T value;
  final PersistenceLoadReport report;
  final bool hadNoStoredValue;
}

class ResilientJsonDocumentStore<T> {
  ResilientJsonDocumentStore({
    required LocalKeyValueStore keyValueStore,
    required PersistenceDocumentKeys keys,
    required PersistenceDocumentCodec<T> codec,
    LegacyPersistenceReader<T>? legacyReader,
    PersistenceEnvelopeCodec envelopeCodec = const PersistenceEnvelopeCodec(),
    SerializedPersistenceQueue? queue,
  }) : _keyValueStore = keyValueStore,
       _keys = keys,
       _codec = codec,
       _legacyReader = legacyReader,
       _envelopeCodec = envelopeCodec,
       _queue = queue ?? SerializedPersistenceQueue();

  final LocalKeyValueStore _keyValueStore;
  final PersistenceDocumentKeys _keys;
  final PersistenceDocumentCodec<T> _codec;
  final LegacyPersistenceReader<T>? _legacyReader;
  final PersistenceEnvelopeCodec _envelopeCodec;
  final SerializedPersistenceQueue _queue;

  Future<ResilientJsonDocumentLoadResult<T>>? _loadFuture;
  PersistenceLoadReport? _lastLoadReport;
  T? _committedValue;
  String? _committedRaw;
  int? _committedRevision;
  bool _hasLoaded = false;
  bool _canWrite = true;

  PersistenceLoadReport? get lastLoadReport => _lastLoadReport;

  bool get canWrite => _canWrite;

  int? get committedRevision => _committedRevision;

  Future<ResilientJsonDocumentLoadResult<T>> load() {
    if (_hasLoaded) {
      return Future.value(
        ResilientJsonDocumentLoadResult<T>(
          value: _committedValue ?? _codec.defaultValue,
          report: _lastLoadReport ?? _defaultReport(),
          hadNoStoredValue: false,
        ),
      );
    }

    final existing = _loadFuture;
    if (existing != null) {
      return existing;
    }

    final future = _load(persistDefault: true);
    _loadFuture = future.whenComplete(() {
      _loadFuture = null;
    });
    return _loadFuture!;
  }

  Future<PersistenceCommitResult> save(T value) {
    return _queue.add(() async {
      if (!_hasLoaded) {
        await _load(persistDefault: false);
      }
      if (!_canWrite) {
        throw PersistenceReadOnlyException(
          '${_keys.documentId} is read-only because it was created by a newer schema.',
        );
      }
      if (_committedRevision != null && _committedValue == value) {
        return PersistenceCommitResult(
          committed: false,
          previousRevision: _committedRevision!,
          committedRevision: _committedRevision,
          cleanupSucceeded: true,
        );
      }
      return _commitValue(value);
    });
  }

  Future<void> flush() => _queue.flush();

  void dispose() {
    _queue.dispose();
  }

  Future<ResilientJsonDocumentLoadResult<T>> _load({
    required bool persistDefault,
  }) async {
    final issues = <PersistenceIssue>[];
    final commitRevision = _readCommitRevision(issues);
    final primaryRaw = _keyValueStore.getString(_keys.primary);
    final pendingRaw = _keyValueStore.getString(_keys.pending);
    final backupRaw = _keyValueStore.getString(_keys.backup);
    final hasAnyDocument =
        primaryRaw != null || pendingRaw != null || backupRaw != null;

    if (hasAnyDocument && commitRevision == null) {
      issues.add(
        const PersistenceIssue(
          code: PersistenceIssueCode.missingCommitRevision,
        ),
      );
    }

    final primary = _decodeCandidate(
      raw: primaryRaw,
      source: PersistenceDocumentSource.primary,
      issues: issues,
    );
    final pending = _decodeCandidate(
      raw: pendingRaw,
      source: PersistenceDocumentSource.pending,
      issues: issues,
    );
    final backup = _decodeCandidate(
      raw: backupRaw,
      source: PersistenceDocumentSource.backup,
      issues: issues,
    );

    final futureCandidate = _firstCommittedFutureCandidate(
      commitRevision: commitRevision,
      candidates: [primary, pending, backup],
    );
    if (futureCandidate != null) {
      return _finishLoad(
        value: _codec.defaultValue,
        raw: null,
        revision: null,
        canWrite: false,
        status: PersistenceLoadStatus.futureSchemaReadOnly,
        source: futureCandidate.source,
        issues: [
          ...issues,
          PersistenceIssue(
            code: PersistenceIssueCode.futureSchemaReadOnly,
            source: futureCandidate.source,
            revision: futureCandidate.revision,
          ),
        ],
        hadNoStoredValue: false,
      );
    }

    if (commitRevision != null && primary?.isUsable == true) {
      if (primary!.revision == commitRevision) {
        await _cleanupUncommittedPending(pending, commitRevision, issues);
        return _finishLoad(
          value: primary.value as T,
          raw: primary.raw,
          revision: primary.revision,
          canWrite: true,
          status: PersistenceLoadStatus.loadedPrimary,
          source: PersistenceDocumentSource.primary,
          issues: issues,
          hadNoStoredValue: false,
        );
      }
      issues.add(
        PersistenceIssue(
          code: primary.revision > commitRevision
              ? PersistenceIssueCode.uncommittedPrimaryIgnored
              : PersistenceIssueCode.revisionMismatch,
          source: PersistenceDocumentSource.primary,
          revision: primary.revision,
        ),
      );
    }

    if (commitRevision != null && pending?.isUsable == true) {
      if (pending!.revision == commitRevision) {
        issues.add(
          PersistenceIssue(
            code: PersistenceIssueCode.primaryRecoveredFromPending,
            source: PersistenceDocumentSource.pending,
            revision: pending.revision,
          ),
        );
        await _copyToPrimaryAndVerify(pending, issues);
        await _cleanupPending(issues);
        return _finishLoad(
          value: pending.value as T,
          raw: pending.raw,
          revision: pending.revision,
          canWrite: true,
          status: PersistenceLoadStatus.recoveredPending,
          source: PersistenceDocumentSource.pending,
          issues: issues,
          hadNoStoredValue: false,
        );
      }
      if (pending.revision > commitRevision) {
        issues.add(
          PersistenceIssue(
            code: PersistenceIssueCode.uncommittedPendingIgnored,
            source: PersistenceDocumentSource.pending,
            revision: pending.revision,
          ),
        );
      }
    }

    final backupToUse = _selectBackup(backup, commitRevision);
    if (backupToUse != null) {
      issues.add(
        PersistenceIssue(
          code: PersistenceIssueCode.primaryRecoveredFromBackup,
          source: PersistenceDocumentSource.backup,
          revision: backupToUse.revision,
        ),
      );
      await _copyToPrimaryAndVerify(backupToUse, issues);
      await _writeCommitRevisionBestEffort(backupToUse.revision, issues);
      await _cleanupPending(issues);
      return _finishLoad(
        value: backupToUse.value as T,
        raw: backupToUse.raw,
        revision: backupToUse.revision,
        canWrite: true,
        status: PersistenceLoadStatus.recoveredBackup,
        source: PersistenceDocumentSource.backup,
        issues: issues,
        hadNoStoredValue: false,
      );
    }

    final legacy = _legacyReader?.read();
    if (legacy != null) {
      issues.addAll(legacy.issues);
      try {
        await _commitValue(legacy.value, forceRevision: 1);
      } catch (_) {
        issues.add(
          const PersistenceIssue(
            code: PersistenceIssueCode.migrationWriteFailed,
            source: PersistenceDocumentSource.legacy,
          ),
        );
      }
      final revision = _committedValue == legacy.value
          ? _committedRevision
          : null;
      return _finishLoad(
        value: legacy.value,
        raw: _committedValue == legacy.value ? _committedRaw : null,
        revision: revision,
        canWrite: true,
        status: PersistenceLoadStatus.migratedLegacy,
        source: PersistenceDocumentSource.legacy,
        issues: issues,
        hadNoStoredValue: false,
      );
    }

    if (hasAnyDocument) {
      issues.add(
        const PersistenceIssue(code: PersistenceIssueCode.allDocumentsInvalid),
      );
    }

    final defaultValue = _codec.defaultValue;
    if (persistDefault) {
      try {
        await _commitValue(defaultValue, forceRevision: 1);
      } catch (_) {
        issues.add(
          const PersistenceIssue(code: PersistenceIssueCode.commitFailed),
        );
      }
    }

    return _finishLoad(
      value: defaultValue,
      raw: _committedValue == defaultValue ? _committedRaw : null,
      revision: _committedValue == defaultValue ? _committedRevision : null,
      canWrite: true,
      status: hasAnyDocument
          ? PersistenceLoadStatus.resetAfterCorruption
          : PersistenceLoadStatus.createdDefault,
      source: PersistenceDocumentSource.defaultValue,
      issues: issues,
      hadNoStoredValue: !hasAnyDocument,
    );
  }

  Future<PersistenceCommitResult> _commitValue(
    T value, {
    int? forceRevision,
  }) async {
    final issues = <PersistenceIssue>[];
    final previousRevision = _committedRevision ?? 0;
    final nextRevision = forceRevision ?? previousRevision + 1;
    final previousRaw = _committedRaw;
    final payload = _codec.encode(value);
    final raw = _envelopeCodec.encode(
      payloadSchemaVersion: _codec.currentSchemaVersion,
      revision: nextRevision,
      payload: payload,
    );

    var primaryMayNeedRollback = false;
    try {
      await _writeStringOrThrow(_keys.pending, raw);
      _verifyStoredRaw(
        raw: _keyValueStore.getString(_keys.pending),
        source: PersistenceDocumentSource.pending,
        expectedRevision: nextRevision,
      );

      if (previousRaw != null) {
        await _writeStringOrThrow(_keys.backup, previousRaw);
      }

      await _writeStringOrThrow(_keys.primary, raw);
      primaryMayNeedRollback = true;
      _verifyStoredRaw(
        raw: _keyValueStore.getString(_keys.primary),
        source: PersistenceDocumentSource.primary,
        expectedRevision: nextRevision,
      );

      await _writeIntOrThrow(_keys.commitRevision, nextRevision);
    } catch (error) {
      if (primaryMayNeedRollback) {
        await _rollbackPrimary(previousRaw);
      }
      await _removeBestEffort(_keys.pending);
      throw PersistenceWriteException(
        'Failed to commit ${_keys.documentId}.',
        code: PersistenceIssueCode.commitFailed,
      );
    }

    _committedValue = value;
    _committedRaw = raw;
    _committedRevision = nextRevision;
    _canWrite = true;
    _hasLoaded = true;

    final cleanupSucceeded = await _removeBestEffort(_keys.pending);
    if (!cleanupSucceeded) {
      issues.add(
        PersistenceIssue(
          code: PersistenceIssueCode.cleanupFailed,
          source: PersistenceDocumentSource.pending,
          revision: nextRevision,
        ),
      );
    }

    return PersistenceCommitResult(
      committed: true,
      previousRevision: previousRevision,
      committedRevision: nextRevision,
      cleanupSucceeded: cleanupSucceeded,
      issues: issues,
    );
  }

  int? _readCommitRevision(List<PersistenceIssue> issues) {
    final revision = _keyValueStore.getInt(_keys.commitRevision);
    if (revision == null) {
      return null;
    }
    if (revision < 1) {
      issues.add(
        PersistenceIssue(
          code: PersistenceIssueCode.invalidEnvelope,
          revision: revision,
        ),
      );
      return null;
    }
    return revision;
  }

  _DecodedCandidate<T>? _decodeCandidate({
    required String? raw,
    required PersistenceDocumentSource source,
    required List<PersistenceIssue> issues,
  }) {
    if (raw == null) {
      return null;
    }
    try {
      final envelope = _envelopeCodec.decode(
        raw: raw,
        supportedPayloadSchemaVersion: _codec.currentSchemaVersion,
      );
      final value = _codec.decode(
        schemaVersion: envelope.payloadSchemaVersion,
        payload: envelope.payload,
      );
      return _DecodedCandidate<T>(
        source: source,
        raw: raw,
        revision: envelope.revision,
        value: value,
      );
    } on PersistenceFutureSchemaException catch (error) {
      return _DecodedCandidate<T>.futureSchema(
        source: source,
        raw: raw,
        revision: error.revision,
      );
    } on PersistenceDecodeException catch (error) {
      issues.add(
        PersistenceIssue(
          code: error.code,
          source: source,
          revision: error.revision,
        ),
      );
    } on FormatException {
      issues.add(
        PersistenceIssue(
          code: PersistenceIssueCode.invalidPayload,
          source: source,
        ),
      );
    } on ArgumentError {
      issues.add(
        PersistenceIssue(
          code: PersistenceIssueCode.invalidPayload,
          source: source,
        ),
      );
    } on UnsupportedError {
      issues.add(
        PersistenceIssue(
          code: PersistenceIssueCode.unsupportedPayloadSchema,
          source: source,
        ),
      );
    }
    return null;
  }

  _DecodedCandidate<T>? _firstCommittedFutureCandidate({
    required int? commitRevision,
    required List<_DecodedCandidate<T>?> candidates,
  }) {
    if (commitRevision == null) {
      return null;
    }
    for (final candidate in candidates) {
      if (candidate?.isFutureSchema == true &&
          candidate!.revision == commitRevision) {
        return candidate;
      }
    }
    return null;
  }

  _DecodedCandidate<T>? _selectBackup(
    _DecodedCandidate<T>? backup,
    int? commitRevision,
  ) {
    if (commitRevision == null || backup?.isUsable != true) {
      return null;
    }
    return backup!.revision <= commitRevision ? backup : null;
  }

  Future<void> _cleanupUncommittedPending(
    _DecodedCandidate<T>? pending,
    int commitRevision,
    List<PersistenceIssue> issues,
  ) async {
    if (pending?.isUsable == true && pending!.revision > commitRevision) {
      issues.add(
        PersistenceIssue(
          code: PersistenceIssueCode.uncommittedPendingIgnored,
          source: PersistenceDocumentSource.pending,
          revision: pending.revision,
        ),
      );
      await _cleanupPending(issues);
    }
  }

  Future<void> _copyToPrimaryAndVerify(
    _DecodedCandidate<T> candidate,
    List<PersistenceIssue> issues,
  ) async {
    try {
      await _writeStringOrThrow(_keys.primary, candidate.raw);
      _verifyStoredRaw(
        raw: _keyValueStore.getString(_keys.primary),
        source: PersistenceDocumentSource.primary,
        expectedRevision: candidate.revision,
      );
    } catch (_) {
      issues.add(
        PersistenceIssue(
          code: PersistenceIssueCode.commitFailed,
          source: candidate.source,
          revision: candidate.revision,
        ),
      );
    }
  }

  Future<void> _writeCommitRevisionBestEffort(
    int revision,
    List<PersistenceIssue> issues,
  ) async {
    try {
      await _writeIntOrThrow(_keys.commitRevision, revision);
    } catch (_) {
      issues.add(
        PersistenceIssue(
          code: PersistenceIssueCode.commitFailed,
          revision: revision,
        ),
      );
    }
  }

  Future<void> _cleanupPending(List<PersistenceIssue> issues) async {
    final removed = await _removeBestEffort(_keys.pending);
    if (!removed) {
      issues.add(
        const PersistenceIssue(
          code: PersistenceIssueCode.cleanupFailed,
          source: PersistenceDocumentSource.pending,
        ),
      );
    }
  }

  ResilientJsonDocumentLoadResult<T> _finishLoad({
    required T value,
    required String? raw,
    required int? revision,
    required bool canWrite,
    required PersistenceLoadStatus status,
    required PersistenceDocumentSource source,
    required List<PersistenceIssue> issues,
    required bool hadNoStoredValue,
  }) {
    _committedValue = value;
    _committedRaw = raw;
    _committedRevision = revision;
    _canWrite = canWrite;
    _hasLoaded = true;
    final report = PersistenceLoadReport(
      documentId: _keys.documentId,
      status: status,
      source: source,
      committedRevision: revision,
      canWrite: canWrite,
      issues: issues,
    );
    _lastLoadReport = report;
    return ResilientJsonDocumentLoadResult<T>(
      value: value,
      report: report,
      hadNoStoredValue: hadNoStoredValue,
    );
  }

  PersistenceLoadReport _defaultReport() {
    return PersistenceLoadReport(
      documentId: _keys.documentId,
      status: PersistenceLoadStatus.createdDefault,
      source: PersistenceDocumentSource.defaultValue,
      committedRevision: null,
      canWrite: _canWrite,
    );
  }

  Future<void> _writeStringOrThrow(String key, String value) async {
    final success = await _keyValueStore.setString(key, value);
    if (!success) {
      throw PersistenceWriteException('Failed to write $key.');
    }
  }

  Future<void> _writeIntOrThrow(String key, int value) async {
    final success = await _keyValueStore.setInt(key, value);
    if (!success) {
      throw PersistenceWriteException('Failed to write $key.');
    }
  }

  Future<bool> _removeBestEffort(String key) async {
    try {
      return await _keyValueStore.remove(key);
    } catch (_) {
      return false;
    }
  }

  Future<void> _rollbackPrimary(String? previousRaw) async {
    try {
      if (previousRaw == null) {
        await _keyValueStore.remove(_keys.primary);
      } else {
        await _keyValueStore.setString(_keys.primary, previousRaw);
      }
    } catch (_) {
      // The next load can still recover via backup or commit revision.
    }
  }

  void _verifyStoredRaw({
    required String? raw,
    required PersistenceDocumentSource source,
    required int expectedRevision,
  }) {
    if (raw == null) {
      throw PersistenceWriteException('Missing readback for $source.');
    }
    final candidate = _decodeCandidate(
      raw: raw,
      source: source,
      issues: <PersistenceIssue>[],
    );
    if (candidate?.isUsable != true ||
        candidate!.revision != expectedRevision) {
      throw PersistenceWriteException('Invalid readback for $source.');
    }
  }
}

class _DecodedCandidate<T> {
  const _DecodedCandidate({
    required this.source,
    required this.raw,
    required this.revision,
    required this.value,
  }) : isFutureSchema = false;

  const _DecodedCandidate.futureSchema({
    required this.source,
    required this.raw,
    required int? revision,
  }) : revision = revision ?? -1,
       value = null,
       isFutureSchema = true;

  final PersistenceDocumentSource source;
  final String raw;
  final int revision;
  final T? value;
  final bool isFutureSchema;

  bool get isUsable => !isFutureSchema && value != null;
}
