import '../domain/persistence_issue.dart';

abstract interface class LegacyPersistenceReader<T> {
  LegacyPersistenceReadResult<T>? read();
}

class LegacyPersistenceReadResult<T> {
  LegacyPersistenceReadResult({
    required this.value,
    Iterable<PersistenceIssue> issues = const [],
  }) : issues = List<PersistenceIssue>.unmodifiable(issues);

  final T value;
  final List<PersistenceIssue> issues;
}
