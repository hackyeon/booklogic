import 'package:flutter_test/flutter_test.dart';

import 'package:booklogic/core/feedback/data/app_feedback_settings_persistence_codec.dart';
import 'package:booklogic/core/feedback/domain/app_feedback_settings.dart';

void main() {
  group('AppFeedbackSettingsPersistenceCodec', () {
    const codec = AppFeedbackSettingsPersistenceCodec();

    test('round-trips all bool combinations', () {
      for (final settings in const [
        AppFeedbackSettings(soundEnabled: true, hapticEnabled: true),
        AppFeedbackSettings(soundEnabled: false, hapticEnabled: true),
        AppFeedbackSettings(soundEnabled: true, hapticEnabled: false),
        AppFeedbackSettings(soundEnabled: false, hapticEnabled: false),
      ]) {
        expect(
          codec.decode(schemaVersion: 1, payload: codec.encode(settings)),
          settings,
        );
      }
    });

    test('rejects missing or mistyped fields', () {
      expect(
        () => codec.decode(
          schemaVersion: 1,
          payload: {'soundEnabled': 'false', 'hapticEnabled': true},
        ),
        throwsFormatException,
      );
      expect(
        () => codec.decode(schemaVersion: 1, payload: {'soundEnabled': true}),
        throwsFormatException,
      );
      expect(
        () => codec.decode(
          schemaVersion: 2,
          payload: codec.encode(AppFeedbackSettings.defaults),
        ),
        throwsUnsupportedError,
      );
    });
  });
}
