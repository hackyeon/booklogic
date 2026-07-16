import 'dart:async';

import 'package:flutter/material.dart';

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
       soundPlayer = soundPlayer ?? AssetGameSoundPlayer(),
       hapticPlayer = hapticPlayer ?? const FlutterGameHapticPlayer();

  final GameProgressStore progressStore;
  final LearningProgressStore learningProgressStore;
  final AppFeedbackSettingsStore feedbackSettingsStore;
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
          enableTutorial: true,
        ),
        AppRoutes.settings: (_) => SettingsScreen(
          feedbackSettingsController: _feedbackSettingsController,
          soundPlayer: widget.soundPlayer,
          hapticPlayer: widget.hapticPlayer,
        ),
      },
    );
  }
}
