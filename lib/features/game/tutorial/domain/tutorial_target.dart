enum TutorialTargetType { book, clueCard, cluePanelToggle, none }

class TutorialTarget {
  const TutorialTarget._({required this.type, required this.targetId});

  factory TutorialTarget.book(String bookId) {
    return TutorialTarget._(
      type: TutorialTargetType.book,
      targetId: 'book:$bookId',
    );
  }

  factory TutorialTarget.clueCard(String clueId) {
    return TutorialTarget._(
      type: TutorialTargetType.clueCard,
      targetId: 'clue:$clueId',
    );
  }

  const TutorialTarget.cluePanelToggle()
    : this._(
        type: TutorialTargetType.cluePanelToggle,
        targetId: 'clue_panel_toggle',
      );

  const TutorialTarget.none()
    : this._(type: TutorialTargetType.none, targetId: null);

  final TutorialTargetType type;
  final String? targetId;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TutorialTarget &&
            runtimeType == other.runtimeType &&
            type == other.type &&
            targetId == other.targetId;
  }

  @override
  int get hashCode => Object.hash(type, targetId);

  @override
  String toString() {
    return 'TutorialTarget(type: $type, targetId: $targetId)';
  }
}
