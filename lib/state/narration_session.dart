import 'dart:async';

import 'package:flutter/foundation.dart';

import '../audio/audio_handler.dart';
import '../data/models.dart';
import '../features/reader/narration_controller.dart';
import '../features/reader/reader_content.dart';
import '../tts/tts_service.dart';
import 'library_controller.dart';
import 'player_controller.dart';
import 'settings_controller.dart';

/// Owns narration above the reader route so playback survives navigation.
class NarrationSession extends ChangeNotifier {
  NarrationSession({
    required TtsService tts,
    required SottoAudioHandler handler,
    required SettingsController settings,
    required LibraryController library,
    required PlayerController player,
  })  : _tts = tts,
        _handler = handler,
        _settings = settings,
        _library = library,
        _player = player;

  final TtsService _tts;
  final SottoAudioHandler _handler;
  final SettingsController _settings;
  final LibraryController _library;
  final PlayerController _player;

  NarrationController? _controller;
  Doc? _doc;

  NarrationController? get controller => _controller;
  Doc? get doc => _doc;

  bool get isActive {
    final controller = _controller;
    if (controller == null) return false;
    return controller.isPlaying ||
        controller.isPreparing ||
        (controller.currentChunk != null && !controller.finished);
  }

  String? get chapterTitle {
    final content = _controller?.content;
    if (content == null || content.chapters.isEmpty) return null;
    return content.chapterAt(_controller!.currentOffset).title;
  }

  double get progress {
    final content = _controller?.content;
    if (content == null || content.charCount == 0) return 0;
    return (_controller!.currentOffset / content.charCount).clamp(0, 1);
  }

  NarrationController open(
    Doc doc,
    ReaderContent content, {
    int startOffset = 0,
  }) {
    final existing = _controller;
    if (existing != null && _doc?.id == doc.id) {
      existing.attach(content, startOffset: existing.currentOffset);
      return existing;
    }
    if (existing != null) unawaited(existing.stop());
    _discard();
    final controller = NarrationController(
      tts: _tts,
      handler: _handler,
      voice: () => _settings.voice,
      speed: () => _settings.speed,
      modelId: () => _settings.modelId,
      playbackSpeed: () => _settings.playbackSpeed,
      onTakeover: _player.clearCurrent,
      onProgress: (offset, progress) {
        final id = _doc?.id;
        if (id != null) _library.saveDocProgress(id, progress, offset);
        notifyListeners();
      },
    );
    controller.attach(content, startOffset: startOffset);
    controller.addListener(_onControllerChanged);
    _controller = controller;
    _doc = doc;
    notifyListeners();
    return controller;
  }

  void _onControllerChanged() => notifyListeners();

  Future<void> toggle() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.toggle();
  }

  Future<void> setPlaybackSpeed(double speed) async {
    await _controller?.setPlaybackSpeed(speed);
  }

  Future<void> stop() async {
    final controller = _controller;
    _controller = null;
    _doc = null;
    if (controller != null) {
      controller.removeListener(_onControllerChanged);
      await controller.stop();
      controller.dispose();
    }
    notifyListeners();
  }

  void _discard() {
    final controller = _controller;
    if (controller == null) return;
    controller.removeListener(_onControllerChanged);
    controller.dispose();
    _controller = null;
    _doc = null;
  }

  @override
  void dispose() {
    _discard();
    super.dispose();
  }
}
