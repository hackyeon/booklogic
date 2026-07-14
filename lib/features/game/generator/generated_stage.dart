import '../domain/book_placement.dart';
import '../domain/clue.dart';
import 'book_swap_step.dart';
import 'puzzle_template_id.dart';
import 'stage_generation_key.dart';
import 'stage_spec.dart';
import 'template_scramble_result.dart';
import 'template_solution.dart';

class GeneratedStage {
  GeneratedStage({
    required this.scrambleResult,
    required List<Clue> clues,
    StageGenerationKey? generationAttemptKey,
    int? generationAttemptSeed,
    this.isFallback = false,
  }) : generationAttemptKey =
           generationAttemptKey ??
           scrambleResult.solution.stageSpec.generationKey,
       generationAttemptSeed =
           generationAttemptSeed ?? scrambleResult.solution.stageSpec.seed,
       clues = List<Clue>.unmodifiable(List<Clue>.of(clues));

  final TemplateScrambleResult scrambleResult;
  final StageGenerationKey generationAttemptKey;
  final int generationAttemptSeed;
  final bool isFallback;
  final List<Clue> clues;

  TemplateSolution get solution => scrambleResult.solution;

  StageSpec get stageSpec => solution.stageSpec;

  PuzzleTemplateId get templateId => solution.templateId;

  List<BookPlacement> get targetPlacements => solution.targetPlacements;

  List<BookPlacement> get initialPlacements => scrambleResult.initialPlacements;

  List<BookSwapStep> get swapHistory => scrambleResult.swapHistory;

  int get scrambleSeed => scrambleResult.scrambleSeed;

  int get level => stageSpec.level;

  int get generatorVersion => stageSpec.generatorVersion;

  int get tierCount => stageSpec.tierCount;

  int get booksPerTier => stageSpec.booksPerTier;

  int get totalBookCount => stageSpec.totalBookCount;

  int get clueCount => clues.length;

  int get targetSwapCount => stageSpec.targetSwapCount;

  int get generationAttempt => generationAttemptKey.attempt;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is GeneratedStage &&
            runtimeType == other.runtimeType &&
            scrambleResult == other.scrambleResult &&
            generationAttemptKey == other.generationAttemptKey &&
            generationAttemptSeed == other.generationAttemptSeed &&
            isFallback == other.isFallback &&
            _listEquals(other.clues, clues);
  }

  @override
  int get hashCode {
    var result = scrambleResult.hashCode & 0x1FFFFFFF;
    result = _combineHash(result, generationAttemptKey.hashCode);
    result = _combineHash(result, generationAttemptSeed);
    result = _combineHash(result, isFallback ? 1 : 0);
    for (final clue in clues) {
      result = _combineHash(result, clue.hashCode);
    }
    return result;
  }

  @override
  String toString() {
    return 'GeneratedStage('
        'level: $level, '
        'generatorVersion: $generatorVersion, '
        'templateId: $templateId, '
        'totalBookCount: $totalBookCount, '
        'clueCount: $clueCount, '
        'targetSwapCount: $targetSwapCount, '
        'scrambleSeed: $scrambleSeed, '
        'generationAttempt: $generationAttempt, '
        'generationAttemptSeed: $generationAttemptSeed, '
        'isFallback: $isFallback'
        ')';
  }
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

int _combineHash(int current, int value) {
  return ((current * 31) + value) & 0x1FFFFFFF;
}
