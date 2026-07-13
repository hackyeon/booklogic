import 'package:flutter/material.dart';

import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _soundEnabled = true;
  bool _musicEnabled = true;
  bool _hapticEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settingsButton)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppDimensions.screenPadding),
          children: [
            _SettingsSection(
              children: [
                SwitchListTile(
                  value: _soundEnabled,
                  onChanged: (value) => setState(() => _soundEnabled = value),
                  title: const Text(AppStrings.sound),
                ),
                SwitchListTile(
                  value: _musicEnabled,
                  onChanged: (value) => setState(() => _musicEnabled = value),
                  title: const Text(AppStrings.music),
                ),
                SwitchListTile(
                  value: _hapticEnabled,
                  onChanged: (value) => setState(() => _hapticEnabled = value),
                  title: const Text(AppStrings.haptic),
                ),
              ],
            ),
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
        ),
      ),
    );
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
