import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/feedback/application/app_feedback_settings_controller.dart';
import '../../../core/feedback/domain/game_haptic_cue.dart';
import '../../../core/feedback/domain/game_sound_cue.dart';
import '../../../core/feedback/haptic/game_haptic_player.dart';
import '../../../core/feedback/sound/game_sound_player.dart';
import '../../../core/theme/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.feedbackSettingsController,
    required this.soundPlayer,
    required this.hapticPlayer,
    super.key,
  });

  final AppFeedbackSettingsController feedbackSettingsController;
  final GameSoundPlayer soundPlayer;
  final GameHapticPlayer hapticPlayer;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Object? _lastShownError;

  @override
  void initState() {
    super.initState();
    widget.feedbackSettingsController.addListener(_handleSettingsChanged);
  }

  @override
  void dispose() {
    widget.feedbackSettingsController.removeListener(_handleSettingsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settingsButton)),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: widget.feedbackSettingsController,
          builder: (context, _) {
            final controller = widget.feedbackSettingsController;
            return ListView(
              padding: const EdgeInsets.all(AppDimensions.screenPadding),
              children: [
                Text(
                  '게임 피드백',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppDimensions.smallSpacing),
                _SettingsSection(
                  children: [
                    SwitchListTile(
                      key: const Key('settings_sound_switch'),
                      value: controller.soundEnabled,
                      onChanged: _handleSoundChanged,
                      title: const Text(AppStrings.sound),
                      subtitle: const Text('책 선택, 교환, 단서 완료 효과음을 재생합니다.'),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      key: const Key('settings_haptic_switch'),
                      value: controller.hapticEnabled,
                      onChanged: _handleHapticChanged,
                      title: const Text(AppStrings.haptic),
                      subtitle: const Text('게임 조작과 완료 시 햅틱 피드백을 사용합니다.'),
                    ),
                  ],
                ),
                if (controller.isSavingSound || controller.isSavingHaptic) ...[
                  const SizedBox(height: AppDimensions.smallSpacing),
                  const LinearProgressIndicator(minHeight: 2),
                ],
                const SizedBox(height: AppDimensions.sectionSpacing),
                _SettingsSection(
                  children: [
                    ListTile(
                      title: const Text(AppStrings.privacyPolicy),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _showPrivacySnackBar(context),
                    ),
                    ListTile(
                      title: const Text(AppStrings.openSourceLicenses),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => showLicensePage(
                        context: context,
                        applicationName: AppStrings.appTitle,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _handleSoundChanged(bool enabled) {
    final controller = widget.feedbackSettingsController;
    if (controller.soundEnabled == enabled) {
      return;
    }
    controller.setSoundEnabled(enabled);
    if (enabled) {
      unawaited(widget.soundPlayer.play(GameSoundCue.bookSelect));
    } else {
      unawaited(widget.soundPlayer.stopAll());
    }
  }

  void _handleHapticChanged(bool enabled) {
    final controller = widget.feedbackSettingsController;
    if (controller.hapticEnabled == enabled) {
      return;
    }
    controller.setHapticEnabled(enabled);
    if (enabled) {
      unawaited(widget.hapticPlayer.play(GameHapticCue.bookSelect));
    }
  }

  void _handleSettingsChanged() {
    final error = widget.feedbackSettingsController.lastError;
    if (error == null || identical(error, _lastShownError)) {
      return;
    }
    _lastShownError = error;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('설정을 저장하지 못했습니다. 현재 실행 중에는 변경 사항이 적용됩니다.'),
          ),
        );
      widget.feedbackSettingsController.clearError();
    });
  }

  void _showPrivacySnackBar(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text(AppStrings.privacyPlaceholder)),
      );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}
