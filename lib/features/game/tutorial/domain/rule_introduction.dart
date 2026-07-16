import '../../domain/clue.dart';
import '../../domain/clue_type.dart';

class RuleIntroduction {
  const RuleIntroduction({
    required this.ruleCode,
    required this.title,
    required this.description,
    required this.exampleClueText,
    required this.clueType,
  });

  final String ruleCode;
  final String title;
  final String description;
  final String exampleClueText;
  final ClueType clueType;
}

String stableRuleCodeForClue(Clue clue) {
  return stableRuleCodeForClueType(clue.type);
}

String stableRuleCodeForClueType(ClueType clueType) {
  return switch (clueType) {
    ClueType.tierAssignment => 'c01_tier_assignment',
    ClueType.edgePosition => 'c02_edge_position',
    ClueType.bothEdges => 'c03_both_edges',
    ClueType.relativeOrder => 'c04_relative_order',
    ClueType.adjacent => 'c05_adjacent',
    ClueType.between => 'c06_between',
    ClueType.sameTier => 'c07_same_tier',
    ClueType.verticalRelation => 'c08_vertical_relation',
    ClueType.notAtEdge => 'c09_not_at_edge',
    ClueType.distance => 'c10_distance',
  };
}

String ruleTitleForClueType(ClueType clueType) {
  return switch (clueType) {
    ClueType.tierAssignment => '새로운 단서 · 단 지정',
    ClueType.edgePosition => '새로운 단서 · 끝 위치',
    ClueType.bothEdges => '새로운 단서 · 양 끝',
    ClueType.relativeOrder => '새로운 단서 · 왼쪽·오른쪽',
    ClueType.adjacent => '새로운 단서 · 바로 옆',
    ClueType.between => '새로운 단서 · 사이',
    ClueType.sameTier => '새로운 단서 · 같은 단',
    ClueType.verticalRelation => '새로운 단서 · 위·아래',
    ClueType.notAtEdge => '새로운 단서 · 끝이 아님',
    ClueType.distance => '새로운 단서 · 거리',
  };
}

String ruleDescriptionForClueType(ClueType clueType) {
  return switch (clueType) {
    ClueType.tierAssignment => '같은 그룹의 책을 지정된 단에 모아야 합니다.',
    ClueType.edgePosition => '해당 책은 지정된 단의 왼쪽 또는 오른쪽 끝에 있어야 합니다.',
    ClueType.bothEdges => '같은 그룹의 두 책이 한 단의 양 끝을 차지해야 합니다.',
    ClueType.relativeOrder => '같은 단에서 책이나 그룹의 좌우 순서를 비교합니다.',
    ClueType.adjacent => '두 책이나 책 묶음 사이에 다른 책 없이 붙어 있어야 합니다.',
    ClueType.between => '대상 책들이 두 경계 책 사이에 있어야 합니다.',
    ClueType.sameTier => '두 책 또는 두 그룹이 같은 단에 있어야 합니다.',
    ClueType.verticalRelation => '같은 세로 열에서 바로 위 또는 바로 아래 관계를 확인합니다.',
    ClueType.notAtEdge => '지정된 책은 해당 단의 양 끝 칸을 피해야 합니다.',
    ClueType.distance => '두 책 사이에 정확한 수의 책이 있어야 합니다.',
  };
}
