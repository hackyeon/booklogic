import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimensions.dart';

class TutorialMessageCard extends StatelessWidget {
  const TutorialMessageCard({
    required this.message,
    required this.stepLabel,
    this.secondaryMessage,
    this.actionLabel,
    this.onAction,
    this.onSkip,
    this.canSkip = false,
    super.key,
  });

  final String message;
  final String? secondaryMessage;
  final String stepLabel;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onSkip;
  final bool canSkip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      container: true,
      liveRegion: true,
      label: '$stepLabel. $message',
      child: Material(
        color: colorScheme.surfaceContainerHigh,
        elevation: 6,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.mediumSpacing),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                stepLabel,
                style: textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppDimensions.smallSpacing),
              Text(message, style: textTheme.bodyLarge),
              if (secondaryMessage != null) ...[
                const SizedBox(height: AppDimensions.smallSpacing),
                Text(
                  secondaryMessage!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: AppDimensions.mediumSpacing),
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppDimensions.smallSpacing,
                runSpacing: AppDimensions.smallSpacing,
                children: [
                  if (canSkip)
                    TextButton(
                      key: const Key('tutorial_skip_button'),
                      onPressed: onSkip,
                      child: const Text('튜토리얼 건너뛰기'),
                    ),
                  if (actionLabel != null && onAction != null)
                    FilledButton(
                      key: const Key('tutorial_acknowledge_button'),
                      onPressed: onAction,
                      child: Text(actionLabel!),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
