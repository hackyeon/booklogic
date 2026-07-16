import 'persistence_issue.dart';

class PersistenceCommitResult {
  PersistenceCommitResult({
    required this.committed,
    required this.previousRevision,
    required this.committedRevision,
    required this.cleanupSucceeded,
    Iterable<PersistenceIssue> issues = const [],
  }) : issues = List<PersistenceIssue>.unmodifiable(issues);

  final bool committed;
  final int previousRevision;
  final int? committedRevision;
  final bool cleanupSucceeded;
  final List<PersistenceIssue> issues;
}
