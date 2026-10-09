import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../services/quran_service.dart';
import '../services/quran_translation_provider.dart';
import '../services/tafsir_provider.dart';
import '../state/app_state.dart';
import '../state/audio_player_state.dart';
import '../theme/app_theme.dart';
import '../utils/share_image.dart';
import 'audio_player_screen.dart';
import 'mushaf_screen.dart';

class SurahScreen extends StatefulWidget {
  final SurahInfo surah;
  final int? initialVerse;
  const SurahScreen({super.key, required this.surah, this.initialVerse});

  @override
  State<SurahScreen> createState() => _SurahScreenState();
}

class _SurahScreenState extends State<SurahScreen> {
  final ScrollController _scroll = ScrollController();
  final Set<String> _bookmarks = {};
  int _viewMode = 1; // 0 = arabic only, 1 = translation, 2 = tafseer
  int? _activeVerse;

  SurahInfo get _surah => widget.surah;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _loadBookmarks();
    context.read<AppState>().setQuranPosition(_surah.number, widget.initialVerse ?? 1);
    // The default view mode is translation — start fetching immediately so
    // translations render as soon as the list builds (they never loaded
    // before unless the user tapped the segment button).
    _loadTranslations();
    final audio = context.read<AudioPlayerState>();
    audio.addListener(_onAudioChanged);
    if (audio.isPlayingSurah(_surah.number)) {
      _activeVerse = audio.currentAyah;
    }
  }

  void _loadTranslations() {
    final lang = context.read<AppState>().isUrdu ? 'ur' : 'en';
    context.read<QuranTranslationProvider>().loadSurahTranslations(
          _surah.number,
          lang: lang,
        );
  }

  @override
  void dispose() {
    context.read<AudioPlayerState>().removeListener(_onAudioChanged);
    WakelockPlus.disable();
    _scroll.dispose();
    super.dispose();
  }

  /// Follows verse-by-verse recitation: highlights and scrolls to the ayah
  /// currently being played.
  void _onAudioChanged() {
    final audio = context.read<AudioPlayerState>();
    if (!audio.isPlayingSurah(_surah.number)) {
      if (_activeVerse != null) {
        setState(() => _activeVerse = null);
      }
      return;
    }
    final playingAyah = audio.currentAyah;
    if (_activeVerse != playingAyah && mounted) {
      setState(() => _activeVerse = playingAyah);
      _scrollToVerse(playingAyah);
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

  void _playSurah() {
    final audio = context.read<AudioPlayerState>();
    if (audio.isPlayingSurah(_surah.number)) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AudioPlayerScreen()),
      );
    } else {
      audio.playSurah(_surah);
    }
  }

  void _playFromAyah(int ayah) {
    context.read<AudioPlayerState>().playSurah(_surah, fromAyah: ayah);
  }

  Future<void> _loadBookmarks() async {
    final b = await QuranService.instance.getBookmarks();
    if (!mounted) return;
    setState(() {
      _bookmarks.addAll(b);
    });
    if (widget.initialVerse != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToVerse(widget.initialVerse!);
      });
    }
  }

  void _scrollToVerse(int ayah) {
    const itemHeight = 220.0;
    final offset = (ayah - 1) * itemHeight - 80;
    _scroll.animateTo(
      offset.clamp(0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
    );
  }

  Future<void> _toggleBookmark(int ayah) async {
    await QuranService.instance.toggleBookmark(_surah.number, ayah);
    final b = await QuranService.instance.getBookmarks();
    if (!mounted) return;
    setState(() {
      _bookmarks
        ..clear()
        ..addAll(b);
    });
  }

  Future<void> _share(int ayah) async {
    final arabic = QuranService.instance.verseArabic(_surah.number, ayah);
    final translation = await QuranService.instance
        .verseTranslationAsync(_surah.number, ayah, urdu: true);
    await SharePlus.instance.share(
      ShareParams(
        text: '${_surah.nameEn} $ayah\n\n$arabic\n\n$translation\n\n- SAJDA: DAILY ATHAN & QIBLA',
      ),
    );
  }

  Future<void> _shareImage(int ayah) async {
    final arabic = QuranService.instance.verseArabic(_surah.number, ayah);
    final urdu = await QuranService.instance
        .verseTranslationAsync(_surah.number, ayah, urdu: true);
    final english = await QuranService.instance
        .verseTranslationAsync(_surah.number, ayah, urdu: false);
    if (!mounted) return;
    await shareWidgetAsImage(
      context: context,
      fileName: 'ayah_${_surah.number}_$ayah',
      caption: '${_surah.nameEn} ${_surah.number}:$ayah',
      widget: Container(
        width: 320,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B211A), Color(0xFF12351F)],
          ),
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.menu_book_rounded, color: Color(0xFFE3C46B), size: 20),
                SizedBox(width: 8),
                    Text(
                      'SAJDA: DAILY ATHAN & QIBLA',
                    style: TextStyle(
                      color: Color(0xFFE3C46B),
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              arabic,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                color: Color(0xFFF4EDDC),
                fontSize: 21,
                height: 1.9,
                fontFamily: 'serif',
              ),
            ),
            const SizedBox(height: 10),
            Text(
              urdu.isEmpty ? english : urdu,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: const TextStyle(color: Color(0xFFA8B8AE), fontSize: 13.5, height: 1.7),
            ),
            const SizedBox(height: 12),
            Text(
              '${_surah.nameEn} (${_surah.nameAr}) • آیت $ayah',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFFB9963F),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final audio = context.watch<AudioPlayerState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surahPlaying = audio.isPlayingSurah(_surah.number);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_surah.number}. ${_surah.nameEn}'),
            Text(
              '${_surah.nameAr} • ${_surah.ayahCount} ${state.t('verses', 'آیات')}',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MushafScreen()),
            ),
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: state.t('Mushaf', 'مصحف'),
          ),
          IconButton(
            onPressed: _pickReciter,
            icon: const Icon(Icons.record_voice_over_outlined),
            tooltip: '${state.t('Reciter', 'قاری')}: ${audio.reciterName}',
          ),
          IconButton(
            onPressed: _playSurah,
            icon: surahPlaying && audio.playing
                ? const Icon(Icons.pause_circle_outline_rounded)
                : const Icon(Icons.play_circle_outline_rounded),
            tooltip: state.t('Play surah', 'سورہ سنیں'),
          ),
        ],
      ),
      body: Column(
        children: [
          // View mode toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SegmentedButton<int>(
              segments: [
                ButtonSegment(
                  value: 0,
                  icon: const Icon(Icons.abc_rounded, size: 16),
                  label: Text(state.t('Arabic', 'عربی')),
                ),
                ButtonSegment(
                  value: 1,
                  icon: const Icon(Icons.translate_rounded, size: 16),
                  label: Text(state.t('Translation', 'ترجمہ')),
                ),
                ButtonSegment(
                  value: 2,
                  icon: const Icon(Icons.menu_book_rounded, size: 16),
                  label: Text(state.t('Tafsir', 'تفسیر')),
                ),
              ],
              selected: {_viewMode},
              onSelectionChanged: (s) {
                final newMode = s.first;
                setState(() => _viewMode = newMode);
                if (newMode == 1) {
                  _loadTranslations();
                } else if (newMode == 2) {
                  context.read<TafsirProvider>().loadSurahTafsir(_surah.number);
                }
              },
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                side: WidgetStatePropertyAll(
                  BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.4),
                  ),
                ),
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? AppColors.primary
                      : AppColors.lightChip,
                ),
                foregroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? Colors.white
                      : AppColors.primary,
                ),
              ),
            ),
          ),
          // Attribution of the translation source (public domain).
          if (_viewMode == 1)
            Builder(
              builder: (context) {
                final src = context
                    .watch<QuranTranslationProvider>()
                    .state
                    .source;
                if (src == null || src.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: Text(
                    '${state.t('Translation', 'ترجمہ')}: $src',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          if (_viewMode == 2)
            Builder(
              builder: (context) {
                final src = context.watch<TafsirProvider>().state.source;
                if (src == null || src.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: Text(
                    src,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          // Bismillah header (Al-Fatiha's first verse IS Bismillah and
          // At-Tawbah has none — the text is stripped from verse 1 of all
          // other surahs, so show it here like a printed mushaf).
          if (_surah.number != 1 && _surah.number != 9)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
              child: Text(
                QuranService.bismillahText,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  height: 1.9,
                  fontFamily: 'serif',
                  color: isDark ? AppColors.darkText : const Color(0xFF12352B),
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: _surah.ayahCount,
              itemBuilder: (ctx, i) {
                final ayah = i + 1;
                final isActive = _activeVerse == ayah;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    border: isActive
                        ? Border.all(color: AppColors.primary, width: 1.5)
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: AppColors.primaryPill(isDark),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '$ayah',
                                style: const TextStyle(
                                  color: AppColors.primaryDeep,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (_bookmarks.contains('${_surah.number}:$ayah'))
                              const Icon(Icons.bookmark_rounded, color: AppColors.primary, size: 20),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          QuranService.instance.verseArabic(_surah.number, ayah),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 21,
                            height: 1.9,
                            fontFamily: 'serif',
                            color: Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkText
                                : const Color(0xFF12352B),
                          ),
                        ),
                        if (_viewMode == 1) ...[
                          const SizedBox(height: 10),
                          Builder(
                            builder: (context) {
                              final translationProvider = context.watch<QuranTranslationProvider>();
                              final translation = translationProvider.state.translations[ayah];
                              final isUrdu = state.isUrdu;
                              if (translation != null && translation.isNotEmpty) {
                                return Text(
                                  translation,
                                  textAlign: isUrdu ? TextAlign.right : TextAlign.left,
                                  textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
                                  style: const TextStyle(fontSize: 14, height: 1.6),
                                );
                              }
                              if (translationProvider.state.availability == QuranTranslationAvailability.loading) {
                                return Text(
                                  state.t('Loading translation…', 'ترجمہ لوڈ ہو رہا ہے…'),
                                  style: const TextStyle(fontSize: 14, height: 1.6, color: Colors.grey),
                                );
                              }
                              return Text(
                                translationProvider.state.message ??
                                    state.t('Translation temporarily unavailable', 'ترجمہ عارضی طور پر دستیاب نہیں ہے۔'),
                                style: const TextStyle(fontSize: 14, height: 1.6, color: Colors.grey),
                              );
                            },
                          ),
                        ],
                        if (_viewMode == 2) ...[
                          const SizedBox(height: 10),
                          Builder(
                            builder: (context) {
                              final tafsirProvider = context.watch<TafsirProvider>();
                              final tafsir = tafsirProvider.state.tafsirs[ayah];
                              if (tafsir != null && tafsir.isNotEmpty) {
                                return Text(
                                  tafsir,
                                  textAlign: TextAlign.right,
                                  textDirection: TextDirection.rtl,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    height: 1.8,
                                    color: AppColors.textMuted,
                                    fontFamily: 'serif',
                                  ),
                                );
                              }
                              if (tafsirProvider.state.availability == TafsirAvailability.loading) {
                                return Text(
                                  state.t('Loading tafsir…', 'تفسیر لوڈ ہو رہی ہے…'),
                                  textAlign: TextAlign.right,
                                  textDirection: TextDirection.rtl,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    height: 1.8,
                                    color: Colors.grey,
                                    fontFamily: 'serif',
                                  ),
                                );
                              }
                              return Text(
                                tafsirProvider.state.message ??
                                    state.t('Tafsir temporarily unavailable', 'تفسیر عارضی طور پر دستیاب نہیں ہے۔'),
                                textAlign: TextAlign.right,
                                textDirection: TextDirection.rtl,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  height: 1.8,
                                  color: Colors.grey,
                                  fontFamily: 'serif',
                                ),
                              );
                            },
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => _toggleBookmark(ayah),
                              icon: Icon(
                                _bookmarks.contains('${_surah.number}:$ayah')
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_border_rounded,
                                color: _bookmarks.contains('${_surah.number}:$ayah')
                                    ? AppColors.primary
                                    : AppColors.textMuted,
                                size: 20,
                              ),
                              tooltip: state.t('Bookmark', 'نشان لگائیں'),
                            ),
                            IconButton(
                              onPressed: () => _share(ayah),
                              icon: const Icon(Icons.share_outlined, color: AppColors.textMuted, size: 20),
                              tooltip: state.t('Share', 'شیئر کریں'),
                            ),
                            IconButton(
                              onPressed: () => _shareImage(ayah),
                              icon: const Icon(Icons.image_outlined, color: AppColors.textMuted, size: 20),
                              tooltip: state.t('Share as image', 'تصویر شیئر کریں'),
                            ),
                             IconButton(
                               onPressed: () => _playFromAyah(ayah),
                               icon: Icon(
                                 isActive && audio.playing
                                     ? Icons.volume_up_rounded
                                     : Icons.headphones_outlined,
                                 color: isActive
                                     ? AppColors.primary
                                     : AppColors.textMuted,
                                 size: 20,
                               ),
                               tooltip: state.t('Play from this ayah', 'اس آیت سے سنیں'),
                             ),
                          ],
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
