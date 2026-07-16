import 'visual_arrangement_signature.dart';

class PuzzleSolutionAnalysis {
  PuzzleSolutionAnalysis({
    required this.targetIsSolution,
    required this.initialIsSolution,
    required this.distinctVisualSolutionCount,
    required this.isSolutionCountExact,
    required this.reachedSolutionLimit,
    required this.reachedNodeLimit,
    required this.visitedNodeCount,
    required List<VisualArrangementSignature> sampleSolutions,
    required this.targetSignature,
    required this.unsupportedReason,
  }) : sampleSolutions = List<VisualArrangementSignature>.unmodifiable(
         sampleSolutions,
       );

  final bool targetIsSolution;
  final bool initialIsSolution;
  final int distinctVisualSolutionCount;
  final bool isSolutionCountExact;
  final bool reachedSolutionLimit;
  final bool reachedNodeLimit;
  final int visitedNodeCount;
  final List<VisualArrangementSignature> sampleSolutions;
  final VisualArrangementSignature? targetSignature;
  final String? unsupportedReason;

  bool get targetSignatureFound {
    final signature = targetSignature;
    if (signature == null) {
      return false;
    }
    return sampleSolutions.contains(signature);
  }
}
