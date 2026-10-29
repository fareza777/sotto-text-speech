import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../audio/audio_handler.dart';
import '../../core/wav_writer.dart';
import '../../tts/tts_service.dart';
import 'reader_content.dart';

class WordSpan {
  const WordSpan({
    required this.start,
    required this.end,
    required this.startTime,
    required this.endTime,
  });

  final int start;
  final int end;
  final double startTime;
  final double endTime;
}

class NarrationChunk {
  NarrationChunk({
    required this.file,
    required this.sentences,
    required this.words,
    required this.duration,
    required this.firstSentenceIndex,
  });

  final File file;
  final List<SentenceSpan> sentences;
  final List<WordSpan> words;
  final Duration duration;
  final int firstSentenceIndex;
}

class NarrationController extends ChangeNotifier {
  NarrationController({
    required TtsService tts,
    required SottoAudioHandler handler,
    required String Function() voice,
    required double Function() speed,
    required String Function() modelId,
    required void Function(int offset, double progress) onProgress,
    double Function()? playbackSpeed,
    VoidCallback? onTakeover,
  }) : _tts = tts,
       _handler = handler,
       _voice = voice,
       _speed = speed,
       _modelId = modelId,
       _onProgress = onProgress,
       _playbackSpeed = playbackSpeed ?? _one,
       _onTakeover = onTakeover {
    _positionSub = _handler.positionStream.listen(_onPosition);
    _stateSub = _handler.playerStateStream.listen(_onPlayerState);
  }

  final TtsService _tts;
  final SottoAudioHandler _handler;
  final String Function() _voice;
  final double Function() _speed;
  final String Function() _modelId;
  final void Function(int offset, double progress) _onProgress;
  final double Function() _playbackSpeed;
  final VoidCallback? _onTakeover;

  static double _one() => 1.0;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _stateSub;

  ReaderContent? _content;
  int _sentenceIndex = 0;
  NarrationChunk? _current;
  NarrationChunk? _queued;
  Future<NarrationChunk?>? _queuedFuture;
  bool _playing = false;
  bool _preparing = false;
  bool _advancing = false;
  Future<NarrationChunk?>? _prewarmFuture;
  int? _prewarmIndex;
  String? _error;
  int _token = 0;
  WordSpan? _word;
  int _lastSavedOffset = -1;
  DateTime _lastSave = DateTime.fromMillisecondsSinceEpoch(0);

  ReaderContent? get content => _content;
  int get sentenceIndex => _sentenceIndex;
  NarrationChunk? get currentChunk => _current;
  bool get isPlaying => _playing;
  bool get isPreparing => _preparing;
  bool get finished {
    final content = _content;
    if (content == null) return false;
    return _current != null &&
        !_playing &&
        !_preparing &&
        _sentenceIndex >= content.sentences.length - 1;
  }
  String? get error => _error;
  WordSpan? get currentWord => _word;

  SentenceSpan? get currentSentence {
    final content = _content;
    if (content == null || content.sentences.isEmpty) return null;
    return content.sentences[_sentenceIndex.clamp(
      0,
      content.sentences.length - 1,
    )];
  }

  int get currentOffset => currentSentence?.start ?? 0;

  void attach(ReaderContent content, {int startOffset = 0}) {
    _content = content;
    _sentenceIndex = content.sentenceIndexAt(startOffset);
    _prewarmFuture = null;
    _prewarmIndex = null;
    notifyListeners();
  }

  /// Builds the first passage while the reader is still idle, so pressing play
  /// starts audio almost immediately even on slow phones.
  Future<void> prewarm() async {
    final content = _content;
    if (content == null || _current != null || _preparing) return;
    final index = _sentenceIndex;
    if (_prewarmIndex == index) return;
    final token = _token;
    _prewarmIndex = index;
    _prewarmFuture = _buildChunk(index, token, firstChunk: true);
  }

  Future<void> setPlaybackSpeed(double speed) =>
      _handler.setSpeed(speed.clamp(0.75, 1.75));

  Future<void> startAt(int offset) async {
    final content = _content;
    if (content == null || content.sentences.isEmpty) return;
    await _playFromSentence(content.sentenceIndexAt(offset));
  }

  Future<void> _playFromSentence(int index) async {
    final content = _content;
    if (content == null) return;
    final target = index.clamp(0, content.sentences.length - 1);
    final usePrewarm = _prewarmIndex == target && _prewarmFuture != null;
    final prewarmFuture = usePrewarm ? _prewarmFuture : null;
    final token = usePrewarm ? _token : ++_token;
    _prewarmFuture = null;
    _prewarmIndex = null;
    _sentenceIndex = target;
    _error = null;
    _preparing = true;
    _playing = false;
    _word = null;
    _queued = null;
    _queuedFuture = null;
    notifyListeners();
    try {
      await _handler.stop();
      _onTakeover?.call();
      final chunk = prewarmFuture != null
          ? await prewarmFuture
          : await _buildChunk(
              _sentenceIndex,
              token,
              firstChunk: _current == null,
            );
      if (token != _token || chunk == null) return;
      _current = chunk;
      _preparing = false;
      notifyListeners();
      await _handler.loadFile(
        chunk.file.path,
        id: 'narration-${chunk.firstSentenceIndex}',
        title: content.title,
        album: 'Sotto Reader',
        duration: chunk.duration,
        speed: _playbackSpeed(),
      );
      _playing = true;
      notifyListeners();
      _prefetchNext();
    } catch (error) {
      if (token != _token) return;
      _preparing = false;
      _error = error is TtsException
          ? error.message
          : 'Could not generate audio.';
      notifyListeners();
    }
  }

  Future<NarrationChunk?> _buildChunk(
    int startIndex,
    int token, {
    bool firstChunk = false,
  }) async {
    final content = _content;
    if (content == null) return null;
    // Start talking sooner on slow phones; later chunks are longer so playback
    // stays ahead of synthesis.
    final limit = firstChunk ? 1 : 3;
    final sentences = <SentenceSpan>[];
    var chars = 0;
    var i = startIndex;
    while (i < content.sentences.length &&
        sentences.length < limit &&
        (chars < 240 || sentences.isEmpty)) {
      final sentence = content.sentences[i];
      sentences.add(sentence);
      chars += sentence.text.length;
      i += 1;
    }
    if (sentences.isEmpty) return null;

    final segments = <Float32List>[];
    final words = <WordSpan>[];
    var elapsed = 0.0;
    var sampleRate = 24000;

    for (var s = 0; s < sentences.length; s++) {
      final sentence = sentences[s];
      final result = await _tts.generate(
        sentence.text,
        voice: _voice(),
        speed: _speed(),
        modelId: _modelId(),
      );
      if (token != _token) return null;
      sampleRate = result.sampleRate;
      if (segments.isNotEmpty) {
        segments.add(Float32List((0.11 * sampleRate).round()));
        elapsed += 0.11;
      }
      final wordOffsets = _wordOffsets(sentence.text);
      for (final timing in result.wordTimings) {
        final range = wordOffsets[timing.wordIndex];
        if (range == null) continue;
        words.add(
          WordSpan(
            start: sentence.start + range.$1,
            end: sentence.start + range.$2,
            startTime: elapsed + timing.startTime,
            endTime: elapsed + timing.endTime,
          ),
        );
      }
      segments.add(result.samples);
      elapsed += result.duration;
    }

    final total = segments.fold<int>(0, (sum, s) => sum + s.length);
    final merged = Float32List(total);
    var offset = 0;
    for (final segment in segments) {
      merged.setAll(offset, segment);
      offset += segment.length;
    }

    final dir = Directory(
      p.join((await getTemporaryDirectory()).path, 'narration'),
    );
    await dir.create(recursive: true);
    final file = File(
      p.join(dir.path, 'chunk_${DateTime.now().microsecondsSinceEpoch}.wav'),
    );
    await file.writeAsBytes(encodeWav(merged, sampleRate), flush: true);

    debugPrint(
      'SOTTO_NARR chunk sentences=${sentences.length} '
      'words=${words.length} dur=${(merged.length / sampleRate).toStringAsFixed(2)}',
    );
    final chunk = NarrationChunk(
      file: file,
      sentences: sentences,
      words: words,
      duration: Duration(
        milliseconds: (merged.length / sampleRate * 1000).round(),
      ),
      firstSentenceIndex: startIndex,
    );
    _cleanupOldChunks(
      keep: {
        file.path,
        if (_current != null) _current!.file.path,
        if (_queued != null) _queued!.file.path,
      },
    );
    return chunk;
  }

  List<(int, int)> _wordOffsets(String text) {
    final spans = <(int, int)>[];
    for (final match in RegExp(r'\S+').allMatches(text)) {
      spans.add((match.start, match.end));
    }
    return spans;
  }

  void _prefetchNext() {
    final content = _content;
    final current = _current;
    if (content == null || current == null) return;
    final nextIndex = current.firstSentenceIndex + current.sentences.length;
    if (nextIndex >= content.sentences.length) return;
    final token = _token;
    _queuedFuture ??= _buildChunk(nextIndex, token)
        .then((chunk) {
          if (token != _token) return null;
          _queued = chunk;
          return chunk;
        })
        .catchError((Object _) => null);
  }

  void _onPlayerState(PlayerState state) {
    if (state.processingState == ProcessingState.completed) {
      final id = _handler.mediaItem.value?.id ?? '';
      final mine = _current == null
          ? null
          : 'narration-${_current!.firstSentenceIndex}';
      if (mine == null || id != mine) return;
      _handleChunkComplete();
      return;
    }
    _playing = state.playing;
    notifyListeners();
  }

  Future<void> _handleChunkComplete() async {
    if (_advancing) return;
    _advancing = true;
    try {
      final content = _content;
      final current = _current;
      if (content == null || current == null) return;
      final nextIndex = current.firstSentenceIndex + current.sentences.length;
      if (nextIndex >= content.sentences.length) {
        _playing = false;
        _sentenceIndex = content.sentences.length - 1;
        _onProgress(current.sentences.last.start, 1);
        notifyListeners();
        return;
      }
      _preparing = _queued == null;
      _sentenceIndex = nextIndex;
      notifyListeners();
      NarrationChunk? next = _queued;
      if (next == null) {
        final pending = _queuedFuture;
        if (pending != null) next = await pending;
      }
      _queued = null;
      _queuedFuture = null;
      if (next == null) {
        await _playFromSentence(nextIndex);
        return;
      }
      _current = next;
      _word = null;
      _preparing = false;
      await _handler.loadFile(
        next.file.path,
        id: 'narration-${next.firstSentenceIndex}',
        title: content.title,
        album: 'Sotto Reader',
        duration: next.duration,
        speed: _playbackSpeed(),
      );
      _playing = true;
      notifyListeners();
      _prefetchNext();
    } finally {
      _advancing = false;
    }
  }

  void _onPosition(Duration position) {
    final chunk = _current;
    if (chunk == null) return;
    final seconds = position.inMilliseconds / 1000.0;
    WordSpan? active;
    for (final word in chunk.words) {
      if (seconds >= word.startTime && seconds < word.endTime) {
        active = word;
        break;
      }
    }
    // Keep the last word highlighted through the short gaps between words so
    // the sentence highlight does not flicker.
    if (active != null && active != _word) {
      _word = active;
      debugPrint(
        'SOTTO_NARR t=${seconds.toStringAsFixed(2)} word=${active?.start} '
        'words=${chunk.words.length} first=${chunk.words.isEmpty ? '-' : chunk.words.first.startTime}',
      );
      notifyListeners();
    }
    final content = _content;
    if (content != null && content.charCount > 0) {
      final offset = active?.start ?? currentOffset;
      final now = DateTime.now();
      if (offset != _lastSavedOffset &&
          (now.difference(_lastSave).inSeconds >= 3 || offset == 0)) {
        _lastSavedOffset = offset;
        _lastSave = now;
        _onProgress(offset, (offset / content.charCount).clamp(0, 1));
      }
    }
  }

  Future<void> pause() async {
    await _handler.pause();
    _playing = false;
    notifyListeners();
  }

  Future<void> resume() async {
    await _handler.play();
    _playing = true;
    notifyListeners();
  }

  Future<void> toggle() async {
    try {
      if (_playing) {
        await pause();
      } else {
        if (_current == null) {
          await startAt(currentOffset);
        } else {
          await resume();
        }
      }
    } catch (error) {
      _preparing = false;
      _playing = false;
      _error = error is TtsException
          ? error.message
          : 'Playback could not start.';
      notifyListeners();
    }
  }

  Future<void> nextSentence() async {
    final content = _content;
    if (content == null) return;
    await _playFromSentence(
      (_sentenceIndex + 1).clamp(0, content.sentences.length - 1),
    );
  }

  Future<void> previousSentence() async {
    final content = _content;
    if (content == null) return;
    await _playFromSentence(
      (_sentenceIndex - 1).clamp(0, content.sentences.length - 1),
    );
  }

  Future<void> seek(Duration position) => _handler.seek(position);

  Future<void> restartForSpeedChange() async {
    if (_current == null) return;
    final wasPlaying = _playing;
    await _playFromSentence(_sentenceIndex);
    if (!wasPlaying) await pause();
  }

  Future<void> stop() async {
    _token += 1;
    _prewarmFuture = null;
    _prewarmIndex = null;
    _playing = false;
    _preparing = false;
    _current = null;
    _queued = null;
    _queuedFuture = null;
    _word = null;
    await _handler.stop();
    _cleanupOldChunks(keep: const {});
    notifyListeners();
  }

  void _cleanupOldChunks({required Set<String> keep}) {
    unawaited(() async {
      try {
        final dir = Directory(
          p.join((await getTemporaryDirectory()).path, 'narration'),
        );
        if (!await dir.exists()) return;
        final files = await dir.list().toList();
        for (final entity in files) {
          if (entity is File && !keep.contains(entity.path)) {
            await entity.delete().catchError((_) => entity);
          }
        }
      } catch (_) {
        // Cache cleanup is best effort.
      }
    }());
  }

  @override
  void dispose() {
    _token += 1;
    _positionSub?.cancel();
    _stateSub?.cancel();
    super.dispose();
  }
}
