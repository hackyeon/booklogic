import 'package:booklogic/core/persistence/data/local_key_value_store.dart';

class FakeLocalKeyValueStore implements LocalKeyValueStore {
  FakeLocalKeyValueStore({Map<String, Object?> initialValues = const {}})
    : values = Map<String, Object?>.of(initialValues);

  final Map<String, Object?> values;
  final setStringCalls = <String>[];
  final setIntCalls = <String>[];
  final setBoolCalls = <String>[];
  final setStringListCalls = <String>[];
  final removeCalls = <String>[];
  final failingSetStringKeys = <String, List<Object?>>{};
  final failingSetIntKeys = <String, List<Object?>>{};
  final failingRemoveKeys = <String, List<Object?>>{};
  final stringWriteTransforms = <String, String Function(String)>{};

  @override
  String? getString(String key) => values[key] as String?;

  @override
  int? getInt(String key) => values[key] as int?;

  @override
  bool? getBool(String key) => values[key] as bool?;

  @override
  List<String>? getStringList(String key) {
    final value = values[key];
    if (value is List<String>) {
      return List<String>.of(value);
    }
    return null;
  }

  @override
  bool containsKey(String key) => values.containsKey(key);

  @override
  Future<bool> setString(String key, String value) async {
    setStringCalls.add(key);
    final failure = _takeFailure(failingSetStringKeys, key);
    if (failure != null) {
      return _resolveFailure(failure);
    }
    final transform = stringWriteTransforms.remove(key);
    values[key] = transform == null ? value : transform(value);
    return true;
  }

  @override
  Future<bool> setInt(String key, int value) async {
    setIntCalls.add(key);
    final failure = _takeFailure(failingSetIntKeys, key);
    if (failure != null) {
      return _resolveFailure(failure);
    }
    values[key] = value;
    return true;
  }

  @override
  Future<bool> setBool(String key, bool value) async {
    setBoolCalls.add(key);
    values[key] = value;
    return true;
  }

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    setStringListCalls.add(key);
    values[key] = List<String>.of(value);
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    removeCalls.add(key);
    final failure = _takeFailure(failingRemoveKeys, key);
    if (failure != null) {
      return _resolveFailure(failure);
    }
    values.remove(key);
    return true;
  }

  void failNextSetString(String key, Object? failure) {
    failingSetStringKeys.putIfAbsent(key, () => []).add(failure);
  }

  void failNextSetInt(String key, Object? failure) {
    failingSetIntKeys.putIfAbsent(key, () => []).add(failure);
  }

  void failNextRemove(String key, Object? failure) {
    failingRemoveKeys.putIfAbsent(key, () => []).add(failure);
  }

  Object? _takeFailure(Map<String, List<Object?>> failures, String key) {
    final queue = failures[key];
    if (queue == null || queue.isEmpty) {
      return null;
    }
    return queue.removeAt(0);
  }

  bool _resolveFailure(Object? failure) {
    if (failure == null) {
      return true;
    }
    if (failure is bool) {
      return failure;
    }
    if (failure is Exception) {
      throw failure;
    }
    throw StateError(failure.toString());
  }
}
