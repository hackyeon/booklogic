import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimensions.dart';
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
    this.ignorePointers = false,
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
  final bool ignorePointers;

  @override
  State<TutorialCoachMarkOverlay> createState() =>
      _TutorialCoachMarkOverlayState();
}

class _TutorialCoachMarkOverlayState extends State<TutorialCoachMarkOverlay> {
  Rect? _targetRect;
  String? _measuredTargetId;
  int _measureAttempts = 0;

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
    final targetRect = _paddedTargetRect(context);
    final color = Colors.black.withValues(alpha: 0.48);

    final overlay = LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

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
                ),
                child: IgnorePointer(
                  ignoring:
                      widget.onTargetTap != null &&
                      !widget.step.requiresAcknowledgement,
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
            ),
          ],
        );
      },
    );
    return Positioned.fill(
      child: widget.ignorePointers ? IgnorePointer(child: overlay) : overlay,
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

  Rect? _paddedTargetRect(BuildContext context) {
    final rect = _targetRect;
    if (rect == null) {
      return null;
    }
    final mediaSize = MediaQuery.sizeOf(context);
    final padded = rect.inflate(8);
    return Rect.fromLTRB(
      padded.left.clamp(0.0, mediaSize.width),
      padded.top.clamp(0.0, mediaSize.height),
      padded.right.clamp(0.0, mediaSize.width),
      padded.bottom.clamp(0.0, mediaSize.height),
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
    final shouldSkip = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('튜토리얼을 건너뛸까요?'),
          content: const Text('게임은 계속 진행할 수 있으며, 새로운 단서 설명은 이후에도 확인할 수 있습니다.'),
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
    if (shouldSkip == true && mounted) {
      widget.onSkipConfirmed();
    }
  }
}

class _TutorialMessageLayoutDelegate extends SingleChildLayoutDelegate {
  const _TutorialMessageLayoutDelegate({required this.targetRect});

  final Rect? targetRect;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final availableWidth = math.max(
      0.0,
      constraints.maxWidth - AppDimensions.screenPadding * 2,
    );
    final availableHeight = math.max(
      0.0,
      constraints.maxHeight - AppDimensions.screenPadding * 2,
    );
    return BoxConstraints(
      maxWidth: math.min(380, availableWidth),
      maxHeight: availableHeight,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    const edgePadding = AppDimensions.screenPadding;
    final horizontalLimit = math.max(
      edgePadding,
      size.width - childSize.width - edgePadding,
    );
    final desiredLeft = targetRect == null
        ? (size.width - childSize.width) / 2
        : targetRect!.center.dx - childSize.width / 2;
    final left = desiredLeft.clamp(edgePadding, horizontalLimit);

    final verticalLimit = math.max(
      edgePadding,
      size.height - childSize.height - edgePadding,
    );
    if (targetRect == null) {
      return Offset(left, verticalLimit);
    }

    final belowTop = targetRect!.bottom + AppDimensions.mediumSpacing;
    final hasRoomBelow =
        belowTop + childSize.height + edgePadding <= size.height;
    final desiredTop = hasRoomBelow
        ? belowTop
        : targetRect!.top - childSize.height - AppDimensions.mediumSpacing;
    return Offset(left, desiredTop.clamp(edgePadding, verticalLimit));
  }

  @override
  bool shouldRelayout(covariant _TutorialMessageLayoutDelegate oldDelegate) {
    return oldDelegate.targetRect != targetRect;
  }
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
