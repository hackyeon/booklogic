import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';

class InterstitialSystemBarGuard extends StatefulWidget {
  const InterstitialSystemBarGuard({
    required this.isShowing,
    required this.child,
    this.targetPlatform,
    super.key,
  });

  final bool isShowing;
  final Widget child;
  final TargetPlatform? targetPlatform;

  @override
  State<InterstitialSystemBarGuard> createState() =>
      _InterstitialSystemBarGuardState();
}

class _InterstitialSystemBarGuardState
    extends State<InterstitialSystemBarGuard> {
  double _lastKnownTopInset = 0;

  @override
  Widget build(BuildContext context) {
    final currentTopInset = MediaQuery.viewPaddingOf(context).top;
    if (!widget.isShowing && currentTopInset > 0) {
      _lastKnownTopInset = currentTopInset;
    }

    final isAndroid =
        (widget.targetPlatform ?? defaultTargetPlatform) ==
        TargetPlatform.android;
    final guardedTopInset = math.max(currentTopInset, _lastKnownTopInset);
    final shouldShowScrim =
        isAndroid && widget.isShowing && guardedTopInset > 0;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (shouldShowScrim)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: guardedTopInset,
            child: IgnorePointer(
              child: AnnotatedRegion<SystemUiOverlayStyle>(
                value: AppTheme.interstitialSystemUiOverlayStyle,
                child: const ColoredBox(
                  key: Key('interstitial_system_bar_scrim'),
                  color: Colors.black,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
