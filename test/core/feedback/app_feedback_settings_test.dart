import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:booklogic/core/feedback/application/app_feedback_settings_controller.dart';
import 'package:booklogic/core/feedback/data/shared_preferences_app_feedback_settings_store.dart';
import 'package:booklogic/core/feedback/domain/app_feedback_settings.dart';

import '../../helpers/fake_app_feedback_settings_store.dart';

void main() {
  group('AppFeedbackSettings', () {
    test('defaults, copyWith, equality, hashCode, and toString', () {
      expect(AppFeedbackSettings.defaults.soundEnabled, isTrue);
      expect(AppFeedbackSettings.defaults.hapticEnabled, isTrue);

      final soundOff = AppFeedbackSettings.defaults.copyWith(
        soundEnabled: false,
      );
      final hapticOff = AppFeedbackSettings.defaults.copyWith(
        hapticEnabled: false,
      );

      expect(soundOff.soundEnabled, isFalse);
      expect(soundOff.hapticEnabled, isTrue);
      expect(hapticOff.soundEnabled, isTrue);
      expect(hapticOff.hapticEnabled, isFalse);
      expect(soundOff, soundOff.copyWith());
      expect(soundOff.hashCode, soundOff.copyWith().hashCode);
      expect(soundOff.toString(), contains('soundEnabled: false'));
      expect(soundOff.toString(), contains('hapticEnabled: true'));
    });
  });

  group('SharedPreferencesAppFeedbackSettingsStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loads default values when keys are absent', () async {
      final store = SharedPreferencesAppFeedbackSettingsStore();

      final settings = await store.load();

      expect(settings.soundEnabled, isTrue);
      expect(settings.hapticEnabled, isTrue);
    });

    test(
      'saves sound and haptic independently without touching other keys',
      () async {
        final store = SharedPreferencesAppFeedbackSettingsStore();
        final preferences = await SharedPreferences.getInstance();
        await preferences.setBool('music_enabled', false);

        await store.saveSoundEnabled(false);
        expect((await store.load()).soundEnabled, isFalse);
        expect((await store.load()).hapticEnabled, isTrue);

        await store.saveHapticEnabled(false);
        final settings = await store.load();

        expect(settings.soundEnabled, isFalse);
        expect(settings.hapticEnabled, isFalse);
        expect(preferences.getBool('music_enabled'), isFalse);
      },
    );
  });

  group('AppFeedbackSettingsController', () {
    test('initializes once and ignores duplicate same-value writes', () async {
      final store = FakeAppFeedbackSettingsStore(
        settings: const AppFeedbackSettings(
          soundEnabled: false,
          hapticEnabled: true,
        ),
      );
      final controller = AppFeedbackSettingsController(store: store);

      await Future.wait([controller.initialize(), controller.initialize()]);
      controller.setSoundEnabled(false);
      controller.setHapticEnabled(true);

      expect(store.loadCount, 1);
      expect(controller.soundEnabled, isFalse);
      expect(controller.hapticEnabled, isTrue);
      expect(store.soundWrites, isEmpty);
      expect(store.hapticWrites, isEmpty);
      controller.dispose();
    });

    test(
      'changes settings immediately and keeps session value on save failure',
      () async {
        final store = FakeAppFeedbackSettingsStore(
          soundSaveErrors: ['sound failed'],
        );
        final controller = AppFeedbackSettingsController(store: store);
        var notifyCount = 0;
        controller.addListener(() => notifyCount += 1);

        await controller.initialize();
        controller.setSoundEnabled(false);
        await Future<void>.delayed(Duration.zero);

        expect(controller.soundEnabled, isFalse);
        expect(controller.lastError, isA<StateError>());
        expect(notifyCount, greaterThanOrEqualTo(2));
        controller.dispose();
      },
    );

    test('serializes rapid toggles so the final value wins', () async {
      final store = FakeAppFeedbackSettingsStore();
      final controller = AppFeedbackSettingsController(store: store);

      await controller.initialize();
      controller
        ..setSoundEnabled(false)
        ..setSoundEnabled(true)
        ..setSoundEnabled(false)
        ..setHapticEnabled(false)
        ..setHapticEnabled(true)
        ..setHapticEnabled(false);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(controller.soundEnabled, isFalse);
      expect(controller.hapticEnabled, isFalse);
      expect(store.soundWrites.last, isFalse);
      expect(store.hapticWrites.last, isFalse);
      controller.dispose();
    });
  });
}
