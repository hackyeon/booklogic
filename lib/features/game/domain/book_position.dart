class BookPosition {
  const BookPosition({required this.tierIndex, required this.slotIndex})
    : assert(tierIndex >= 0),
      assert(slotIndex >= 0);

  final int tierIndex;
  final int slotIndex;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BookPosition &&
            runtimeType == other.runtimeType &&
            tierIndex == other.tierIndex &&
            slotIndex == other.slotIndex;
  }

  @override
  int get hashCode => Object.hash(tierIndex, slotIndex);
}
