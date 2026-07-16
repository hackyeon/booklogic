import 'package:flutter/material.dart';

import 'tutorial_target_registry.dart';

class TutorialTargetWidget extends StatelessWidget {
  const TutorialTargetWidget({
    required this.registry,
    required this.targetId,
    required this.child,
    super.key,
  });

  final TutorialTargetRegistry registry;
  final String targetId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: registry.keyFor(targetId), child: child);
  }
}
