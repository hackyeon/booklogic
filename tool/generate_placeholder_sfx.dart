import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

void main() {
  final outputDirectory = Directory('assets/audio/sfx');
  outputDirectory.createSync(recursive: true);

  _writeWav(
    path: 'assets/audio/sfx/book_select.wav',
    samples: _bookSelectSamples(),
  );
  _writeWav(
    path: 'assets/audio/sfx/book_swap.wav',
    samples: _bookSwapSamples(),
  );
  _writeWav(
    path: 'assets/audio/sfx/clue_satisfied.wav',
    samples: _clueSatisfiedSamples(),
  );
  _writeWav(
    path: 'assets/audio/sfx/stage_clear.wav',
    samples: _stageClearSamples(),
  );
}

const _sampleRate = 44100;
const _maxAmplitude = 32767;

List<double> _bookSelectSamples() {
  const duration = 0.12;
  return _tone(
    durationSeconds: duration,
    frequencyStart: 260,
    frequencyEnd: 210,
    amplitude: 0.22,
    envelope: (t) => _percussiveEnvelope(t, attack: 0.015, release: 0.08),
    noiseAmount: 0.04,
  );
}

List<double> _bookSwapSamples() {
  const duration = 0.22;
  return _tone(
    durationSeconds: duration,
    frequencyStart: 180,
    frequencyEnd: 125,
    amplitude: 0.24,
    envelope: (t) => _percussiveEnvelope(t, attack: 0.02, release: 0.18),
    noiseAmount: 0.07,
  );
}

List<double> _clueSatisfiedSamples() {
  const duration = 0.24;
  final base = _tone(
    durationSeconds: duration,
    frequencyStart: 660,
    frequencyEnd: 660,
    amplitude: 0.22,
    envelope: (t) => _bellEnvelope(t, release: 0.22),
  );
  final overtone = _tone(
    durationSeconds: duration,
    frequencyStart: 990,
    frequencyEnd: 990,
    amplitude: 0.1,
    envelope: (t) => _bellEnvelope(t, release: 0.18),
  );
  return _mix([base, overtone]);
}

List<double> _stageClearSamples() {
  const duration = 0.78;
  final first = _delayedTone(
    durationSeconds: duration,
    delaySeconds: 0,
    toneDurationSeconds: 0.34,
    frequency: 392,
    amplitude: 0.18,
  );
  final second = _delayedTone(
    durationSeconds: duration,
    delaySeconds: 0.18,
    toneDurationSeconds: 0.34,
    frequency: 494,
    amplitude: 0.18,
  );
  final third = _delayedTone(
    durationSeconds: duration,
    delaySeconds: 0.36,
    toneDurationSeconds: 0.38,
    frequency: 587,
    amplitude: 0.2,
  );
  return _mix([first, second, third]);
}

List<double> _delayedTone({
  required double durationSeconds,
  required double delaySeconds,
  required double toneDurationSeconds,
  required double frequency,
  required double amplitude,
}) {
  final totalLength = (durationSeconds * _sampleRate).round();
  final delayLength = (delaySeconds * _sampleRate).round();
  final toneSamples = _tone(
    durationSeconds: toneDurationSeconds,
    frequencyStart: frequency,
    frequencyEnd: frequency,
    amplitude: amplitude,
    envelope: (t) => _bellEnvelope(t, release: toneDurationSeconds),
  );
  final samples = List<double>.filled(totalLength, 0);
  for (var index = 0; index < toneSamples.length; index += 1) {
    final targetIndex = delayLength + index;
    if (targetIndex >= samples.length) {
      break;
    }
    samples[targetIndex] += toneSamples[index];
  }
  return samples;
}

List<double> _tone({
  required double durationSeconds,
  required double frequencyStart,
  required double frequencyEnd,
  required double amplitude,
  required double Function(double t) envelope,
  double noiseAmount = 0,
}) {
  final length = (durationSeconds * _sampleRate).round();
  final samples = <double>[];
  var phase = 0.0;
  for (var index = 0; index < length; index += 1) {
    final t = index / max(1, length - 1);
    final frequency = frequencyStart + (frequencyEnd - frequencyStart) * t;
    phase += 2 * pi * frequency / _sampleRate;
    final deterministicNoise = noiseAmount == 0
        ? 0.0
        : sin(index * 12.9898) * sin(index * 78.233) * noiseAmount;
    final value = (sin(phase) + deterministicNoise) * amplitude * envelope(t);
    samples.add(value.clamp(-1.0, 1.0));
  }
  return samples;
}

List<double> _mix(List<List<double>> tracks) {
  final length = tracks.map((track) => track.length).reduce(max);
  final samples = List<double>.filled(length, 0);
  for (final track in tracks) {
    for (var index = 0; index < track.length; index += 1) {
      samples[index] += track[index];
    }
  }
  return samples.map((sample) => sample.clamp(-0.9, 0.9).toDouble()).toList();
}

double _percussiveEnvelope(
  double t, {
  required double attack,
  required double release,
}) {
  final attackPortion = attack;
  if (t < attackPortion) {
    return t / attackPortion;
  }
  final releaseStart = 1 - release;
  if (t > releaseStart) {
    return max(0, (1 - t) / release);
  }
  return 1;
}

double _bellEnvelope(double t, {required double release}) {
  return exp(-5.5 * t / release).clamp(0.0, 1.0);
}

void _writeWav({required String path, required List<double> samples}) {
  final dataSize = samples.length * 2;
  final fileSize = 36 + dataSize;
  final bytes = BytesBuilder();

  void writeAscii(String value) => bytes.add(value.codeUnits);
  void writeUint16(int value) {
    final buffer = ByteData(2)..setUint16(0, value, Endian.little);
    bytes.add(buffer.buffer.asUint8List());
  }

  void writeUint32(int value) {
    final buffer = ByteData(4)..setUint32(0, value, Endian.little);
    bytes.add(buffer.buffer.asUint8List());
  }

  writeAscii('RIFF');
  writeUint32(fileSize);
  writeAscii('WAVE');
  writeAscii('fmt ');
  writeUint32(16);
  writeUint16(1);
  writeUint16(1);
  writeUint32(_sampleRate);
  writeUint32(_sampleRate * 2);
  writeUint16(2);
  writeUint16(16);
  writeAscii('data');
  writeUint32(dataSize);

  for (final sample in samples) {
    final intSample = (sample * _maxAmplitude).round().clamp(
      -_maxAmplitude,
      _maxAmplitude,
    );
    writeUint16(intSample & 0xFFFF);
  }

  File(path).writeAsBytesSync(bytes.toBytes());
}
