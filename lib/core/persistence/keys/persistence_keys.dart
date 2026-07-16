class PersistenceDocumentKeys {
  const PersistenceDocumentKeys({
    required this.documentId,
    required this.primary,
    required this.pending,
    required this.backup,
    required this.commitRevision,
  });

  final String documentId;
  final String primary;
  final String pending;
  final String backup;
  final String commitRevision;
}

class PersistenceKeys {
  const PersistenceKeys._();

  static const gameProgress = PersistenceDocumentKeys(
    documentId: 'game_progress',
    primary: 'bookshelf_puzzle.persistence.game_progress.primary',
    pending: 'bookshelf_puzzle.persistence.game_progress.pending',
    backup: 'bookshelf_puzzle.persistence.game_progress.backup',
    commitRevision:
        'bookshelf_puzzle.persistence.game_progress.commit_revision',
  );

  static const learningProgress = PersistenceDocumentKeys(
    documentId: 'learning_progress',
    primary: 'bookshelf_puzzle.persistence.learning_progress.primary',
    pending: 'bookshelf_puzzle.persistence.learning_progress.pending',
    backup: 'bookshelf_puzzle.persistence.learning_progress.backup',
    commitRevision:
        'bookshelf_puzzle.persistence.learning_progress.commit_revision',
  );

  static const feedbackSettings = PersistenceDocumentKeys(
    documentId: 'feedback_settings',
    primary: 'bookshelf_puzzle.persistence.feedback_settings.primary',
    pending: 'bookshelf_puzzle.persistence.feedback_settings.pending',
    backup: 'bookshelf_puzzle.persistence.feedback_settings.backup',
    commitRevision:
        'bookshelf_puzzle.persistence.feedback_settings.commit_revision',
  );
}
