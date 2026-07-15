import 'puzzle_template_id.dart';
import 'stage_spec.dart';

class PuzzleTemplateResolver {
  const PuzzleTemplateResolver();

  PuzzleTemplateId resolve(StageSpec spec) {
    if (spec.generatorVersion != 1) {
      throw UnsupportedError(
        'PuzzleTemplateResolver does not support generatorVersion '
        '${spec.generatorVersion}.',
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
    throw UnsupportedError('StageGenerator does not support level $level.');
  }

  bool isT03Level(int level) {
    return level >= 23 && level <= 47 && (level - 23) % 4 == 0;
  }
}
