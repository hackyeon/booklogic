enum StageValidationIssueCode {
  unsupportedTemplate,
  invalidStageSpec,
  invalidTargetPlacements,
  invalidInitialPlacements,
  duplicateBookId,
  duplicateVisualBook,
  invalidDuplicateStructure,
  mismatchedBookSet,
  invalidClueCount,
  duplicateClueId,
  invalidClueId,
  invalidClueStructure,
  invalidT02TargetStructure,
  invalidT02ClueStructure,
  invalidT03TargetStructure,
  invalidT03ClueStructure,
  unresolvedClueSelector,
  targetDoesNotSatisfyAllClues,
  initialAlreadySatisfiesAllClues,
  invalidScrambleSeed,
  invalidSwapHistoryCount,
  invalidSwapStep,
  swapHistoryBookMismatch,
  identicalVisualBookSwap,
  forwardReplayMismatch,
  reverseReplayMismatch,
  minimumSwapDistanceMismatch,
  minimumVisualSwapDistanceMismatch,
  invalidGenerationAttemptKey,
  invalidGenerationAttemptSeed,
  invalidFallbackMetadata,
}

class StageValidationIssue {
  const StageValidationIssue({
    required this.code,
    required this.message,
    this.relatedId,
  }) : assert(message.length > 0);

  final StageValidationIssueCode code;
  final String message;
  final String? relatedId;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is StageValidationIssue &&
            runtimeType == other.runtimeType &&
            code == other.code &&
            message == other.message &&
            relatedId == other.relatedId;
  }

  @override
  int get hashCode {
    var result = code.index & 0x1FFFFFFF;
    result = _combineHash(result, message.hashCode);
    result = _combineHash(result, relatedId.hashCode);
    return result;
  }

  @override
  String toString() {
    final relatedText = relatedId == null ? '' : ', relatedId: $relatedId';
    return 'StageValidationIssue(code: $code, message: $message$relatedText)';
  }
}

int _combineHash(int current, int value) {
  return ((current * 31) + value) & 0x1FFFFFFF;
}
