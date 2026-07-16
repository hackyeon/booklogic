import '../generated_stage.dart';
import '../puzzle_template_id.dart';
import 'puzzle_quality_analysis.dart';

class GenerationCandidateQuality {
  const GenerationCandidateQuality({
    required this.stage,
    required this.analysis,
  });

  final GeneratedStage stage;
  final PuzzleQualityAnalysis analysis;

  int get generationAttempt => stage.generationAttempt;

  PuzzleTemplateId get templateId => stage.templateId;

  bool get passesHardRequirements => analysis.passesHardRequirements;

  int get solutionCountForRanking {
    if (analysis.solutionAnalysis.isSolutionCountExact) {
      return analysis.solutionAnalysis.distinctVisualSolutionCount;
    }
    return analysis.solutionAnalysis.distinctVisualSolutionCount + 1;
  }

  int get unsatisfiedClueCount => analysis.initialUnsatisfiedClueCount;
}
