import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../domain/tutorial_step.dart';
import 'tutorial_message_card.dart';
import 'tutorial_target_registry.dart';

class TutorialCoachMarkOverlay extends StatefulWidget {
  const TutorialCoachMarkOverlay({
    required this.registry,
    required this.step,
    required this.stepIndex,
    required this.totalStepCount,
    required this.onAcknowledge,
    required this.onSkipConfirmed,
    this.onTargetTap,
    this.blockBackgroundInteraction = true,
    this.useRootSafeInsets = false,
    super.key,
  });

  final TutorialTargetRegistry registry;
  final TutorialStep step;
  final int stepIndex;
  final int totalStepCount;
  final VoidCallback onAcknowledge;
  final VoidCallback onSkipConfirmed;
  final VoidCallback? onTargetTap;
  final bool blockBackgroundInteraction;
  final bool useRootSafeInsets;

  @override
  State<TutorialCoachMarkOverlay> createState() =>
      _TutorialCoachMarkOverlayState();
}

class _TutorialCoachMarkOverlayState extends State<TutorialCoachMarkOverlay> {
  Rect? _targetRect;
  String? _measuredTargetId;
  int _measureAttempts = 0;
  bool _isSkipConfirmationOpen = false;

  @override
  void initState() {
    super.initState();
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(covariant TutorialCoachMarkOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.step.id != widget.step.id) {
      _targetRect = null;
      _measuredTargetId = null;
      _measureAttempts = 0;
      _scheduleMeasure();
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeInsets = widget.useRootSafeInsets
        ? MediaQuery.viewPaddingOf(context)
        : EdgeInsets.zero;
    const color = AppColors.tutorialScrim;

    final overlay = LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final targetRect = _paddedTargetRect(size);

        return Stack(
          children: [
            if (targetRect == null)
              Positioned.fill(
                child: _Barrier(
                  color: color,
                  absorbsPointer: widget.blockBackgroundInteraction,
                ),
              )
            else
              ..._barriers(targetRect, size, color),
            if (targetRect != null)
              Positioned.fromRect(
                rect: targetRect,
                child: IgnorePointer(
                  child: DecoratedBox(
                    key: const Key('tutorial_target_cutout'),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 3,
                      ),
                    ),
                  ),
                ),
              ),
            if (targetRect != null && widget.onTargetTap != null)
              Positioned.fromRect(
                rect: targetRect,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onTargetTap,
                  child: const SizedBox.expand(),
                ),
              ),
            Positioned.fill(
              child: CustomSingleChildLayout(
                delegate: _TutorialMessageLayoutDelegate(
                  targetRect: targetRect,
                  safeInsets: safeInsets,
                ),
                child: TutorialMessageCard(
                  message: widget.step.message,
                  secondaryMessage: widget.step.secondaryMessage,
                  stepLabel:
                      '튜토리얼 ${widget.stepIndex + 1}/${widget.totalStepCount}',
                  actionLabel: widget.step.actionLabel,
                  onAction: widget.step.requiresAcknowledgement
                      ? widget.onAcknowledge
                      : null,
                  canSkip: widget.step.allowSkip,
                  onSkip: _confirmSkip,
                ),
              ),
            ),
          ],
        );
      },
    );
    return Positioned.fill(
      child: SizedBox.expand(
        key: const Key('tutorial_overlay_bounds'),
        child: overlay,
      ),
    );
  }

  List<Widget> _barriers(Rect targetRect, Size screenSize, Color color) {
    return [
      Positioned(
        left: 0,
        top: 0,
        width: screenSize.width,
        height: targetRect.top,
        child: _Barrier(
          color: color,
          absorbsPointer: widget.blockBackgroundInteraction,
        ),
      ),
      Positioned(
        left: 0,
        top: targetRect.top,
        width: targetRect.left,
        height: targetRect.height,
        child: _Barrier(
          color: color,
          absorbsPointer: widget.blockBackgroundInteraction,
        ),
      ),
      Positioned(
        left: targetRect.right,
        top: targetRect.top,
        width: screenSize.width - targetRect.right,
        height: targetRect.height,
        child: _Barrier(
          color: color,
          absorbsPointer: widget.blockBackgroundInteraction,
        ),
      ),
      Positioned(
        left: 0,
        top: targetRect.bottom,
        width: screenSize.width,
        height: screenSize.height - targetRect.bottom,
        child: _Barrier(
          color: color,
          absorbsPointer: widget.blockBackgroundInteraction,
        ),
      ),
    ];
  }

  Rect? _paddedTargetRect(Size overlaySize) {
    final rect = _targetRect;
    if (rect == null) {
      return null;
    }
    final padded = rect.inflate(8);
    return Rect.fromLTRB(
      padded.left.clamp(0.0, overlaySize.width),
      padded.top.clamp(0.0, overlaySize.height),
      padded.right.clamp(0.0, overlaySize.width),
      padded.bottom.clamp(0.0, overlaySize.height),
    );
  }

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _measureTarget();
    });
  }

  Future<void> _measureTarget() async {
    final targetId = widget.step.target.targetId;
    if (targetId == null) {
      setState(() {
        _targetRect = null;
        _measuredTargetId = null;
      });
      return;
    }

    if (_measuredTargetId != targetId) {
      _measuredTargetId = targetId;
      await widget.registry.ensureVisible(targetId);
      if (!mounted) {
        return;
      }
    }

    final rect = widget.registry.rectFor(
      targetId: targetId,
      overlayContext: context,
    );
    if (rect != null) {
      setState(() {
        _targetRect = rect;
      });
      return;
    }

    _measureAttempts += 1;
    if (_measureAttempts < 3) {
      _scheduleMeasure();
    } else {
      debugPrint('Tutorial target was not found: $targetId');
      setState(() {
        _targetRect = null;
      });
    }
  }

  Future<void> _confirmSkip() async {
    if (_isSkipConfirmationOpen) {
      return;
    }
    _isSkipConfirmationOpen = true;
    bool? shouldSkip;
    try {
      shouldSkip = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('튜토리얼을 건너뛸까요?'),
            content: const Text(
              '게임은 계속 진행할 수 있으며, 새로운 단서 설명은 이후에도 확인할 수 있습니다.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('계속 배우기'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('건너뛰기'),
              ),
            ],
          );
        },
      );
    } finally {
      _isSkipConfirmationOpen = false;
    }
    if (shouldSkip == true && mounted) {
      widget.onSkipConfirmed();
    }
  }
}

class _TutorialMessageLayoutDelegate extends SingleChildLayoutDelegate {
  const _TutorialMessageLayoutDelegate({
    required this.targetRect,
    required this.safeInsets,
  });

  final Rect? targetRect;
  final EdgeInsets safeInsets;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final availableWidth = math.max(
      0.0,
      constraints.maxWidth -
          safeInsets.horizontal -
          AppDimensions.screenPadding * 2,
    );
    final availableHeight = math.max(
      0.0,
      constraints.maxHeight -
          safeInsets.vertical -
          AppDimensions.screenPadding * 2,
    );
    return BoxConstraints(
      maxWidth: math.min(380, availableWidth),
      maxHeight: availableHeight,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final leftEdge = safeInsets.left + AppDimensions.screenPadding;
    final rightEdge = safeInsets.right + AppDimensions.screenPadding;
    final topEdge = safeInsets.top + AppDimensions.screenPadding;
    final bottomEdge = safeInsets.bottom + AppDimensions.screenPadding;
    final horizontalLimit = math.max(
      leftEdge,
      size.width - childSize.width - rightEdge,
    );
    final desiredLeft = targetRect == null
        ? (size.width - childSize.width) / 2
        : targetRect!.center.dx - childSize.width / 2;
    final left = desiredLeft.clamp(leftEdge, horizontalLimit);

    final verticalLimit = math.max(
      topEdge,
      size.height - childSize.height - bottomEdge,
    );
    if (targetRect == null) {
      return Offset(left, verticalLimit);
    }

    final belowTop = targetRect!.bottom + AppDimensions.mediumSpacing;
    final hasRoomBelow =
        belowTop + childSize.height + bottomEdge <= size.height;
    if (hasRoomBelow) {
      return Offset(left, belowTop);
    }

    final aboveTop =
        targetRect!.top - childSize.height - AppDimensions.mediumSpacing;
    if (aboveTop >= topEdge) {
      return Offset(left, aboveTop);
    }

    final clampedBelowTop = belowTop.clamp(topEdge, verticalLimit);
    final clampedAboveTop = aboveTop.clamp(topEdge, verticalLimit);
    final belowOverlap = _verticalOverlap(
      top: clampedBelowTop,
      height: childSize.height,
      target: targetRect!,
    );
    final aboveOverlap = _verticalOverlap(
      top: clampedAboveTop,
      height: childSize.height,
      target: targetRect!,
    );
    return Offset(
      left,
      belowOverlap <= aboveOverlap ? clampedBelowTop : clampedAboveTop,
    );
  }

  @override
  bool shouldRelayout(covariant _TutorialMessageLayoutDelegate oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.safeInsets != safeInsets;
  }
}

double _verticalOverlap({
  required double top,
  required double height,
  required Rect target,
}) {
  return math.max(
    0,
    math.min(top + height, target.bottom) - math.max(top, target.top),
  );
}

class _Barrier extends StatelessWidget {
  const _Barrier({required this.color, required this.absorbsPointer});

  final Color color;
  final bool absorbsPointer;

  @override
  Widget build(BuildContext context) {
    final barrier = ColoredBox(color: color);
    if (!absorbsPointer) {
      return IgnorePointer(child: barrier);
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: barrier,
    );
  }
}
