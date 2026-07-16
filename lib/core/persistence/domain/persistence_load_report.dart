import 'persistence_document_source.dart';
import 'persistence_issue.dart';
import 'persistence_load_status.dart';

class PersistenceLoadReport {
  PersistenceLoadReport({
    required this.documentId,
    required this.status,
    required this.source,
    required this.committedRevision,
    required this.canWrite,
    Iterable<PersistenceIssue> issues = const [],
  }) : issues = List<PersistenceIssue>.unmodifiable(issues);

  final String documentId;
  final PersistenceLoadStatus status;
  final PersistenceDocumentSource source;
  final int? committedRevision;
  final bool canWrite;
  final List<PersistenceIssue> issues;

  bool get wasRecovered =>
      status == PersistenceLoadStatus.recoveredPending ||
      status == PersistenceLoadStatus.recoveredBackup;

  bool get wasMigrated => status == PersistenceLoadStatus.migratedLegacy;

  bool get usesDefaultValue =>
      status == PersistenceLoadStatus.createdDefault ||
      status == PersistenceLoadStatus.resetAfterCorruption ||
      status == PersistenceLoadStatus.futureSchemaReadOnly;

  bool get hasWarning =>
      wasRecovered ||
      usesDefaultValue ||
      status == PersistenceLoadStatus.futureSchemaReadOnly ||
      issues.isNotEmpty;
}
