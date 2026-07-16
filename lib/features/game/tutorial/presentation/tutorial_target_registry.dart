import 'package:flutter/material.dart';

class TutorialTargetRegistry {
  final Map<String, GlobalKey> _keysByTargetId = <String, GlobalKey>{};

  GlobalKey keyFor(String targetId) {
    return _keysByTargetId.putIfAbsent(
      targetId,
      () => GlobalKey(debugLabel: targetId),
    );
  }

  Rect? rectFor({
    required String targetId,
    required BuildContext overlayContext,
  }) {
    final targetContext = keyFor(targetId).currentContext;
    if (targetContext == null) {
      return null;
    }

    final targetRenderObject = targetContext.findRenderObject();
    final overlayRenderObject = overlayContext.findRenderObject();
    if (targetRenderObject is! RenderBox ||
        overlayRenderObject is! RenderBox ||
        !targetRenderObject.hasSize ||
        !overlayRenderObject.hasSize) {
      return null;
    }

    final globalTopLeft = targetRenderObject.localToGlobal(Offset.zero);
    final localTopLeft = overlayRenderObject.globalToLocal(globalTopLeft);
    return localTopLeft & targetRenderObject.size;
  }

  Future<bool> ensureVisible(String targetId) async {
    final targetContext = keyFor(targetId).currentContext;
    if (targetContext == null) {
      return false;
    }
    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      alignment: 0.4,
    );
    return true;
  }

  void clear() {
    _keysByTargetId.clear();
  }
}
