abstract final class GeneratorConfig {
  static const String namespace = 'bookshelf_puzzle';

  static const int currentVersion = 1;

  static const int uint32Mask = 0xFFFFFFFF;

  static const int fnvOffsetBasis = 0x811C9DC5;

  static const int fnvPrime = 0x01000193;

  static const int zeroSeedFallback = 0x6D2B79F5;

  static const int t01ScrambleSalt = 0x9E3779B9;

  static const int t02ScrambleSalt = 0x85EBCA6B;

  static const int t03ScrambleSalt = 0xC2B2AE35;
}
