class InclusiveIntRange {
  const InclusiveIntRange({required this.min, required this.max})
    : assert(min <= max);

  final int min;
  final int max;

  int get length => max - min + 1;

  bool contains(int value) {
    return value >= min && value <= max;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is InclusiveIntRange && other.min == min && other.max == max;
  }

  @override
  int get hashCode {
    var result = min & 0x1FFFFFFF;
    result = ((result * 31) + max) & 0x1FFFFFFF;
    return result;
  }

  @override
  String toString() {
    return 'InclusiveIntRange(min: $min, max: $max)';
  }
}
