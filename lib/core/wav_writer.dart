import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'pcm_sink.dart';

Uint8List encodeWav(Float32List samples, int sampleRate) {
  final dataBytes = samples.length * 2;
  final buffer = ByteData(44 + dataBytes);
  _writeHeader(buffer, sampleRate, dataBytes);
  var offset = 44;
  for (final sample in samples) {
    final value = (sample.clamp(-1.0, 1.0) * 32767).round();
    buffer.setInt16(offset, value, Endian.little);
    offset += 2;
  }
  return buffer.buffer.asUint8List();
}

void _writeHeader(ByteData buffer, int sampleRate, int dataBytes) {
  void ascii(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      buffer.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  buffer.setUint32(4, 36 + dataBytes, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  buffer.setUint32(16, 16, Endian.little);
  buffer.setUint16(20, 1, Endian.little);
  buffer.setUint16(22, 1, Endian.little);
  buffer.setUint32(24, sampleRate, Endian.little);
  buffer.setUint32(28, sampleRate * 2, Endian.little);
  buffer.setUint16(32, 2, Endian.little);
  buffer.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  buffer.setUint32(40, dataBytes, Endian.little);
}

/// Streams PCM16 into a WAV file so long exports never hold the whole
/// waveform in memory.
class WavFileWriter implements PcmSink {
  WavFileWriter._(this._file, this._raf, this.sampleRate);

  final File _file;
  final RandomAccessFile _raf;
  @override
  final int sampleRate;
  int _dataBytes = 0;
  bool _closed = false;

  static Future<WavFileWriter> open(File file, {int sampleRate = 24000}) async {
    await file.parent.create(recursive: true);
    if (await file.exists()) await file.delete();
    final raf = await file.open(mode: FileMode.write);
    final header = ByteData(44);
    _writeHeader(header, sampleRate, 0);
    await raf.writeFrom(header.buffer.asUint8List());
    return WavFileWriter._(file, raf, sampleRate);
  }

  @override
  Future<void> addSamples(Float32List samples) async {
    final bytes = Uint8List(samples.length * 2);
    final view = ByteData.view(bytes.buffer);
    for (var i = 0; i < samples.length; i++) {
      view.setInt16(i * 2, (samples[i].clamp(-1.0, 1.0) * 32767).round(), Endian.little);
    }
    await _raf.writeFrom(bytes);
    _dataBytes += bytes.length;
  }

  @override
  Future<void> addSilence(double seconds) async {
    final count = (seconds * sampleRate).round();
    if (count <= 0) return;
    final silence = Uint8List(count * 2);
    await _raf.writeFrom(silence);
    _dataBytes += silence.length;
  }

  @override
  Duration get duration =>
      Duration(milliseconds: (math.max(0, _dataBytes) / 2 / sampleRate * 1000).round());

  @override
  Future<File> finish() async {
    if (!_closed) {
      _closed = true;
      final header = ByteData(44);
      _writeHeader(header, sampleRate, _dataBytes);
      await _raf.setPosition(0);
      await _raf.writeFrom(header.buffer.asUint8List());
      await _raf.close();
    }
    return _file;
  }

  @override
  Future<void> abort() async {
    if (!_closed) {
      _closed = true;
      await _raf.close();
    }
    if (await _file.exists()) await _file.delete();
  }
}
