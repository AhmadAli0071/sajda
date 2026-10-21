import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/background_audio_permissions.dart';
import '../services/radio_service.dart';
import '../state/app_state.dart';
import '../state/audio_player_state.dart';
import '../theme/app_theme.dart';
import 'audio_player_screen.dart';

/// Live Quran Radio — free public Icecast streams from MP3Quran.net.
class RadioScreen extends StatefulWidget {
  const RadioScreen({super.key});

  @override
  State<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends State<RadioScreen> {
  List<RadioStation>? _stations;
  Object? _failure;
  bool _fetching = true;
  String _query = '';
  String _category = RadioCategory.all;

  @override
  void initState() {
    super.initState();
    _load();
    final audio = context.read<AudioPlayerState>();
    audio.addListener(_onAudioError);
  }

  @override
  void dispose() {
    context.read<AudioPlayerState>().removeListener(_onAudioError);
    super.dispose();
  }

  void _onAudioError() {
    final audio = context.read<AudioPlayerState>();
    final err = audio.error;
    if (err != null && mounted) {
      showAppSnack(context, err, error: true);
      audio.clearError();
    }
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() => _fetching = true);
    try {
      final stations = await RadioService.instance.getStations(
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _stations = stations;
        _failure = null;
        _fetching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _failure = e;
        _fetching = false;
      });
    }
  }

  Future<void> _onTapStation(AudioPlayerState audio, RadioStation station) async {
    if (audio.isPlayingRadio(station)) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AudioPlayerScreen()),
      );
    } else {
      await ensureBackgroundAudioReady(context);
      if (!mounted) return;
      audio.playRadio(station);
    }
  }

  List<RadioStation> get _filtered {
    final stations = _stations;
    if (stations == null) return const [];
    final q = _query.trim().toLowerCase();
    return stations.where((s) {
      if (_category != RadioCategory.all && s.category != _category) {
        return false;
      }
      if (q.isEmpty) return true;
      return s.displayName.toLowerCase().contains(q) ||
          s.name.toLowerCase().contains(q) ||
          (s.reciter?.toLowerCase().contains(q) ?? false);
    }).toList(growable: false);
  }

  String _categoryLabel(AppState state, String code) {
    switch (code) {
      case RadioCategory.recitation:
        return state.t('Recitation', 'تلاوت');
      case RadioCategory.translation:
        return state.t('Translation', 'ترجمہ');
      case RadioCategory.tafsir:
        return state.t('Tafsir', 'تفسیر');
      case RadioCategory.adhkar:
        return state.t('Adhkar', 'اذکار');
      case RadioCategory.hadith:
        return state.t('Hadith', 'حدیث');
      case RadioCategory.occasion:
        return state.t('Occasions', 'مناسبات');
      default:
        return state.t('All', 'سب');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final audio = context.watch<AudioPlayerState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stations = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: Text(state.t('Quran Radio', 'قرآن ریڈیو')),
        actions: [
          IconButton(
            onPressed: () => _load(forceRefresh: true),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: state.t('Refresh', 'ریفریش'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: state.t('Search station...', 'اسٹیشن تلاش کریں...'),
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () => setState(() => _query = ''),
                      ),
              ),
            ),
          ),
          // Category filter chips (All + Recitation/Translation/Tafsir/…).
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final code in [RadioCategory.all, ...RadioCategory.values])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_categoryLabel(state, code)),
                      selected: _category == code,
                      onSelected: (_) => setState(() => _category = code),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _fetching
                ? const AppLoader()
                : _failure != null
                    ? ErrorView(
                        message: _failure is RadioApiException
                            ? (_failure as RadioApiException).message
                            : state.t('Could not load radio stations',
                                'ریڈیو اسٹیشن لوڈ نہیں ہو سکے'),
                        onRetry: _load,
                      )
                    : stations.isEmpty
                        ? EmptyView(
                            message: state.t('No stations found',
                                'کوئی اسٹیشن نہیں ملا'),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: stations.length,
                            itemBuilder: (ctx, i) {
                              final station = stations[i];
                              final active = audio.isPlayingRadio(station);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: GlassCard(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  color: active
                                      ? (isDark
                                          ? AppColors.darkSurfaceAlt
                                          : AppColors.primaryLight)
                                      : null,
                                  onTap: () => _onTapStation(audio, station),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          gradient: active
                                              ? const LinearGradient(
                                                  colors: [
                                                    AppColors.primary,
                                                    AppColors.primaryDeep
                                                  ],
                                                )
                                              : null,
                                          color: active
                                              ? null
                                              : AppColors.primaryPill(isDark),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          active
                                              ? Icons.graphic_eq_rounded
                                              : Icons.radio_rounded,
                                          color: active
                                              ? Colors.white
                                              : AppColors.primary,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              station.displayName,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                    fontWeight: active
                                                        ? FontWeight.w800
                                                        : null,
                                                  ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            // Translation stations name the
                                            // reciter under the friendly label.
                                            if (station.reciter != null) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                station.reciter!,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color: isDark
                                                          ? AppColors.darkMuted
                                                          : AppColors
                                                              .lightSecondaryText,
                                                    ),
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (active)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.danger,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            state.t('LIVE', 'لائیو'),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      IconButton(
                                        onPressed: () =>
                                            _onTapStation(audio, station),
                                        icon: active
                                            ? (audio.loading
                                                ? const SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                                  )
                                                : Icon(
                                                    audio.playing
                                                        ? Icons
                                                            .pause_circle_filled
                                                        : Icons
                                                            .play_circle_fill,
                                                    color: AppColors.primary,
                                                    size: 32,
                                                  ))
                                            : const Icon(
                                                Icons.play_circle_outline_rounded,
                                                color: AppColors.primary,
                                                size: 32,
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
