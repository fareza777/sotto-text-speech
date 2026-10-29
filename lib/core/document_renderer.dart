import 'dart:io';

import 'package:path/path.dart' as p;

import '../data/models.dart';
import '../features/reader/reader_content.dart';
import '../tts/tts_service.dart';
import 'audio_export.dart';
import 'audio_format.dart';
import 'audio_peaks.dart';
import 'mp3_encoder.dart';
import 'pcm_sink.dart';
import 'wav_writer.dart';

class RenderProgress {
  const RenderProgress({
    required this.fraction,
    required this.current,
    required this.total,
    required this.label,
  });

  final double fraction;
  final int current;
  final int total;
  final String label;
}

Future<AudioTrack> renderDocument({
  required Doc doc,
  required ReaderContent content,
  required TtsService tts,
  required String voice,
  required double speed,
  required String modelId,
  AudioFormat format = AudioFormat.wav,
  int bitRate = 128,
  void Function(RenderProgress)? onProgress,
  bool Function()? isCancelled,
}) {
  return renderSentences(
    doc: doc,
    sentences: content.sentences,
    tts: tts,
    voice: voice,
    speed: speed,
    modelId: modelId,
    format: format,
    bitRate: bitRate,
    onProgress: onProgress,
    isCancelled: isCancelled,
  );
}

/// Renders sentences into a single streaming file. Memory stays flat even for
/// full-length books because each sentence is written out before the next one
/// is synthesized.
Future<AudioTrack> renderSentences({
  required Doc doc,
  required List<SentenceSpan> sentences,
  required TtsService tts,
  required String voice,
  required double speed,
  required String modelId,
  AudioFormat format = AudioFormat.wav,
  int bitRate = 128,
  void Function(RenderProgress)? onProgress,
  bool Function()? isCancelled,
}) async {
  if (sentences.isEmpty) {
    throw const FormatException('This document has no readable text.');
  }
  if (format == AudioFormat.mp3 && !Mp3FileWriter.isAvailable) {
    throw const FormatException('MP3 encoding is unavailable on this build.');
  }

  final dir = await exportsDirectory();
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final file = File(p.join(dir.path, '${slugify(doc.title)}_$stamp.${format.extension}'));
  final PcmSink sink = format == AudioFormat.mp3
      ? await Mp3FileWriter.open(file, bitRate: bitRate)
      : await WavFileWriter.open(file);

  final peakChunks = <List<double>>[];
  final cues = <_Cue>[];
  var elapsed = 0.0;
  try {
    for (var i = 0; i < sentences.length; i++) {
      if (isCancelled?.call() == true) {
        await sink.abort();
        throw const RenderCancelled();
      }
      final sentence = sentences[i];
      final result = await tts.generate(
        sentence.text,
        voice: voice,
        speed: speed,
        modelId: modelId,
      );
      if (i > 0) {
        await sink.addSilence(0.14);
        elapsed += 0.14;
      }
      await sink.addSamples(result.samples);
      cues.add(_Cue(elapsed, elapsed + result.duration, sentence.text));
      elapsed += result.duration;
      peakChunks.add(peaksFromSamples(result.samples, buckets: 16));
      onProgress?.call(RenderProgress(
        fraction: (i + 1) / sentences.length,
        current: i + 1,
        total: sentences.length,
        label: sentence.text.length > 48
            ? '${sentence.text.substring(0, 48)}…'
            : sentence.text,
      ));
    }
    await sink.finish();
    await _writeSrt(file, cues);
    final size = await file.length();
    return AudioTrack(
      title: doc.title,
      path: file.path,
      format: format.name,
      voice: voice,
      model: modelId,
      speed: speed,
      durationMs: sink.duration.inMilliseconds,
      sizeBytes: size,
      docId: doc.id,
      peaks: encodePeaks(mergePeaks(peakChunks)),
      excerpt: sentences.length > 3
          ? '${sentences.take(3).map((s) => s.text).join(' ')}…'
          : sentences.map((s) => s.text).join(' '),
    );
  } catch (error) {
    if (error is! RenderCancelled) {
      await sink.abort();
    }
    rethrow;
  }
}

class _Cue {
  const _Cue(this.start, this.end, this.text);
  final double start;
  final double end;
  final String text;
}

Future<void> _writeSrt(File audioFile, List<_Cue> cues) async {
  if (cues.isEmpty) return;
  final buffer = StringBuffer();
  for (var i = 0; i < cues.length; i++) {
    final cue = cues[i];
    buffer
      ..writeln(i + 1)
      ..writeln('${_srtTime(cue.start)} --> ${_srtTime(cue.end)}')
      ..writeln(_wrapCue(cue.text))
      ..writeln();
  }
  final srt = File('${audioFile.path.substring(0, audioFile.path.lastIndexOf('.'))}.srt');
  await srt.writeAsString(buffer.toString(), flush: true);
}

String _srtTime(double seconds) {
  final totalMs = (seconds * 1000).round();
  final h = totalMs ~/ 3600000;
  final m = (totalMs % 3600000) ~/ 60000;
  final s = (totalMs % 60000) ~/ 1000;
  final ms = totalMs % 1000;
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(h)}:${two(m)}:${two(s)},${ms.toString().padLeft(3, '0')}';
}

String _wrapCue(String text, {int width = 42}) {
  final words = text.split(RegExp(r'\s+'));
  final lines = <String>[];
  final line = StringBuffer();
  for (final word in words) {
    if (line.isNotEmpty && line.length + word.length + 1 > width) {
      lines.add(line.toString());
      line.clear();
    }
    if (line.isNotEmpty) line.write(' ');
    line.write(word);
  }
  if (line.isNotEmpty) lines.add(line.toString());
  return lines.join(Platform.lineTerminator);
}

class RenderCancelled implements Exception {
  const RenderCancelled();
}

bool isRenderCancelled(Object error) => error is RenderCancelled;
