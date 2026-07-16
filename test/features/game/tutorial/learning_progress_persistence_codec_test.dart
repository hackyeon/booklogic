import 'package:flutter_test/flutter_test.dart';

import 'package:booklogic/features/game/tutorial/data/learning_progress_persistence_codec.dart';
import 'package:booklogic/features/game/tutorial/domain/learning_progress.dart';

void main() {
  group('LearningProgressPersistenceCodec', () {
    const codec = LearningProgressPersistenceCodec();

    test('round-trips with sorted unique rule codes', () {
      final progress = LearningProgress(
        tutorialCompleted: true,
        acknowledgedRuleCodes: ['future_rule', 'c01_tier_assignment'],
      );

      final payload = codec.encode(progress);

      expect(payload['acknowledgedRuleCodes'], [
        'c01_tier_assignment',
        'future_rule',
      ]);
      expect(codec.decode(schemaVersion: 1, payload: payload), progress);
    });

    test('rejects invalid document payloads strictly', () {
      expect(
        () => codec.decode(
          schemaVersion: 1,
          payload: {
            'tutorialCompleted': 'true',
            'acknowledgedRuleCodes': const <String>[],
          },
        ),
        throwsFormatException,
      );
      expect(
        () => codec.decode(
          schemaVersion: 1,
          payload: {
            'tutorialCompleted': true,
            'acknowledgedRuleCodes': [''],
          },
        ),
        throwsFormatException,
      );
      expect(
        () => codec.decode(
          schemaVersion: 1,
          payload: {
            'tutorialCompleted': true,
            'acknowledgedRuleCodes': [1],
          },
        ),
        throwsFormatException,
      );
      expect(
        () => codec.decode(
          schemaVersion: 2,
          payload: codec.encode(LearningProgress()),
        ),
        throwsUnsupportedError,
      );
    });
  });
}
