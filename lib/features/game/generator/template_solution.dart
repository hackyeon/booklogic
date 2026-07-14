import '../domain/book.dart';
import '../domain/book_placement.dart';
import 'puzzle_template_id.dart';
import 'stage_spec.dart';

class TemplateSolution {
  TemplateSolution({
    required this.stageSpec,
    required this.templateId,
    required List<BookPlacement> targetPlacements,
  }) : targetPlacements = List<BookPlacement>.unmodifiable(targetPlacements),
       _books = List<Book>.unmodifiable(
         targetPlacements.map((placement) => placement.book),
       );

  final StageSpec stageSpec;
  final PuzzleTemplateId templateId;
  final List<BookPlacement> targetPlacements;
  final List<Book> _books;

  int get level => stageSpec.level;

  int get totalBookCount => targetPlacements.length;

  List<Book> get books => _books;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TemplateSolution &&
            other.stageSpec == stageSpec &&
            other.templateId == templateId &&
            _placementListEquals(other.targetPlacements, targetPlacements);
  }

  @override
  int get hashCode {
    var result = stageSpec.hashCode & 0x1FFFFFFF;
    result = _combineHash(result, templateId.index);
    for (final placement in targetPlacements) {
      result = _combineHash(result, placement.book.hashCode);
      result = _combineHash(result, placement.position.hashCode);
    }
    return result;
  }

  @override
  String toString() {
    return 'TemplateSolution('
        'level: $level, '
        'templateId: $templateId, '
        'totalBookCount: $totalBookCount'
        ')';
  }
}

bool _placementListEquals(List<BookPlacement> left, List<BookPlacement> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    final leftPlacement = left[index];
    final rightPlacement = right[index];
    if (leftPlacement.book != rightPlacement.book ||
        leftPlacement.position != rightPlacement.position) {
      return false;
    }
  }
  return true;
}

int _combineHash(int current, int value) {
  return ((current * 31) + value) & 0x1FFFFFFF;
}
