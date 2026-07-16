import 'book_selector.dart';
import 'clue_type.dart';

enum ShelfEdge { left, right }

enum HorizontalRelation { leftOf, rightOf }

enum AdjacentDirection { immediatelyLeftOf, immediatelyRightOf }

enum VerticalRelation { immediatelyAbove, immediatelyBelow }

sealed class Clue {
  const Clue({required this.id}) : assert(id.length > 0);

  final String id;

  ClueType get type;
}

final class EdgePositionClue extends Clue {
  const EdgePositionClue({
    required super.id,
    required this.subject,
    required this.tierIndex,
    required this.edge,
  }) : assert(tierIndex >= 0);

  final BookSelector subject;
  final int tierIndex;
  final ShelfEdge edge;

  @override
  ClueType get type => ClueType.edgePosition;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is EdgePositionClue &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            subject == other.subject &&
            tierIndex == other.tierIndex &&
            edge == other.edge;
  }

  @override
  int get hashCode => Object.hash(runtimeType, id, subject, tierIndex, edge);

  @override
  String toString() {
    return 'EdgePositionClue(id: $id, subject: $subject, '
        'tierIndex: $tierIndex, edge: $edge)';
  }
}

final class BothEdgesClue extends Clue {
  const BothEdgesClue({
    required super.id,
    required this.subject,
    required this.tierIndex,
  }) : assert(tierIndex >= 0);

  final BookSelector subject;
  final int tierIndex;

  @override
  ClueType get type => ClueType.bothEdges;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BothEdgesClue &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            subject == other.subject &&
            tierIndex == other.tierIndex;
  }

  @override
  int get hashCode => Object.hash(runtimeType, id, subject, tierIndex);

  @override
  String toString() {
    return 'BothEdgesClue(id: $id, subject: $subject, '
        'tierIndex: $tierIndex)';
  }
}

final class RelativeOrderClue extends Clue {
  const RelativeOrderClue({
    required super.id,
    required this.subject,
    required this.reference,
    required this.tierIndex,
    required this.relation,
  }) : assert(tierIndex >= 0);

  final BookSelector subject;
  final BookSelector reference;
  final int tierIndex;
  final HorizontalRelation relation;

  @override
  ClueType get type => ClueType.relativeOrder;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is RelativeOrderClue &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            subject == other.subject &&
            reference == other.reference &&
            tierIndex == other.tierIndex &&
            relation == other.relation;
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      id,
      subject,
      reference,
      tierIndex,
      relation,
    );
  }

  @override
  String toString() {
    return 'RelativeOrderClue(id: $id, subject: $subject, '
        'reference: $reference, tierIndex: $tierIndex, relation: $relation)';
  }
}

final class BetweenClue extends Clue {
  const BetweenClue({
    required super.id,
    required this.subject,
    required this.boundary,
    required this.tierIndex,
  }) : assert(tierIndex >= 0);

  final BookSelector subject;
  final BookSelector boundary;
  final int tierIndex;

  @override
  ClueType get type => ClueType.between;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BetweenClue &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            subject == other.subject &&
            boundary == other.boundary &&
            tierIndex == other.tierIndex;
  }

  @override
  int get hashCode {
    return Object.hash(runtimeType, id, subject, boundary, tierIndex);
  }

  @override
  String toString() {
    return 'BetweenClue(id: $id, subject: $subject, boundary: $boundary, '
        'tierIndex: $tierIndex)';
  }
}

final class TierAssignmentClue extends Clue {
  const TierAssignmentClue({
    required super.id,
    required this.subject,
    required this.tierIndex,
  }) : assert(tierIndex >= 0);

  final BookSelector subject;
  final int tierIndex;

  @override
  ClueType get type => ClueType.tierAssignment;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TierAssignmentClue &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            subject == other.subject &&
            tierIndex == other.tierIndex;
  }

  @override
  int get hashCode => Object.hash(runtimeType, id, subject, tierIndex);

  @override
  String toString() {
    return 'TierAssignmentClue(id: $id, subject: $subject, '
        'tierIndex: $tierIndex)';
  }
}

final class SameTierClue extends Clue {
  const SameTierClue({
    required super.id,
    required this.first,
    required this.second,
  });

  final BookSelector first;
  final BookSelector second;

  @override
  ClueType get type => ClueType.sameTier;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SameTierClue &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            first == other.first &&
            second == other.second;
  }

  @override
  int get hashCode => Object.hash(runtimeType, id, first, second);

  @override
  String toString() {
    return 'SameTierClue(id: $id, first: $first, second: $second)';
  }
}

final class AdjacentClue extends Clue {
  const AdjacentClue({
    required super.id,
    required this.subject,
    required this.reference,
    required this.tierIndex,
    required this.direction,
  }) : assert(tierIndex >= 0);

  final BookSelector subject;
  final BookSelector reference;
  final int tierIndex;
  final AdjacentDirection direction;

  @override
  ClueType get type => ClueType.adjacent;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AdjacentClue &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            subject == other.subject &&
            reference == other.reference &&
            tierIndex == other.tierIndex &&
            direction == other.direction;
  }

  @override
  int get hashCode {
    return Object.hash(
      runtimeType,
      id,
      subject,
      reference,
      tierIndex,
      direction,
    );
  }

  @override
  String toString() {
    return 'AdjacentClue(id: $id, subject: $subject, reference: $reference, '
        'tierIndex: $tierIndex, direction: $direction)';
  }
}

final class VerticalRelationClue extends Clue {
  const VerticalRelationClue({
    required super.id,
    required this.subject,
    required this.reference,
    required this.relation,
  });

  final BookSelector subject;
  final BookSelector reference;
  final VerticalRelation relation;

  @override
  ClueType get type => ClueType.verticalRelation;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is VerticalRelationClue &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            subject == other.subject &&
            reference == other.reference &&
            relation == other.relation;
  }

  @override
  int get hashCode {
    return Object.hash(runtimeType, id, subject, reference, relation);
  }

  @override
  String toString() {
    return 'VerticalRelationClue(id: $id, subject: $subject, '
        'reference: $reference, relation: $relation)';
  }
}

final class NotAtEdgeClue extends Clue {
  const NotAtEdgeClue({
    required super.id,
    required this.subject,
    required this.tierIndex,
  }) : assert(tierIndex >= 0);

  final BookSelector subject;
  final int tierIndex;

  @override
  ClueType get type => ClueType.notAtEdge;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is NotAtEdgeClue &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            subject == other.subject &&
            tierIndex == other.tierIndex;
  }

  @override
  int get hashCode => Object.hash(runtimeType, id, subject, tierIndex);

  @override
  String toString() {
    return 'NotAtEdgeClue(id: $id, subject: $subject, '
        'tierIndex: $tierIndex)';
  }
}

final class DistanceClue extends Clue {
  const DistanceClue({
    required super.id,
    required this.first,
    required this.second,
    required this.tierIndex,
    required this.booksBetween,
  }) : assert(tierIndex >= 0),
       assert(booksBetween >= 1);

  final BookSelector first;
  final BookSelector second;
  final int tierIndex;
  final int booksBetween;

  @override
  ClueType get type => ClueType.distance;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DistanceClue &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            first == other.first &&
            second == other.second &&
            tierIndex == other.tierIndex &&
            booksBetween == other.booksBetween;
  }

  @override
  int get hashCode {
    return Object.hash(runtimeType, id, first, second, tierIndex, booksBetween);
  }

  @override
  String toString() {
    return 'DistanceClue(id: $id, first: $first, second: $second, '
        'tierIndex: $tierIndex, booksBetween: $booksBetween)';
  }
}
