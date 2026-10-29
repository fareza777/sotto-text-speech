import 'dart:async';
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:kittentts/kittentts.dart';

import 'english_phonemizer.dart';
import 'model_catalog.dart';
import 'model_repository.dart';

class TtsException implements Exception {
  TtsException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Owns the ONNX session. Loading is expensive, so one engine stays resident
/// for the active model and is released when the app goes idle.
class TtsService extends ChangeNotifier {
  TtsService(this._models);

  final ModelRepository _models;
  KittenTTS? _engine;
  String? _loadedModelId;
  Future<void>? _loading;
  double _loadProgress = 0;
  String _loadStatus = '';
  bool _busy = false;
  Timer? _idleTimer;
  Object? _lastError;
  Future<void> _inferenceLock = Future<void>.value();

  Future<T> _serialize<T>(Future<T> Function() task) async {
    final previous = _inferenceLock;
    final completer = Completer<void>();
    _inferenceLock = completer.future;
    await previous;
    try {
      return await task();
    } finally {
      completer.complete();
    }
  }

  static const idleUnload = Duration(seconds: 120);

  String? get loadedModelId => _loadedModelId;
  bool get isLoaded => _engine != null;
  bool get isLoading => _loading != null;
  bool get isBusy => _busy;
  double get loadProgress => _loadProgress;
  String get loadStatus => _loadStatus;
  Object? get lastError => _lastError;

  static int preferredThreads() {
    final cores = Platform.numberOfProcessors;
    if (cores <= 4) return 2;
    if (cores <= 6) return 3;
    return 4;
  }

  Future<void> load({
    String modelId = 'nano-int8',
    bool forceReload = false,
  }) async {
    if (!forceReload && _engine != null && _loadedModelId == modelId) {
      _touch();
      return;
    }
    final inFlight = _loading;
    if (inFlight != null) {
      await inFlight;
      if (_loadedModelId == modelId) return;
    }
    final future = _doLoad(modelId);
    _loading = future;
    notifyListeners();
    try {
      await future;
    } finally {
      _loading = null;
      notifyListeners();
    }
  }

  Future<void> _doLoad(String modelId) async {
    _lastError = null;
    _loadProgress = 0;
    _loadStatus = 'Preparing model';
    notifyListeners();
    try {
      await unload();
      final files = await _models.filesIfPresent(modelId);
      _loadStatus = 'Loading ${modelSpec(modelId).name}';
      _loadProgress = 0.15;
      notifyListeners();
      final engine = await KittenTTS.create(
        config: KittenTTSConfig(
          model: modelId,
          defaultVoice: 'bella',
          storageDirectory: File(files.onnxPath).parent.path,
          modelFiles: files,
          phonemizer: EnglishPhonemizer(),
          analytics: false,
          ortNumThreads: preferredThreads(),
          maxTokensPerChunk: 400,
        ),
        onProgress: (progress, [info]) {
          _loadProgress = 0.15 + progress * 0.85;
          notifyListeners();
        },
      );
      _engine = engine;
      _loadedModelId = modelId;
      _loadProgress = 1;
      _loadStatus = 'Ready';
      _touch();
    } catch (error) {
      _lastError = error;
      _engine = null;
      _loadedModelId = null;
      _loadStatus = 'Could not load model';
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<KittenTTSResult> generate(
    String text, {
    required String voice,
    required double speed,
    String modelId = 'nano-int8',
  }) {
    return _serialize(
      () => _generateUnlocked(
        text,
        voice: voice,
        speed: speed,
        modelId: modelId,
      ),
    );
  }

  Future<KittenTTSResult> _generateUnlocked(
    String text, {
    required String voice,
    required double speed,
    String modelId = 'nano-int8',
  }) async {
    await load(modelId: modelId);
    final engine = _engine;
    if (engine == null) throw TtsException('The voice engine is not ready.');
    final trimmed = text.trim();
    if (trimmed.isEmpty) throw TtsException('There is no text to read.');
    _busy = true;
    _idleTimer?.cancel();
    notifyListeners();
    try {
      return await engine.generate(trimmed, voice: voice, speed: speed);
    } on KittenTTSError catch (error) {
      throw TtsException(_friendly(error));
    } on TtsException {
      rethrow;
    } catch (error) {
      throw TtsException('Synthesis failed: $error');
    } finally {
      _busy = false;
      _touch();
      notifyListeners();
    }
  }

  Stream<KittenTTSResult> stream(
    String text, {
    required String voice,
    required double speed,
    String modelId = 'nano-int8',
  }) async* {
    final previous = _inferenceLock;
    final completer = Completer<void>();
    _inferenceLock = completer.future;
    await previous;
    try {
      yield* _streamUnlocked(
        text,
        voice: voice,
        speed: speed,
        modelId: modelId,
      );
    } finally {
      completer.complete();
    }
  }

  Stream<KittenTTSResult> _streamUnlocked(
    String text, {
    required String voice,
    required double speed,
    String modelId = 'nano-int8',
  }) async* {
    await load(modelId: modelId);
    final engine = _engine;
    if (engine == null) throw TtsException('The voice engine is not ready.');
    _busy = true;
    _idleTimer?.cancel();
    notifyListeners();
    try {
      yield* engine
          .stream(text, voice: voice, speed: speed)
          .handleError((Object error) {
        if (error is KittenTTSError) throw TtsException(_friendly(error));
        throw TtsException('Synthesis failed: $error');
      });
    } finally {
      _busy = false;
      _touch();
      notifyListeners();
    }
  }

  double estimateDurationSeconds(String text, double speed) {
    final words = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final wpm = 165 * speed.clamp(0.5, 2.0);
    return math.max(0.6, words / wpm * 60);
  }

  void _touch() {
    _idleTimer?.cancel();
    _idleTimer = Timer(idleUnload, () {
      if (_busy) {
        _touch();
        return;
      }
      unload();
    });
  }

  Future<void> unload() async {
    _idleTimer?.cancel();
    final engine = _engine;
    _engine = null;
    _loadedModelId = null;
    if (engine != null) {
      await engine.dispose().catchError((_) {});
    }
    notifyListeners();
  }

  Future<void> reloadForModelChange() async {
    final id = _loadedModelId;
    if (id == null) return;
    await load(modelId: id, forceReload: true);
  }

  String _friendly(KittenTTSError error) {
    final message = error.message;
    if (message.toLowerCase().contains('empty')) {
      return 'There is no text to read.';
    }
    return 'The voice engine hit a problem. $message';
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _engine?.dispose().catchError((_) {});
    super.dispose();
  }
}
