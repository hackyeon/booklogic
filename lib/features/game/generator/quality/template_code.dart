import '../puzzle_template_id.dart';

String templateCode(PuzzleTemplateId templateId) {
  return switch (templateId) {
    PuzzleTemplateId.t01AnchorChain => 't01_anchor_chain',
    PuzzleTemplateId.t02EdgeSandwich => 't02_edge_sandwich',
    PuzzleTemplateId.t03AdjacentBlocks => 't03_adjacent_blocks',
    PuzzleTemplateId.t04TierGrouping => 't04_tier_grouping',
    PuzzleTemplateId.t05TierOrder => 't05_tier_order',
    PuzzleTemplateId.t06VerticalPair => 't06_vertical_pair',
  };
}
