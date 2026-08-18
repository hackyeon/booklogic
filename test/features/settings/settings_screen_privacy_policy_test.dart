import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:booklogic/core/constants/app_strings.dart';
import 'package:booklogic/core/constants/app_urls.dart';
import 'package:booklogic/core/feedback/application/app_feedback_settings_controller.dart';
import 'package:booklogic/core/feedback/domain/app_feedback_settings.dart';
import 'package:booklogic/features/settings/presentation/settings_screen.dart';

import '../../helpers/fake_app_feedback_settings_store.dart';
import '../../helpers/fake_game_haptic_player.dart';
import '../../helpers/fake_game_sound_player.dart';

void main() {
  testWidgets('privacy policy tile opens the official URL externally', (
    tester,
  ) async {
    final launcher = _RecordingUrlLauncher(result: true);
    await _pumpSettings(tester, launcher: launcher.call);

    final tileFinder = find.byKey(const Key('settings_privacy_policy'));
    expect(tileFinder, findsOneWidget);
    final tile = tester.widget<ListTile>(tileFinder);
    expect((tile.title! as Text).data, AppStrings.privacyPolicy);
    expect((tile.trailing! as Icon).icon, Icons.chevron_right_rounded);

    await tester.tap(tileFinder);
    await tester.pump();

    expect(launcher.requestedUris, [Uri.parse(AppUrls.privacyPolicy)]);
    expect(launcher.requestedModes, [LaunchMode.externalApplication]);
    expect(find.text(AppStrings.privacyPolicyOpenError), findsNothing);
  });

  testWidgets('privacy policy tile shows an error when launch returns false', (
    tester,
  ) async {
    final launcher = _RecordingUrlLauncher(result: false);
    await _pumpSettings(tester, launcher: launcher.call);

    await tester.tap(find.byKey(const Key('settings_privacy_policy')));
    await tester.pumpAndSettle();

    expect(launcher.requestedUris, [Uri.parse(AppUrls.privacyPolicy)]);
    expect(launcher.requestedModes, [LaunchMode.externalApplication]);
    expect(find.text(AppStrings.privacyPolicyOpenError), findsOneWidget);
  });

  testWidgets('privacy policy tile handles launcher exceptions', (
    tester,
  ) async {
    final launcher = _RecordingUrlLauncher(error: StateError('blocked'));
    await _pumpSettings(tester, launcher: launcher.call);

    await tester.tap(find.byKey(const Key('settings_privacy_policy')));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.privacyPolicyOpenError), findsOneWidget);
    expect(find.textContaining('StateError'), findsNothing);
  });
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  required SettingsUrlLauncher launcher,
}) async {
  final controller = AppFeedbackSettingsController(
    store: FakeAppFeedbackSettingsStore(settings: AppFeedbackSettings.defaults),
  );
  await controller.initialize();
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    MaterialApp(
      home: SettingsScreen(
        feedbackSettingsController: controller,
        soundPlayer: FakeGameSoundPlayer(),
        hapticPlayer: FakeGameHapticPlayer(),
        urlLauncher: launcher,
      ),
    ),
  );
}

class _RecordingUrlLauncher {
  _RecordingUrlLauncher({this.result = false, this.error});

  final bool result;
  final Object? error;
  final List<Uri> requestedUris = [];
  final List<LaunchMode> requestedModes = [];

  Future<bool> call(
    Uri uri, {
    LaunchMode mode = LaunchMode.platformDefault,
  }) async {
    requestedUris.add(uri);
    requestedModes.add(mode);
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return result;
  }
}
