import 'dart:async';

import 'package:flutter/material.dart';

import '../core/ads/application/ad_bootstrap_controller.dart';
import '../core/ads/application/ad_session_coordinator.dart';
import '../core/ads/config/ad_runtime_config.dart';
import '../core/ads/config/ad_unit_id_provider.dart';
import '../core/ads/consent/ad_consent_controller.dart';
import '../core/ads/consent/ad_consent_service.dart';
import '../core/ads/consent/google_ump_consent_service.dart';
import '../core/ads/interstitial/google_interstitial_ad_gateway.dart';
import '../core/ads/interstitial/interstitial_ad_controller.dart';
import '../core/ads/interstitial/interstitial_ad_gateway.dart';
import '../core/ads/interstitial/interstitial_ad_policy.dart';
import '../core/ads/interstitial/next_level_ad_gate.dart';
import '../core/ads/sdk/google_mobile_ads_initializer.dart';
import '../core/ads/sdk/mobile_ads_initializer.dart';
import '../core/constants/app_strings.dart';
import '../core/feedback/application/app_feedback_settings_controller.dart';
import '../core/feedback/data/app_feedback_settings_store.dart';
import '../core/feedback/data/shared_preferences_app_feedback_settings_store.dart';
import '../core/feedback/haptic/flutter_game_haptic_player.dart';
import '../core/feedback/haptic/game_haptic_player.dart';
import '../core/feedback/sound/asset_game_sound_player.dart';
import '../core/feedback/sound/game_sound_player.dart';
import '../core/persistence/application/persistence_health_controller.dart';
import '../core/persistence/application/persistence_lifecycle_coordinator.dart';
import '../core/persistence/data/local_key_value_store.dart';
import '../core/progress/game_progress_controller.dart';
import '../core/progress/game_progress_store.dart';
import '../core/progress/shared_preferences_game_progress_store.dart';
import '../core/theme/app_theme.dart';
import '../features/game/tutorial/application/learning_progress_controller.dart';
import '../features/game/tutorial/application/learning_progress_store.dart';
import '../features/game/tutorial/data/shared_preferences_learning_progress_store.dart';
import '../features/game/presentation/game_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import 'app_routes.dart';

class BookLogicApp extends StatefulWidget {
  BookLogicApp({
    LocalKeyValueStore? keyValueStore,
    GameProgressStore? progressStore,
    LearningProgressStore? learningProgressStore,
    AppFeedbackSettingsStore? feedbackSettingsStore,
    AdRuntimeConfig? adRuntimeConfig,
    this.adConsentService,
    MobileAdsInitializer? mobileAdsInitializer,
    InterstitialAdGateway? interstitialAdGateway,
    this.adUnitIdProvider,
    GameSoundPlayer? soundPlayer,
    GameHapticPlayer? hapticPlayer,
    super.key,
  }) : progressStore =
           progressStore ??
           SharedPreferencesGameProgressStore(keyValueStore: keyValueStore),
       learningProgressStore =
           learningProgressStore ??
           SharedPreferencesLearningProgressStore(keyValueStore: keyValueStore),
       feedbackSettingsStore =
           feedbackSettingsStore ??
           SharedPreferencesAppFeedbackSettingsStore(
             keyValueStore: keyValueStore,
           ),
       adRuntimeConfig = adRuntimeConfig ?? AdRuntimeConfig.fromEnvironment(),
       mobileAdsInitializer =
           mobileAdsInitializer ?? const GoogleMobileAdsInitializer(),
       interstitialAdGateway =
           interstitialAdGateway ?? const GoogleInterstitialAdGateway(),
       soundPlayer = soundPlayer ?? AssetGameSoundPlayer(),
       hapticPlayer = hapticPlayer ?? const FlutterGameHapticPlayer();

  final GameProgressStore progressStore;
  final LearningProgressStore learningProgressStore;
  final AppFeedbackSettingsStore feedbackSettingsStore;
  final AdRuntimeConfig adRuntimeConfig;
  final AdConsentService? adConsentService;
  final MobileAdsInitializer mobileAdsInitializer;
  final InterstitialAdGateway interstitialAdGateway;
  final AdUnitIdProvider? adUnitIdProvider;
  final GameSoundPlayer soundPlayer;
  final GameHapticPlayer hapticPlayer;

  @override
  State<BookLogicApp> createState() => _BookLogicAppState();
}

class _BookLogicAppState extends State<BookLogicApp>
    with WidgetsBindingObserver {
  late final GameProgressController _progressController;
  late final LearningProgressController _learningProgressController;
  late final AppFeedbackSettingsController _feedbackSettingsController;
  late final AdConsentController _adConsentController;
  late final InterstitialAdPolicy _interstitialAdPolicy;
  late final InterstitialAdController _interstitialAdController;
  late final AdSessionCoordinator _adSessionCoordinator;
  late final AdBootstrapController _adBootstrapController;
  late final NextLevelAdGate _nextLevelAdGate;
  late final PersistenceLifecycleCoordinator _persistenceLifecycleCoordinator;
  late final PersistenceHealthController _persistenceHealthController;

  @override
  void initState() {
    super.initState();
    _progressController = GameProgressController(store: widget.progressStore);
    _learningProgressController = LearningProgressController(
      store: widget.learningProgressStore,
    );
    _feedbackSettingsController = AppFeedbackSettingsController(
      store: widget.feedbackSettingsStore,
    );
    _adConsentController = AdConsentController(
      service:
          widget.adConsentService ??
          GoogleUmpConsentService(config: widget.adRuntimeConfig),
    );
    _interstitialAdPolicy = const InterstitialAdPolicy();
    _interstitialAdController = InterstitialAdController(
      consentController: _adConsentController,
      mobileAdsInitializer: widget.mobileAdsInitializer,
      gateway: widget.interstitialAdGateway,
      adUnitIdProvider:
          widget.adUnitIdProvider ??
          PlatformAdUnitIdProvider(config: widget.adRuntimeConfig),
      policy: _interstitialAdPolicy,
    );
    _adSessionCoordinator = AdSessionCoordinator(
      consentController: _adConsentController,
      interstitialController: _interstitialAdController,
      policy: _interstitialAdPolicy,
    );
    _adBootstrapController = AdBootstrapController(
      consentController: _adConsentController,
      interstitialController: _interstitialAdController,
      adSessionCoordinator: _adSessionCoordinator,
    );
    _nextLevelAdGate = DefaultNextLevelAdGate(
      policy: _interstitialAdPolicy,
      interstitialController: _interstitialAdController,
    );
    _persistenceLifecycleCoordinator = PersistenceLifecycleCoordinator(
      stores: [
        widget.progressStore,
        widget.learningProgressStore,
        widget.feedbackSettingsStore,
      ],
    )..attach();
    _persistenceHealthController = PersistenceHealthController(
      providers: [
        widget.progressStore,
        widget.learningProgressStore,
        widget.feedbackSettingsStore,
      ],
    );
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initializePersistence());
    unawaited(widget.soundPlayer.initialize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _progressController.dispose();
    _learningProgressController.dispose();
    _feedbackSettingsController.dispose();
    _adBootstrapController.dispose();
    _adSessionCoordinator.dispose();
    _interstitialAdController.dispose();
    _adConsentController.dispose();
    _persistenceLifecycleCoordinator.dispose();
    _persistenceHealthController.dispose();
    unawaited(widget.soundPlayer.stopAll());
    unawaited(widget.soundPlayer.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(widget.soundPlayer.stopAll());
    }
    _persistenceLifecycleCoordinator.handleLifecycleState(state);
  }

  Future<void> _initializePersistence() async {
    await _progressController.load();
    await _learningProgressController.initialize(
      currentLevel: _progressController.currentLevel,
    );
    await _feedbackSettingsController.initialize();
    _persistenceHealthController.initialize();
    unawaited(
      _adBootstrapController.initialize(
        currentLevel: _progressController.currentLevel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      initialRoute: AppRoutes.home,
      routes: {
        AppRoutes.home: (_) => HomeScreen(
          progressController: _progressController,
          persistenceHealthController: _persistenceHealthController,
        ),
        AppRoutes.game: (_) => GameScreen(
          level: _progressController.currentLevel,
          generatorVersion: _progressController.generatorVersion,
          progressController: _progressController,
          learningProgressController: _learningProgressController,
          feedbackSettingsController: _feedbackSettingsController,
          soundPlayer: widget.soundPlayer,
          hapticPlayer: widget.hapticPlayer,
          nextLevelAdGate: _nextLevelAdGate,
          adSessionCoordinator: _adSessionCoordinator,
          enableTutorial: true,
        ),
        AppRoutes.settings: (_) => SettingsScreen(
          feedbackSettingsController: _feedbackSettingsController,
          adConsentController: _adConsentController,
          soundPlayer: widget.soundPlayer,
          hapticPlayer: widget.hapticPlayer,
        ),
      },
    );
  }
}
