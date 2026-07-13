import 'generator_config.dart';

class DeterministicRandom {
  DeterministicRandom(int seed)
    : _initialSeed = _normalizeSeed(seed),
      _state = _normalizeSeed(seed);

  final int _initialSeed;
  int _state;

  int get initialSeed => _initialSeed;

  int get currentState => _state;

  int nextUint32() {
    var x = _state;

    x ^= x << 13;
    x &= GeneratorConfig.uint32Mask;

    x ^= x >> 17;
    x &= GeneratorConfig.uint32Mask;

    x ^= x << 5;
    x &= GeneratorConfig.uint32Mask;

    _state = x;
    return _state;
  }

  int nextInt(int maxExclusive) {
    if (maxExclusive <= 0) {
      throw ArgumentError.value(maxExclusive, 'maxExclusive', '0보다 커야 합니다.');
    }

    return nextUint32() % maxExclusive;
  }

  bool nextBool() {
    return nextInt(2) == 1;
  }

  double nextDouble() {
    return nextUint32() / 4294967296.0;
  }

  T choose<T>(List<T> values) {
    if (values.isEmpty) {
      throw StateError('빈 목록에서는 값을 선택할 수 없습니다.');
    }

    return values[nextInt(values.length)];
  }

  List<T> shuffled<T>(Iterable<T> values) {
    final result = List<T>.of(values);

    // Generator v1 treats random call order as part of compatibility.
    // Avoid consuming random values for logging, debugging, or assertions.
    for (var index = result.length - 1; index > 0; index -= 1) {
      final swapIndex = nextInt(index + 1);
      final temp = result[index];
      result[index] = result[swapIndex];
      result[swapIndex] = temp;
    }

    return result;
  }

  static int _normalizeSeed(int seed) {
    final normalized = seed & GeneratorConfig.uint32Mask;
    if (normalized == 0) {
      return GeneratorConfig.zeroSeedFallback;
    }
    return normalized;
  }
}
