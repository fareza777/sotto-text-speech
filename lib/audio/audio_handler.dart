import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

class SottoAudioHandler extends BaseAudioHandler {
  SottoAudioHandler() {
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _player.pause();
      }
    });
  }

  final _player = AudioPlayer();

  AudioPlayer get player => _player;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;

  Future<void> setSpeed(double speed) =>
      _player.setSpeed(speed.clamp(0.5, 2.0));

  Future<void> ensureSession() async {
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration.speech());
  }

  Future<void> loadFile(
    String path, {
    required String id,
    required String title,
    String? album,
    Duration? duration,
    bool autoPlay = true,
    double speed = 1.0,
  }) async {
    await ensureSession();
    mediaItem.add(
      MediaItem(
        id: id,
        title: title,
        album: album ?? 'Sotto',
        artist: 'Sotto',
        duration: duration,
      ),
    );
    await _player.setFilePath(path);
    await _player.setSpeed(speed.clamp(0.5, 2.0));
    // just_audio's play() completes only when playback ends. Awaiting it here
    // would block the caller (and narration prefetch) for the whole track.
    if (autoPlay) unawaited(_player.play());
  }

  @override
  Future<void> play() async => unawaited(_player.play());

  @override
  Future<void> pause() => _player.pause();

  // BaseAudioHandler.stop() writes to the playback-state subject, which
  // conflicts with the live event pipe ("cannot add items while items are
  // being added from addStream"). Stopping the player emits an idle event
  // through that pipe, so the notification and lock screen update correctly
  // without touching the subject directly.
  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> onTaskRemoved() => stop();

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.rewind,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.fastForward,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: switch (_player.processingState) {
        ProcessingState.idle => AudioProcessingState.idle,
        ProcessingState.loading => AudioProcessingState.loading,
        ProcessingState.buffering => AudioProcessingState.buffering,
        ProcessingState.ready => AudioProcessingState.ready,
        ProcessingState.completed => AudioProcessingState.completed,
      },
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }
}
