import 'persistence_issue_code.dart';

class PersistenceWriteException implements Exception {
  const PersistenceWriteException(this.message, {this.code});

  final String message;
  final PersistenceIssueCode? code;

  @override
  String toString() => 'PersistenceWriteException($message)';
}

class PersistenceReadOnlyException implements Exception {
  const PersistenceReadOnlyException(this.message);

  final String message;

  @override
  String toString() => 'PersistenceReadOnlyException($message)';
}
