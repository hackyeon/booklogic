import 'dart:async';

import 'package:booklogic/core/ads/consent/ad_consent_controller.dart';
import 'package:booklogic/core/ads/domain/interstitial_ad_state.dart';
import 'package:booklogic/core/ads/domain/interstitial_show_outcome.dart';
import 'package:booklogic/core/ads/interstitial/interstitial_ad_controller.dart';
import 'package:booklogic/core/ads/interstitial/interstitial_ad_handle.dart';
import 'package:booklogic/core/ads/interstitial/interstitial_ad_policy.dart';
import 'package:booklogic/core/ads/presentation/interstitial_system_bar_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_ad_services.dart';

void main() {
  testWidgets(
    'Android guard follows controller showing state and caches top inset',
    (tester) async {
      final handle = _PendingInterstitialAdHandle();
      final fixture = await _buildControllerFixture(
        handle,
        presentationBarrier: () => tester.binding.endOfFrame,
      );
      final topInset = ValueNotifier<double>(24);
      addTearDown(fixture.dispose);
      addTearDown(topInset.dispose);

      await fixture.controller.ensureLoaded(currentLevel: 6);
      expect(fixture.controller.state, InterstitialAdState.ready);
      await _pumpGuard(
        tester,
        controller: fixture.controller,
        topInset: topInset,
        targetPlatform: TargetPlatform.android,
      );
      expect(_scrim, findsNothing);

      topInset.value = 0;
      final showFuture = fixture.controller.showIfReady();
      expect(fixture.controller.state, InterstitialAdState.showing);
      expect(handle.showCount, 0);
      await tester.pump();

      expect(_scrim, findsOneWidget);
      expect(tester.getSize(_scrim).height, 24);
      expect(tester.widget<ColoredBox>(_scrim).color, Colors.black);
      expect(handle.showCount, 1);

      handle.complete(InterstitialShowOutcome.shownAndDismissed);
      expect(await showFuture, InterstitialShowOutcome.shownAndDismissed);
      await tester.pump();

      expect(fixture.controller.state, InterstitialAdState.idle);
      expect(_scrim, findsNothing);
      expect(handle.disposeCount, 1);
    },
  );

  testWidgets('failedToShow removes the Android system bar scrim', (
    tester,
  ) async {
    final handle = _PendingInterstitialAdHandle();
    final fixture = await _buildControllerFixture(handle);
    final topInset = ValueNotifier<double>(24);
    addTearDown(fixture.dispose);
    addTearDown(topInset.dispose);

    await fixture.controller.ensureLoaded(currentLevel: 6);
    await _pumpGuard(
      tester,
      controller: fixture.controller,
      topInset: topInset,
      targetPlatform: TargetPlatform.android,
    );

    final showFuture = fixture.controller.showIfReady();
    await tester.pump();
    expect(_scrim, findsOneWidget);

    handle.complete(InterstitialShowOutcome.failedToShow);
    expect(await showFuture, InterstitialShowOutcome.failedToShow);
    await tester.pump();

    expect(fixture.controller.state, InterstitialAdState.idle);
    expect(_scrim, findsNothing);
  });

  testWidgets('show exception removes the Android system bar scrim', (
    tester,
  ) async {
    final handle = _PendingInterstitialAdHandle();
    final fixture = await _buildControllerFixture(handle);
    final topInset = ValueNotifier<double>(24);
    addTearDown(fixture.dispose);
    addTearDown(topInset.dispose);

    await fixture.controller.ensureLoaded(currentLevel: 6);
    await _pumpGuard(
      tester,
      controller: fixture.controller,
      topInset: topInset,
      targetPlatform: TargetPlatform.android,
    );

    final showFuture = fixture.controller.showIfReady();
    await tester.pump();
    expect(_scrim, findsOneWidget);

    handle.completeError(StateError('show failed'));
    expect(await showFuture, InterstitialShowOutcome.failedToShow);
    await tester.pump();

    expect(fixture.controller.state, InterstitialAdState.idle);
    expect(_scrim, findsNothing);
  });

  testWidgets('iOS never adds the Android system bar scrim', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(390, 844),
            viewPadding: EdgeInsets.only(top: 47),
          ),
          child: InterstitialSystemBarGuard(
            isShowing: true,
            targetPlatform: TargetPlatform.iOS,
            child: ColoredBox(color: Colors.white),
          ),
        ),
      ),
    );

    expect(_scrim, findsNothing);
  });
}

Finder get _scrim => find.byKey(const Key('interstitial_system_bar_scrim'));

Future<void> _pumpGuard(
  WidgetTester tester, {
  required InterstitialAdController controller,
  required ValueNotifier<double> topInset,
  required TargetPlatform targetPlatform,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ListenableBuilder(
        listenable: Listenable.merge([controller, topInset]),
        builder: (context, _) {
          return MediaQuery(
            data: MediaQueryData(
              size: const Size(390, 844),
              viewPadding: EdgeInsets.only(top: topInset.value),
            ),
            child: InterstitialSystemBarGuard(
              isShowing: controller.isShowing,
              targetPlatform: targetPlatform,
              child: const ColoredBox(color: Colors.white),
            ),
          );
        },
      ),
    ),
  );
}

Future<_ControllerFixture> _buildControllerFixture(
  InterstitialAdHandle handle, {
  InterstitialPresentationBarrier? presentationBarrier,
}) async {
  final service = FakeAdConsentService(canRequestAdsValue: true);
  final consentController = AdConsentController(service: service);
  await consentController.initialize();
  final controller = InterstitialAdController(
    consentController: consentController,
    mobileAdsInitializer: FakeMobileAdsInitializer(),
    gateway: FakeInterstitialAdGateway(ads: [handle]),
    adUnitIdProvider: FakeAdUnitIdProvider(id: 'test-interstitial'),
    policy: const InterstitialAdPolicy(),
    presentationBarrier: presentationBarrier,
  );
  return _ControllerFixture(
    consentController: consentController,
    controller: controller,
  );
}

class _ControllerFixture {
  const _ControllerFixture({
    required this.consentController,
    required this.controller,
  });

  final AdConsentController consentController;
  final InterstitialAdController controller;

  void dispose() {
    controller.dispose();
    consentController.dispose();
  }
}

class _PendingInterstitialAdHandle implements InterstitialAdHandle {
  final Completer<InterstitialShowOutcome> _completer =
      Completer<InterstitialShowOutcome>();
  int disposeCount = 0;
  int showCount = 0;

  @override
  Future<InterstitialShowOutcome> show() {
    showCount += 1;
    return _completer.future;
  }

  void complete(InterstitialShowOutcome outcome) {
    _completer.complete(outcome);
  }

  void completeError(Object error) {
    _completer.completeError(error);
  }

  @override
  void dispose() {
    disposeCount += 1;
  }
}
