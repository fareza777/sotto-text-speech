import 'dart:math' as math;
import 'dart:typed_data';

/// 64 normalized amplitude buckets, stored as a compact CSV string.
List<double> peaksFromSamples(Float32List samples, {int buckets = 64}) {
  if (samples.isEmpty || buckets <= 0) return const [];
  final result = List<double>.filled(buckets, 0);
  for (var i = 0; i < samples.length; i++) {
    final bucket = (i * buckets ~/ samples.length).clamp(0, buckets - 1);
    final value = samples[i].abs();
    if (value > result[bucket]) result[bucket] = value;
  }
  return _normalized(result);
}

List<double> mergePeaks(Iterable<List<double>> chunks, {int buckets = 64}) {
  final flat = <double>[];
  for (final chunk in chunks) {
    flat.addAll(chunk);
  }
  if (flat.isEmpty || buckets <= 0) return const [];
  final result = List<double>.filled(buckets, 0);
  for (var i = 0; i < flat.length; i++) {
    final bucket = (i * buckets ~/ flat.length).clamp(0, buckets - 1);
    if (flat[i] > result[bucket]) result[bucket] = flat[i];
  }
  return _normalized(result);
}

List<double> _normalized(List<double> values) {
  var maxValue = 0.0;
  for (final value in values) {
    if (value > maxValue) maxValue = value;
  }
  if (maxValue <= 0) return List<double>.filled(values.length, 0.12);
  return values.map((v) => (v / maxValue).clamp(0.06, 1.0)).toList(growable: false);
}

String encodePeaks(List<double> peaks) =>
    peaks.map((v) => v.clamp(0, 1).toStringAsFixed(2)).join(',');

List<double> decodePeaks(String? csv) {
  if (csv == null || csv.isEmpty) return const [];
  return csv
      .split(',')
      .map((v) => double.tryParse(v) ?? 0)
      .map((v) => v.clamp(0.0, 1.0))
      .toList(growable: false);
}

/// Fallback shape for audio rendered before peaks were stored.
List<double> syntheticPeaks(int seed, {int buckets = 64}) {
  final random = math.Random(seed);
  return List<double>.generate(buckets, (i) {
    final centerBias = 1 - ((i - buckets / 2).abs() / (buckets / 1.35)).clamp(0, 1) * 0.5;
    return (0.25 + random.nextDouble() * 0.75) * centerBias;
  }, growable: false);
}
