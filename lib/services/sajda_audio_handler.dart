import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// Connects just_audio to audio_service so playback survives backgrounding
/// and surfaces play/pause/seek/next/previous controls in the Android media
/// notification and on the lock screen.
class SajdaAudioHandler extends BaseAudioHandler {
  /// Media-load watchdog. A stalled CDN/Icecast connection otherwise leaves
  /// the loading spinner spinning forever (and the play button disabled).
  /// On timeout the load is killed and the caller's error path shows a
  /// retryable message.
  static const loadTimeout = Duration(seconds: 20);

  final AudioPlayer player = AudioPlayer();

  /// Bumped on every stop(); lets the load-then-play sequences detect that
  /// the user closed playback while a load was in flight, so they must not
  /// start audio afterwards (ghost playback with no UI).
  int _session = 0;

  /// True while a live radio stream (no seek/next/previous) is loaded.
  bool liveMode = false;

  SajdaAudioHandler() {
    player.playbackEventStream.map(_transformEvent).pipe(playbackState);
  }

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> stop() async {
    _session++;
    await player.stop();
    await super.stop();
  }

  @override
  Future<void> skipToNext() =>
      liveMode ? Future.value() : player.seekToNext();

  @override
  Future<void> skipToPrevious() =>
      liveMode ? Future.value() : player.seekToPrevious();

  /// Runs [op] under a hard deadline. If it stalls, the player is stopped so
  /// the abandoned load can neither complete later nor start audio, then the
  /// TimeoutException propagates to the caller's error handling.
  Future<T> _guarded<T>(Future<T> Function() op) async {
    try {
      return await op().timeout(loadTimeout);
    } on TimeoutException {
      try {
        await player.stop();
      } catch (_) {}
      rethrow;
    }
  }

  /// Loads a verse-by-verse surah playlist (gapless) and starts playback.
  Future<void> playSurahSources(
    List<AudioSource> sources, {
    int initialIndex = 0,
  }) async {
    final session = _session;
    liveMode = false;
    await player.stop();
    await _guarded(
      () => player.setAudioSources(sources, initialIndex: initialIndex),
    );
    if (_session != session) return; // stopped while loading
    await player.play();
  }

  /// Loads a single ayah clip.
  Future<void> playSingleSource(AudioSource source) async {
    final session = _session;
    liveMode = false;
    await player.stop();
    await _guarded(() => player.setAudioSource(source));
    if (_session != session) return; // stopped while loading
    await player.play();
  }

  /// Loads a live Icecast radio stream.
  Future<void> playLiveUrl(String url) async {
    final session = _session;
    liveMode = true;
    await player.stop();
    await _guarded(() => player.setAudioSource(AudioSource.uri(Uri.parse(url))));
    if (_session != session) return; // stopped while loading
    await player.play();
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    final controls = liveMode
        ? [
            if (player.playing) MediaControl.pause else MediaControl.play,
            MediaControl.stop,
          ]
        : [
            MediaControl.skipToPrevious,
            if (player.playing) MediaControl.pause else MediaControl.play,
            MediaControl.skipToNext,
            MediaControl.stop,
          ];
    return PlaybackState(
      controls: controls,
      systemActions: liveMode
          ? const {MediaAction.seek, MediaAction.stop}
          : const {
              MediaAction.seek,
              MediaAction.seekForward,
              MediaAction.seekBackward,
              MediaAction.skipToNext,
              MediaAction.skipToPrevious,
            },
      androidCompactActionIndices:
          liveMode ? const [0] : const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[player.processingState]!,
      playing: player.playing,
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
    );
  }
}
