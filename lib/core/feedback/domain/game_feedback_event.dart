import 'dart:collection';

enum GameFeedbackEventType {
  bookSelected,
  booksSwapped,
  cluesNewlySatisfied,
  stageCleared,
}

class GameFeedbackEvent {
  GameFeedbackEvent({
    required this.type,
    this.bookId,
    Iterable<String> clueIds = const [],
  }) : clueIds = List<String>.unmodifiable(clueIds);

  final GameFeedbackEventType type;
  final String? bookId;
  final List<String> clueIds;

  UnmodifiableListView<String> get clueIdsView {
    return UnmodifiableListView(clueIds);
  }

  @override
  String toString() {
    return 'GameFeedbackEvent(type: $type, bookId: $bookId, clueIds: $clueIds)';
  }
}
