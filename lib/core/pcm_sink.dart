import 'dart:io';
import 'dart:typed_data';

/// Streaming audio target. Implementations must keep memory flat no matter how
/// long the source document is.
abstract class PcmSink {
  int get sampleRate;
  Duration get duration;
  Future<void> addSamples(Float32List samples);
  Future<void> addSilence(double seconds);
  Future<File> finish();
  Future<void> abort();
}
