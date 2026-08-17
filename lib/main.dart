import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/persistence/data/shared_preferences_key_value_store.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(AppTheme.systemUiOverlayStyle);
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  final preferences = await SharedPreferences.getInstance();

  runApp(
    BookLogicApp(keyValueStore: SharedPreferencesKeyValueStore(preferences)),
  );
}
