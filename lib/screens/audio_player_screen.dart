import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/quran_service.dart';
import '../state/app_state.dart';
import '../state/audio_player_state.dart';
import '../theme/app_theme.dart';

String _fmt(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Full-screen player for surah recitations and live Quran radio.
/// Surah mode: play/pause, seekbar, ayah navigation, surah navigation,
/// reciter selection and repeat-ayah. Radio mode: live stream controls.
class AudioPlayerScreen extends StatefulWidget {
  const AudioPlayerScreen({super.key});

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  String? _lastError;
  bool _closeRequested = false;

  @override
  void initState() {
    super.initState();
    final audio = context.read<AudioPlayerState>();
    audio.addListener(_onAudioChanged);
  }

  @override
  void dispose() {
    context.read<AudioPlayerState>().removeListener(_onAudioChanged);
    super.dispose();
  }

  void _onAudioChanged() {
    final audio = context.read<AudioPlayerState>();
    // Playback fully stopped (X on the mini bar / Stop button / fatal error):
    // there is nothing to show on this screen anymore — close it. Several
    // notifies can fire within one stop(); close only once, or the second
    // pop would remove the screen underneath this one.
    if (!audio.hasAudio) {
      if (mounted && !_closeRequested) {
        _closeRequested = true;
        Navigator.of(context).maybePop();
      }
      return;
    }
    _closeRequested = false;
    final err = audio.error;
    if (err != null && err != _lastError && mounted) {
      _lastError = err;
      showAppSnack(context, err, error: true);
      audio.clearError();
    }
  }

  Future<void> _pickReciter() async {
    final audio = context.read<AudioPlayerState>();
    final state = context.read<AppState>();
    final chosen = await showModalBottomSheet<ReciterChoice>(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkSurface
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: RadioGroup<String>(
          groupValue: audio.reciterCode,
          onChanged: (code) {
            if (code == null) return;
            for (final r in QuranService.reciters) {
              if (r.code == code) {
                Navigator.of(ctx).pop(r);
                return;
              }
            }
          },
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 10),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 20, right: 20),
                child: Text(
                  state.t('Select Reciter', 'قاری منتخب کریں'),
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
              ),
              for (final r in QuranService.reciters)
                RadioListTile<String>(
                  value: r.code,
                  title: Text(r.name),
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null) {
      await audio.setReciter(chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioPlayerState>();
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final surah = audio.currentSurah;
    final station = audio.radioStation;
    final title = surah != null
        ? '${surah.number}. ${surah.nameEn}'
        : (station?.name ?? state.t('Now Playing', 'اب چل رہا ہے'));
    final subtitle = surah != null
        ? audio.reciterName
        : state.t('Live Quran Radio', 'لائیو قرآن ریڈیو');

    return Scaffold(
      appBar: AppBar(title: Text(state.t('Now Playing', 'اب چل رہا ہے'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          children: [
            HeroPanel(
              withPattern: true,
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              child: Column(
                children: [
                  Container(
                    width: 108,
                    height: 108,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Icon(
                      audio.isLive ? Icons.radio_rounded : Icons.menu_book_rounded,
                      color: Colors.white,
                      size: 52,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (audio.isLive) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.danger,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            state.t('LIVE', 'لائیو'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Seekbar (surah recitations only — live radio has no duration).
            if (!audio.isLive) ...[
              StreamBuilder<Duration?>(
                stream: audio.player?.durationStream,
                builder: (ctx, snap) {
                  final duration = snap.data ?? audio.duration;
                  final pos = audio.position;
                  final max = duration?.inMilliseconds.toDouble() ?? 0;
                  final value =
                      max > 0 ? pos.inMilliseconds.clamp(0, max.toInt()) : 0;
                  return Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 7,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 14,
                          ),
                        ),
                        child: Slider(
                          value: value.toDouble(),
                          max: max > 0 ? max : 1,
                          onChanged: audio.hasAudio && max > 0
                              ? (v) => audio.seek(
                                    Duration(milliseconds: v.round()),
                                  )
                              : null,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _fmt(pos),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              _fmt(duration ?? Duration.zero),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: audio.hasAudio && audio.currentAyah > 1
                        ? audio.previousAyah
                        : null,
                    icon: const Icon(Icons.skip_previous_rounded),
                    tooltip: state.t('Previous ayah', 'پچھلی آیت'),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPill(isDark),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      audio.hasAudio
                          ? '${state.t('Ayah', 'آیت')} ${audio.currentAyah} / ${audio.currentAyahCount}'
                          : '-',
                      style: const TextStyle(
                        color: AppColors.primaryDeep,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: audio.hasAudio &&
                            audio.currentAyah < audio.currentAyahCount
                        ? audio.nextAyah
                        : null,
                    icon: const Icon(Icons.skip_next_rounded),
                    tooltip: state.t('Next ayah', 'اگلی آیت'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: audio.hasAudio ? audio.toggleRepeatAyah : null,
                    icon: Icon(
                      audio.repeatAyah
                          ? Icons.repeat_one_rounded
                          : Icons.repeat_rounded,
                      color: audio.repeatAyah
                          ? AppColors.primary
                          : AppColors.textMuted,
                    ),
                    tooltip: state.t('Repeat ayah', 'آیت دہرائیں'),
                  ),
                ],
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    audio.buffering || audio.loading
                        ? Icons.wifi_tethering_rounded
                        : Icons.graphic_eq_rounded,
                    color: audio.playing ? AppColors.primary : AppColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    audio.loading
                        ? state.t('Connecting...', 'رابطہ ہو رہا ہے...')
                        : audio.buffering
                            ? state.t('Buffering...', 'بفرنگ...')
                            : state.t('Streaming live', 'لائیو نشریات'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            const SizedBox(height: 12),

            // Main controls.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!audio.isLive) ...[
                  IconButton(
                    onPressed: audio.hasAudio && audio.currentSurah != null &&
                            audio.currentSurah!.number > 1
                        ? audio.previousSurah
                        : null,
                    iconSize: 34,
                    icon: const Icon(Icons.first_page_rounded),
                    tooltip: state.t('Previous surah', 'پچھلی سورہ'),
                  ),
                  IconButton(
                    onPressed: audio.hasAudio
                        ? () => audio.seek(audio.position - const Duration(seconds: 10))
                        : null,
                    iconSize: 34,
                    icon: const Icon(Icons.replay_10_rounded),
                  ),
                ],
                const SizedBox(width: 10),
                _PlayButton(audio: audio),
                const SizedBox(width: 10),
                if (!audio.isLive) ...[
                  IconButton(
                    onPressed: audio.hasAudio
                        ? () => audio.seek(audio.position + const Duration(seconds: 10))
                        : null,
                    iconSize: 34,
                    icon: const Icon(Icons.forward_10_rounded),
                  ),
                  IconButton(
                    onPressed: audio.hasAudio && audio.currentSurah != null &&
                            audio.currentSurah!.number < 114
                        ? audio.nextSurah
                        : null,
                    iconSize: 34,
                    icon: const Icon(Icons.last_page_rounded),
                    tooltip: state.t('Next surah', 'اگلی سورہ'),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 20),

            if (!audio.isLive)
              OutlinedButton.icon(
                onPressed: _pickReciter,
                icon: const Icon(Icons.record_voice_over_outlined, size: 20),
                label: Text(
                  '${state.t('Reciter', 'قاری')}: ${audio.reciterName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            if (audio.hasAudio)
              TextButton.icon(
                onPressed: audio.stop,
                icon: const Icon(Icons.stop_circle_outlined, size: 20),
                label: Text(state.t('Stop playback', 'پلے بیک بند کریں')),
              ),

            const SizedBox(height: 6),
            Text(
              state.t(
                'Recitations: Al Quran Cloud • Radio: MP3Quran.net',
                'تلاوت: Al Quran Cloud • ریڈیو: MP3Quran.net',
              ),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final AudioPlayerState audio;
  const _PlayButton({required this.audio});

  @override
  Widget build(BuildContext context) {
    final busy = audio.loading || (!audio.playing && audio.buffering);
    return GestureDetector(
      onTap: busy ? null : audio.toggle,
      child: Container(
        width: 76,
        height: 76,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDeep],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x6600BFA5),
              blurRadius: 22,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: busy
              ? const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : Icon(
                  audio.playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 44,
                ),
        ),
      ),
    );
  }
}
