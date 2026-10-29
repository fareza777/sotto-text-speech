import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/models.dart';
import 'audio_format.dart';
import 'audio_peaks.dart';
import 'mp3_encoder.dart';
import 'wav_writer.dart';

Future<Directory> exportsDirectory() async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(docs.path, 'exports'));
  await dir.create(recursive: true);
  return dir;
}

String slugify(String value, {int maxLength = 48}) {
  final cleaned = value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
      .trim()
      .replaceAll(RegExp(r'\s+'), '-');
  final trimmed = cleaned.isEmpty ? 'sotto-audio' : cleaned;
  return trimmed.length <= maxLength ? trimmed : trimmed.substring(0, maxLength);
}

Future<AudioTrack> saveAudioToLibrary({
  required Float32List samples,
  required int sampleRate,
  required String title,
  required String voice,
  required String modelId,
  required double speed,
  AudioFormat format = AudioFormat.wav,
  int bitRate = 128,
  int? docId,
  String? excerpt,
}) async {
  final dir = await exportsDirectory();
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final file = File(p.join(dir.path, '${slugify(title)}_$stamp.${format.extension}'));
  final Uint8List bytes = format == AudioFormat.mp3
      ? await encodeMp3(samples, sampleRate: sampleRate, bitRate: bitRate)
      : encodeWav(samples, sampleRate);
  await file.writeAsBytes(bytes, flush: true);
  return AudioTrack(
    title: title.trim().isEmpty ? 'Untitled audio' : title.trim(),
    path: file.path,
    format: format.name,
    voice: voice,
    model: modelId,
    speed: speed,
    durationMs: (samples.length / sampleRate * 1000).round(),
    sizeBytes: bytes.length,
    docId: docId,
    excerpt: excerpt,
    peaks: encodePeaks(peaksFromSamples(samples)),
  );
}
