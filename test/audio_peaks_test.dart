import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sotto/core/audio_peaks.dart';

void main() {
  test('peaks summarize a waveform into normalized buckets', () {
    final samples = Float32List(24000);
    for (var i = 0; i < samples.length; i++) {
      samples[i] = math.sin(i / 12) * (0.2 + 0.8 * i / samples.length);
    }
    final peaks = peaksFromSamples(samples);
    expect(peaks.length, 64);
    expect(peaks.reduce(math.max), closeTo(1.0, 0.001));
    expect(peaks.every((v) => v > 0), isTrue);
  });

  test('silence still produces a drawable shape', () {
    final peaks = peaksFromSamples(Float32List(4800));
    expect(peaks.length, 64);
    expect(peaks.every((v) => v > 0), isTrue);
  });

  test('merge keeps the bucket count', () {
    final merged = mergePeaks([
      List<double>.generate(16, (i) => 0.1 * i),
      List<double>.generate(16, (i) => 1 - 0.05 * i),
    ]);
    expect(merged.length, 64);
    expect(merged.reduce(math.max), closeTo(1.0, 0.001));
  });

  test('encode and decode round trip', () {
    final peaks = List<double>.generate(64, (i) => i / 63);
    final decoded = decodePeaks(encodePeaks(peaks));
    expect(decoded.length, 64);
    expect(decoded.first, closeTo(0.0, 0.01));
    expect(decoded.last, closeTo(1.0, 0.01));
    expect(decodePeaks(null), isEmpty);
    expect(decodePeaks(''), isEmpty);
  });
}
