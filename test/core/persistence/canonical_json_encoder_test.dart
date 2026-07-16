import 'package:flutter_test/flutter_test.dart';

import 'package:booklogic/core/persistence/codec/canonical_json_encoder.dart';

void main() {
  group('CanonicalJsonEncoder', () {
    const encoder = CanonicalJsonEncoder();

    test('sorts map keys deterministically and keeps list order', () {
      expect(encoder.encode({'b': 2, 'a': 1}), '{"a":1,"b":2}');
      expect(
        encoder.encode({
          'a': ['b', 'a'],
        }),
        '{"a":["b","a"]}',
      );
      expect(
        encoder.encode({
          '한글': true,
          'nested': {'z': null, 'a': -1},
        }),
        '{"nested":{"a":-1,"z":null},"한글":true}',
      );
    });

    test('rejects non-finite doubles and unsupported objects', () {
      expect(() => encoder.encode(double.nan), throwsArgumentError);
      expect(() => encoder.encode(double.infinity), throwsArgumentError);
      expect(() => encoder.encode(DateTime(2026)), throwsArgumentError);
    });
  });
}
