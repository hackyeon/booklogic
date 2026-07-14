class StageLayout {
  const StageLayout({required this.tierCount, required this.booksPerTier})
    : assert(tierCount >= 1),
      assert(tierCount <= 3),
      assert(booksPerTier >= 4),
      assert(booksPerTier <= 6),
      assert(tierCount * booksPerTier <= 18);

  final int tierCount;
  final int booksPerTier;

  int get totalBookCount => tierCount * booksPerTier;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is StageLayout &&
            other.tierCount == tierCount &&
            other.booksPerTier == booksPerTier;
  }

  @override
  int get hashCode {
    var result = tierCount & 0x1FFFFFFF;
    result = ((result * 31) + booksPerTier) & 0x1FFFFFFF;
    return result;
  }

  @override
  String toString() {
    return 'StageLayout('
        'tierCount: $tierCount, '
        'booksPerTier: $booksPerTier, '
        'totalBookCount: $totalBookCount'
        ')';
  }
}
