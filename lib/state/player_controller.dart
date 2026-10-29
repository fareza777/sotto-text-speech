import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../audio/audio_handler.dart';
import '../data/models.dart';

/// Library playback (exported audio, playlists). Narration has its own
/// controller because it generates audio on the fly.
class PlayerController extends ChangeNotifier {
  PlayerController(this._handler) {
    _stateSub = _handler.playerStateStream.listen((state) {
      final id = _handler.mediaItem.value?.id ?? '';
      // Narration swaps the same player; ignore its completion events.
      if (!id.startsWith('track-')) {
        _playing = state.playing &&
            state.processingState != ProcessingState.completed;
        notifyListeners();
        return;
      }
      _playing =
          state.playing && state.processingState != ProcessingState.completed;
      if (state.processingState == ProcessingState.completed) {
        _playing = false;
        _onCompleted?.call();
      }
      notifyListeners();
    });
    _posSub = _handler.positionStream.listen((value) {
      _position = value;
      notifyListeners();
    });
    _durSub = _handler.durationStream.listen((value) {
      _duration = value;
      notifyListeners();
    });
  }

  final SottoAudioHandler _handler;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;

  List<AudioTrack> _queue = const [];
  int _index = 0;
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration? _duration;
  VoidCallback? _onCompleted;
  double _playbackSpeed = 1.0;
  Timer? _sleepTimer;
  Timer? _sleepTicker;
  DateTime? _sleepAt;

  /// Set by the app so starting library audio stops narration first.
  Future<void> Function()? onBeforePlay;

  AudioTrack? get current =>
      _queue.isEmpty || _index >= _queue.length ? null : _queue[_index];
  List<AudioTrack> get queue => List.unmodifiable(_queue);
  bool get isPlaying => _playing;
  Duration get position => _position;
  Duration get duration => _duration ?? Duration.zero;
  double get playbackSpeed => _playbackSpeed;
  Duration? get sleepRemaining {
    final at = _sleepAt;
    if (at == null) return null;
    final left = at.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  double get progress {
    final total = duration.inMilliseconds;
    if (total <= 0) return 0;
    return (position.inMilliseconds / total).clamp(0, 1);
  }

  Future<void> playQueue(List<AudioTrack> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;
    await onBeforePlay?.call();
    _queue = tracks;
    _index = startIndex.clamp(0, tracks.length - 1);
    await _loadCurrent(autoPlay: true);
  }

  Future<void> playTrack(AudioTrack track) async {
    await onBeforePlay?.call();
    _queue = [track];
    _index = 0;
    await _loadCurrent(autoPlay: true);
  }

  Future<void> _loadCurrent({bool autoPlay = true}) async {
    final track = current;
    if (track == null) return;
    _onCompleted = _advanceAfterComplete;
    await _handler.loadFile(
      track.path,
      id: 'track-${track.id ?? track.path.hashCode}',
      title: track.title,
      album: 'Sotto Library',
      duration: Duration(milliseconds: track.durationMs),
      autoPlay: autoPlay,
      speed: _playbackSpeed,
    );
  }

  void _advanceAfterComplete() {
    if (_index + 1 < _queue.length) {
      _index += 1;
      _loadCurrent();
    }
  }

  Future<void> toggle() async {
    if (_playing) {
      await _handler.pause();
    } else {
      if (_queue.isEmpty) return;
      await _handler.play();
    }
  }

  Future<void> seek(Duration position) => _handler.seek(position);

  Future<void> next() async {
    if (_index + 1 >= _queue.length) return;
    _index += 1;
    await _loadCurrent();
  }

  Future<void> previous() async {
    if (_index == 0) {
      await _handler.seek(Duration.zero);
      return;
    }
    _index -= 1;
    await _loadCurrent();
  }

  Future<void> setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed.clamp(0.75, 1.75);
    await _handler.setSpeed(_playbackSpeed);
    notifyListeners();
  }

  /// Clears the library queue without touching the audio service, used when
  /// narration takes over the shared player.
  void clearCurrent() {
    _queue = const [];
    _index = 0;
    _playing = false;
    _position = Duration.zero;
    notifyListeners();
  }

  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    _sleepTicker?.cancel();
    if (duration == null) {
      _sleepAt = null;
      notifyListeners();
      return;
    }
    _sleepAt = DateTime.now().add(duration);
    _sleepTimer = Timer(duration, _sleepNow);
    _sleepTicker = Timer.periodic(const Duration(seconds: 20), (_) {
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> _sleepNow() async {
    _sleepTimer?.cancel();
    _sleepTicker?.cancel();
    final player = _handler.player;
    for (var step = 8; step >= 0; step--) {
      try {
        await player.setVolume(step / 8);
      } catch (_) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }
    await _handler.pause();
    try {
      await player.setVolume(1.0);
    } catch (_) {}
    _sleepAt = null;
    notifyListeners();
  }

  Future<void> stop() async {
    _onCompleted = null;
    await _handler.stop();
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _sleepTimer?.cancel();
    _sleepTicker?.cancel();
    super.dispose();
  }
}
