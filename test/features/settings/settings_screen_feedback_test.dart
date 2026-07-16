import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:booklogic/core/feedback/application/app_feedback_settings_controller.dart';
import 'package:booklogic/core/feedback/domain/app_feedback_settings.dart';
import 'package:booklogic/core/feedback/domain/game_haptic_cue.dart';
import 'package:booklogic/core/feedback/domain/game_sound_cue.dart';
import 'package:booklogic/features/settings/presentation/settings_screen.dart';

import '../../helpers/fake_app_feedback_settings_store.dart';
import '../../helpers/fake_game_haptic_player.dart';
import '../../helpers/fake_game_sound_player.dart';

void main() {
  testWidgets('shows feedback switches and hides music switch', (tester) async {
    final store = FakeAppFeedbackSettingsStore(
      settings: const AppFeedbackSettings(
        soundEnabled: true,
        hapticEnabled: false,
      ),
    );
    final controller = AppFeedbackSettingsController(store: store);
    await controller.initialize();
    final soundPlayer = FakeGameSoundPlayer();
    final hapticPlayer = FakeGameHapticPlayer();

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          feedbackSettingsController: controller,
          soundPlayer: soundPlayer,
          hapticPlayer: hapticPlayer,
        ),
      ),
    );

    expect(find.text('게임 피드백'), findsOneWidget);
    expect(find.text('효과음'), findsOneWidget);
    expect(find.text('진동'), findsOneWidget);
    expect(find.text('배경음악'), findsNothing);
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('settings_sound_switch')),
          )
          .value,
      isTrue,
    );
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('settings_haptic_switch')),
          )
          .value,
      isFalse,
    );

    await tester.tap(find.byKey(const Key('settings_sound_switch')));
    await tester.pump();
    expect(controller.soundEnabled, isFalse);
    expect(store.saves.last.soundEnabled, isFalse);
    expect(store.saves.last.hapticEnabled, isFalse);
    expect(soundPlayer.playedCues, isEmpty);
    expect(soundPlayer.stopAllCount, 1);

    await tester.tap(find.byKey(const Key('settings_sound_switch')));
    await tester.pump();
    expect(controller.soundEnabled, isTrue);
    expect(soundPlayer.playedCues, [GameSoundCue.bookSelect]);

    await tester.tap(find.byKey(const Key('settings_haptic_switch')));
    await tester.pump();
    expect(controller.hapticEnabled, isTrue);
    expect(store.saves.last.soundEnabled, isTrue);
    expect(store.saves.last.hapticEnabled, isTrue);
    expect(hapticPlayer.playedCues, [GameHapticCue.bookSelect]);

    controller.dispose();
  });
}
