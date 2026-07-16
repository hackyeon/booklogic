import 'deterministic_random.dart';
import 'difficulty_profile.dart';
import 'difficulty_profile_resolver.dart';
import 'generator_config.dart';
import 'generator_version_policy.dart';
import 'inclusive_int_range.dart';
import 'stage_generation_key.dart';
import 'stage_layout.dart';
import 'stage_seed_factory.dart';
import 'stage_spec.dart';
import 't06_rule_profile.dart';
import 't06_rule_profile_resolver.dart';

class StageSpecFactory {
  const StageSpecFactory({
    this.profileResolver = const DifficultyProfileResolver(),
    this.t06ProfileResolver = const T06RuleProfileResolver(),
    this.seedFactory = const StageSeedFactory(),
    this.versionPolicy = const GeneratorVersionPolicy(),
  });

  final DifficultyProfileResolver profileResolver;
  final T06RuleProfileResolver t06ProfileResolver;
  final StageSeedFactory seedFactory;
  final GeneratorVersionPolicy versionPolicy;

  StageSpec create({
    required int level,
    int generatorVersion = GeneratorConfig.currentVersion,
  }) {
    _validateInput(level: level, generatorVersion: generatorVersion);
    versionPolicy.validate(level: level, generatorVersion: generatorVersion);

    if (generatorVersion == GeneratorConfig.generatorVersion2) {
      return _createVersion2(level: level, generatorVersion: generatorVersion);
    }
    return _createVersion1(level: level, generatorVersion: generatorVersion);
  }

  StageSpec _createVersion1({
    required int level,
    required int generatorVersion,
  }) {
    final profile = profileResolver.resolve(level);
    final generationKey = StageGenerationKey(
      generatorVersion: generatorVersion,
      level: level,
    );
    final seed = seedFactory.create(generationKey);
    final random = DeterministicRandom(seed);

    final layout = _pickLayout(profile: profile, random: random);
    final clueCount = _pickFromRange(
      range: profile.clueCountRange,
      random: random,
    );
    final targetSwapCount = _pickFromRange(
      range: profile.targetSwapCountRange,
      random: random,
    );
    final duplicateGroupCount = _pickFromRange(
      range: profile.duplicateGroupCountRange,
      random: random,
    );

    final spec = StageSpec(
      generationKey: generationKey,
      seed: seed,
      profileId: profile.id,
      layout: layout,
      clueCount: clueCount,
      targetSwapCount: targetSwapCount,
      duplicateGroupCount: duplicateGroupCount,
      maxDuplicateCopies: profile.maxDuplicateCopies,
    );
    _validateSpec(spec: spec, profile: profile);
    return spec;
  }

  StageSpec _createVersion2({
    required int level,
    required int generatorVersion,
  }) {
    final profile = t06ProfileResolver.resolve(level);
    final generationKey = StageGenerationKey(
      generatorVersion: generatorVersion,
      level: level,
    );
    final seed = seedFactory.create(generationKey);
    final random = DeterministicRandom(seed);

    final clueCount = _pickFromRange(
      range: profile.clueCountRange,
      random: random,
    );
    final targetSwapCount = _pickFromRange(
      range: profile.targetSwapCountRange,
      random: random,
    );
    final duplicateGroupCount = _pickFromRange(
      range: profile.duplicateGroupCountRange,
      random: random,
    );

    final spec = StageSpec(
      generationKey: generationKey,
      seed: seed,
      profileId: profile.id,
      layout: profile.layout,
      clueCount: clueCount,
      targetSwapCount: targetSwapCount,
      duplicateGroupCount: duplicateGroupCount,
      maxDuplicateCopies: 2,
    );
    _validateT06Spec(spec: spec, profile: profile);
    return spec;
  }

  void _validateInput({required int level, required int generatorVersion}) {
    if (level < 1) {
      throw ArgumentError.value(level, 'level', '1 이상이어야 합니다.');
    }
    if (generatorVersion < 1) {
      throw ArgumentError.value(
        generatorVersion,
        'generatorVersion',
        '1 이상이어야 합니다.',
      );
    }
  }

  StageLayout _pickLayout({
    required DifficultyProfile profile,
    required DeterministicRandom random,
  }) {
    final layoutIndex = random.nextInt(profile.allowedLayouts.length);
    return profile.allowedLayouts[layoutIndex];
  }

  int _pickFromRange({
    required InclusiveIntRange range,
    required DeterministicRandom random,
  }) {
    return range.min + random.nextInt(range.length);
  }

  void _validateSpec({
    required StageSpec spec,
    required DifficultyProfile profile,
  }) {
    if (!profile.containsLevel(spec.level)) {
      throw StateError('StageSpec level is outside its profile.');
    }
    if (!profile.allowedLayouts.contains(spec.layout)) {
      throw StateError('StageSpec layout is outside its profile.');
    }
    if (!profile.clueCountRange.contains(spec.clueCount)) {
      throw StateError('StageSpec clueCount is outside its profile.');
    }
    if (!profile.targetSwapCountRange.contains(spec.targetSwapCount)) {
      throw StateError('StageSpec targetSwapCount is outside its profile.');
    }
    if (!profile.duplicateGroupCountRange.contains(spec.duplicateGroupCount)) {
      throw StateError('StageSpec duplicateGroupCount is outside its profile.');
    }
    if (spec.maxDuplicateCopies != profile.maxDuplicateCopies) {
      throw StateError('StageSpec maxDuplicateCopies does not match profile.');
    }
    if (spec.totalBookCount > 18) {
      throw StateError('StageSpec totalBookCount exceeds 18.');
    }
    if (spec.tierCount < 1 || spec.tierCount > 3) {
      throw StateError('StageSpec tierCount is outside 1..3.');
    }
    if (spec.booksPerTier < 4 || spec.booksPerTier > 6) {
      throw StateError('StageSpec booksPerTier is outside 4..6.');
    }
    if (spec.generationKey.attempt != 0) {
      throw StateError('StageSpec generationKey attempt must be 0.');
    }
  }

  void _validateT06Spec({
    required StageSpec spec,
    required T06RuleProfile profile,
  }) {
    if (!profile.containsLevel(spec.level)) {
      throw StateError('T06 StageSpec level is outside its profile.');
    }
    if (spec.generatorVersion != GeneratorConfig.generatorVersion2 ||
        spec.layout != profile.layout ||
        spec.totalBookCount != 12 ||
        !profile.clueCountRange.contains(spec.clueCount) ||
        !profile.targetSwapCountRange.contains(spec.targetSwapCount) ||
        !profile.duplicateGroupCountRange.contains(spec.duplicateGroupCount) ||
        spec.maxDuplicateCopies != 2) {
      throw StateError('T06 StageSpec does not match its profile.');
    }
  }
}
