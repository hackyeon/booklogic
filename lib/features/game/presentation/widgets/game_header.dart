import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/app_colors.dart';

class GameHeader extends StatelessWidget {
  const GameHeader({
    required this.level,
    required this.onBack,
    required this.onSettings,
    this.settingsEnabled = true,
    super.key = const Key('game_header'),
  });

  final int level;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final bool settingsEnabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.gameHeaderHorizontalPadding,
        vertical: AppDimensions.gameHeaderVerticalPadding,
      ),
      child: Row(
        children: [
          _HeaderControl(
            key: const Key('game_back_button'),
            tooltip: '뒤로 가기',
            icon: Icons.arrow_back_rounded,
            onPressed: onBack,
          ),
          Expanded(
            child: Center(
              child: Semantics(
                label: '레벨 $level',
                excludeSemantics: true,
                child: Container(
                  key: const Key('game_level_label'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Level $level',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.primaryStrong,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
          _HeaderControl(
            key: const Key('game_settings_button'),
            tooltip: '설정',
            icon: Icons.settings_rounded,
            onPressed: settingsEnabled ? onSettings : null,
          ),
        ],
      ),
    );
  }
}

class _HeaderControl extends StatelessWidget {
  const _HeaderControl({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: tooltip,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: AppDimensions.gameHeaderControlSize,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.bookShadow,
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            tooltip: tooltip,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(
              width: AppDimensions.gameHeaderControlSize,
              height: AppDimensions.gameHeaderControlSize,
            ),
            color: AppColors.primaryStrong,
            disabledColor: AppColors.textSecondary,
            onPressed: onPressed,
            icon: Icon(icon),
          ),
        ),
      ),
    );
  }
}
