import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/card_content.dart';
import '../data/static_data.dart';
import '../services/quran_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/share_image.dart';

/// F8 — shareable Ayah / 99 Names / du'a poster studio.
class CardStudioScreen extends StatefulWidget {
  const CardStudioScreen({super.key});

  @override
  State<CardStudioScreen> createState() => _CardStudioScreenState();
}

class _CardStudioScreenState extends State<CardStudioScreen> {
  int _source = 0;
  int _item = 0;
  int _theme = 0;
  String _translation = '';
  bool _translationLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTranslation());
  }

  bool get _isAyah => _source == 0;

  Future<void> _loadTranslation() async {
    if (!_isAyah) return;
    final app = context.read<AppState>();
    final (surah, ayah) = cardStudioAyahs[_item % cardStudioAyahs.length];
    setState(() {
      _translationLoading = true;
      _translation = '';
    });
    final text = await QuranService.instance.verseTranslationAsync(
      surah,
      ayah,
      urdu: app.isUrdu,
    );
    if (!mounted) return;
    setState(() {
      _translation = text;
      _translationLoading = false;
    });
  }

  void _setSource(int value) {
    if (_source == value) return;
    setState(() {
      _source = value;
      _item = 0;
      _translation = '';
    });
    if (value == 0) _loadTranslation();
  }

  void _nextItem() {
    setState(() {
      _item++;
      _translation = '';
    });
    if (_isAyah) _loadTranslation();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = cardStudioThemes[_theme];
    final content = _content(app);

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: AppBar(title: Text(app.t('Card Studio', 'کارڈ اسٹوڈیو'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        children: [
          Row(
            children: [
              _SourceChip(
                label: app.t('Ayah', 'آیت'),
                icon: Icons.menu_book_rounded,
                selected: _source == 0,
                onTap: () => _setSource(0),
              ),
              const SizedBox(width: 8),
              _SourceChip(
                label: app.t('99 Names', '99 نام'),
                icon: Icons.star_rounded,
                selected: _source == 1,
                onTap: () => _setSource(1),
              ),
              const SizedBox(width: 8),
              _SourceChip(
                label: app.t('Du\'a', 'دعا'),
                icon: Icons.volunteer_activism_rounded,
                selected: _source == 2,
                onTap: () => _setSource(2),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = math.min(360.0, constraints.maxWidth);
              return Center(
                child: SizedBox(
                  width: width,
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: MediaQuery.withNoTextScaling(
                      child: _PosterCard(
                        app: app,
                        theme: theme,
                        arabic: content.arabic,
                        title: content.title,
                        subtitle: content.subtitle,
                        reference: content.reference,
                        isUrdu: app.isUrdu,
                        loading: _translationLoading && _isAyah,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _nextItem,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.shuffle_rounded, size: 18),
                  label: Text(
                    app.t('Next', 'اگلا'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () => shareWidgetAsImage(
                    context: context,
                    widget: SizedBox(
                      width: 360,
                      child: AspectRatio(
                        aspectRatio: 3 / 4,
                        child: MediaQuery.withNoTextScaling(
                          child: _PosterCard(
                            app: app,
                            theme: theme,
                            arabic: content.arabic,
                            title: content.title,
                            subtitle: content.subtitle,
                            reference: content.reference,
                            isUrdu: app.isUrdu,
                            loading: false,
                          ),
                        ),
                      ),
                    ),
                    fileName: 'sajda_card_${_source}_$_item',
                    caption:
                        '${content.reference} — ${app.t('from Sajda', 'سجدة کی جانب سے')}\n'
                        'https://play.google.com/store/apps/details?id=com.sajda.dataplus',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: Text(
                    app.t('Share', 'شیئر کریں'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            app.t('Choose a theme', 'تھیم منتخب کریں'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(cardStudioThemes.length, (i) {
              final option = cardStudioThemes[i];
              final selected = i == _theme;
              return GestureDetector(
                onTap: () => setState(() => _theme = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 46,
                  height: 46,
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? AppColors.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: option.colors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: selected
                        ? Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: option.foreground,
                          )
                        : null,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? AppColors.darkSurfaceAlt
                    : AppColors.lightBorder,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.tips_and_updates_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    app.t(
                      'Posters are generated on your device at 1080px wide — perfect for WhatsApp and Instagram. No personal data leaves your phone.',
                      'پوسٹر آپ کے فون پر 1080px چوڑائی میں بنتے ہیں — واٹس ایپ اور انسٹاگرام کے لیے بہترین۔ کوئی ذاتی ڈیٹا فون سے باہر نہیں جاتا۔',
                    ),
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.45,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _PosterContent _content(AppState app) {
    if (_source == 0) {
      final (surah, ayah) = cardStudioAyahs[_item % cardStudioAyahs.length];
      final arabic = QuranService.instance.verseArabic(surah, ayah);
      final reference =
          '${app.t('Surah', 'سورہ')} ${QuranService.instance.surah(surah).nameEn}'
          ' • ${app.t('Ayah', 'آیت')} $ayah';
      return _PosterContent(
        arabic: arabic,
        title: _translation.isNotEmpty
            ? _translation
            : app.t('Quran $surah:$ayah', 'قرآن $surah:$ayah'),
        subtitle: _translation.isNotEmpty
            ? reference
            : app.t(
                'Translation available when online',
                'ترجمہ آن لائن ہونے پر دستیاب ہے',
              ),
        reference: reference,
      );
    }
    if (_source == 1) {
      final name = allahNames[_item % allahNames.length];
      return _PosterContent(
        arabic: name.arabic,
        title: app.isUrdu ? name.ur : name.en,
        subtitle: app.isUrdu ? name.meaningUr : name.meaning,
        reference: app.t(
          '${name.number} of the 99 Names of Allah',
          'اللہ کے 99 ناموں میں سے ${name.number}',
        ),
      );
    }
    final dua = duaCardContents[_item % duaCardContents.length];
    return _PosterContent(
      arabic: dua.arabic,
      title: app.isUrdu ? dua.titleUr : dua.titleEn,
      subtitle:
          '${dua.transliteration}\n'
          '${app.isUrdu ? dua.translationUr : dua.translationEn}',
      reference: dua.source,
    );
  }
}

class _PosterContent {
  final String arabic;
  final String title;
  final String subtitle;
  final String reference;

  const _PosterContent({
    required this.arabic,
    required this.title,
    required this.subtitle,
    required this.reference,
  });
}

class _SourceChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SourceChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.14)
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.transparent,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 19,
                color: selected
                    ? AppColors.primaryDark
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? AppColors.primaryDark : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PosterCard extends StatelessWidget {
  final AppState app;
  final CardThemeOption theme;
  final String arabic;
  final String title;
  final String subtitle;
  final String reference;
  final bool isUrdu;
  final bool loading;

  const _PosterCard({
    required this.app,
    required this.theme,
    required this.arabic,
    required this.title,
    required this.subtitle,
    required this.reference,
    required this.isUrdu,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final fg = theme.foreground;
    final len = arabic.length;
    final arabicSize = len > 170
        ? 15.0
        : len > 120
        ? 17.0
        : len > 70
        ? 20.0
        : 26.0;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: theme.colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -34,
            top: -20,
            child: Icon(
              Icons.mosque_rounded,
              size: 150,
              color: fg.withValues(alpha: 0.05),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.mosque_rounded,
                      color: fg.withValues(alpha: 0.7),
                      size: 15,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'SAJDA',
                      style: TextStyle(
                        letterSpacing: 2.6,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: fg.withValues(alpha: 0.82),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        reference.split(' • ').first,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 8.5,
                          color: fg.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      arabic,
                      textAlign: TextAlign.center,
                      maxLines: 12,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: arabicSize,
                        height: 1.9,
                        color: fg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (loading)
                  Center(
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        color: fg.withValues(alpha: 0.6),
                      ),
                    ),
                  )
                else ...[
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.accent,
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    maxLines: isUrdu ? 4 : 5,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg.withValues(alpha: 0.72),
                      fontSize: 10.5,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        app.t(
                          'Sajda • Daily Athan & Qibla',
                          'سجدة • روزانہ اذان اور قبلہ',
                        ),
                        style: TextStyle(
                          color: fg.withValues(alpha: 0.45),
                          fontSize: 8,
                        ),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        'play.google.com/store/apps/details?id=com.sajda.dataplus',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          color: fg.withValues(alpha: 0.3),
                          fontSize: 5.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
