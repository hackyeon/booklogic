import 'package:flutter/material.dart';

import '../core/constants/app_strings.dart';
import '../core/progress/game_progress_controller.dart';
import '../core/progress/game_progress_store.dart';
import '../core/progress/shared_preferences_game_progress_store.dart';
import '../core/theme/app_theme.dart';
import '../features/game/presentation/game_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import 'app_routes.dart';

class BookLogicApp extends StatefulWidget {
  const BookLogicApp({
    this.progressStore = const SharedPreferencesGameProgressStore(),
    super.key,
  });

  final GameProgressStore progressStore;

  @override
  State<BookLogicApp> createState() => _BookLogicAppState();
}

class _BookLogicAppState extends State<BookLogicApp> {
  late final GameProgressController _progressController;

  @override
  void initState() {
    super.initState();
    _progressController = GameProgressController(store: widget.progressStore);
    _progressController.load();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      initialRoute: AppRoutes.home,
      routes: {
        AppRoutes.home: (_) =>
            HomeScreen(progressController: _progressController),
        AppRoutes.game: (_) => GameScreen(
          level: _progressController.currentLevel,
          generatorVersion: _progressController.generatorVersion,
          progressController: _progressController,
        ),
        AppRoutes.settings: (_) => const SettingsScreen(),
      },
    );
  }
}
