import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sotto/core/mp3_encoder.dart';
import 'package:sotto/tts/model_repository.dart';
import 'package:sotto/tts/tts_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('bundled model synthesises audio and MP3 on device', (tester) async {
    final models = ModelRepository();
    final tts = TtsService(models);
    final loadStart = DateTime.now();
    await tts.load(modelId: 'nano-int8');
    final loadMs = DateTime.now().difference(loadStart).inMilliseconds;

    const text =
        'Hello. This is Sotto, running entirely on your device. The quick brown fox jumps over the lazy dog.';
    final genStart = DateTime.now();
    final result = await tts.generate(text, voice: 'bella', speed: 1.0);
    final genMs = DateTime.now().difference(genStart).inMilliseconds;

    var sum = 0.0;
    var peak = 0.0;
    for (final sample in result.samples) {
      sum += sample * sample;
      final value = sample.abs();
      if (value > peak) peak = value;
    }
    final rms = result.samples.isEmpty ? 0.0 : math.sqrt(sum / result.samples.length);
    final rtf = result.duration == 0 ? 0.0 : (genMs / 1000) / result.duration;

    // ignore: avoid_print
    print('SOTTO_SELFTEST loadMs=$loadMs genMs=$genMs '
        'duration=${result.duration.toStringAsFixed(2)} '
        'rtf=${rtf.toStringAsFixed(2)} rms=${rms.toStringAsFixed(4)} '
        'peak=${peak.toStringAsFixed(3)} words=${result.wordTimings.length} '
        'sampleRate=${result.sampleRate}');

    expect(result.samples.length, greaterThan(result.sampleRate ~/ 2));
    expect(rms, greaterThan(0.01));
    expect(peak, greaterThan(0.05));
    expect(result.wordTimings.length, greaterThan(8));
    expect(result.wordTimings.first.wordIndex, 0);

    final wav = result.wavData();
    expect(wav.length, greaterThan(10000));
    expect(String.fromCharCodes(wav.take(4)), 'RIFF');

    expect(Mp3FileWriter.isAvailable, isTrue,
        reason: 'libsotto_mp3.so should be packaged in the APK');
    final mp3 = await encodeMp3(result.samples, sampleRate: result.sampleRate);
    expect(mp3.length, greaterThan(5000));
    final hasFrameSync = mp3.length > 100 &&
        (mp3[0] == 0x49 || (mp3[0] == 0xFF && (mp3[1] & 0xE0) == 0xE0));
    expect(hasFrameSync, isTrue, reason: 'MP3 output should start with ID3 or a frame sync');
    final expectedBytes = result.duration * 128000 / 8;
    expect(
      mp3.length,
      closeTo(expectedBytes, expectedBytes * 0.18),
      reason: 'MP3 at 128 kbps should be roughly duration × 16 KB/s',
    );

    final dir = await getApplicationDocumentsDirectory();
    final wavFile = File(p.join(dir.path, 'selftest.wav'));
    final mp3File = File(p.join(dir.path, 'selftest.mp3'));
    await wavFile.writeAsBytes(wav, flush: true);
    await mp3File.writeAsBytes(mp3, flush: true);

    // ignore: avoid_print
    print('SOTTO_SELFTEST wav=${wav.length} mp3=${mp3.length} '
        'wavPath=${wavFile.path} mp3Path=${mp3File.path}');

    tts.dispose();
  });
}
