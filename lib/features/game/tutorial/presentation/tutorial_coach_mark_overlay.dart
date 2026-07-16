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
    super.key,
  });

  final TutorialTargetRegistry registry;
  final TutorialStep step;
  final int stepIndex;
  final int totalStepCount;
  final VoidCallback onAcknowledge;
  final VoidCallback onSkipConfirmed;

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

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final cardRect = _messageCardRect(
            screenSize: size,
            targetRect: targetRect,
          );

          return Stack(
            children: [
              if (targetRect == null)
                Positioned.fill(child: _Barrier(color: color))
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
              Positioned.fromRect(
                rect: cardRect,
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
            ],
          );
        },
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
        child: _Barrier(color: color),
      ),
      Positioned(
        left: 0,
        top: targetRect.top,
        width: targetRect.left,
        height: targetRect.height,
        child: _Barrier(color: color),
      ),
      Positioned(
        left: targetRect.right,
        top: targetRect.top,
        width: screenSize.width - targetRect.right,
        height: targetRect.height,
        child: _Barrier(color: color),
      ),
      Positioned(
        left: 0,
        top: targetRect.bottom,
        width: screenSize.width,
        height: screenSize.height - targetRect.bottom,
        child: _Barrier(color: color),
      ),
    ];
  }

  Rect _messageCardRect({required Size screenSize, required Rect? targetRect}) {
    const horizontalPadding = AppDimensions.screenPadding;
    const verticalPadding = AppDimensions.screenPadding;
    final width = (screenSize.width - horizontalPadding * 2).clamp(
      240.0,
      380.0,
    );
    const height = 200.0;
    final left = targetRect == null
        ? (screenSize.width - width) / 2
        : (targetRect.center.dx - width / 2).clamp(
            horizontalPadding,
            screenSize.width - width - horizontalPadding,
          );
    final belowTop = (targetRect?.bottom ?? 0) + AppDimensions.mediumSpacing;
    final aboveTop =
        (targetRect?.top ?? (screenSize.height / 2)) -
        height -
        AppDimensions.mediumSpacing;
    final hasRoomBelow =
        belowTop + height + verticalPadding < screenSize.height;
    final top = targetRect == null
        ? (screenSize.height - height - verticalPadding)
        : hasRoomBelow
        ? belowTop
        : aboveTop.clamp(verticalPadding, screenSize.height - height);

    return Rect.fromLTWH(left, top, width, height);
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

class _Barrier extends StatelessWidget {
  const _Barrier({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: ColoredBox(color: color),
    );
  }
}
