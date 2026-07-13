import 'book_selector.dart';
import 'clue_type.dart';

enum ShelfEdge { left, right }

enum HorizontalRelation { leftOf, rightOf }

enum AdjacentDirection { immediatelyLeftOf, immediatelyRightOf }

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
