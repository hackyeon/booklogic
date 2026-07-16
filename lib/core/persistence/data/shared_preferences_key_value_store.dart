import 'package:shared_preferences/shared_preferences.dart';

import 'local_key_value_store.dart';

class SharedPreferencesKeyValueStore implements LocalKeyValueStore {
  const SharedPreferencesKeyValueStore(this.preferences);

  final SharedPreferences preferences;

  @override
  String? getString(String key) => preferences.getString(key);

  @override
  int? getInt(String key) => preferences.getInt(key);

  @override
  bool? getBool(String key) => preferences.getBool(key);

  @override
  List<String>? getStringList(String key) => preferences.getStringList(key);

  @override
  bool containsKey(String key) => preferences.containsKey(key);

  @override
  Future<bool> setString(String key, String value) {
    return preferences.setString(key, value);
  }

  @override
  Future<bool> setInt(String key, int value) {
    return preferences.setInt(key, value);
  }

  @override
  Future<bool> setBool(String key, bool value) {
    return preferences.setBool(key, value);
  }

  @override
  Future<bool> setStringList(String key, List<String> value) {
    return preferences.setStringList(key, value);
  }

  @override
  Future<bool> remove(String key) {
    return preferences.remove(key);
  }
}
