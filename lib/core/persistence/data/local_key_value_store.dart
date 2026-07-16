abstract interface class LocalKeyValueStore {
  String? getString(String key);

  int? getInt(String key);

  bool? getBool(String key);

  List<String>? getStringList(String key);

  bool containsKey(String key);

  Future<bool> setString(String key, String value);

  Future<bool> setInt(String key, int value);

  Future<bool> setBool(String key, bool value);

  Future<bool> setStringList(String key, List<String> value);

  Future<bool> remove(String key);
}
