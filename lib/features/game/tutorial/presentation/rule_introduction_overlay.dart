import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../domain/rule_introduction.dart';

class RuleIntroductionOverlay extends StatelessWidget {
  const RuleIntroductionOverlay({
    required this.introduction,
    required this.onAcknowledge,
    super.key,
  });

  final RuleIntroduction introduction;
  final VoidCallback onAcknowledge;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.42),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.screenPadding),
                  child: Semantics(
                    container: true,
                    liveRegion: true,
                    label:
                        '${introduction.title}. ${introduction.description}. 예시: ${introduction.exampleClueText}',
                    child: Material(
                      color: colorScheme.surfaceContainerHigh,
                      elevation: 8,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(
                          AppDimensions.mediumSpacing,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '새로운 단서',
                              style: textTheme.labelLarge?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: AppDimensions.smallSpacing),
                            Text(
                              introduction.title,
                              style: textTheme.titleLarge,
                            ),
                            const SizedBox(height: AppDimensions.mediumSpacing),
                            Text(
                              introduction.description,
                              style: textTheme.bodyLarge,
                            ),
                            const SizedBox(height: AppDimensions.mediumSpacing),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: colorScheme.outlineVariant,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(
                                  AppDimensions.mediumSpacing,
                                ),
                                child: Text(
                                  introduction.exampleClueText,
                                  style: textTheme.bodyMedium,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppDimensions.mediumSpacing),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton(
                                key: const Key(
                                  'rule_introduction_acknowledge_button',
                                ),
                                onPressed: onAcknowledge,
                                child: const Text('확인'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
