abstract final class GeneratorConfig {
  static const String namespace = 'bookshelf_puzzle';

  static const int generatorVersion1 = 1;

  static const int generatorVersion2 = 2;

  static const int initialGeneratorVersion = generatorVersion1;

  static const int latestGeneratorVersion = generatorVersion2;

  static const int currentVersion = initialGeneratorVersion;

  static const int uint32Mask = 0xFFFFFFFF;

  static const int fnvOffsetBasis = 0x811C9DC5;

  static const int fnvPrime = 0x01000193;

  static const int zeroSeedFallback = 0x6D2B79F5;

  static const int t01ScrambleSalt = 0x9E3779B9;

  static const int t02ScrambleSalt = 0x85EBCA6B;

  static const int t03ScrambleSalt = 0xC2B2AE35;

  static const int t04ScrambleSalt = 0x27D4EB2F;

  static const int t05ScrambleSalt = 0x165667B1;

  static const int t06ScrambleSalt = 0xD3A2646C;
}
