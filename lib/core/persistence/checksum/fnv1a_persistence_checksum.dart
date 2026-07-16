import 'persistence_checksum.dart';

class Fnv1aPersistenceChecksum implements PersistenceChecksum {
  const Fnv1aPersistenceChecksum();

  static const int _offsetBasis = 0x811c9dc5;
  static const int _prime = 0x01000193;
  static const int _mask32 = 0xffffffff;

  @override
  int calculate(List<int> bytes) {
    var hash = _offsetBasis;
    for (final byte in bytes) {
      hash ^= byte & 0xff;
      hash = (hash * _prime) & _mask32;
    }
    return hash;
  }
}
