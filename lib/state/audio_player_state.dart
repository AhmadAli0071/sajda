import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/quran_audio_service.dart';
import '../services/quran_service.dart';
import '../services/radio_service.dart';
import '../services/sajda_audio_handler.dart';

/// App-wide audio state for:
///  - Surah recitations (Al Quran Cloud API + islamic.network CDN,
///    copyright-free verse-by-verse streams)
///  - Live Quran radio (MP3Quran.net Icecast streams, free public broadcast)
///
/// Playback runs through [SajdaAudioHandler] (just_audio + audio_service),
/// so media-notification controls and background playback work out of the box.
class AudioPlayerState extends ChangeNotifier {
  SajdaAudioHandler? _handler;
  AudioPlayer? _player;
  StreamSubscription? _stateSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _sequenceSub;
  StreamSubscription? _processingSub;
  final Completer<void> _ready = Completer<void>();
  int _token = 0;

  static const _kReciter = 'sajda_quran_reciter';

  SurahInfo? currentSurah;
  RadioStation? radioStation;
  String reciterCode = QuranService.reciters.first.code;
  String reciterName = QuranService.reciters.first.name;

  bool _playing = false;
  bool _loading = false;
  bool _buffering = false;
  bool _repeatAyah = false;
  Duration _position = Duration.zero;
  Duration? _duration;
  int _ayahIndex = 0; // 0-based index within the surah playlist
  int _ayahCount = 0;
  String? _error;

  // just_audio's positionStream emits ~4x/sec. Notifying watchers at that
  // rate rebuilds every screen watching AudioPlayerState (surah, radio,
  // audio player) continuously during playback. Throttle to 1/sec with a
  // trailing timer so the final position always reaches the UI.
  DateTime _lastPositionNotify = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _positionNotifyTimer;
  bool _disposed = false;

  AudioPlayerState() {
    unawaited(_bootstrap());
  }

  // ---------- Getters ----------

  bool get playing => _playing;
  bool get loading => _loading;
  bool get buffering => _buffering;
  bool get repeatAyah => _repeatAyah;
  Duration get position => _position;
  Duration? get duration => _duration;
  String? get error => _error;
  bool get isLive => radioStation != null;
  bool get hasAudio => currentSurah != null || radioStation != null;
  bool get isReady => _ready.isCompleted && _player != null;

  /// 1-based ayah number currently playing (surah mode only).
  int get currentAyah => _ayahIndex + 1;
  int get currentAyahCount => _ayahCount;

  bool isPlayingSurah(int surahNumber) =>
      currentSurah?.number == surahNumber && radioStation == null;

  bool isPlayingRadio(RadioStation station) =>
      radioStation?.url == station.url;

  // ---------- Bootstrap ----------

  Future<void> _bootstrap() async {
    await _loadSavedReciter();
    try {
      _handler = await AudioService.init(
        builder: () => SajdaAudioHandler(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'app.sajda.dataplus.audio',
          androidNotificationChannelName: 'Quran Audio',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
        ),
      );
    } catch (_) {
      _handler = null;
    } finally {
      _player = _handler?.player;
      if (_player != null) _subscribe(_player!);
      _ready.complete();
      notifyListeners();
    }
  }

  Future<void> _loadSavedReciter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_kReciter);
      if (saved == null) return;
      for (final r in QuranService.reciters) {
        if (r.code == saved) {
          reciterCode = r.code;
          reciterName = r.name;
          return;
        }
      }
    } catch (_) {}
  }

  void _subscribe(AudioPlayer player) {
    _stateSub = player.playerStateStream.listen((state) {
      // Stray events from an aborted load can still arrive after stop()
      // (just_audio warns about unconsumed events on platform switches).
      // Never let them resurrect `playing` once nothing is loaded.
      if (!hasAudio) return;
      // Ground truth: the media is loaded (ready = audible/imminent). Any
      // lingering play() bookkeeping await must not keep the loader spinning
      // (e.g. a dropped platform response leaves `await play()` hung on some
      // devices while audio is already playing) — clear it here.
      var changed = false;
      if (_loading && state.processingState == ProcessingState.ready) {
        _loading = false;
        changed = true;
      }
      if (_playing != state.playing) {
        _playing = state.playing;
        changed = true;
      }
      if (changed) notifyListeners();
    });
    _processingSub = player.processingStateStream.listen((state) {
      // An interrupted load can emit a trailing `buffering` AFTER stop() has
      // already reset the flags — and no `idle` ever follows it, so the
      // play-button loader spun forever. Only trust these events while
      // something is actually loaded.
      final buffering = state == ProcessingState.buffering && hasAudio;
      if (_buffering != buffering) {
        _buffering = buffering;
        notifyListeners();
      }
    });
    _positionSub = player.positionStream.listen((p) {
      _position = p;
      _notifyPositionThrottled();
    });
    _durationSub = player.durationStream.listen((d) {
      _duration = d;
      notifyListeners();
    });
    _sequenceSub = player.sequenceStateStream.listen((s) {
      final index = s.currentIndex;
      if (index == null) return;
      final count = s.sequence.length;
      if (_ayahIndex != index || _ayahCount != count) {
        _ayahIndex = index;
        _ayahCount = count;
        _position = Duration.zero;
        notifyListeners();
      }
    });
  }

  // ---------- Playback ----------

  Future<void> playSurah(
    SurahInfo surah, {
    int fromAyah = 1,
  }) async {
    await _ready.future;
    final handler = _handler;
    if (handler == null) {
      _setError('Audio playback is unavailable on this device');
      return;
    }

    final token = ++_token;
    _loading = true;
    _error = null;
    radioStation = null;
    currentSurah = surah;
    _ayahCount = surah.ayahCount;
    _ayahIndex = (fromAyah - 1).clamp(0, surah.ayahCount - 1);
    _position = Duration.zero;
    _duration = null;
    notifyListeners();

    try {
      final recitation = await QuranAudioService.instance
          .getSurah(surah.number, reciterCode);
      if (recitation == null || recitation.ayahUrls.isEmpty) {
        throw const AudioApiException(
          'Recitation is not available for this surah',
        );
      }
      _throwIfStale(token);

      final startIndex = (fromAyah - 1).clamp(0, recitation.ayahUrls.length - 1);
      final sources = recitation.ayahUrls
          .map((url) => AudioSource.uri(Uri.parse(url)))
          .toList(growable: false);

      _updateMediaItem(
        id: 'surah_${surah.number}_$reciterCode',
        title: '${surah.number}. ${surah.nameEn}',
        subtitle: reciterName,
        album: 'Quran Recitation',
      );
      await handler.playSurahSources(sources, initialIndex: startIndex);
      await _player?.setLoopMode(_repeatAyah ? LoopMode.one : LoopMode.off);
      _throwIfStale(token);
      _loading = false;
      notifyListeners();
    } catch (e) {
      if (_isStale(token)) return;
      _loading = false;
      _buffering = false;
      if (e is PlayerInterruptedException) {
        notifyListeners();
        return;
      }
      currentSurah = null;
      _setError(e is AudioApiException
          ? e.message
          : 'Could not play this surah. Please check your connection and try again.');
    }
  }

  Future<void> playRadio(RadioStation station) async {
    await _ready.future;
    final handler = _handler;
    if (handler == null) {
      _setError('Audio playback is unavailable on this device');
      return;
    }

    final token = ++_token;
    _loading = true;
    _error = null;
    currentSurah = null;
    _ayahIndex = 0;
    _ayahCount = 0;
    _position = Duration.zero;
    _duration = null;
    radioStation = station;
    notifyListeners();

    try {
      _updateMediaItem(
        id: 'radio_${station.id}',
        title: station.name,
        subtitle: 'Live Quran Radio',
        album: 'Quran Radio',
      );
      await handler.playLiveUrl(station.url);
      _throwIfStale(token);
      _loading = false;
      notifyListeners();
    } catch (e) {
      if (_isStale(token)) return;
      _loading = false;
      _buffering = false;
      if (e is PlayerInterruptedException) {
        notifyListeners();
        return;
      }
      radioStation = null;
      _setError('Could not tune into this station. Please try again later.');
    }
  }

  Future<void> toggle() async {
    final player = _player;
    if (player == null) return;
    if (player.playing) {
      await _handler?.pause();
    } else {
      await _handler?.play();
    }
  }

  Future<void> seek(Duration d) async {
    final duration = _duration;
    var target = d;
    if (duration != null && d > duration) target = duration;
    if (d.isNegative) target = Duration.zero;
    await _handler?.seek(target);
    // A user-driven seek must feel instant — don't wait for the throttle.
    _position = target;
    _flushPositionNotify();
  }

  Future<void> nextAyah() async {
    await _player?.seekToNext();
  }

  Future<void> previousAyah() async {
    await _player?.seekToPrevious();
  }

  Future<void> nextSurah() async {
    final surah = currentSurah;
    if (surah == null || surah.number >= 114) return;
    await playSurah(QuranService.instance.surah(surah.number + 1));
  }

  Future<void> previousSurah() async {
    final surah = currentSurah;
    if (surah == null || surah.number <= 1) return;
    await playSurah(QuranService.instance.surah(surah.number - 1));
  }

  Future<void> setReciter(ReciterChoice reciter) async {
    if (reciter.code == reciterCode) return;
    reciterCode = reciter.code;
    reciterName = reciter.name;
    notifyListeners();
    unawaited(_persistReciter(reciter.code));
    final surah = currentSurah;
    if (surah != null) {
      await playSurah(surah, fromAyah: currentAyah);
    }
  }

  Future<void> toggleRepeatAyah() async {
    _repeatAyah = !_repeatAyah;
    await _player?.setLoopMode(_repeatAyah ? LoopMode.one : LoopMode.off);
    notifyListeners();
  }

  Future<void> stop() async {
    _token++;
    try {
      await _handler?.stop();
    } catch (_) {
      // A failing native stop must never leave the UI stuck with a dead
      // player — the state reset below runs either way.
    } finally {
      currentSurah = null;
      radioStation = null;
      _ayahIndex = 0;
      _ayahCount = 0;
      _position = Duration.zero;
      _duration = null;
      _playing = false;
      _loading = false;
      // The processing-state stream may never emit again after an abrupt
      // stop, leaving `buffering` stuck true — which kept the play-button
      // loader spinning forever. Reset it explicitly.
      _buffering = false;
      _error = null;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ---------- Internals ----------

  /// Coalesces position-stream notifications to ~1/sec. A trailing timer
  /// guarantees the final position of a seek or track change always lands.
  void _notifyPositionThrottled() {
    if (_disposed) return;
    final now = DateTime.now();
    final elapsed = now.difference(_lastPositionNotify);
    if (elapsed >= const Duration(seconds: 1)) {
      _lastPositionNotify = now;
      notifyListeners();
    } else {
      _positionNotifyTimer ??=
          Timer(const Duration(seconds: 1) - elapsed, _flushPositionNotify);
    }
  }

  void _flushPositionNotify() {
    _positionNotifyTimer?.cancel();
    _positionNotifyTimer = null;
    if (_disposed) return;
    _lastPositionNotify = DateTime.now();
    notifyListeners();
  }

  AudioPlayer? get player => _player;

  void _updateMediaItem({
    required String id,
    required String title,
    required String subtitle,
    required String album,
  }) {
    _handler?.mediaItem.add(MediaItem(
      id: id,
      album: album,
      title: title,
      artist: subtitle,
      genre: album,
    ));
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  void _throwIfStale(int token) {
    if (_isStale(token)) throw PlayerInterruptedException('stale');
  }

  bool _isStale(int token) => token != _token;

  Future<void> _persistReciter(String code) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kReciter, code);
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    _positionNotifyTimer?.cancel();
    _stateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _sequenceSub?.cancel();
    _processingSub?.cancel();
    _player?.dispose();
    super.dispose();
  }
}
