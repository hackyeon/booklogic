import 'puzzle_template_id.dart';
import 'stage_spec.dart';

class PuzzleTemplateResolver {
  const PuzzleTemplateResolver();

  PuzzleTemplateId resolve(StageSpec spec, {int? generatorVersion}) {
    final effectiveVersion = generatorVersion ?? spec.generatorVersion;
    if (effectiveVersion == 2) {
      if (spec.level >= 201 && spec.level <= 400) {
        return PuzzleTemplateId.t06VerticalPair;
      }
      throw UnsupportedError(
        'StageGenerator does not support level ${spec.level}.',
      );
    }
    if (effectiveVersion != 1) {
      throw UnsupportedError(
        'PuzzleTemplateResolver does not support generatorVersion '
        '$effectiveVersion.',
      );
    }
    final level = spec.level;
    if (level >= 1 && level <= 20) {
      return PuzzleTemplateId.t01AnchorChain;
    }
    if (level >= 21 && level <= 50) {
      if (isT03Level(level)) {
        return PuzzleTemplateId.t03AdjacentBlocks;
      }
      return PuzzleTemplateId.t02EdgeSandwich;
    }
    if (level >= 51 && level <= 100) {
      return PuzzleTemplateId.t04TierGrouping;
    }
    if (level >= 101 && level <= 200) {
      return PuzzleTemplateId.t05TierOrder;
    }
    throw UnsupportedError('StageGenerator does not support level $level.');
  }

  bool isT03Level(int level) {
    return level >= 23 && level <= 47 && (level - 23) % 4 == 0;
  }
}
