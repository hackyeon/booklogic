import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release baseline contains only stable non-secret values', () {
    final baseline =
        jsonDecode(File('release/release_baseline.json').readAsStringSync())
            as Map<String, Object?>;

    expect(baseline['baselineVersion'], 1);
    expect(baseline['appVersion'], '1.0.0+1');
    expect(baseline['androidApplicationId'], 'com.hack.booklogic.booklogic');
    expect(baseline['iosBundleIdentifier'], 'com.hack.booklogic.booklogic');
    expect(baseline['minimumSupportedLevel'], 1);
    expect(baseline['maximumSupportedLevel'], 400);

    final text = jsonEncode(baseline);
    expect(text, isNot(contains('ADMOB')));
    expect(text, isNot(contains('ca-app-pub-')));
    expect(text, isNot(contains('keystore')));
    expect(text, isNot(contains('/Users/')));

    final versions = (baseline['generatorVersions']! as Map)
        .cast<String, Object?>();
    expect((versions['1']! as Map)['manifestChecksum'], 2127356086);
    expect((versions['2']! as Map)['manifestChecksum'], 2719162944);
  });
}
