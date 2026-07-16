import 'persistence_document_source.dart';
import 'persistence_issue_code.dart';

class PersistenceIssue {
  const PersistenceIssue({required this.code, this.source, this.revision});

  final PersistenceIssueCode code;
  final PersistenceDocumentSource? source;
  final int? revision;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PersistenceIssue &&
            code == other.code &&
            source == other.source &&
            revision == other.revision;
  }

  @override
  int get hashCode => Object.hash(code, source, revision);

  @override
  String toString() {
    return 'PersistenceIssue('
        'code: $code, '
        'source: $source, '
        'revision: $revision'
        ')';
  }
}
