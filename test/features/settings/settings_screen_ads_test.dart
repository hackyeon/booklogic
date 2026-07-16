import 'package:booklogic/core/ads/consent/ad_consent_controller.dart';
import 'package:booklogic/core/feedback/application/app_feedback_settings_controller.dart';
import 'package:booklogic/core/feedback/domain/app_feedback_settings.dart';
import 'package:booklogic/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_ad_services.dart';
import '../../helpers/fake_app_feedback_settings_store.dart';
import '../../helpers/fake_game_haptic_player.dart';
import '../../helpers/fake_game_sound_player.dart';

void main() {
  group('SettingsScreen ad privacy options', () {
    testWidgets('shows the ad privacy tile only when required', (tester) async {
      final visibleFixture = await _buildSettingsFixture(
        privacyOptionsRequired: true,
      );

      await tester.pumpWidget(visibleFixture.widget);

      expect(
        find.byKey(const Key('settings_ad_privacy_options')),
        findsOneWidget,
      );
      expect(find.text('광고 개인정보 설정'), findsOneWidget);
      expect(find.text('광고와 관련된 개인정보 선택을 변경합니다.'), findsOneWidget);

      visibleFixture.dispose();

      final hiddenFixture = await _buildSettingsFixture(
        privacyOptionsRequired: false,
      );

      await tester.pumpWidget(hiddenFixture.widget);

      expect(
        find.byKey(const Key('settings_ad_privacy_options')),
        findsNothing,
      );

      hiddenFixture.dispose();
    });

    testWidgets('opens privacy options through the consent controller', (
      tester,
    ) async {
      final fixture = await _buildSettingsFixture(privacyOptionsRequired: true);

      await tester.pumpWidget(fixture.widget);
      await tester.tap(find.byKey(const Key('settings_ad_privacy_options')));
      await tester.pumpAndSettle();

      expect(fixture.adConsentService.showPrivacyOptionsFormCount, 1);

      fixture.dispose();
    });

    testWidgets('shows a snack bar when privacy options cannot open', (
      tester,
    ) async {
      final fixture = await _buildSettingsFixture(
        privacyOptionsRequired: true,
        showPrivacyOptionsError: StateError('blocked'),
      );

      await tester.pumpWidget(fixture.widget);
      await tester.tap(find.byKey(const Key('settings_ad_privacy_options')));
      await tester.pumpAndSettle();

      expect(
        find.text('광고 개인정보 설정을 열지 못했습니다. 잠시 후 다시 시도해 주세요.'),
        findsOneWidget,
      );

      fixture.dispose();
    });
  });
}

Future<_SettingsFixture> _buildSettingsFixture({
  required bool privacyOptionsRequired,
  Object? showPrivacyOptionsError,
}) async {
  final feedbackSettingsController = AppFeedbackSettingsController(
    store: FakeAppFeedbackSettingsStore(settings: AppFeedbackSettings.defaults),
  );
  await feedbackSettingsController.initialize();

  final adConsentService = FakeAdConsentService(
    canRequestAdsValue: true,
    privacyOptionsRequiredValue: privacyOptionsRequired,
    showPrivacyOptionsFormError: showPrivacyOptionsError,
  );
  final adConsentController = AdConsentController(service: adConsentService);
  await adConsentController.initialize();

  return _SettingsFixture(
    adConsentService: adConsentService,
    adConsentController: adConsentController,
    feedbackSettingsController: feedbackSettingsController,
    widget: MaterialApp(
      home: SettingsScreen(
        feedbackSettingsController: feedbackSettingsController,
        adConsentController: adConsentController,
        soundPlayer: FakeGameSoundPlayer(),
        hapticPlayer: FakeGameHapticPlayer(),
      ),
    ),
  );
}

class _SettingsFixture {
  const _SettingsFixture({
    required this.adConsentService,
    required this.adConsentController,
    required this.feedbackSettingsController,
    required this.widget,
  });

  final FakeAdConsentService adConsentService;
  final AdConsentController adConsentController;
  final AppFeedbackSettingsController feedbackSettingsController;
  final Widget widget;

  void dispose() {
    adConsentController.dispose();
    feedbackSettingsController.dispose();
  }
}
