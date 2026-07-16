import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'placeholder sfx assets exist, are registered, and are short wav files',
    () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('assets/audio/sfx/'));

      for (final path in const [
        'assets/audio/sfx/book_select.wav',
        'assets/audio/sfx/book_swap.wav',
        'assets/audio/sfx/clue_satisfied.wav',
        'assets/audio/sfx/stage_clear.wav',
      ]) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: path);
        final bytes = file.readAsBytesSync();
        expect(bytes.length, greaterThan(44), reason: path);
        expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
        expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');

        final data = ByteData.sublistView(Uint8List.fromList(bytes));
        final sampleRate = data.getUint32(24, Endian.little);
        final dataSize = data.getUint32(40, Endian.little);
        final durationSeconds = dataSize / 2 / sampleRate;
        expect(durationSeconds, lessThanOrEqualTo(1), reason: path);
      }
    },
  );
}
