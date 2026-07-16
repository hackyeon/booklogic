import 'generation_candidate_quality.dart';
import 'template_code.dart';

class GenerationCandidateRanker {
  const GenerationCandidateRanker();

  GenerationCandidateQuality best(List<GenerationCandidateQuality> candidates) {
    if (candidates.isEmpty) {
      throw ArgumentError.value(candidates, 'candidates', '비어있지 않아야 합니다.');
    }
    final sorted = List<GenerationCandidateQuality>.of(candidates)
      ..sort(compare);
    return sorted.first;
  }

  int compare(
    GenerationCandidateQuality left,
    GenerationCandidateQuality right,
  ) {
    final hardComparison = _compareBoolDesc(
      left.passesHardRequirements,
      right.passesHardRequirements,
    );
    if (hardComparison != 0) {
      return hardComparison;
    }

    final exactComparison = _compareBoolDesc(
      left.analysis.solutionAnalysis.isSolutionCountExact,
      right.analysis.solutionAnalysis.isSolutionCountExact,
    );
    if (exactComparison != 0) {
      return exactComparison;
    }

    final solutionComparison = left.solutionCountForRanking.compareTo(
      right.solutionCountForRanking,
    );
    if (solutionComparison != 0) {
      return solutionComparison;
    }

    final unsatisfiedComparison = right.analysis.initialUnsatisfiedClueCount
        .compareTo(left.analysis.initialUnsatisfiedClueCount);
    if (unsatisfiedComparison != 0) {
      return unsatisfiedComparison;
    }

    final satisfiedComparison = left.analysis.initialSatisfiedClueCount
        .compareTo(right.analysis.initialSatisfiedClueCount);
    if (satisfiedComparison != 0) {
      return satisfiedComparison;
    }

    final attemptComparison = left.generationAttempt.compareTo(
      right.generationAttempt,
    );
    if (attemptComparison != 0) {
      return attemptComparison;
    }

    return _stableCandidateKey(left).compareTo(_stableCandidateKey(right));
  }

  int _compareBoolDesc(bool left, bool right) {
    if (left == right) {
      return 0;
    }
    return left ? -1 : 1;
  }

  String _stableCandidateKey(GenerationCandidateQuality candidate) {
    final stage = candidate.stage;
    return '${stage.level}:'
        '${stage.generatorVersion}:'
        '${stage.generationAttempt}:'
        '${templateCode(stage.templateId)}';
  }
}
