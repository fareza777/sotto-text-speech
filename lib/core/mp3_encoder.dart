import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'pcm_sink.dart';

typedef _LameInit = Pointer<Void> Function();
typedef _LameInitDart = Pointer<Void> Function();
typedef _LameSetInt = Int32 Function(Pointer<Void>, Int32);
typedef _LameSetIntDart = int Function(Pointer<Void>, int);
typedef _LameInitParams = Int32 Function(Pointer<Void>);
typedef _LameInitParamsDart = int Function(Pointer<Void>);
typedef _LameEncodeFloat = Int32 Function(
  Pointer<Void>,
  Pointer<Float>,
  Pointer<Float>,
  Int32,
  Pointer<Uint8>,
  Int32,
);
typedef _LameEncodeFloatDart = int Function(
  Pointer<Void>,
  Pointer<Float>,
  Pointer<Float>,
  int,
  Pointer<Uint8>,
  int,
);
typedef _LameFlush = Int32 Function(Pointer<Void>, Pointer<Uint8>, Int32);
typedef _LameFlushDart = int Function(Pointer<Void>, Pointer<Uint8>, int);
typedef _LameClose = Int32 Function(Pointer<Void>);
typedef _LameCloseDart = int Function(Pointer<Void>);

class _Lame {
  _Lame(DynamicLibrary lib)
      : init = lib.lookupFunction<_LameInit, _LameInitDart>('lame_init'),
        setInSampleRate =
            lib.lookupFunction<_LameSetInt, _LameSetIntDart>('lame_set_in_samplerate'),
        setNumChannels =
            lib.lookupFunction<_LameSetInt, _LameSetIntDart>('lame_set_num_channels'),
        setBitrate = lib.lookupFunction<_LameSetInt, _LameSetIntDart>('lame_set_brate'),
        setMode = lib.lookupFunction<_LameSetInt, _LameSetIntDart>('lame_set_mode'),
        setQuality =
            lib.lookupFunction<_LameSetInt, _LameSetIntDart>('lame_set_quality'),
        initParams =
            lib.lookupFunction<_LameInitParams, _LameInitParamsDart>('lame_init_params'),
        encode = lib.lookupFunction<_LameEncodeFloat, _LameEncodeFloatDart>(
            'lame_encode_buffer_ieee_float'),
        flush = lib.lookupFunction<_LameFlush, _LameFlushDart>('lame_encode_flush'),
        close = lib.lookupFunction<_LameClose, _LameCloseDart>('lame_close');

  final _LameInitDart init;
  final _LameSetIntDart setInSampleRate;
  final _LameSetIntDart setNumChannels;
  final _LameSetIntDart setBitrate;
  final _LameSetIntDart setMode;
  final _LameSetIntDart setQuality;
  final _LameInitParamsDart initParams;
  final _LameEncodeFloatDart encode;
  final _LameFlushDart flush;
  final _LameCloseDart close;

  static _Lame? _instance;
  static bool _failed = false;

  static _Lame? get instance {
    if (_instance != null) return _instance;
    if (_failed) return null;
    try {
      _instance = _Lame(DynamicLibrary.open('libsotto_mp3.so'));
      return _instance;
    } catch (_) {
      _failed = true;
      return null;
    }
  }
}

class Mp3FileWriter implements PcmSink {
  Mp3FileWriter._(this._file, this._raf, this._handle, this._bitRate, this.sampleRate);

  final File _file;
  final RandomAccessFile _raf;
  final Pointer<Void> _handle;
  final int _bitRate;
  @override
  final int sampleRate;

  int _totalSamples = 0;
  bool _closed = false;

  static bool get isAvailable => _Lame.instance != null;

  static Future<Mp3FileWriter> open(
    File file, {
    int sampleRate = 24000,
    int bitRate = 128,
  }) async {
    final lame = _Lame.instance;
    if (lame == null) {
      throw UnsupportedError('The MP3 encoder is not available on this build.');
    }
    await file.parent.create(recursive: true);
    if (await file.exists()) await file.delete();
    final handle = lame.init();
    if (handle == nullptr) {
      throw StateError('Could not create the MP3 encoder.');
    }
    final ok = lame.setInSampleRate(handle, sampleRate) >= 0 &&
        lame.setNumChannels(handle, 1) >= 0 &&
        lame.setBitrate(handle, bitRate) >= 0 &&
        lame.setMode(handle, 3) >= 0 &&
        lame.setQuality(handle, 2) >= 0 &&
        lame.initParams(handle) >= 0;
    if (!ok) {
      lame.close(handle);
      throw StateError('MP3 encoder rejected its configuration.');
    }
    final raf = await file.open(mode: FileMode.write);
    return Mp3FileWriter._(file, raf, handle, bitRate, sampleRate);
  }

  @override
  Duration get duration =>
      Duration(milliseconds: (_totalSamples / sampleRate * 1000).round());

  @override
  Future<void> addSamples(Float32List samples) async {
    if (_closed || samples.isEmpty) return;
    final lame = _Lame.instance;
    if (lame == null) return;
    final pcm = calloc<Float>(samples.length);
    final out = calloc<Uint8>(_bufferSize(samples.length));
    try {
      pcm.asTypedList(samples.length).setAll(0, samples);
      final written = lame.encode(
        _handle,
        pcm,
        pcm,
        samples.length,
        out,
        _bufferSize(samples.length),
      );
      if (written > 0) {
        await _raf.writeFrom(out.asTypedList(written));
      }
      _totalSamples += samples.length;
    } finally {
      calloc.free(pcm);
      calloc.free(out);
    }
  }

  @override
  Future<void> addSilence(double seconds) async {
    final count = (seconds * sampleRate).round();
    if (count <= 0) return;
    await addSamples(Float32List(count));
  }

  int _bufferSize(int samples) => (samples * 1.25 + 7200).round();

  @override
  Future<File> finish() async {
    if (!_closed) {
      _closed = true;
      final lame = _Lame.instance;
      if (lame != null) {
        const bufferSize = 7200;
        final out = calloc<Uint8>(bufferSize);
        try {
          final written = lame.flush(_handle, out, bufferSize);
          if (written > 0) {
            await _raf.writeFrom(out.asTypedList(written));
          }
        } finally {
          calloc.free(out);
        }
        lame.close(_handle);
      }
      await _raf.close();
    }
    return _file;
  }

  @override
  Future<void> abort() async {
    if (!_closed) {
      _closed = true;
      final lame = _Lame.instance;
      lame?.close(_handle);
      await _raf.close();
    }
    if (await _file.exists()) await _file.delete();
  }
}

/// One-shot encode for short Studio clips.
Future<Uint8List> encodeMp3(
  Float32List samples, {
  int sampleRate = 24000,
  int bitRate = 128,
}) async {
  final lame = _Lame.instance;
  if (lame == null) {
    throw UnsupportedError('The MP3 encoder is not available on this build.');
  }
  final handle = lame.init();
  if (handle == nullptr) throw StateError('Could not create the MP3 encoder.');
  if (lame.setInSampleRate(handle, sampleRate) < 0 ||
      lame.setNumChannels(handle, 1) < 0 ||
      lame.setBitrate(handle, bitRate) < 0 ||
      lame.setMode(handle, 3) < 0 ||
      lame.setQuality(handle, 2) < 0 ||
      lame.initParams(handle) < 0) {
    throw StateError('MP3 encoder rejected its configuration.');
  }

  final output = BytesBuilder(copy: false);
  const chunk = 1152;
  try {
    for (var start = 0; start < samples.length; start += chunk) {
      final count = math.min(chunk, samples.length - start);
      final pcm = calloc<Float>(count);
      final out = calloc<Uint8>((count * 1.25 + 7200).round());
      try {
        pcm.asTypedList(count).setRange(0, count, samples, start);
        final written = lame.encode(handle, pcm, pcm, count, out, (count * 1.25 + 7200).round());
        if (written > 0) output.add(out.asTypedList(written).toList(growable: false));
      } finally {
        calloc.free(pcm);
        calloc.free(out);
      }
    }
    final out = calloc<Uint8>(7200);
    try {
      final written = lame.flush(handle, out, 7200);
      if (written > 0) output.add(out.asTypedList(written).toList(growable: false));
    } finally {
      calloc.free(out);
    }
  } finally {
    lame.close(handle);
  }
  return output.takeBytes();
}
