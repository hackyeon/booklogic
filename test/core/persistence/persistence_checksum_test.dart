import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:booklogic/core/persistence/checksum/fnv1a_persistence_checksum.dart';
import 'package:booklogic/core/persistence/codec/canonical_json_encoder.dart';

void main() {
  group('Fnv1aPersistenceChecksum', () {
    const checksum = Fnv1aPersistenceChecksum();
    const encoder = CanonicalJsonEncoder();

    test('is deterministic and reacts to byte changes', () {
      final first = checksum.calculate(utf8.encode('abc'));
      final second = checksum.calculate(utf8.encode('abc'));
      final changed = checksum.calculate(utf8.encode('abd'));

      expect(first, second);
      expect(first, isNot(changed));
      expect(checksum.calculate(const []), inInclusiveRange(0, 0xffffffff));
    });

    test('uses canonical JSON when map insertion order changes', () {
      final left = encoder.encode({'b': 2, 'a': 1});
      final right = encoder.encode({'a': 1, 'b': 2});

      expect(
        checksum.calculate(utf8.encode(left)),
        checksum.calculate(utf8.encode(right)),
      );
    });
  });
}
