import 'dart:collection';
import 'dart:convert';

class CanonicalJsonEncoder {
  const CanonicalJsonEncoder();

  String encode(Object? value) {
    return jsonEncode(_canonicalize(value));
  }

  Object? _canonicalize(Object? value) {
    if (value == null || value is bool || value is int || value is String) {
      return value;
    }
    if (value is double) {
      if (!value.isFinite) {
        throw ArgumentError.value(value, 'value', 'double must be finite.');
      }
      return value;
    }
    if (value is List) {
      return value.map(_canonicalize).toList(growable: false);
    }
    if (value is Map) {
      final sorted = SplayTreeMap<String, Object?>();
      for (final entry in value.entries) {
        final key = entry.key;
        if (key is! String) {
          throw ArgumentError.value(
            key,
            'key',
            'JSON object keys must be strings.',
          );
        }
        sorted[key] = _canonicalize(entry.value);
      }
      return sorted;
    }
    throw ArgumentError.value(value, 'value', 'Unsupported JSON value.');
  }
}
