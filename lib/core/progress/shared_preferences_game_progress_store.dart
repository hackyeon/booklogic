import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'game_progress.dart';
import 'game_progress_store.dart';

class SharedPreferencesGameProgressStore implements GameProgressStore {
  const SharedPreferencesGameProgressStore();

  static const String storageKey = 'bookshelf_puzzle.game_progress.v1';

  @override
  Future<GameProgress?> read() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(storageKey);
    if (raw == null) {
      return null;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Game progress root must be an object.');
    }

    final json = <String, dynamic>{};
    for (final entry in decoded.entries) {
      final key = entry.key;
      if (key is! String) {
        throw const FormatException('Game progress keys must be strings.');
      }
      json[key] = entry.value;
    }

    return GameProgress.fromJson(json);
  }

  @override
  Future<void> write(GameProgress progress) async {
    final preferences = await SharedPreferences.getInstance();
    final success = await preferences.setString(
      storageKey,
      jsonEncode(progress.toJson()),
    );
    if (!success) {
      throw StateError('Failed to save game progress.');
    }
  }
}
